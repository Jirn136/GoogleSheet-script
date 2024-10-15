#!/bin/bash

# Fetch strings from Google Sheets and generate strings.xml files

# Check for required environment variable
if [ -z "$CREDENTIALS" ]; then
    echo "Error: CREDENTIALS is not set."
    exit 1
fi

# Check for required argument (Sheet ID)
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <sheet_id>"
    exit 1
fi

SHEET_ID=$1
VALUES_DIR="./resources"

# Prompt the user for the gid (worksheet ID)
read -p "Enter the gid for the worksheet (press Enter to use default gid): " GID

# Set GID to a default value if none is entered (default to the first worksheet's gid: 0)
GID=${GID:-0}

# Create output directory if it does not exist
mkdir -p "$VALUES_DIR"

# Fetch data from Google Sheets using Python
DATA=$(python - <<END
import os
import json
import gspread
from oauth2client.service_account import ServiceAccountCredentials

# Use credentials and authenticate
scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']

# Load the credentials from the environment variable
creds_json = os.getenv('CREDENTIALS')
creds_data = json.loads(creds_json)
creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_data, scope)

client = gspread.authorize(creds)

# Open the spreadsheet by ID
sheet = client.open_by_key("$SHEET_ID")

# Find the worksheet based on the GID
try:
    worksheet = None
    for ws in sheet.worksheets():
        if str(ws.id) == "$GID":
            worksheet = ws
            break
    if worksheet is None:
        raise ValueError("Worksheet with gid $GID not found")

    # Fetch all records from the worksheet
    data = worksheet.get_all_records()
    print(json.dumps(data))
except Exception as e:
    print(f"Error: {e}")
    exit(1)
END
)

# Check for JSON parsing errors
if [ $? -ne 0 ]; then
    echo "Error fetching data from Google Sheets."
    exit 1
fi

# Remove existing strings.xml files to avoid duplication
find "$VALUES_DIR" -name "strings.xml" -type f -delete

# Generate strings.xml for each language column
echo "$DATA" | jq -c '.[]' | while IFS= read -r row; do
    declare -A translations
    id=$(echo "$row" | jq -r '.ID')
    type=$(echo "$row" | jq -r '.Type')

    # Loop through all language keys
    for lang in $(echo "$row" | jq -r 'keys_unsorted[] | select(. != "ID" and . != "Type" and . != "Quantity")'); do
        translations[$lang]=$(echo "$row" | jq -r ".\"$lang\"")

        # Define the output directory and file
        lang_dir="$VALUES_DIR/values-${lang}"
        mkdir -p "$lang_dir"
        xml_file="$lang_dir/strings.xml"

        # If the file doesn't exist, create it with the XML header
        if [ ! -f "$xml_file" ]; then
            echo '<?xml version="1.0" encoding="utf-8"?>' > "$xml_file"
            echo '<resources>' >> "$xml_file"
        fi

        # Handle different types
        if [ "$type" == "string" ]; then
            echo "    <string name=\"$id\">${translations[$lang]}</string>" >> "$xml_file"
        elif [ "$type" == "plural" ]; then
            quantity=$(echo "$row" | jq -r '.Quantity')
            if ! grep -q "<plurals name=\"$id\">" "$xml_file"; then
                echo "    <plurals name=\"$id\">" >> "$xml_file"
                echo "        <item quantity=\"$quantity\">${translations[$lang]}</item>" >> "$xml_file"
                echo "    </plurals>" >> "$xml_file"
            else
                sed -i "/<plurals name=\"$id\">/a\        <item quantity=\"$quantity\">${translations[$lang]}</item>" "$xml_file"
            fi
        fi
    done
done

# Close all strings.xml files properly
find "$VALUES_DIR" -name "strings.xml" | while read -r file; do
    echo "</resources>" >> "$file"
done
