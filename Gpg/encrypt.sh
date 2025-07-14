#!/bin/bash

# Default paths
PUBLIC_KEYS_FOLDER="Keys/Public"
DEFAULT_OUTPUT_FILE="Messages/Encrypted/Message-{nr}.txt"
DEFAULT_KEY="pub.asc"

# Check inputs
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <message-file> [output-file] [pubkey-id]"
    exit 1
fi

message_file=$1
output_file=${2:-$DEFAULT_OUTPUT_FILE}
pubkey_id=${3:-$DEFAULT_KEY}

# Check if message file exists
if [ ! -f "$message_file" ]; then
    echo "Error: Message file $message_file not found"
    exit 1
fi

# Validate the public key path
public_key="$PUBLIC_KEYS_FOLDER/$pubkey_id"
if [ ! -f "$public_key" ]; then
    echo "Error: Public key file $public_key not found"
    exit 1
fi

# Create EncryptedMessages directory if it doesn't exist
mkdir -p Messages/Encrypted

# Replace {nr} with the next available number in the output file pattern
number=1
while [[ -f ${output_file/\{nr\}/$number} ]]; do
    ((number++))
done
output_file=${output_file/\{nr\}/$number}

# Import the public key
gpg --import "$public_key"

# Get the key ID of the imported key
key_id=$(gpg --list-keys --with-colons | awk -F: '/^pub:/ {print $5}' | tail -n1)

# Encrypt the message
gpg --encrypt --armor --recipient "$key_id" --output "$output_file" "$message_file"

echo "Message encrypted and saved to $output_file"
