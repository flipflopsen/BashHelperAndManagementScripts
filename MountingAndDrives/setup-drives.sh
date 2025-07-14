#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Drive Setup: Automated mounting, symlinks and development links for
# additional storage devices on Linux.
#
# This script detects internal / external drives, creates mount points under
# /mnt, configures fstab for auto-mount on boot, and can optionally create
# convenient symlinks in ~/Drives as well as developer-oriented links in
# ~/Development/Storage.  It also supports listing, mounting, unmounting all
# drives and an interactive mode for fine-grained selection.
#
# Author   : flipflopsen
# License  : MIT
# Updated  : 2025-07-14
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Configuration Section
# Customize default paths and settings here
# ----------------------------------------------------------------------------

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default flags
AUTO_DETECT=false
SETUP_AUTOMOUNT=false
CREATE_SYMLINKS=false
SETUP_DEVELOPMENT_LINKS=false
LIST_DRIVES=false
INTERACTIVE=false
MOUNT_ALL=false
UNMOUNT_ALL=false

# Default directories
MOUNT_BASE="/mnt"
SYMLINK_BASE="$HOME/Drives"
DEV_SYMLINK_BASE="$HOME/Development/Storage"

# White-/Blacklist, if USE_BLACKLIST is false, whitelist will be used.
USE_BLACKLIST=true
DRIVE_WHITELIST=("/dev/sda1"
                 "/dev/sdc1"
                 "/dev/nvme0n1p1")

DRIVE_BLACKLIST=("/dev/nvme0n1p1"
                 "/dev/nvme0n1p2"
                 "/dev/sdf1"
                 "/dev/sdf2")

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_blue() {
    echo -e "${BLUE}[DETECT]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Hard Drive Mount and Symlink Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -d, --detect           Auto-detect and display available drives
    -a, --automount        Setup automatic mounting on boot
    -s, --symlinks         Create convenient symlinks in ~/Drives
    -v, --dev-links        Create development-focused symlinks
    -l, --list             List currently mounted drives
    -i, --interactive      Interactive mode for drive selection
    -m, --mount-all        Mount all detected drives
    -u, --unmount-all      Unmount all additional drives
    -h, --help             Show this help message

EXAMPLES:
    $0 --detect --symlinks              # Detect drives and create symlinks
    $0 --interactive --automount        # Interactive setup with automount
    $0 --mount-all --dev-links          # Mount all and create dev symlinks
    $0 --list                           # Show current mounts

DIRECTORIES:
    Mounts:     $MOUNT_BASE/drive_*
    Symlinks:   $SYMLINK_BASE/
    Dev Links:  $DEV_SYMLINK_BASE/
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--detect)
            AUTO_DETECT=true
            shift
            ;;
        -a|--automount)
            SETUP_AUTOMOUNT=true
            shift
            ;;
        -s|--symlinks)
            CREATE_SYMLINKS=true
            shift
            ;;
        -v|--dev-links)
            SETUP_DEVELOPMENT_LINKS=true
            shift
            ;;
        -l|--list)
            LIST_DRIVES=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -m|--mount-all)
            MOUNT_ALL=true
            shift
            ;;
        -u|--unmount-all)
            UNMOUNT_ALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if running as root for certain operations
check_root_needed() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        print_error "It will use sudo when needed for specific operations."
        exit 1
    fi
}

# Check if partition is EFI or other stuff
check_partition() {
    local device_path="$1"
    local efi_guid="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
    #local ms_header_guid="e3c9e316-0b5c-4db8-817d-f92df00215ae"

    # Get the partition type using lsblk
    local parttype
    parttype=$(lsblk -no PARTTYPE "$device_path" 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs)

    #if [[ "$parttype" == "$efi_guid" || "$parttype" == "$ms_header_guid" ]]; then
    if [[ "$parttype" == "$efi_guid" ]]; then
        return 1
    else
        return 0
    fi
}


# Function to get drive info
get_drive_info() {
    local device=$1
    local size=$(lsblk -b -d -o SIZE -n "$device" 2>/dev/null | numfmt --to=iec)
    local model=$(lsblk -d -o MODEL -n "$device" 2>/dev/null | xargs)
    local label=$(lsblk -o LABEL -n "$device" 2>/dev/null | head -1 | xargs)
    local fstype=$(lsblk -o FSTYPE -n "$device" 2>/dev/null | head -1 | xargs)

    echo "Size: $size, Model: $model, Label: $label, FS: $fstype"
}

