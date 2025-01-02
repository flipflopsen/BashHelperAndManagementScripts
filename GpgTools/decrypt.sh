#!/bin/bash

# Default paths for private keys
PRIVATE_KEYS_FOLDER="Keys/Private"
DEFAULT_KEY="priv.asc"

# Check input
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <encrypted-file>"
    exit 1
fi

encrypted_file=$1

# Validate the private key path
private_key="$PRIVATE_KEYS_FOLDER/$DEFAULT_KEY"
if [ ! -f "$private_key" ]; then
    echo "Error: Private key file $private_key not found"
    exit 1
fi

# Create DecryptedMessages directory if it doesn't exist
mkdir -p Messages/Decrypted

# Find the next available number for the decrypted message
number=1
while [[ -f "Messages/Decrypted/Message-$number.txt" ]]; do
    ((number++))
done

output_file="Messages/Decrypted/Message-$number.txt"

# Import the private key (if not already in the keyring)
gpg --import "$private_key"

# Decrypt the message
gpg --decrypt "$encrypted_file" > "$output_file"

echo "Message decrypted and saved to $output_file"
