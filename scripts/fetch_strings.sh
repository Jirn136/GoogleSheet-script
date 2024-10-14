#!/bin/bash

# Fetch strings from Google Sheets and generate strings.xml and Localizable.strings files

# Check for required environment variable
if [ -z "$CREDENTIALS" ]; then
    echo "Error: CREDENTIALS is not set."
    exit 1
fi

# Check for required argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <sheet_id>"
    exit 1
fi

SHEET_ID=$1
ANDROID_VALUES_DIR="./resources/android"
IOS_VALUES_DIR="./resources/ios"

# Create output directories if they do not exist
mkdir -p "$ANDROID_VALUES_DIR"
mkdir -p "$IOS_VALUES_DIR"

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

# Remove existing strings.xml and Localizable.strings files to avoid duplication
find "$ANDROID_VALUES_DIR" -name "strings.xml" -type f -delete
find "$IOS_VALUES_DIR" -name "Localizable.strings" -type f -delete

# Generate strings.xml and Localizable.strings for each language column
echo "$DATA" | jq -c '.[]' | while IFS= read -r row; do
    declare -A translations
    id=$(echo "$row" | jq -r '.ID')
    type=$(echo "$row" | jq -r '.Type')

    # Loop through all language keys
    for lang in $(echo "$row" | jq -r 'keys_unsorted[] | select(. != "ID" and . != "Type" and . != "Quantity")'); do
        translations[$lang]=$(echo "$row" | jq -r ".\"$lang\"")

        # Android strings.xml generation
        android_lang_dir="$ANDROID_VALUES_DIR/values-${lang}"
        mkdir -p "$android_lang_dir"
        android_xml_file="$android_lang_dir/strings.xml"

        # If the file doesn't exist, create it with the XML header
        if [ ! -f "$android_xml_file" ]; then
            echo '<?xml version="1.0" encoding="utf-8"?>' > "$android_xml_file"
            echo '<resources>' >> "$android_xml_file"
        fi

        # Handle different types for Android
        if [ "$type" == "string" ]; then
            echo "    <string name=\"$id\">${translations[$lang]}</string>" >> "$android_xml_file"
        elif [ "$type" == "plural" ]; then
            quantity=$(echo "$row" | jq -r '.Quantity')
            if ! grep -q "<plurals name=\"$id\">" "$android_xml_file"; then
                echo "    <plurals name=\"$id\">" >> "$android_xml_file"
                echo "        <item quantity=\"$quantity\">${translations[$lang]}</item>" >> "$android_xml_file"
                echo "    </plurals>" >> "$android_xml_file"
            else
                sed -i "/<plurals name=\"$id\">/a\        <item quantity=\"$quantity\">${translations[$lang]}</item>" "$android_xml_file"
            fi
        fi

        # iOS Localizable.strings generation
        ios_lang_dir="$IOS_VALUES_DIR/$lang.lproj"
        mkdir -p "$ios_lang_dir"
        ios_strings_file="$ios_lang_dir/Localizable.strings"

        # If the file doesn't exist, create it with the iOS format header
        if [ ! -f "$ios_strings_file" ]; then
            echo "/* Localizable strings for $lang */" > "$ios_strings_file"
        fi

        # Handle different types for iOS
        if [ "$type" == "string" ]; then
            echo "\"$id\" = \"${translations[$lang]}\";" >> "$ios_strings_file"
        elif [ "$type" == "plural" ]; then
            # iOS does not natively support plurals in the same way, so this may require a custom approach.
            quantity=$(echo "$row" | jq -r '.Quantity')
            echo "\"$id.$quantity\" = \"${translations[$lang]}\";" >> "$ios_strings_file"
        fi
    done
done

# Close all Android strings.xml files properly
find "$ANDROID_VALUES_DIR" -name "strings.xml" | while read -r file; do
    echo "</resources>" >> "$file"
done
