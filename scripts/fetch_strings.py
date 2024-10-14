import sys
import gspread
import os
import json
import stat
from oauth2client.service_account import ServiceAccountCredentials
from io import StringIO
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom.minidom import parseString

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

    # Determine languages from the columns (all columns after 'ID' and 'Type')
    languages = list(data[0].keys())[2:]  # Skip the first two columns (ID and Type)

    # Process the data and generate strings.xml content for each language
    for lang in languages:
        strings_xml = generate_strings_xml(data, lang)
        
        # Define the output path for strings.xml based on language
        output_path = f"./resources/values-{lang}/strings.xml"  # Change path as needed

        # Ensure the directory exists and has write permissions
        output_dir = os.path.dirname(output_path)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            print(f"Directory '{output_dir}' created.")
            
            # Set the directory's permissions to ensure it's writable
            os.chmod(output_dir, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)  # Read, write, and execute for user, group, others

        # Check if we have write access to the directory
        if not os.access(output_dir, os.W_OK):
            print(f"Directory '{output_dir}' is not writable. Adjusting permissions...")
            os.chmod(output_dir, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)

        # Save the strings.xml to the specified path
        try:
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(strings_xml)
            print(f"strings.xml generated and saved to {output_path}")
        except Exception as e:
            print(f"Error writing to the file: {e}")
            sys.exit(1)

def generate_strings_xml(data, lang):
    # Create the root element for the XML
    resources = Element('resources')

    for row in data:
        string_id = str(row['ID'])
        string_type = str(row['Type'])

        # Only generate strings for the specified language
        translation = str(row.get(lang, ''))  # Get the translation or empty string if not found

        if string_type == 'string':
            string_element = SubElement(resources, 'string', name=string_id)
            string_element.text = translation

        elif string_type == 'plural' and 'Quantity' in row:
            plural_element = SubElement(resources, 'plurals', name=string_id)
            quantity = str(row['Quantity']).strip().lower()

            # Define valid plural quantities for Android
            valid_quantities = ['zero', 'one', 'two', 'few', 'many', 'other']
            if quantity in valid_quantities:
                item_translation = str(row.get(lang, ''))
                item = SubElement(plural_element, 'item', quantity=quantity)
                item.text = item_translation
            else:
                print(f"Warning: Invalid quantity '{quantity}' for ID '{string_id}'. Skipping.")

    # Convert the ElementTree to a string and prettify it using minidom
    xml_str = tostring(resources, 'utf-8')
    parsed_xml = parseString(xml_str)
    return parsed_xml.toprettyxml(indent="  ")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fetch_strings.py <sheet_id>")
        sys.exit(1)

    sheet_id = sys.argv[1]
    fetch_strings(sheet_id)
