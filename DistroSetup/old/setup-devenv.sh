#!/bin/bash

# Arch Linux Development Environment Setup Script
# Usage: ./setup-dev-env.sh [OPTIONS]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default flags
INSTALL_BASE=true
INSTALL_LANGUAGES=true
INSTALL_IDES=true
INSTALL_LSP=true
INSTALL_DATABASES=true
INSTALL_SECURITY=true
INSTALL_AI_ML=true
INSTALL_UTILS=true
SETUP_PROJECTS=true
INSTALL_ALL=true

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

# Help function
show_help() {
    cat << EOF
Arch Linux Development Environment Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -b, --base         Install base development tools (default: enabled)
    -l, --languages    Install programming languages and compilers
    -i, --ides         Install IDEs and editors
    -s, --lsp          Install Language Server Protocol packages
    -d, --databases    Install databases (PostgreSQL, etc.)
    -t, --security     Install security/pentesting tools
    -m, --ai-ml        Install AI/ML development tools
    -u, --utils        Install additional utilities
    -p, --projects     Setup project folder structure
    -a, --all          Install everything
    -h, --help         Show this help message

Examples:
    $0 --all                          # Install everything
    $0 --languages --ides --lsp       # Install languages, IDEs, and LSPs
    $0 --base --projects              # Install base tools and setup projects
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--base)
            INSTALL_BASE=true
            shift
            ;;
        -l|--languages)
            INSTALL_LANGUAGES=true
            shift
            ;;
        -i|--ides) 
            INSTALL_IDES=true
            shift
            ;;
        -s|--lsp)
            INSTALL_LSP=true
            shift
            ;;
        -d|--databases)
            INSTALL_DATABASES=true 
            ;;
        -t|--security)
            INSTALL_SECURITY=true
            shift
            ;;
        -m|--ai-ml)
            INSTALL_AI_ML=true
            shift
            ;;
        -u|--utils)
            INSTALL_UTILS=true
            shift
            ;;
        -p|--projects)
            SETUP_PROJECTS=true
            shift
            ;;
        -a|--all)
            INSTALL_ALL=true
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

# If --all is specified, enable all flags
if [[ "$INSTALL_ALL" == true ]]; then
    INSTALL_BASE=true
    INSTALL_LANGUAGES=true
    INSTALL_IDES=true
    INSTALL_LSP=true
    INSTALL_DATABASES=true
    INSTALL_SECURITY=true
    INSTALL_AI_ML=true
    INSTALL_UTILS=true
    SETUP_PROJECTS=true
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root!"
   exit 1
fi

# Update system first with pacman
print_status "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install prerequisites for yay if not already installed
print_status "Installing prerequisites for yay..."
sudo pacman -S --needed --noconfirm base-devel git

# Install yay if not already installed
if ! command -v yay &> /dev/null; then
    print_status "Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    print_status "Yay installed successfully!"
else
    print_status "Yay is already installed"
fi

# Install base development tools
if [[ "$INSTALL_BASE" == true ]]; then
    print_status "Installing base development tools..."
    yay -S --needed --noconfirm \
        base-devel \
        git \
        wget \
        curl \
        vim \
        neovim \
        tmux \
        htop \
        btop \
        tree \
        unzip \
        zip \
        rsync \
        openssh \
        man-db \
        man-pages \
        less \
        grep \
        sed \
        gawk \
        jq \
        yq
fi

# Install programming languages and compilers
if [[ "$INSTALL_LANGUAGES" == true ]]; then
    print_status "Installing programming languages and compilers..."

    # Core compilers and runtimes
    yay -S --needed --noconfirm \
        gcc \
        clang \
        llvm \
        gdb \
        valgrind \
        cmake \
        meson \
        ninja \
        make \
        autoconf \
        automake \
        pkg-config

    # Python ecosystem
    yay -S --needed --noconfirm \
        python \
        python-pip \
        python-virtualenv \
        python-poetry \
        python-wheel \
        python-setuptools \
        python-pylint \
        python-black \
        python-flake8 \
        python-pytest \
        python-numpy \
        python-pandas \
        python-scipy \
        python-matplotlib \
        python-jupyter \
        ipython

    # Java ecosystem
    yay -S --needed --noconfirm \
        jdk11-openjdk \
        jdk17-openjdk \
        jdk21-openjdk \
        openjdk11-doc \
        openjdk17-doc \
        openjdk21-doc \
        maven \
        gradle

    # Node.js and JavaScript
    yay -S --needed --noconfirm \
        npm \
        yarn

    # Go
    yay -S --needed --noconfirm \
        go \
        go-tools

    # Rust
    yay -S --needed --noconfirm \
        rust-analyzer \
        cargo

    # C# and .NET
    yay -S --needed --noconfirm \
        dotnet-sdk \
        dotnet-runtime \
        omnisharp-roslyn

    # Assembly tools
    yay -S --needed --noconfirm \
        nasm \
        yasm \
        binutils \
        objdump \
        hexdump \
        strace \
        ltrace
