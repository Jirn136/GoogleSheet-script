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
  curl -s -H "Authorization: Bearer ${access_token}" "${SHEET_URL}" | jq -r '.values'
}

# Parse and generate XML
generate_strings_xml() {
  local data=$1
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<resources>'
  
  # Read each row and generate strings or plurals
  echo "$data" | jq -r '.[] | @csv' | while IFS=',' read -r key type quantity en other; do
    if [ "$type" == "\"plural\"" ]; then
      echo "  <plurals name=${key}>"
      echo "    <item quantity=\"${quantity}\">${en}</item>"
      echo "  </plurals>"
    else
      echo "  <string name=${key}>${en}</string>"
    fi
  done

  echo '</resources>'
}

main() {
  if [ -z "$SHEET_ID" ] || [ -z "$SHEET_RANGE" ]; then
    echo "Usage: $0 <SHEET_ID> <SHEET_RANGE>"
    exit 1
  fi

  # Get access token
  ACCESS_TOKEN=$(get_access_token)
  if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Unable to retrieve access token."
    exit 1
  fi

  # Fetch data from the sheet
  SHEET_DATA=$(fetch_sheet_data "$ACCESS_TOKEN")
  if [ -z "$SHEET_DATA" ]; then
    echo "Error: Unable to fetch data from the sheet."
    exit 1
  fi

  # Generate the strings.xml file
  generate_strings_xml "$SHEET_DATA" > res/values/strings.xml
}

main
