import os
import sys
import json
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import xml.etree.ElementTree as ET

def fetch_strings(sheet_id):
    # Retrieve the credentials JSON string from the environment variable
    creds_json_str = os.getenv('GOOGLE_SHEET_CREDENTIALS')
    if not creds_json_str:
        print("Error: GOOGLE_CREDENTIALS_JSON environment variable not set.")
        sys.exit(1)

    # Parse the JSON string into a dictionary
    try:
        creds_json = json.loads(creds_json_str)
    except json.JSONDecodeError:
        print("Error: Failed to parse GOOGLE_CREDENTIALS_JSON. Ensure it is a valid JSON string.")
        sys.exit(1)

    # Authenticate using the parsed credentials dictionary
    creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_json, ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive'])
    client = gspread.authorize(creds)

    # Open the spreadsheet by ID and fetch the first worksheet
    sheet = client.open_by_key(sheet_id)
    worksheet = sheet.get_worksheet(0)  # Get the first worksheet

    # Fetch all records from the worksheet
    data = worksheet.get_all_records()

    # Print current working directory for debugging
    print("Current Working Directory:", os.getcwd())

    # Define the project base path using an environment variable or default to the current directory
    project_base = os.getenv('PROJECT_BASE_PATH', os.getcwd())
    res_dir = os.path.join(project_base, "resources/values")

    # Ensure the directory exists
    if not os.path.exists(res_dir):
        os.makedirs(res_dir)
        print(f"Directory '{res_dir}' created.")

    # Path for the strings.xml file
    output_path = os.path.join(res_dir, "strings.xml")

    # Create the XML structure
    resources = ET.Element("resources")

    for row in data:
        string_id = row['ID']
        string_type = row['Type']
        translation = str(row['en'])  # Adjust to match your language column

        if string_type == "string":
            ET.SubElement(resources, "string", name=string_id).text = translation
        elif string_type == "plural":
            quantity = row.get('Quantity', 'other')
            quantity_str = str(quantity)  # Ensure quantity is a string
            plural_elem = ET.SubElement(resources, "plurals", name=string_id)
            ET.SubElement(plural_elem, "item", quantity=quantity_str).text = translation

    # Write the XML to the file
    tree = ET.ElementTree(resources)
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"strings.xml generated and saved to {output_path}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fetch_strings.py <sheet_id>")
        sys.exit(1)

    sheet_id = sys.argv[1]
    fetch_strings(sheet_id)
