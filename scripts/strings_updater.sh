#!/bin/bash

# Function to read user input for the spreadsheet range
read_user_input() {
    echo "Enter the Google Sheets Range (e.g., Sheet1!A:F):"
    read RANGE_NAME
}

# Set variables
SPREADSHEET_ID="$SPREADSHEET_ID"

# Decode credentials from the environment variable
echo $CREDENTIALS_JSON | base64 --decode > credentials.json

# Get user input for the range
read_user_input

# Install required dependencies if not installed
pip install gspread oauth2client xmltodict --quiet

# Python script embedded within the shell script
python3 <<EOF
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import xml.etree.ElementTree as ET
import os

# Configuration from user input
SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']
SPREADSHEET_ID = "$SPREADSHEET_ID"
RANGE_NAME = "$RANGE_NAME"

def authenticate_google_sheets(credentials_path):
    creds = ServiceAccountCredentials.from_json_keyfile_name(credentials_path, SCOPES)
    client = gspread.authorize(creds)
    return client

def fetch_languages_and_columns(sheet):
    # Fetch the first row to get languages
    header_row = sheet.row_values(1)  # Get the first row (header)
    languages = []
    language_columns = []
    
    for index, value in enumerate(header_row):
        if value:  # Check if the cell is not empty
            languages.append(value)  # Add the language code
            language_columns.append(index)  # Store the column index
    
    return languages, language_columns

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

    # Fetch languages and their corresponding columns
    languages, language_columns = fetch_languages_and_columns(sheet)

    for lang_index, lang_code in enumerate(languages):
        strings, plurals = fetch_strings(sheet, language_columns[lang_index] - 1)  # Adjust for column offset
        create_strings_xml(strings, plurals, lang_code)

if __name__ == '__main__':
    main()
EOF

echo "Android string files have been generated based on your preferences."
