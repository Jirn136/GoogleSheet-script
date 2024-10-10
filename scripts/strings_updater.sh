#!/bin/bash

# Parameters: Sheet ID and Range
SHEET_ID=$1
SHEET_RANGE=$2

# Constants
CREDENTIALS_FILE="credentials.json"
TOKEN_URL="https://oauth2.googleapis.com/token"
SHEET_URL="https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}/values/${SHEET_RANGE}"

# Function to get Google API access token
get_access_token() {
  local access_token
  access_token=$(curl -s -X POST -H "Content-Type: application/json" \
    -d @${CREDENTIALS_FILE} ${TOKEN_URL} | jq -r '.access_token')
  echo $access_token
}

# Fetch the Google Sheets data
fetch_sheet_data() {
  local access_token=$1
  response=$(curl -s -H "Authorization: Bearer ${access_token}" "${SHEET_URL}")
  echo "$response"
}

# Parse and generate XML
generate_strings_xml() {
  local data=$1
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<resources>'
  
  # Read each row and generate strings or plurals
  echo "$data" | jq -r '.values[] | @csv' | while IFS=',' read -r key type quantity en other; do
    # Strip quotes from the variables
    key=$(echo "$key" | tr -d '"')
    type=$(echo "$type" | tr -d '"')
    quantity=$(echo "$quantity" | tr -d '"')
    en=$(echo "$en" | tr -d '"')

    # Log the processed strings
    echo "Processing: Key: $key, Type: $type, Quantity: $quantity, Value: $en"

    if [ "$type" == "string" ]; then
      echo "  <string name=\"$key\">$en</string>"
    elif [ "$type" == "plural" ]; then
      echo "  <plurals name=\"$key\">"
      echo "    <item quantity=\"$quantity\">$en</item>"
      echo "  </plurals>"
    fi
  done

  echo '</resources>'
}

main() {
  if [ -z "$SHEET_ID" ] || [ -z "$SHEET_RANGE" ]; then
    echo "Usage: $0 <SHEET_ID> <SHEET_RANGE>"
    exit 1
  fi

  # Create the directory if it doesn't exist
  mkdir -p res/values

  # Get access token
  ACCESS_TOKEN=$(get_access_token)
  if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Unable to retrieve access token."
    exit 1
  fi

  # Fetch data from the sheet
  SHEET_DATA=$(fetch_sheet_data "$ACCESS_TOKEN")
  
  # Log the raw response from the Google Sheets API
  echo "Raw response from Google Sheets API:"
  echo "$SHEET_DATA"

  if [ -z "$SHEET_DATA" ]; then
    echo "Error: No data received from the sheet."
    exit 1
  fi

  # Check if the data is in the expected format
  if echo "$SHEET_DATA" | jq -e '.values' >/dev/null; then
    # Generate the strings.xml file
    generate_strings_xml "$SHEET_DATA" > res/values/strings.xml

    # Log the contents of the generated strings.xml file
    echo "Generated strings.xml content:"
    cat res/values/strings.xml
  else
    echo "Error: Unexpected response format. Data might be missing or incorrectly formatted."
    exit 1
  fi
}

main
