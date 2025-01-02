#!/bin/bash

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
echo "$json_content" | openssl enc -aes-256-cbc -a -salt -pass pass:"$encryption_password" -out "$HOME/Documents/GitAccess.txt"

echo "Encrypted access file created at $HOME/Documents/GitAccess.txt"