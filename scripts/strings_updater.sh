#!/bin/bash

# Function to read user input for spreadsheet ID and range
read_user_input() {
    echo "Enter the Google Sheets ID:"
    read SPREADSHEET_ID
    echo "Enter the Google Sheets Range (e.g., Sheet1!A:F):"
    read RANGE_NAME
    echo "Enter the credentials JSON (raw JSON):"
    read -r CREDENTIALS_JSON
}

# Set variables
SPREADSHEET_ID="$SPREADSHEET_ID"

# Get user input
read_user_input

# Install required dependencies if not installed
pip install gspread oauth2client xmltodict --quiet

# Python script embedded within the shell script
python3 <<EOF
import gspread
import json
import os
from oauth2client.service_account import ServiceAccountCredentials

# Configuration from user input
SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']
SPREADSHEET_ID = "$SPREADSHEET_ID"
RANGE_NAME = "$RANGE_NAME"
CREDENTIALS_JSON = """$CREDENTIALS_JSON"""

# Function to authenticate and get Google Sheets client
def authenticate_google_sheets(credentials_json):
    creds = json.loads(credentials_json)
    credentials = ServiceAccountCredentials.from_json_keyfile_dict(creds, SCOPES)
    client = gspread.authorize(credentials)
    return client

def fetch_strings(sheet):
    data = sheet.get(RANGE_NAME)
    strings = {}
    plurals = {}

    for row in data[1:]:  # Skip header row
        key, type_value, quantity, *translations = row
        for lang_code, value in zip(translations, translations):
            if type_value.lower() == "plural":
                if key not in plurals:
                    plurals[key] = {}
                plurals[key][quantity] = value
            elif type_value.lower() == "string":
                strings[key] = value

    return strings, plurals

def create_strings_xml(strings, plurals, lang_code):
    import xml.etree.ElementTree as ET
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
    client = authenticate_google_sheets(CREDENTIALS_JSON)
    sheet = client.open_by_key(SPREADSHEET_ID).sheet1
    strings, plurals = fetch_strings(sheet)

    # Get language codes from the first row
    header = sheet.row_values(1)
    languages = header[3:]  # Assuming the first three columns are static

    for lang_index, lang_code in enumerate(languages):
        create_strings_xml(strings, plurals, lang_code)

if __name__ == '__main__':
    main()
EOF

echo "Android string files have been generated based on your preferences."
