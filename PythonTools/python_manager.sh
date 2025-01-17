#!/bin/bash

BASE_DIR="${1:-/home/flip/.pyenv}"
SYMLINK_PY="/usr/bin/py"

function list_versions() {
    echo "Available Python versions:"
    for version_dir in "$BASE_DIR/versions"/*; do
        version=$(basename "$version_dir")
        short_version=$(echo "$version" | cut -d'.' -f1,2)
        echo "* Python $short_version (full: $version)"
    done
}

function change_version() {
    echo "Enter the version you'd like to activate (e.g., 3.10):"
    read selected_version

    version_path=""
    for version_dir in "$BASE_DIR/versions"/*; do
        version=$(basename "$version_dir")
        short_version=$(echo "$version" | cut -d'.' -f1,2)
        if [[ "$short_version" == "$selected_version" ]]; then
            version_path="$version_dir"
            break
        fi
    done

    if [[ -z "$version_path" ]]; then
        echo "Version $selected_version not found!"
        return
    fi

    ln -sf "$version_path/bin/python$selected_version" "$SYMLINK_PY"

    echo "Activated Python $selected_version from $version_path"
}


function list_installed_packages() {
    echo "Installed pip packages for active Python version ($SYMLINK_PY):"
    "$SYMLINK_PY" -m pip list
    echo
}

function update_shims() {
    echo "Updating shims (typically done via pyenv):"
    command -v pyenv &> /dev/null && pyenv rehash
    echo "Shims updated."
}

while true; do
    echo "Python Version Manager"
    echo
    current_version="$("$SYMLINK_PY" --version 2>/dev/null)"
    current_location=$(readlink -f "$SYMLINK_PY")
    echo "Active Python Version: ${current_version:-None}"
    echo "Location of active version: ${current_location:-None}"
    echo
    echo "Commands:"
    echo "C. Change version"
    echo "V. List available versions"
    echo "P. List installed pip packages of active version"
    echo "S. Set Base dir (default is /home/flip/.pyenv)"
    echo "U. Update available shims and versions"
    echo "X. Exit"
    echo
    echo -n "Input: "

    read -r input
    case $input in
        C|c) change_version ;;
        V|v) list_versions ;;
        P|p) list_installed_packages ;;
        S|s)
            echo "Enter new base directory:"
            read -r new_base_dir
            BASE_DIR="$new_base_dir"
            ;;
        U|u) update_shims ;;
        X|x) exit 0 ;;
        *) echo "Invalid input!" ;;
    esac
done
