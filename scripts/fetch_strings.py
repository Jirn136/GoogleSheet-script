import gspread
from oauth2client.service_account import ServiceAccountCredentials
import os
import xml.etree.ElementTree as ET

# Set up credentials and Google Sheets access
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
credentials = ServiceAccountCredentials.from_json_keyfile_name('path/to/credentials.json', scope)
client = gspread.authorize(credentials)

# Open your sheet
spreadsheet = client.open('YOUR_GOOGLE_SHEET_NAME')
sheet = spreadsheet.sheet1

# Fetch all records
records = sheet.get_all_records()

# Directory to store generated files
base_dir = 'app/src/main/res'

# Process each row and generate strings.xml files
def generate_string_files(records):
    translations = {}
    
    for record in records:
        string_id = record['id']
        string_type = record['type']
        quantity = record.get('quantity', '')
        translations_per_lang = {key: value for key, value in record.items() if key not in ['id', 'type', 'quantity']}

        for lang, translation in translations_per_lang.items():
            if lang not in translations:
                translations[lang] = {}
            if string_type == 'string':
                translations[lang][string_id] = translation
            elif string_type == 'plural':
                if string_id not in translations[lang]:
                    translations[lang][string_id] = {}
                translations[lang][string_id][quantity] = translation

    for lang, strings in translations.items():
        generate_xml_file(lang, strings)

def generate_xml_file(language, strings):
    # Determine the path
    if language == 'en':
        path = os.path.join(base_dir, 'values', 'strings.xml')
    else:
        path = os.path.join(base_dir, f'values-{language}', 'strings.xml')

    os.makedirs(os.path.dirname(path), exist_ok=True)
    
    resources = ET.Element("resources")

    for string_id, value in strings.items():
        if isinstance(value, dict):  # It's a plural
            plural_element = ET.SubElement(resources, "plurals", name=string_id)
            for quantity, translation in value.items():
                ET.SubElement(plural_element, "item", quantity=quantity).text = translation
        else:  # It's a simple string
            string_element = ET.SubElement(resources, "string", name=string_id)
            string_element.text = value

    tree = ET.ElementTree(resources)
    tree.write(path, encoding='utf-8', xml_declaration=True)

generate_string_files(records)
