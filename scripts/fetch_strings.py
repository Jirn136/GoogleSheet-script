import sys
import gspread
import os
from oauth2client.service_account import ServiceAccountCredentials
from io import StringIO
import json

def fetch_strings(sheet_id):
    # Use credentials and authenticate
    scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']

    # Get the credentials from the environment variable
    creds_json = os.getenv('GOOGLE_SHEET_CREDENTIALS')
    if creds_json is None:
        print("No credentials found in the environment variable 'GOOGLE_SHEET_CREDENTIALS'.")
        sys.exit(1)

    # Load the credentials from the environment variable
    creds_io = StringIO(creds_json)
    creds_data = json.load(creds_io)
    creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_data, scope)

    client = gspread.authorize(creds)

    # Open the spreadsheet by ID and fetch the first worksheet
    sheet = client.open_by_key(sheet_id)
    worksheet = sheet.get_worksheet(0)  # Get the first worksheet

    # Fetch all records from the worksheet
    data = worksheet.get_all_records()

    # Process the data (you can expand this as needed)
    for row in data:
        print(f"ID: {row['ID']}, Type: {row['Type']}, Quantity: {row.get('Quantity', 'N/A')}, Translation: {row['en']}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fetch_strings.py <sheet_id>")
        sys.exit(1)

    sheet_id = sys.argv[1]
    fetch_strings(sheet_id)
