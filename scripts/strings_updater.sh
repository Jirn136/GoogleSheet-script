#!/bin/bash

# Decode credentials from the environment variable
echo $CREDENTIALS_JSON | base64 --decode > credentials.json

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
SPREADSHEET_ID = "$SHEET_ID"
RANGE_NAME = "$RANGE_NAME"

def authenticate_google_sheets(credentials_path):
    creds = ServiceAccountCredentials.from_json_keyfile_name(credentials_path, SCOPES)
    client = gspread.authorize(creds)
    return client

def fetch_languages(sheet):
    data = sheet.get(RANGE_NAME)
    # The first row contains the language codes starting from the 4th column
    languages = data[0][3:]  # Adjust the index to get languages from the 4th column onwards
    return languages

def fetch_strings(sheet, lang_columns):
    data = sheet.get(RANGE_NAME)
    strings = {}
    plurals = {}

    for row in data[1:]:  # Skip header row
        key, type_value, quantity, *translations = row

        for lang_index, lang_column_index in enumerate(lang_columns):
            value = translations[lang_index]

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

    os.makedirs(f"generated_strings/values-{lang_code}", exist_ok=True)
    tree = ET.ElementTree(resources)
    tree.write(f'generated_strings/values-{lang_code}/strings.xml', encoding='utf-8', xml_declaration=True)

def main():
    credentials_path = "credentials.json"
    client = authenticate_google_sheets(credentials_path)
    sheet = client.open_by_key(SPREADSHEET_ID).sheet1

    languages = fetch_languages(sheet)
    lang_columns = list(range(len(languages)))  # Create a list of indices for the language columns

    for lang_index, lang_code in enumerate(languages):
        strings, plurals = fetch_strings(sheet, lang_columns)  # Pass indices of language columns
        create_strings_xml(strings, plurals, lang_code)

if __name__ == '__main__':
    main()
EOF

echo "Android string files have been generated based on your preferences."