fi

# Install IDEs and editors
if [[ "$INSTALL_IDES" == true ]]; then
    print_status "Installing IDEs and editors..."

    # Visual Studio Code
    yay -S --needed --noconfirm \
        visual-studio-code-bin

    # Terminal-based development tools
    yay -S --needed --noconfirm \
        ranger \
        fzf \
        ripgrep \
        fd \
        bat \
        exa \
        git-delta
fi

# Install Language Server Protocol packages
if [[ "$INSTALL_LSP" == true ]]; then
    print_status "Installing Language Server Protocol packages..."

    # Core LSP servers
    yay -S --needed --noconfirm \
        bash-language-server \
        clang \
        rust-analyzer \
        gopls \
        python-lsp-server \
        pyright \
        lua-language-server \
        texlab \
        yaml-language-server \
        typescript-language-server \
        vscode-css-languageserver \
        vscode-html-languageserver \
        vscode-json-languageserver \
        jdtls \
        omnisharp-roslyn \
        dockerfile-language-server-bin \
        marksman \
        cmake-language-server
fi

# Install databases
if [[ "$INSTALL_DATABASES" == true ]]; then
    print_status "Installing databases..."

    # PostgreSQL
    sudo systemctl start postgresql

    # Other databases
    yay -S --needed --noconfirm \
        mariadb \
        mongodb-bin \
        redis \
        sqlite

    # Database tools
    yay -S --needed --noconfirm \
        dbeaver \
        sqlitebrowser
fi

# Install security/pentesting tools
if [[ "$INSTALL_SECURITY" == true ]]; then
    print_status "Installing security and pentesting tools..."

    1
fi

# Install AI/ML development tools
if [[ "$INSTALL_AI_ML" == true ]]; then
    print_status "Installing AI/ML development tools..."

    # Python ML libraries
    yay -S --needed --noconfirm \
        python-scikit-learn \
        python-tensorflow \
        python-pytorch \
        python-transformers \
        python-opencv \
        python-pillow \
        python-seaborn \
        python-plotly

    # Jupyter ecosystem
    yay -S --needed --noconfirm \
        jupyter-notebook \
        jupyterlab

    # Additional ML tools
    yay -S --needed --noconfirm \
        cuda \
        cudnn \
        miniconda3
fi

# Install additional utilities
if [[ "$INSTALL_UTILS" == true ]]; then
    print_status "Installing additional utilities..."

    yay -S --needed --noconfirm \
        kubectl \
        helm \
        terraform \
        ansible \
        vagrant \
        virtualbox \
        qemu \
        libvirt \
        firefox \
        chromium \
        thunderbird \
        discord \
        zoom \
        obs-studio \
        vlc \
        gimp \
        inkscape \
        blender \
        postman-bin \
        insomnia

    # Enable Docker
    #sudo systemctl enable docker
    #sudo systemctl start docker
    #sudo usermod -aG docker $USER
fi

# Setup project folder structure
if [[ "$SETUP_PROJECTS" == true ]]; then
    print_status "Setting up project folder structure..."

    # Create main development directory
    mkdir -p ~/Development/{Projects/{Personal,Work,Learning,OpenSource},Tools/{Scripts,Configs,Templates},Resources/{Documentation,References,Assets},Environments/{Docker,VM,Containers},Backup,Archive}

    # Create language-specific directories
    mkdir -p ~/Development/Projects/{Python,Java,CSharp,JavaScript,Go,Rust,C-CPP,Assembly,AI-ML,Security,Web,Mobile,GameDev,Research}

    # Setup git configuration
    print_status "Setting up git configuration..."

    # Setup oh-my-zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_status "Setting up oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Create useful aliases
    cat > ~/.config/zsh/aliases.zsh << 'EOF'
