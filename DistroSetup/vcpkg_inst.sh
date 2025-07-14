#!/usr/bin/env bash
# =============================================================================
# vcpkg_inst.sh – Cross-platform vcpkg installation helper
#
# Installs Microsoft vcpkg into /opt/vcpkg (configurable) and wires your shell
# environment on any mainstream Linux distro.
#
# Author   : flipflopsen
# License  : MIT
# Updated  : 2025-07-14
# =============================================================================
set -o errexit -o nounset -o pipefail

# Import distro abstraction helpers (apt/dnf/yum/pacman/yay)
source "$(dirname "$0")/distro_utils.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VCPKG_INSTALL_DIR="/opt/vcpkg"
VCPKG_REPO="https://github.com/Microsoft/vcpkg.git"
ZSHRC_FILE="$HOME/.zshrc"

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
    echo -e "${BLUE}[VCPKG]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root!"
   print_error "It will use sudo when needed for specific operations."
   exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for required tools
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi
    
    if ! command -v ninja &> /dev/null; then
        missing_deps+=("ninja")
    fi
    
    if ! command -v pkg-config &> /dev/null; then
        missing_deps+=("pkg-config")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v unzip &> /dev/null; then
        missing_deps+=("unzip")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi
    
    # Check for build tools
    if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
        missing_deps+=("gcc or clang")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_status "Installing missing dependencies using detected package manager (${DETECTED_PM})..."
        
        pkg_update
        # Map meta-dependency names to real package names per distro
        local install_list=()
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "gcc or clang")
                    case "$DETECTED_PM" in
                        apt)   install_list+=("build-essential" "clang");;
                        dnf|yum) install_list+=("gcc" "gcc-c++" "clang");;
                        *)     install_list+=("gcc" "clang");;
                    esac
                    ;;
                *) install_list+=("$dep") ;;
            esac
        done
        pkg_install "${install_list[@]}"
    fi
    
    print_status "All prerequisites satisfied"
}

# Function to backup .zshrc
backup_zshrc() {
    if [[ -f "$ZSHRC_FILE" ]]; then
        local backup_file="${ZSHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC_FILE" "$backup_file"
        print_status "Backed up .zshrc to $backup_file"
    fi
}

# Function to install vcpkg
install_vcpkg() {
    print_status "Installing vcpkg to $VCPKG_INSTALL_DIR..."
    
    # Check if vcpkg is already installed
    if [[ -d "$VCPKG_INSTALL_DIR" ]]; then
        print_warning "vcpkg directory already exists at $VCPKG_INSTALL_DIR"
        read -p "Do you want to remove and reinstall? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Removing existing vcpkg installation..."
            sudo rm -rf "$VCPKG_INSTALL_DIR"
        else
            print_status "Updating existing vcpkg installation..."
            cd "$VCPKG_INSTALL_DIR"
            sudo git pull origin master
            sudo ./bootstrap-vcpkg.sh -disableMetrics
            return 0
        fi
    fi
    
    # Create parent directory and set permissions
    sudo mkdir -p "$(dirname "$VCPKG_INSTALL_DIR")"
    
    # Clone vcpkg repository
    print_blue "Cloning vcpkg repository..."
    sudo git clone "$VCPKG_REPO" "$VCPKG_INSTALL_DIR"
    
    # Change to vcpkg directory
    cd "$VCPKG_INSTALL_DIR"
    
    # Run bootstrap script
    print_blue "Running vcpkg bootstrap script..."
    sudo ./bootstrap-vcpkg.sh -disableMetrics
    
    # Set proper permissions
    print_status "Setting proper permissions..."
    sudo chown -R root:root "$VCPKG_INSTALL_DIR"
    sudo chmod -R 755 "$VCPKG_INSTALL_DIR"
    
    # Make vcpkg executable accessible to all users
    sudo chmod 755 "$VCPKG_INSTALL_DIR/vcpkg"
    
    print_status "vcpkg installation completed successfully"
}

