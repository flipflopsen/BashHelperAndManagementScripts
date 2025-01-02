#!/bin/bash

# Check if the output file path is provided as a command-line argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file_path>"
    exit 1
fi

output_file="$1"

# Prompt user for required details
echo "Enter git username:"
read git_username
echo "Enter personal access token:"
read -s git_token
echo "Enter encryption password:"
read -s encryption_password

# Create JSON structure
json_content="{\"user\":\"${git_username}\",\"token\":\"${git_token}\"}"

# Save to file encrypted
echo "$json_content" | openssl enc -aes-256-cbc -a -salt -pass pass:"$encryption_password" -out "$output_file"

echo "Encrypted access file created at $output_file"
