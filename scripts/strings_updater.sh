#!/bin/bash

# Check if required environment variables are set
if [ -z "$SPREADSHEET_ID" ]; then
    echo "Error: SPREADSHEET_ID is not set."
    exit 1
fi

if [ -z "$RANGE_NAME" ]; then
    echo "Error: RANGE_NAME is not set."
    exit 1
fi

if [ -z "$CREDENTIALS_JSON" ]; then
    echo "Error: CREDENTIALS_JSON is not set."
    exit 1
fi

# Decode credentials from the environment variable
echo "$CREDENTIALS_JSON" | base64 --decode > credentials.json

# Define languages and their corresponding columns as environment variables
LANGUAGES=("en" "de" "fr")  # Update this array with your desired languages
LANGUAGE_COLUMNS=(3 4 5)     # Update this array with the column numbers corresponding to the languages

# Install required dependencies if not installed
pip install gspread oauth2client xmltodict --quiet

# Python script embedded within the shell script
python3 <<EOF
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import xml.etree.ElementTree as ET
import os

# Configuration from environment variables
SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']
SPREADSHEET_ID = "$SPREADSHEET_ID"
RANGE_NAME = "$RANGE_NAME"
LANGUAGES = ${LANGUAGES[@]}
LANGUAGE_COLUMNS = ${LANGUAGE_COLUMNS[@]}

def authenticate_google_sheets(credentials_path):
    creds = ServiceAccountCredentials.from_json_keyfile_name(credentials_path, SCOPES)
    client = gspread.authorize(creds)
    return client

def fetch_strings(sheet, lang_column_index):
    data = sheet.get(RANGE_NAME)
    strings = {}
    plurals = {}

    for row in data[1:]:  # Skip header row
        key, type_value, quantity, *translations = row
        value = translations[lang_column_index]

        if type_value.lower() == "plural":
            if key not in plurals:
                plurals[key] = {}
            plurals[key][quantity] = value
        elif type_value.lower() == "string":
            strings[key] = value

    return strings, plurals

def create_strings_xml(strings, plurals, lang_code):
    resources = ET.Element('resources')

    # Add regular strings
    for key, value in strings.items():
        string_elem = ET.SubElement(resources, 'string', name=key)
        string_elem.text = value

    # Add plural strings
    for key, quantities in plurals.items():
        plural_elem = ET.SubElement(resources, 'plurals', name=key)
        for quantity, value in quantities.items():
            item_elem = ET.SubElement(plural_elem, 'item', quantity=quantity)
            item_elem.text = value

    os.makedirs(f"android/res/values-{lang_code}", exist_ok=True)
    tree = ET.ElementTree(resources)
    tree.write(f'android/res/values-{lang_code}/strings.xml', encoding='utf-8', xml_declaration=True)

def main():
    credentials_path = "credentials.json"
    client = authenticate_google_sheets(credentials_path)
    sheet = client.open_by_key(SPREADSHEET_ID).sheet1

    for lang_index, lang_code in enumerate(LANGUAGES):
        strings, plurals = fetch_strings(sheet, LANGUAGE_COLUMNS[lang_index] - 1)  # Adjust for column offset
        create_strings_xml(strings, plurals, lang_code)

if __name__ == '__main__':
    main()
EOF

echo "String files have been generated based on your preferences."