# Helper to check if device is in whitelist
is_in_whitelist() {
    local device=$1
    for d in "${DRIVE_WHITELIST[@]}"; do
        if [[ "$d" == "$device" ]]; then
            return 0
        fi
    done
    return 1
}

# Helper to check if device is blacklist whitelist
is_in_blacklist() {
    local device=$1
    for d in "${DRIVE_BLACKLIST[@]}"; do
        if [[ "$d" == "$device" ]]; then
            return 0
        fi
    done
    return 1
}


# Function to detect available drives
detect_drives() {
    print_status "Detecting available drives..."

    # Get all block devices except loop devices and the root device
    local root_device=$(df / | tail -1 | cut -d' ' -f1 | sed 's/[0-9]*$//')

    echo
    print_blue "Available drives (excluding root drive $root_device):"
    echo "=================================================================="

    # List all drives with details
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $7}')

        # Skip if it's the root device or a partition of it
        if [[ "$device" == *"$root_device"* ]]; then
            continue
        fi

        # Skip if it's a loop device
        if [[ "$device" == *"loop"* ]]; then
            continue
        fi

        local info=$(get_drive_info "$device")

        if [[ -n "$mountpoint" && "$mountpoint" != "" ]]; then
            echo "📁 $device -> $mountpoint"
        else
            echo "💾 $device (unmounted)"
        fi
        echo "   $info"
        echo
    done < <(lsblk -o NAME,SIZE,MOUNTPOINT,FSTYPE | grep -E '^[├└]?[─├└]*sd[a-z][0-9]*|^[├└]?[─├└]*nvme[0-9]+n[0-9]+p[0-9]+' | sed 's/^[├└─]*//g')
}

# Function to list currently mounted drives
list_mounted_drives() {
    print_status "Currently mounted drives:"
    echo

    # Show mounted filesystems excluding system ones
    df -h | grep -E '^/dev/(sd|nvme)' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local avail=$(echo "$line" | awk '{print $4}')
        local use_percent=$(echo "$line" | awk '{print $5}')
        local mountpoint=$(echo "$line" | awk '{print $6}')

        echo "📂 $device"
        echo "   Mount: $mountpoint"
        echo "   Size: $size | Used: $used ($use_percent) | Available: $avail"

        # Check for symlinks pointing to this mount
        if [[ -d "$SYMLINK_BASE" ]]; then
            local symlinks=$(find "$SYMLINK_BASE" -type l -exec readlink {} \; -print 2>/dev/null | grep -B1 "$mountpoint" | grep "$SYMLINK_BASE" || true)
            if [[ -n "$symlinks" ]]; then
                echo "   Symlinks: $symlinks"
            fi
        fi
        echo
    done
}

# Function to create mount point and mount drive
mount_drive() {
    local device=$1
    local label=$2
    local mount_name=${3:-$(basename "$device")}

    local mount_point="$MOUNT_BASE/$mount_name"

    #print_status "Mounting $device to $mount_point..."

    # Create mount point
    sudo mkdir -p "$mount_point"

    # Determine filesystem type
    local fstype=$(lsblk -o FSTYPE -n "$device" | head -1 | xargs)

    # Mount with appropriate options
    case "$fstype" in
        "ntfs")
            print_status "Mounting NTFS device $device to $mount_point..."
            sudo mount -t ntfs-3g -o defaults,noatime,utf8,dmask=002,fmask=111,uid=1000,gid=1000 "$device" "$mount_point"
            ;;
        "exfat")
            print_status "Mounting exFAT device: $device to $mount_point with user permissions..."
            sudo mount -t exfat -o defaults,user,uid=1000,gid=1000,umask=002 "$device" "$mount_point"
            ;;
        "vfat"|"fat32")
            print_status "Mounting VFAT device: $device to $mount_point..."
            sudo mount -t vfat -o defaults,uid=1000,gid=1000,umask=022 "$device" "$mount_point"
            ;;
        "ext4"|"ext3"|"ext2")
            print_status "Mounting EXT device $device to $mount_point..."
            sudo bindfs -u $(id -u) -g $(id -g) -p 755 "$device" "$mount_point"
            ;;
        *)
            print_status "Mounting device $device to $mount_point with default options..."
            sudo mount "$device" "$mount_point"
            ;;
    esac

    print_status "Successfully mounted $device to $mount_point"
    return 0
}

