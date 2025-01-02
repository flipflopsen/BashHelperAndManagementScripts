#!/bin/bash

# Default file path
DEFAULT_FILE_PATH="$HOME/Documents/Git/EncryptedGitAccess.txt"

# Check if a custom output file path is provided as the first command-line argument
if [ -n "$1" ]; then
    OUTPUT_FILE_PATH="$1"
else
    OUTPUT_FILE_PATH="$DEFAULT_FILE_PATH"
fi

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE_PATH")"

# Prompt user for required details
echo "Enter your GitHub username:"
read git_username
echo "Enter your GitHub email:"
read git_email
echo "Enter your GitHub personal access token:"
read -s git_token
echo "Please enter the encryption password to secure your data:"
read -s encryption_password

# Create JSON structure to save the username and token
json_content="{\"username\":\"${git_username}\",\"token\":\"${git_token}\"}"

# Encrypt and save to file
echo "$json_content" | openssl enc -aes-256-cbc -a -salt -pass pass:"$encryption_password" -out "$OUTPUT_FILE_PATH"

echo "Encrypted access file created at $OUTPUT_FILE_PATH"

# Configuring Git user and email locally
git config --local user.name "$git_username"
git config --local user.email "$git_email"

echo "Local Git configuration set for username and email."
