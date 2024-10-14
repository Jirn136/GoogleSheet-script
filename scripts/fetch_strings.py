import sys
import gspread
import os
import json
from oauth2client.service_account import ServiceAccountCredentials
from io import StringIO
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom.minidom import parseString
import subprocess

def fetch_strings(sheet_id):
    # Use credentials and authenticate
    scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']

    # Get the credentials from the environment variable
    creds_json = os.getenv('GOOGLE_SHEET_CREDENTIALS')
    if not creds_json:
        print("No credentials found or the environment variable 'GOOGLE_SHEET_CREDENTIALS' is empty.")
        sys.exit(1)

    try:
        # Load the credentials from the environment variable
        creds_io = StringIO(creds_json)
        creds_data = json.load(creds_io)
        creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_data, scope)
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON credentials: {e}")
        sys.exit(1)

    client = gspread.authorize(creds)

    # Open the spreadsheet by ID and fetch the first worksheet
    sheet = client.open_by_key(sheet_id)
    worksheet = sheet.get_worksheet(0)  # Get the first worksheet

    # Fetch all records from the worksheet
    data = worksheet.get_all_records()

    # Process the data and generate strings.xml content for each language
    generate_strings_xml(data)

def generate_strings_xml(data):
    # Identify language columns (after Quantity)
    language_columns = [key for key in data[0].keys() if key not in ['ID', 'Type', 'Quantity']]

    for lang in language_columns:
        resources = Element('resources')

        for row in data:
            string_id = str(row['ID'])
            string_type = str(row['Type'])
            translation = str(row.get(lang, '')).strip()  # Get the translation for the current language column

            if string_type == 'string':
                # Create a simple string element
                string_element = SubElement(resources, 'string', name=string_id)
                string_element.text = translation

            elif string_type == 'plural' and 'Quantity' in row:
                # Create a plural element
                plural_element = SubElement(resources, 'plurals', name=string_id)
                quantity = str(row['Quantity']).strip().lower()

                # Define valid plural quantities for Android
                valid_quantities = ['zero', 'one', 'two', 'few', 'many', 'other']
                if quantity in valid_quantities:
                    item = SubElement(plural_element, 'item', quantity=quantity)
                    item.text = translation
                else:
                    print(f"Warning: Invalid quantity '{quantity}' for ID '{string_id}'. Skipping.")

        # Define the output path for strings.xml
        output_path = f"./resources/values-{lang}/strings.xml"

        # Ensure the directory exists
        output_dir = os.path.dirname(output_path)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            print(f"Directory '{output_dir}' created.")

        # Save the strings.xml to the specified path
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(prettify_xml(tostring(resources, 'utf-8')))

        print(f"strings.xml generated and saved to {output_path}")

def prettify_xml(xml_str):
    """Prettify the XML string."""
    parsed_xml = parseString(xml_str)
    return parsed_xml.toprettyxml(indent="  ")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fetch_strings.py <sheet_id>")
        sys.exit(1)

    # Get Git configuration
    try:
        email = subprocess.check_output(['git', 'config', 'user.email']).strip().decode('utf-8')
        name = subprocess.check_output(['git', 'config', 'user.name']).strip().decode('utf-8')
        print(f"Git user email: {email}")
        print(f"Git user name: {name}")
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving Git user info: {e}")
        sys.exit(1)

    sheet_id = sys.argv[1]
    fetch_strings(sheet_id)