# Function to setup environment variables
setup_environment_vars() {
    print_status "Setting up environment variables in $ZSHRC_FILE..."
    
    # Create .zshrc if it doesn't exist
    touch "$ZSHRC_FILE"
    
    # Check if vcpkg environment variables already exist
    if grep -q "# vcpkg environment variables" "$ZSHRC_FILE"; then
        print_warning "vcpkg environment variables already exist in .zshrc"
        read -p "Do you want to update them? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove existing vcpkg configuration
            sed -i '/# vcpkg environment variables/,/# End vcpkg configuration/d' "$ZSHRC_FILE"
        else
            print_status "Skipping environment variable setup"
            return 0
        fi
    fi
    
    # Add vcpkg environment variables to .zshrc
    cat >> "$ZSHRC_FILE" << 'EOF'

# vcpkg environment variables
export VCPKG_ROOT="/opt/vcpkg"
export PATH="$VCPKG_ROOT:$PATH"

# vcpkg aliases and functions
alias vcpkg-search='vcpkg search'
alias vcpkg-install='vcpkg install'
alias vcpkg-remove='vcpkg remove'
alias vcpkg-list='vcpkg list'
alias vcpkg-update='cd $VCPKG_ROOT && git pull && ./bootstrap-vcpkg.sh -disableMetrics'

# vcpkg integration functions
vcpkg-integrate-cmake() {
    echo "Add this to your CMakeLists.txt:"
    echo 'set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")'
}

vcpkg-integrate-meson() {
    echo "Use this meson cross-file: ${VCPKG_ROOT}/scripts/buildsystems/meson/vcpkg.meson"
}

vcpkg-new-project() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: vcpkg-new-project <project_name> [triplet]"
        return 1
    fi
    
    local project_name="$1"
    local triplet="${2:-x64-linux}"
    
    mkdir -p "$project_name"
    cd "$project_name"
    
    # Create vcpkg.json manifest
    cat > vcpkg.json << VCPKG_EOF
{
    "name": "$project_name",
    "version": "0.1.0",
    "dependencies": []
}
VCPKG_EOF
    
    # Create CMakeLists.txt template
    cat > CMakeLists.txt << CMAKE_EOF
cmake_minimum_required(VERSION 3.20)
project($project_name)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_TOOLCHAIN_FILE "\${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")

find_package(PkgConfig REQUIRED)

add_executable($project_name main.cpp)
CMAKE_EOF
    
    # Create main.cpp template
    cat > main.cpp << CPP_EOF
#include <iostream>

int main() {
    std::cout << "Hello from $project_name!" << std::endl;
    return 0;
}
CPP_EOF
    
    echo "Created new vcpkg project: $project_name"
    echo "Default triplet: $triplet"
}

# Set default vcpkg triplet for your system
export VCPKG_DEFAULT_TRIPLET="x64-linux"

# vcpkg tab completion (if available)
if [[ -f "$VCPKG_ROOT/scripts/vcpkg_completion.zsh" ]]; then
    source "$VCPKG_ROOT/scripts/vcpkg_completion.zsh"
fi

# End vcpkg configuration
EOF

    print_status "Environment variables added to $ZSHRC_FILE"
}

# Function to test vcpkg installation
test_vcpkg() {
    print_status "Testing vcpkg installation..."
    
    # Source the new environment
    export VCPKG_ROOT="$VCPKG_INSTALL_DIR"
    export PATH="$VCPKG_INSTALL_DIR:$PATH"
    
    # Test vcpkg command
    if "$VCPKG_INSTALL_DIR/vcpkg" version > /dev/null 2>&1; then
        local version=$("$VCPKG_INSTALL_DIR/vcpkg" version | head -1)
        print_blue "vcpkg is working! Version: $version"
    else
        print_error "vcpkg installation test failed"
        return 1
    fi
    
    # Test a simple package search
    print_blue "Testing package search (searching for 'fmt')..."
    if "$VCPKG_INSTALL_DIR/vcpkg" search fmt > /dev/null 2>&1; then
        print_status "Package search test passed"
    else
        print_warning "Package search test failed (this might be normal on first run)"
    fi
}

# Function to show post-installation instructions
show_post_install_info() {
    print_status "vcpkg Installation Complete!"
    echo "============================================"
    print_blue "Installation Details:"
    echo "  • vcpkg installed at: $VCPKG_INSTALL_DIR"
    echo "  • Environment variables added to: $ZSHRC_FILE"
    echo "  • Default triplet: x64-linux"
    echo
    print_blue "Next Steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Test with: vcpkg search boost"
    echo "  3. Install a package: vcpkg install fmt"
    echo "  4. Use vcpkg-new-project <name> to create new projects"
    echo
    print_blue "CMake Integration:"
    echo "  Add to your CMakeLists.txt:"
    echo '  set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")'
    echo
    print_blue "Useful Aliases Added:"
    echo "  • vcpkg-search <package>    - Search for packages"
    echo "  • vcpkg-install <package>   - Install packages"
    echo "  • vcpkg-list               - List installed packages"
    echo "  • vcpkg-update             - Update vcpkg"
    echo "  • vcpkg-new-project <name> - Create new project with vcpkg"
    echo
    print_warning "Remember to restart your terminal to use the new environment variables!"
}

# Main execution
main() {
    print_status "Starting vcpkg installation and setup..."
    
    check_prerequisites
    backup_zshrc
    install_vcpkg
    setup_environment_vars
    test_vcpkg
    show_post_install_info
    
    print_status "vcpkg setup completed successfully! 🚀"
}

# Run main function
main "$@"

