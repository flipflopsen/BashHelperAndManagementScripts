# Linux bash utils and stuff. (TMUX, Git, GPG)
This repository contains some scripts and utilities I've written with the goal of creating some comfort in setting up and using other software in some use cases.

No guarantee of 100% bug-free code.
PR's are welcome as long as you don't try to shamefully include some "magic" bytecode in there. 

## Scripts Overview
### Git section
1. **CreateEncryptedGitAccess**: Encrypts and stores Git credentials.
2. **gitclonepac**: Utilizes encrypted credentials to securely clone repositories.
3. **SetGitAccountAccess**: Configures and encrypts GitHub account details, also manages local Git settings.
### Terminal Multiplexer
1. **tmux_manager**: A robust tool for handling various tmux session operations, saves sessions beyond reboot, etc. (has colors)
### GPG related
1. **encrypt**: Encrypt

## Prerequisites
The following tools and libraries are required to run these scripts:
- `bash`
- `git` (for Git-related scripts)
- `tmux` (for managing tmux sessions you probably need tmux)
- `openssl` (for handling encryption and decryption)
- `jq` (for parsing JSON in Bash scripts)
- `gpg` (for GPG related operations (encrypt/decrypt))

These tools can typically be installed via your Linux distribution’s package manager. Below are instructions for different systems and package managers:

**Ubuntu (Debian-based distros)**
```bash
sudo apt update
sudo apt install bash git tmux openssl jq gpg
```

**Arch-based distros**
```bash
sudo pacman -Syu
sudo pacman -S bash git tmux openssl jq gpg
```

**Fedora (and other RHEL-based distros)**
```bash
sudo dnf update
sudo dnf install bash git tmux openssl jq gpg
```

**Homebrew (for macOS and Linux)** Homebrew doesn't support direct installation of packages like bash or tmux natively on Linux as system tools, but it can be used for various applications:
```bash
brew install git jq gpg tmux
```
---
## Usage
### CreateEncryptedGitAccess
**Purpose**: This script encrypts and saves your Git username and personal access token using AES-256-CBC as a text file to be used in "gitclonepac.sh".

#### How to Run
`./CreateEncryptedGitAccess.sh`
Follow the prompts to input your Git credentials and an encryption password.

---
### gitclonepac
**Purpose**: Clones a Git repository using the file created from "CreateEncryptedGitAccess" or "SetGitAccountAccess", since both scripts are saving your encrypted username + personal access token.

#### How to Run
`./gitclonepac.sh <repository-url>`
Ensure you provide the correct repository URL and that you have an existing encrypted credentials file.

---
### SetGitAccountAccess
**Purpose**: Configures your Git account details on your local machine and saves username and personal access token with the same encryption (AES-256-CBC) as the "CreateEncryptedGitAccess" script.

#### How to Run
`./SetGitAccountAccess.sh [optional-output-file-path]`
The script uses a default path for the output file, but you can specify a different one as a command-line argument.

---
### tmux_manager
**Purpose**: Provides an interactive menu to manage tmux sessions, including their creation, (re)naming, saving and deletion as well as some configuration.

#### How to Run
`./tmux_manager.sh`

Use the interactive menu to select options for managing your tmux sessions.
The sessions are selectable via their session number or by their name (string representation).

I personally would create a shortcut.
If you do that you can either move this script to some location already in path (like .local/bin), or call it directly off the cloned folder.
How you create a shortcut on the linux distro your using is a case of using a search engine in case you don't already know how to create one.

---
### Overview of GPG related scripts
This project includes two main scripts, `encrypt.sh` and `decrypt.sh`, used for encryption and decryption of messages using GPG. The scripts are designed to handle encryption keys and messages within a specific directory structure to keep the system organized and secure.

#### Folder Structure
The scripts operate within the following directory structure:

```
.
├── decrypt.sh
├── encrypt.sh
├── Keys
│   ├── Private
│   │   └── priv.asc       # Replace with your private key, if needed (wouldn't recommend leaving it there)
│   ├── Public
│   │   └── pub.asc        # Replace with your public key
│   └── README.md
└── Messages
    ├── Decrypted
    ├── Encrypted
    ├── ToDecrypt
    └── ToEncrypt
```

- **Keys/Public**: Contains public keys used for encrypting messages.
- **Keys/Private**: Contains private keys used for decrypting messages.
- **Messages/Encrypted**: Stores encrypted messages.
- **Messages/Decrypted**: Stores decrypted messages.

#### Usage
##### Encrypting Messages
Run `encrypt.sh` with the required parameters:
```bash
./encrypt.sh <path-to-message-file> [optional-output-file-path] [optional-public-key-id]
```

- `<path-to-message-file>`: Mandatory parameter specifying the path to the plain text message file you want to encrypt.
- `[optional-output-file-path]`: Optional parameter to specify a custom path for the output file, defaults to `Messages/Encrypted/Message-{nr}.txt` where `{nr}` is replaced by the next available number.
- `[optional-public-key-id]`: Optional parameter specifying the filename of the public key within `Keys/Public` to use for encryption, defaults to `pub.asc`.

Example:
```bash
./encrypt.sh Messages/ToEncrypt/test_message.txt Messages/Encrypted/custom_message_1.txt my_pubkey.asc
```

##### Decrypting Messages
Run `decrypt.sh` with the required parameter:
```bash
./decrypt.sh <path-to-encrypted-file>
```

- `<path-to-encrypted-file>`: Mandatory parameter specifying the path to the encrypted message file that you want to decrypt.

Example:
```bash
./decrypt.sh Messages/Encrypted/Message-1.txt
```

The decrypted content will be saved in the `Messages/Decrypted` directory, following the naming convention `Message-{nr}.txt`.

##### Security Notice
- Always verify that the permissible keys (`pub.asc` for public and `priv.asc` for private keys) are securely stored and access is restricted.
- Do not expose private keys in unsecured locations.
- Regularly update and backup your keys to prevent data loss.

---
### Configuration
Normally the scripts provide (optional) input arguments.
The tmux_manager script has a configuration menu which is interactive.

### Some words
Generally, take extra precautions with how you handle your encryption keys and passwords - these Git scripts are not guaranteed to offer state-of-the-art secure management of passwords/credentials but are rather some tooling I've created for my workflow in specific use cases. No guarantees or insurance are provided.

I've tried to comment on the code and make it as readable as possible. I would recommend, especially for the Git scripts, that you first take a look at them before trusting them, which should generally apply to code you don’t know or clone from a random person on GitHub. :)