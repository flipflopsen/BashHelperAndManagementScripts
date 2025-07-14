# Bash Helper and Management Scripts

A toolbox of some of my bash scripts, some of them I am using in my daily workflow.
I would recommend the `setup-drives` script, the `tmux_manager` if you're already using tmux and if you dislike tools like Lutris, take a look at `proton-run`.

Before you blindly execute any of the scripts I would strongly recommend taking a quick look at them since a few scripts have a lot of configurable flags or variables at the top of the script.
No guarantee that every script works 100% on your env!

---

## Table of Contents

0. [Prerequisites](#prerequisites)
1. [Categories](#categories)
2. [Repository Map](#repository-map)
3. [Script Highlights](#script-highlights)
4. [Scripts Overview](#scripts-overview)
5. [Some Words](#some-words)
6. [Contributing](#contributing)

---

## Prerequisites

The following tools and libraries are required to run these scripts:

- `bash`
- `git` (for Git-related scripts)
- `tmux` (for managing tmux sessions you probably need tmux)
- `openssl` (for handling encryption and decryption)
- `jq` (for parsing JSON in Bash scripts)
- `gpg` (for GPG related operations (encrypt/decrypt))
- `bindfs` (for permission handling, ensure it is installed on your system and integrate it as required. It's useful when dealing with filesystems that are readable across both Windows and UNIX systems but have differing permissions capabilities.

These tools can typically be installed via your Linux distribution’s package manager. Below are instructions for different systems and package managers:

### **Ubuntu (Debian-based distros)**

```bash
sudo apt update
sudo apt install bash git tmux openssl jq gpg
```

### **Arch-based distros**

```bash
sudo pacman -Syu
sudo pacman -S bash git tmux openssl jq gpg
```

### **Fedora (and other RHEL-based distros)**

```bash
sudo dnf update
sudo dnf install bash git tmux openssl jq gpg
```

**Homebrew (for macOS and Linux)** Homebrew doesn't support direct installation of packages like bash or tmux natively on Linux as system tools, but it can be used for various applications:

```bash
brew install git jq gpg tmux
```

---

## Categories
- **Cross-Distro Dev Setup** – `DistroSetup/dev_setup.sh` installs languages, IDEs, Docker/Podman, databases, LSPs, AI/ML tooling and shell goodies via simple flags. Works on apt, dnf/yum and yay/pacman.
- **Drive Automount & Symlinks** – `MountingAndDrives/setup-drives.sh` detects drives, writes fstab, mounts/unmounts, and creates symlinks under `~/Drives` + `~/Development/Storage`.
- **Moverino** – parallel, pattern-aware file mover / copier (`FileManagement/Moverino.sh`).
- **Proton-Run** – run Windows binaries in isolated Proton prefixes without Steam (`Proton/proton-run`).
- **GPG Helpers** – easy message encryption/decryption and key handling (`Gpg/`).
- **Virtualisation Tools** – convert VMDK → qcow2 (`Virtualization/vmdk2qcow2.sh`).
- **Tiny Quality-of-Life Scripts** – enable/disable touchpad, terminal shortcuts, etc.

## Repository Map

```text
LinToolsAndStuff/
├── DistroSetup/          # Dev-environment bootstrap (cross-distro)
│   ├── dev_setup.sh      # setup for new linux distros, installs a bunch of stuff and is highly configurable
│   ├── distro_utils.sh   # package-manager helper tool
│   └── old/
├── FileManagement/
│   └── Moverino.sh       # high-performance file & folder mover
├── MountingAndDrives/
│   └── setup-drives.sh   # drive automount & links
├── Virtualization/
│   └── vmdk2qcow2.sh     # disk conversion (not written by me)
├── Proton/
│   └── proton-run        # Proton wrapper
├── Gpg/                  # key files + encrypt/decrypt scripts
├── Git/                  # git credential helpers etc.
├── TerminalTools/        # misc CLI helpers
├── PythonTools/          # assorted python utilities
└── README.md             # you are here
```

## Script Highlights

| Script | Purpose |
|--------|---------|
| `dev_setup.sh` | Flag-driven developer setup (languages, IDEs, Docker, databases, AI/ML, etc.). |
| `setup-drives.sh` | Detect/mount drives, fstab entries, symlinks, interactive mode. |
| `Moverino.sh` | Robust parallel file mover/copy tool. |
| `proton-run` | Minimal wrapper to run Windows executables with custom Proton. |
| `tmux_manager` | TMUX Session manager with interactive creation of sessions with renaming, rejoining etc. |


## Scripts Overview

### Git section

1. **CreateEncryptedGitAccess**: Encrypts and stores Git credentials.
2. **gitclonepac**: Utilizes encrypted credentials to securely clone repositories.
3. **SetGitAccountAccess**: Configures and encrypts GitHub account details, also manages local Git settings.
4. **gitdecode**: Decodes GitAccess.txt generated from CreateEncryptedGitAccess, only exists because I needed it once.

### Terminal Multiplexer

1. **tmux_manager**: A robust tool for handling various tmux session operations, saves sessions beyond reboot, etc. (has colors)

### GPG related

1. **encrypt**: Script to encrypt a file using a given public key
2. **decrypt**: Script to decrypt a file using a given private key

### New Distro Setup Script (supports multiple package managers)

```bash
chmod +x DistroSetup/dev_setup.sh
./DistroSetup/dev_setup.sh --all               # everything
./DistroSetup/dev_setup.sh --base --languages  # pick categories
```

Run with `--help` to see all flags.

### Drive handling & Mounting

Use the new script `setup-drives.sh` for mounting drives and creating symlinks.
This script is a lot more fail-safe and supports most used formats, has more checks for e.g. EFI Partitions and more.

```bash
chmod +x MountingAndDrives/setup-drives.sh
./MountingAndDrives/setup-drives.sh --interactive --automount --symlinks
```

If you encounter some **permission issues** on the mounted drive, or some other error then **check the uid and gid** of the mount commands in the script **because they are hardcoded**.

#### Old Scripts

1. **mount_drives**: Script mount drives and change ownership to a user, all defined in the  drive_configuration.json file. And it creates a symlink at a configurable location for easier access via terminal (especially on arch, better than navigating to /run/media/$USER/... all the time).

2. **unmount_drives**: Script to unmount drives defined in the drive_configuration.json file.


### File mover

```bash
chmod +x FileManagement/Moverino.sh
./FileManagement/Moverino.sh --source ~/Downloads --dest /mnt/BigDrive --pattern '*.iso'
```

### Proton launcher

```bash
chmod +x Proton/proton-run
./Proton/proton-run /path/to/game.exe --proton 9.0 --winetricks corefonts
```


---

## Usage

### CreateEncryptedGitAccess

**Purpose**: This script encrypts and saves your Git username and personal access token using AES-256-CBC as a text file to be used in "gitclonepac.sh".

#### How to Run CreateEncryptedGitAccess

`./CreateEncryptedGitAccess.sh`
Follow the prompts to input your Git credentials and an encryption password.

---

### gitclonepac

**Purpose**: Clones a Git repository using the file created from "CreateEncryptedGitAccess" or "SetGitAccountAccess", since both scripts are saving your encrypted username + personal access token.

#### How to Run gitclonepac

`./gitclonepac.sh <repository-url>`
Ensure you provide the correct repository URL and that you have an existing encrypted credentials file.

---

### SetGitAccountAccess

**Purpose**: Configures your Git account details on your local machine and saves username and personal access token with the same encryption (AES-256-CBC) as the "CreateEncryptedGitAccess" script.

#### How to Run SetGitAccountAccess

`./SetGitAccountAccess.sh [optional-output-file-path]`
The script uses a default path for the output file, but you can specify a different one as a command-line argument.

---

### tmux_manager

**Purpose**: Provides an interactive menu to manage tmux sessions, including their creation, (re)naming, saving and deletion as well as some configuration.

#### How to Run tmux_manager

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

```text
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

#### Usage of the GPG Scripts

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

## Some Words

Generally, take extra precautions with how you handle your encryption keys and passwords - these Git scripts are not guaranteed to offer state-of-the-art secure management of passwords/credentials but are rather some tooling I've created for my workflow in specific use cases. No guarantees or insurance are provided.

Normally the scripts provide (optional) input arguments.
A few scripts e.g. the tmux_manager script do have interactive menus, others offer CLI arguments and others utilize flags or (env)vars or everything together.

I've tried to comment on the code and make it as readable as possible. I would recommend, especially for the Git scripts, that you first take a look at them before trusting them, which should generally apply to code you don’t know or clone from a random person on GitHub. :)

## Contributing
If you want to continue then feel free to do so wiht utilizing the PR system and/or Issues section.
