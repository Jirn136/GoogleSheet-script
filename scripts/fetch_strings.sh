# #!/bin/bash

# # Fetch strings from Google Sheets and generate strings.xml files

# # Check for required environment variable
# if [ -z "$CREDENTIALS" ]; then
#     echo "Error: CREDENTIALS is not set."
#     exit 1
# fi

# # Check for required argument
# if [ "$#" -ne 1 ]; then
#     echo "Usage: $0 <sheet_id>"
#     exit 1
# fi

# SHEET_ID=$1
# VALUES_DIR="./resources"

# # Create output directory if it does not exist
# mkdir -p "$VALUES_DIR"

# # Fetch data from Google Sheets using Python
# DATA=$(python - <<END
# import os
# import json
# import gspread
# from oauth2client.service_account import ServiceAccountCredentials

# # Use credentials and authenticate
# scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']

# # Load the credentials from the environment variable
# creds_json = os.getenv('CREDENTIALS')
# creds_data = json.loads(creds_json)
# creds = ServiceAccountCredentials.from_json_keyfile_dict(creds_data, scope)

# client = gspread.authorize(creds)

# # Open the spreadsheet by ID and fetch the first worksheet
# sheet = client.open_by_key("$SHEET_ID")
# worksheet = sheet.get_worksheet(0)  # Get the first worksheet

# # Fetch all records from the worksheet
# data = worksheet.get_all_records()
# print(json.dumps(data))
# END
# )

# # Check for JSON parsing errors
# if [ $? -ne 0 ]; then
#     echo "Error fetching data from Google Sheets."
#     exit 1
# fi

# # Prepare associative arrays to hold translations
# declare -A translations

# # Process each row and collect translations
# echo "$DATA" | jq -c '.[]' | while IFS= read -r row; do
#     quantity=$(echo "$row" | jq -r '.Quantity')

#     # Loop through all keys in the row except for ID, Type, and Quantity
#     for lang in $(echo "$row" | jq -r 'keys_unsorted[] | select(. != "ID" and . != "Type" and . != "Quantity")'); do
#         id=$(echo "$row" | jq -r '.ID')
#         translation=$(echo "$row" | jq -r ".\"$lang\"")
#         translations["$lang,$id"]="$translation"
#     done
# done

# # Generate strings.xml for each language
# for lang in "${!translations[@]}"; do
#     lang_code="${lang%%,*}"
#     id="${lang##*,}"
    
#     lang_dir="$VALUES_DIR/values-${lang_code}"
#     mkdir -p "$lang_dir"
#     xml_file="$lang_dir/strings.xml"

#     # Start writing the XML if file does not exist
#     if [ ! -f "$xml_file" ]; then
#         {
#             echo '<?xml version="1.0" encoding="utf-8"?>'
#             echo '<resources>'
#         } > "$xml_file"
#     fi

#     # Append the translation string
#     translation=${translations["$lang"]}
#     echo "    <string name=\"$id\">$translation</string>" >> "$xml_file"
# done

# # Close the resources tag for each language file
# for lang in $(ls $VALUES_DIR | grep 'values-'); do
#     xml_file="$VALUES_DIR/$lang/strings.xml"
#     echo '</resources>' >> "$xml_file"
#     echo "strings.xml updated for $lang"
# done