# Function to create symlinks
create_symlinks() {
    print_status "Creating symlinks in $SYMLINK_BASE..."

    mkdir -p "$SYMLINK_BASE"

    # Find all mounted drives and create symlinks
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $6}')

        # Skip if it's the root filesystem
        if [[ "$mountpoint" == "/" ]]; then
            continue
        fi

        # Skip system mounts
        if [[ "$mountpoint" =~ ^/(boot|proc|sys|dev|run|tmp) ]]; then
            continue
        fi

        # Create a friendly name for the symlink
        local drive_name
        local label=$(lsblk -o LABEL -n "$device" 2>/dev/null | head -1 | xargs)

        if [[ -n "$label" && "$label" != "" ]]; then
            drive_name="$label"
        else
            drive_name=$(basename "$device")
        fi

        # Clean up the name (remove spaces, special chars)
        drive_name=$(echo "$drive_name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        local symlink_path="$SYMLINK_BASE/$drive_name"

        # Create symlink if it doesn't exist
        if [[ ! -L "$symlink_path" ]]; then
            ln -sf "$mountpoint" "$symlink_path"
            print_status "Created symlink: $symlink_path -> $mountpoint"
        else
            print_warning "Symlink already exists: $symlink_path"
        fi

    done < <(df | grep -E '^/dev/(sd|nvme)')
}

# Function to create development-focused symlinks
create_dev_symlinks() {
    print_status "Creating development-focused symlinks in $DEV_SYMLINK_BASE..."

    mkdir -p "$DEV_SYMLINK_BASE"

    # Create symlinks for common development directories
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $6}')

        # Skip root and system mounts
        if [[ "$mountpoint" == "/" ]] || [[ "$mountpoint" =~ ^/(boot|proc|sys|dev|run|tmp) ]]; then
            continue
        fi

        local label=$(lsblk -o LABEL -n "$device" 2>/dev/null | head -1 | xargs)
        local drive_name

        if [[ -n "$label" && "$label" != "" ]]; then
            drive_name="$label"
        else
            drive_name=$(basename "$device")
        fi

        drive_name=$(echo "$drive_name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        # Create development-specific symlinks
        local dev_symlink="$DEV_SYMLINK_BASE/$drive_name"

        if [[ ! -L "$dev_symlink" ]]; then
            ln -sf "$mountpoint" "$dev_symlink"
            print_status "Created dev symlink: $dev_symlink -> $mountpoint"
        fi

        # Create specific project symlinks if common directories exist
        for dir in "Projects" "Code" "Development" "Repositories" "Git"; do
            if [[ -d "$mountpoint/$dir" ]]; then
                local project_symlink="$DEV_SYMLINK_BASE/${drive_name}_${dir}"
                if [[ ! -L "$project_symlink" ]]; then
                    ln -sf "$mountpoint/$dir" "$project_symlink"
                    print_status "Created project symlink: $project_symlink -> $mountpoint/$dir"
                fi
            fi
        done

    done < <(df | grep -E '^/dev/(sd|nvme)')
}

