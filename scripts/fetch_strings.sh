#!/bin/bash

# Fetch strings from Google Sheets and generate strings.xml files

# Usage: ./fetch_strings.sh <sheet_id>

# Check for required environment variable
if [ -z "$GOOGLE_SHEET_CREDENTIALS" ]; then
    echo "Error: GOOGLE_SHEET_CREDENTIALS is not set."
    exit 1
fi

# Check for required argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <sheet_id>"
    exit 1
fi

SHEET_ID=$1
VALUES_DIR="./resources"

# Install dependencies
pip install gspread oauth2client || {
    echo "Failed to install dependencies."
    exit 1
}

# Fetch data from Google Sheets using Python
DATA=$(python - <<END
import os
import json
import gspread
from oauth2client.service_account import ServiceAccountCredentials

# Use credentials and authenticate
scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']

# Load the credentials from the environment variable
creds_json = os.getenv('GOOGLE_SHEET_CREDENTIALS')
creds_data = json.loads(creds_json)
creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_data, scope)

client = gspread.authorize(creds)

# Open the spreadsheet by ID and fetch the first worksheet
sheet = client.open_by_key("$SHEET_ID")
worksheet = sheet.get_worksheet(0)  # Get the first worksheet

# Fetch all records from the worksheet
data = worksheet.get_all_records()
print(json.dumps(data))
END
)

# Check for JSON parsing errors
if [ $? -ne 0 ]; then
    echo "Error fetching data from Google Sheets."
    exit 1
fi

# Create output directory if it does not exist
mkdir -p "$VALUES_DIR"

# Generate strings.xml for each language column
echo "$DATA" | jq -c '.[]' | while IFS= read -r row; do
    # Extract language translations
    declare -A translations
    quantity=$(echo "$row" | jq -r '.Quantity')
    
    # Loop through all keys in the row
    for lang in $(echo "$row" | jq -r 'keys_unsorted[] | select(. != "ID" and . != "Type" and . != "Quantity")'); do
        translations[$lang]=$(echo "$row" | jq -r ".\"$lang\"")
    done

    # Generate strings.xml files for each language
    for lang in "${!translations[@]}"; do
        lang_dir="$VALUES_DIR/values-${lang}"
        mkdir -p "$lang_dir"
        xml_file="$lang_dir/strings.xml"

        # Start writing the XML
        {
            echo '<?xml version="1.0" encoding="utf-8"?>'
            echo '<resources>'

            for id in $(echo "$row" | jq -r '.ID'); do
                translation=${translations[$lang]}
                echo "    <string name=\"$id\">$translation</string>"
            done

            echo '</resources>'
        } > "$xml_file"

        echo "strings.xml generated and saved to $xml_file"
    done
done
