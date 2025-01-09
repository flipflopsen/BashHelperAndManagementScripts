#!/bin/bash

# Directories for Python versions and shims
PYTHON_BASE_DIR="/home/flip/.pyenv/versions/"
SHIMS_DIR="/home/flip/.pyenv/shims/"

# Default location for the state management file
STATE_FILE="${HOME}/.archlinux-python/state.json"

# Ensure the state file directory exists
mkdir -p "${HOME}/.archlinux-python"

show_help() {
    echo "Usage: $0 [option] [arguments]"
    echo ""
    echo "Options:"
    echo "  --help                  Display this help message."
    echo "  --list                  List all installed Python versions."
    echo "  --switch <version>      Switch to a specific Python version."
    echo "                          Optionally add '--no-alias' to skip setting 'py' alias."
    echo "  addproject -v <version> <path>  Add a project path to PYTHONPATH for a specific version."
    echo "  removeproject -v <version> <path> Remove a project path from PYTHONPATH for a specific version."
    echo "  -v <version> --list-packages    List installed pip packages for a specified Python version."
    echo ""
}

# List available Python versions with path and assigned projects
list_pythons() {
    echo "Version | Path | Projects"
    ls "${PYTHON_BASE_DIR}" | while read version; do
        local version_path="${PYTHON_BASE_DIR}/$version"
        local projects=$(jq -r ".[\"python$version\"].path | join(\", \")" "$STATE_FILE" 2>/dev/null || echo "No projects assigned")
        echo "$version | $version_path | $projects"
    done
}

# Function to determine the correct shim based on installed version directories
get_shim_for_version() {
    local version=$1
    local major_minor=$(echo "$version" | grep -oP '^\d+\.\d+')
    local shim_path="${SHIMS_DIR}/python${major_minor}"
    if [[ -f "$shim_path" ]]; then
        echo "$shim_path"
    else
        echo ""
    fi
}

# Switch Python versions
switch_python() {
    local version=$1
    local set_alias=${2:-true} # Default to setting alias unless specified otherwise
    local target_python=$(get_shim_for_version "$version")

    if [[ -n "$target_python" ]]; then
        if [[ "$set_alias" == true ]]; then
            sudo ln -sf "$target_python" "/usr/local/bin/py"
            echo "Alias 'py' set to Python $version."
        fi
        echo "Switched to Python $version."
    else
        echo "Python version $version does not exist. Make sure you put the correct version number and that the python executable exists."
    fi
}

list_packages() {
    local version=$1
    local target_python=$(get_shim_for_version "$version")
    if [[ -n "$target_python" ]]; then
        "$target_python" -m pip list
    else
        echo "Python version $version does not have pip or does not exist."
    fi
}

case "$1" in
    --help)
        show_help
        ;;
    --list)
        list_pythons
        ;;
    --switch)
        if [[ "$3" == "--no-alias" ]]; then
            switch_python "$2" false
        else
            switch_python "$2" true
        fi
        ;;
    addproject)
        modify_pythonpath "add" "$3" "$4"
        ;;
    removeproject)
        modify_pythonpath "remove" "$3" "$4"
        ;;
    -v)
        if [[ "$3" == "--list-packages" ]]; then
            list_packages "$2"
        else
            echo "Invalid option for -v. Use '--list-packages'."
        fi
        ;;
    *)
        echo "Unknown option: $1. Use --help for usage."
        ;;
esac