# Function to setup automount
setup_automount() {
    print_status "Setting up automatic mounting..."

    # Create backup directory if it doesn't exist
    local backup_dir="/etc/fstab_backups"
    sudo mkdir -p "$backup_dir"

    # Backup current fstab with timestamp in the backup directory
    local backup_file="$backup_dir/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/fstab "$backup_file"
    print_status "Backed up fstab to $backup_file"

    print_status "Creating fstab entries for automatic mounting..."

    # Get unmounted drives
    while IFS= read -r device; do
        local mountpoint=$(lsblk -o MOUNTPOINT -n "$device" | head -1)

        # Skip if already mounted
        if [[ -n "$mountpoint" ]]; then
            continue
        fi

        local uuid=$(lsblk -o UUID -n "$device" | head -1)
        local fstype=$(lsblk -o FSTYPE -n "$device" | head -1)
        local label=$(lsblk -o LABEL -n "$device" | head -1 | xargs)

        if [[ -n "$uuid" && -n "$fstype" ]]; then
            local mount_name
            if [[ -n "$label" ]]; then
                mount_name=$(echo "$label" | sed 's/[^a-zA-Z0-9._-]/_/g')
            else
                mount_name=$(basename "$device")
            fi

            local mount_point="$MOUNT_BASE/$mount_name"
            local options

            case "$fstype" in
                "ntfs")
                    options="defaults,noatime,uid=$(id -u),gid=$(id -g),umask=022,auto,user"
                    ;;
                "exfat")
                    options="defaults,noatime,uid=$(id -u),gid=$(id -g),umask=022,auto,user"
                    ;;
                "vfat"|"fat32")
                    options="defaults,noatime,uid=$(id -u),gid=$(id -g),umask=022,auto,user"
                    ;;
                "ext4"|"ext3"|"ext2")
                    options="defaults,noatime,auto,user"
                    ;;
                *)
                    options="defaults,noatime,auto,user"
                    ;;
            esac

            # Create mount point
            sudo mkdir -p "$mount_point"

            # Add to fstab
            local fstab_entry="UUID=$uuid $mount_point $fstype $options 0 2"

            if ! grep -q "$uuid" /etc/fstab; then
                echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
                print_status "Added to fstab: $mount_point ($device)"
            else
                print_warning "Entry for $device already exists in fstab"
            fi
        fi

    done < <(lsblk -o NAME -n | grep -E '^[├└]?[─├└]*sd[a-z][0-9]+|^[├└]?[─├└]*nvme[0-9]+n[0-9]+p[0-9]+' | sed 's/^[├└─]*//g' | sed 's/^/\/dev\//')

    print_status "Automount setup complete. Drives will mount automatically on next boot."
}


# Function to mount all detected drives
mount_all_drives() {
    print_status "Mounting all detected drives..."

    while IFS= read -r device; do
        if [[ "$USE_BLACKLIST" == true ]]; then
            if is_in_blacklist "$device"; then
                print_warning "$device is in blacklist, skipping."
                continue
            fi
        else
            if ! is_in_whitelist "$device"; then
                print_warning "$device is not in whitelist, skipping."
                continue
            fi
        fi
        local mountpoint=$(lsblk -o MOUNTPOINT -n "$device" | head -1)

        # Skip if already mounted
        if [[ -n "$mountpoint" ]]; then
            print_warning "$device is already mounted at $mountpoint"
            continue
        fi

        local label=$(lsblk -o LABEL -n "$device" | head -1 | xargs)
        local mount_name

        if [[ -n "$label" ]]; then
            mount_name=$(echo "$label" | sed 's/[^a-zA-Z0-9._-]/_/g')
        else
            mount_name=$(basename "$device")
        fi

        print_status
        check_partition "$device"
        if [[ $? -eq 1 ]]; then
            print_error "BAD PART DETECTED"
        else
            echo "Safe to proceed with $device"
        fi

        if mount_drive "$device" "$label" "$mount_name"; then
            print_status "Successfully mounted $device"
        else
            print_error "Failed to mount $device"
        fi

    done < <(lsblk -o NAME -n | grep -E '^[├└]?[─├└]*sd[a-z][0-9]+|^[├└]?[─├└]*nvme[0-9]+n[0-9]+p[0-9]+' | sed 's/^[├└─]*//g' | sed 's/^/\/dev\//')
}