# Development aliases
alias grep='rg'
alias find='fd'

# Package management aliases
alias update='yay -Syu'
alias install='yay -S'
alias search='yay -Ss'
alias remove='yay -R'
alias clean='yay -Sc'
alias orphan='yay -Qtd'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gb='git branch'
alias gd='git diff'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
EOF

    # Create development script templates
    mkdir -p ~/Development/Tools/Templates

    # Python template
    cat > ~/Development/Tools/Templates/python_template.py << 'EOF'
#!/usr/bin/env python3
"""
Module docstring
"""

import argparse
import logging
import sys
from pathlib import Path


def setup_logging(level=logging.INFO):
    """Setup logging configuration"""
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Description of the script')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')

    args = parser.parse_args()

    setup_logging(logging.DEBUG if args.verbose else logging.INFO)

    # Your code here
    print("Hello, World!")


if __name__ == "__main__":
    main()
EOF

    # Create a project initialization script
    cat > ~/Development/Tools/Scripts/init_project.sh << 'EOF'
#!/bin/bash
# Project initialization script

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project_name> [project_type]"
    echo "Project types: python, java, csharp, javascript, go, rust, c, cpp"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_TYPE=${2:-python}
PROJECT_DIR="$HOME/Development/Projects/$PROJECT_NAME"

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize git
git init
echo "# $PROJECT_NAME" > README.md
echo ".vscode/" > .gitignore
echo "*.log" >> .gitignore

# Create project structure based on type
case $PROJECT_TYPE in
    python)
        mkdir -p src tests docs
        touch src/__init__.py
        touch tests/__init__.py
        echo "python-specific files" > requirements.txt
        ;;
    java)
        mkdir -p src/main/java src/test/java
        touch pom.xml
        ;;
    csharp)
        dotnet new console -n $PROJECT_NAME
        ;;
    javascript)
        npm init -y
        mkdir -p src tests
        ;;
    go)
        go mod init $PROJECT_NAME
        touch main.go
        ;;
    rust)
        cargo init
        ;;
    c|cpp)
        mkdir -p src include tests build
        touch Makefile
        ;;
esac

echo "Project $PROJECT_NAME initialized in $PROJECT_DIR"
EOF

    chmod +x ~/Development/Tools/Scripts/init_project.sh

    print_status "Project folder structure created at ~/Development/"
    print_status "Use 'bash ~/Development/Tools/Scripts/init_project.sh <name> <type>' to initialize new projects"
fi

# Final setup and configuration
print_status "Performing final setup..."

# Update locate database
sudo updatedb

# Set up shell configuration
if [[ -f ~/.zshrc ]]; then
    # Source aliases if they exist
    if [[ -f ~/.config/zsh/aliases.zsh ]]; then
        if ! grep -q "source ~/.config/zsh/aliases.zsh" ~/.zshrc; then
            echo "source ~/.config/zsh/aliases.zsh" >> ~/.zshrc
        fi
    fi
else
    print_warning "No .zshrc file found. Oh-my-zsh might not be properly configured."
fi

# Print completion message
print_status "Development environment setup complete!"
print_status "=================================================="
print_status "Summary of what was installed:"

[[ "$INSTALL_BASE" == true ]] && echo "✓ Base development tools"
[[ "$INSTALL_LANGUAGES" == true ]] && echo "✓ Programming languages and compilers"
[[ "$INSTALL_IDES" == true ]] && echo "✓ IDEs and editors"
[[ "$INSTALL_LSP" == true ]] && echo "✓ Language Server Protocol packages"
[[ "$INSTALL_DATABASES" == true ]] && echo "✓ Databases"
[[ "$INSTALL_SECURITY" == true ]] && echo "✓ Security/pentesting tools"
[[ "$INSTALL_AI_ML" == true ]] && echo "✓ AI/ML development tools"
[[ "$INSTALL_UTILS" == true ]] && echo "✓ Additional utilities"
[[ "$SETUP_PROJECTS" == true ]] && echo "✓ Project folder structure"

print_status "=================================================="
print_warning "Please restart your terminal or run 'source ~/.zshrc' to apply changes"
print_warning "If you installed Docker, log out and back in for group changes to take effect"
print_status "Your development environment is ready! Happy coding! 🚀"
