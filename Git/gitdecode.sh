#!/bin/bash

# Check if at least the correct number of arguments is given
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <git-url> [alternative-access-file]"
    exit 1
fi

GIT_URL="$1"
DEFAULT_ACCESS_FILE_PATH="$HOME/Documents/GitAccess.txt"

# Function to decrypt and parse JSON file for credentials
function get_credentials {
    local fpath="$1"
    local password="$2"

    # Decrypt file to temporary JSON for parsing, securely delete afterward
    local temp_json_path=$(mktemp)
    openssl enc -aes-256-cbc -d -a -in "$fpath" -pass pass:"$password" -out "$temp_json_path" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "Decryption failed, possibly wrong password."
        rm -f "$temp_json_path"
        exit 1
    fi

    local user=$(jq -r '.user' "$temp_json_path")
    local token=$(jq -r '.token' "$temp_json_path")
    
    # Clean up temporary file securely
    shred -u "$temp_json_path"

    # Check if user or token is null
    if [ "$user" == "null" ] || [ "$token" == "null" ]; then
        echo "Error reading user or token from JSON content."
        exit 1
    fi

    # Return credentials
    echo "$user:$token"
}

# Determine which access file to use
ACCESS_FILE="$DEFAULT_ACCESS_FILE_PATH"
if [ ! -f "$ACCESS_FILE" ] && [ "$#" -eq 2 ]; then
    ACCESS_FILE="$2"
fi

# Check if the access file exists
if [ ! -f "$ACCESS_FILE" ]; then
    echo "The encrypted Git access file does not exist."
    exit 1
fi

# Get decryption password from user
echo "Enter the encryption password for Git access file:"
read -s decryption_password

# Extract credentials
credentials=$(get_credentials "$ACCESS_FILE" "$decryption_password")
if [ -z "$credentials" ]; then
    echo "Failed to obtain credentials."
    exit 1
fi

# Replace 'https://' with 'https://username:token@' in the Git URL
AUTH_URL=$(echo "$GIT_URL" | sed "s|https://|https://$credentials@|")

echo "AccessToken:"
echo $credentials
# Run git clone with the modified URL
#git clone "$AUTH_URL"
echo "Repository cloned successfully."