# Function to unmount all additional drives
unmount_all_drives() {
    print_status "Unmounting all additional drives..."

    # Get root device to avoid unmounting it
    local root_device=$(df / | tail -1 | cut -d' ' -f1 | sed 's/[0-9]*$//')

    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $6}')

        # Skip root and system mounts
        if [[ "$device" == *"$root_device"* ]] || [[ "$mountpoint" =~ ^/(|boot|proc|sys|dev|run|tmp)$ ]]; then
            continue
        fi

        # Check whitelist/blacklist
        if [[ "$USE_BLACKLIST" == true ]]; then
            if is_in_blacklist "$device"; then
                print_warning "$device is in blacklist, skipping unmount."
                continue
            fi
        else
            if ! is_in_whitelist "$device"; then
                print_warning "$device is not in whitelist, skipping unmount."
                continue
            fi
        fi

        print_status "Unmounting $device from $mountpoint..."
        if sudo umount "$mountpoint"; then
            print_status "Successfully unmounted $device"

            # Remove mount point if it's in our standard location
            if [[ "$mountpoint" == "$MOUNT_BASE"/* ]]; then
                sudo rmdir "$mountpoint" 2>/dev/null || true
            fi
        else
            print_error "Failed to unmount $device"
        fi

    done < <(df | grep -E '^/dev/(sd|nvme)')

    # Clean up broken symlinks
    if [[ -d "$SYMLINK_BASE" ]]; then
        find "$SYMLINK_BASE" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    fi

    if [[ -d "$DEV_SYMLINK_BASE" ]]; then
        find "$DEV_SYMLINK_BASE" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    fi
}

# Interactive mode
interactive_mode() {
    print_status "Interactive Drive Setup Mode"
    echo "=============================="

    detect_drives

    echo
    echo "What would you like to do?"
    echo "1) Mount all detected drives"
    echo "2) Mount specific drives"
    echo "3) Create symlinks for mounted drives"
    echo "4) Setup automount"
    echo "5) Create development symlinks"
    echo "6) Show current mounts"
    echo "7) Unmount all additional drives"
    echo "0) Exit"

    read -p "Choose an option [0-7]: " choice

    case $choice in
        1)
            mount_all_drives
            echo
            read -p "Create symlinks? [y/N]: " create_links
            if [[ "$create_links" =~ ^[Yy] ]]; then
                create_symlinks
            fi
            ;;
        2)
            echo "Available unmounted drives:"
            lsblk -o NAME,SIZE,LABEL,FSTYPE | grep -E '^[├└]?[─├└]*sd[a-z][0-9]+|^[├└]?[─├└]*nvme[0-9]+n[0-9]+p[0-9]+' | sed 's/^[├└─]*//g'
            echo
            read -p "Enter device name (e.g., sdb1): " device_name
            if [[ -b "/dev/$device_name" ]]; then
                mount_drive "/dev/$device_name"
            else
                print_error "Device /dev/$device_name not found"
            fi
            ;;
        3)
            create_symlinks
            ;;
        4)
            setup_automount
            ;;
        5)
            create_dev_symlinks
            ;;
        6)
            list_mounted_drives
            ;;
        7)
            read -p "Are you sure you want to unmount all additional drives? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                unmount_all_drives
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Main execution
check_root_needed

# Create base directories
mkdir -p "$SYMLINK_BASE" "$DEV_SYMLINK_BASE"

# Execute based on flags
if [[ "$LIST_DRIVES" == true ]]; then
    list_mounted_drives
fi

if [[ "$AUTO_DETECT" == true ]]; then
    detect_drives
fi

if [[ "$UNMOUNT_ALL" == true ]]; then
    unmount_all_drives
fi

if [[ "$MOUNT_ALL" == true ]]; then
    mount_all_drives
fi

if [[ "$CREATE_SYMLINKS" == true ]]; then
    create_symlinks
fi

if [[ "$SETUP_DEVELOPMENT_LINKS" == true ]]; then
    create_dev_symlinks
fi

if [[ "$SETUP_AUTOMOUNT" == true ]]; then
    setup_automount
fi

if [[ "$INTERACTIVE" == true ]]; then
    interactive_mode
fi

# If no specific flags were used, show help
if [[ "$AUTO_DETECT" == false && "$SETUP_AUTOMOUNT" == false && "$CREATE_SYMLINKS" == false && "$SETUP_DEVELOPMENT_LINKS" == false && "$LIST_DRIVES" == false && "$INTERACTIVE" == false && "$MOUNT_ALL" == false && "$UNMOUNT_ALL" == false ]]; then
    show_help
    echo
    print_status "Quick start: Run with --interactive for guided setup"
fi

print_status "Drive setup operations completed!"