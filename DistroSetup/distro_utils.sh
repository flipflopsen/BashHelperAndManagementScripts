#!/usr/bin/env bash
# =============================================================================
# distro_utils.sh - Linux distribution & package manager abstraction layer
#
# Provides helper functions to detect the current Linux distribution,
# identify the available package manager, and perform installation/update
# operations in a distribution-agnostic manner.
#
# Supported managers: apt, dnf, yum, pacman (yay or sudo pacman)
# Author      : flipflopsen
# License     : MIT
# Updated     : 2025-07-14
# =============================================================================
set -o errexit -o nounset -o pipefail

# -----------------------------------------------------------------------------
# Detect distribution and package manager
# -----------------------------------------------------------------------------
DETECTED_PM=""

detect_package_manager() {
    if command -v apt &>/dev/null; then
        DETECTED_PM="apt"
    elif command -v dnf &>/dev/null; then
        DETECTED_PM="dnf"
    elif command -v yum &>/dev/null; then
        DETECTED_PM="yum"
    elif command -v yay &>/dev/null; then
        DETECTED_PM="yay"   # Arch with yay helper (preferred)
    elif command -v pacman &>/dev/null; then
        DETECTED_PM="pacman"
    else
        echo "Unsupported distro: no known package manager found (apt, dnf, yum, pacman/yay)" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Package manager wrappers
# -----------------------------------------------------------------------------
pkg_update() {
    case "$DETECTED_PM" in
        apt)    sudo apt update -y;;
        dnf)    sudo dnf makecache --refresh -y;;
        yum)    sudo yum makecache -y;;
        yay)    yay -Sy --noconfirm;;
        pacman) sudo pacman -Sy --noconfirm;;
    esac
}

pkg_install() {
    local pkgs=("$@")
    case "$DETECTED_PM" in
        apt)    sudo apt install -y "${pkgs[@]}";;
        dnf)    sudo dnf install -y "${pkgs[@]}";;
        yum)    sudo yum install -y "${pkgs[@]}";;
        yay)    yay -S --needed --noconfirm "${pkgs[@]}";;
        pacman) sudo pacman -S --needed --noconfirm "${pkgs[@]}";;
    esac
}

pkg_exists() {
    local pkg="$1"
    case "$DETECTED_PM" in
        apt)    dpkg -s "$pkg" &>/dev/null;;
        dnf|yum) rpm -q "$pkg" &>/dev/null;;
        yay|pacman) pacman -Qi "$pkg" &>/dev/null;;
    esac
}

# Call detection immediately on sourcing
if [[ -z "${DETECTED_PM}" ]]; then
    detect_package_manager
fi
