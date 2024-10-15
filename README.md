# Localization Files Generator

This project allows you to fetch localization strings from a Google Sheet and generate platform-specific files for Android and iOS. 

## Overview

The generator uses a YAML configuration file, a shell script, and Google Sheets as the source of truth for localization strings. The output includes:

- Android `strings.xml` files
- iOS `Localizable.strings` files

## Prerequisites

- A Google Sheet containing the localization strings.
- Google Service Account credentials for accessing the Google Sheets API.
- Environment variables for your credentials and GitHub token.

## Google Sheets Format

Your Google Sheet should be structured with the following columns in this specific order:

| ID            | Type   | Quantity | en            | fr          |
|---------------|--------|----------|---------------|-------------|
| txt_sample    | string |          | Hello world   | Bonjour le monde |
| txt_new_string| string |          | Welcome       | Bienvenue   |
| txt_multiple  | plural | one      | Sample        | Échantillon |
|               |        | other    | Samples       | Échantillons |

- **ID**: A unique identifier for each string.
- **Type**: Specifies whether the entry is a `string` or `plural`.
- **Quantity**: Used for pluralization.
- **en**: English translation.
- **fr**: French translation.

