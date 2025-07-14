#!/usr/bin/env bash
# =============================================================================
# dev_setup.sh – Cross-distro Developer Workstation Bootstrap
#
# Combines the feature-rich flag/CLI framework of the previous `setup-devenv.sh`
# with the cross-distro, modular installation logic of `install_devel.sh`.
#
# Supported distributions: Debian/Ubuntu (apt), Fedora/RHEL (dnf/yum), Arch
# Linux (pacman or yay).  All package operations are routed through
# `distro_utils.sh` wrappers (`pkg_update`, `pkg_install`, `pkg_exists`).
#
# Author   : flipflopsen
# License  : MIT
# Updated  : 2025-07-14
# =============================================================================

# Set bash options
set -o errexit -o nounset -o pipefail
# Script Directory and distro_utils.sh import
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./distro_utils.sh
source "${SCRIPT_DIR}/distro_utils.sh"

# ----------------------- Install Flags-------------------------------------
INSTALL_BASE=false
INSTALL_LANGUAGES=false
INSTALL_IDES=false
INSTALL_LSP=false
INSTALL_DATABASES=false
INSTALL_SECURITY=false
INSTALL_AI_ML=false
INSTALL_UTILS=false
INSTALL_VIRTUALIZATION=false
SETUP_PROJECTS=false
CONFIGURE_GIT=false
INSTALL_PIP_GLOBAL=false
INSTALL_ZSH=false
INSTALL_ZSH_ALIASES=false
INSTALL_ZOXIDE_FZF=false
INSTALL_ALL=false

# Extra
CREATE_ARCH_JAVA_SDKMAN_MANAGER_HELPER=false

# If INSTALL_LANGUAGES, which ones?
INSTALL_PYTHON=false
INSTALL_JAVA=false
INSTALL_RUST=false
INSTALL_GO=false
INSTALL_C=false
INSTALL_CPP=false
INSTALL_ASSEMBLY=false
INSTALL_CSHARP=false
INSTALL_JAVASCRIPT=false
INSTALL_ALL_LANGUAGES=false

# --------------------------------------------------------------------------

# ---------- User-configurable variables (override via env or CLI) ----------
GIT_USER_NAME="${GIT_USER_NAME:-flopsendopsen}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-copyit0@gmail.com}"
DOCKER_GROUP_USER="${DOCKER_GROUP_USER:-$USER}"
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/Development}"
AI_VENV_DIR="${AI_VENV_DIR:-$HOME/ai-venv}"
# --------------------------------------------------------------------------

# ----------------------- Package List--------------------------------------
# Base tools which are useful and Build packages
BASE_PKGS=(git curl wget unzip zip tar bzip2 openssh htop
    neofetch tree lsof strace vim neovim tmux exa ripgrep bat git-delta fzf)
BUILD_PKGS=(cmake make gcc gdb valgrind llvm meson ninja autoconf automake pkg-config)

# Language packages etc.
PYTHON_VERSIONS=(3.13.2
    3.12.3
    3.11.6
    3.10.14
    3.9.21
    2.7.18)
PYTHON_PKGS=(python python-pip python-virtualenv python-uv python3 python3-pip python3-venv python3-ipython python3-pyenv)

JAVA_VERSIONS=(8.0.452-librca
    11.0.21-librca
    17.0.15-librca
    21.0.7-librca
    24.0.1-librca
    25.ea.30-open
    26.ea.5-open)
JAVA_PKGS=(maven gradle)

RUST_PKGS=(rust-analyzer cargo)
JS_PKGS=(npm yarn)
GO_PKGS=(go go-tools)
C_SHARP_PKGS=(dotnet-sdk dotnet-runtime omnisharp-roslyn)
ASSEMBLY_PKGS=(nasm yasm binutils objdump hexdump strace ltrace)

# IDE and LSP packages
IDE_PKGS=(code)

LSP_PKGS=(bash-language-server
    clang
    rust-analyzer
    gopls
    python-lsp-server
    pyright
    lua-language-server
    texlab
    yaml-language-server
    typescript-language-server
    vscode-css-languageserver
    vscode-html-languageserver
    vscode-json-languageserver
    jdtls
    omnisharp-roslyn
    dockerfile-language-server-bin
    marksman
    cmake-language-server)

DB_PKGS=(postgresql mariadb redis sqlite sqlitebrowser dbeaver)
SEC_PKGS=(ufw gufw nmap)

AI_ML_PKGS=(python3-ipython python3-pyenv cuda miniconda3)
ARCHON_AGENT_BUILDER=true

UTILS_PKGS=(htop btop tree unzip zip rsync openssh gnupg lsof strace jq yq)
VIRTUALIZATION_PKGS=(docker docker-compose podman)

# Shell packages
SHELL_PKGS=(zsh zsh-autosuggestions zsh-syntax-highlighting)
ZSH_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)
ZSH_THEME="bureau"

# Pip packages
PIP_PKGS=(uv virtualenv pandas scipy numpy jupyterlab jupyter matplotlib)
PIP_AI_PKGS=(huggingface_hub transformers langflow aider-install codename-goose goose-desktop scikit-learn tensorflow pytorch opencv pillow seaborn plotly)

# ----------------------- Color helpers ------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
print_status() { echo -e "${GREEN}[INFO]${NC} $*"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_error() { echo -e "${RED}[ERR ]${NC} $*" >&2; }
# --------------------------------------------------------------------------

show_help() {
    cat <<EOF
Cross-distro Developer Environment Setup
Usage: $0 [OPTIONS]

OPTIONS
  -b, --base         Install base dev tools
  -l, --languages    Install compilers & runtimes (Python, Go, etc.)
  -i, --ides         Install editors & IDEs
  -s, --lsp          Install Language Server packages
  -d, --databases    Install databases (Postgres, etc.)
  -t, --security     Install security/pentesting tools
  -m, --ai-ml        Install AI/ML tooling
  -u, --utils        Install miscellaneous utilities
  -p, --projects     Create project folder structure under \$PROJECT_ROOT
  -a, --all          Enable all install categories
  -h, --help         Show this help

Environment overrides:
  GIT_USER_NAME, GIT_USER_EMAIL, DOCKER_GROUP_USER, PROJECT_ROOT
EOF
}

# ------------------------- CLI Parsing -------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
    -b | --base) INSTALL_BASE=true ;;
    -l | --languages) INSTALL_LANGUAGES=true ;;
    -i | --ides) INSTALL_IDES=true ;;
    -s | --lsp) INSTALL_LSP=true ;;
    -d | --databases) INSTALL_DATABASES=true ;;
    -t | --security) INSTALL_SECURITY=true ;;
    -m | --ai-ml) INSTALL_AI_ML=true ;;
    -u | --utils) INSTALL_UTILS=true ;;
    -p | --projects) SETUP_PROJECTS=true ;;
    -a | --all) INSTALL_ALL=true ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
    shift
done

if [[ "$INSTALL_ALL" == true ]]; then
    INSTALL_BASE=true INSTALL_LANGUAGES=true INSTALL_IDES=true INSTALL_LSP=true \
        INSTALL_DATABASES=true INSTALL_SECURITY=true INSTALL_AI_ML=true \
        INSTALL_UTILS=true SETUP_PROJECTS=true
fi

if [[ $EUID -eq 0 ]]; then
    print_error "Do not run as root – the script will use sudo when required."
    exit 1
fi

# ---------------------- Helper Functions -----------------------------------
ensure_group_membership() {
    local group=$1 user=$2
    if ! id -nG "$user" | grep -qw "$group"; then
        sudo usermod -aG "$group" "$user"
    fi
}

# ---------------------- Install Functions -----------------------------------
install_base() {
    print_status "Installing base development tools..."
    pkg_update
    local pkgs=(git wget curl vim neovim tmux htop btop tree unzip zip rsync openssh gnupg lsof strace jq yq)
    case "$DETECTED_PM" in
    apt) pkgs+=(build-essential) ;;
    dnf | yum) pkgs+=("@Development Tools") ;;
    yay | pacman) pkgs+=(base-devel) ;;
    esac
    pkg_install "${pkgs[@]}"
}

install_languages() {
    print_status "Installing language runtimes & compilers..."

    if $INSTALL_C; then
        install_c
    fi
    if $INSTALL_CPP; then
        install_cpp
    fi
    if $INSTALL_ASSEMBLY; then
        install_assembly
    fi
    if $INSTALL_PYTHON; then
        install_python_pyenv
    fi
    if $INSTALL_GO; then
        install_go
    fi
    if $INSTALL_JAVASCRIPT; then
        install_javascript
    fi
    if $INSTALL_JAVA; then
        install_java
    fi
    if $INSTALL_RUST; then
        install_rust
    fi
    if $INSTALL_CSHARP; then
        install_csharp
    fi
}

install_python_pyenv() {
    print_status "Installing pyenv & Pythons..."
    case "$DETECTED_PM" in
    apt) pkg_install make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev xz-utils tk-dev libffi-dev ;;
    dnf | yum) pkg_install "@Development Tools" zlib-devel bzip2-devel readline-devel sqlite-devel openssl-devel tk-devel libffi-devel xz-devel ;;
    yay | pacman) pkg_install zlib bzip2 openssl libffi readline sqlite xz tk ;;
    esac
    if ! command -v pyenv &>/dev/null; then
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    fi
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    for ver in "${PYTHON_VERSIONS[@]}"; do pyenv install -s "$ver"; done
    pyenv global "${PYTHON_VERSIONS[0]}"
}

install_pip_global() {
    print_status "Installing global pip packages system-wide..."

    if ! command -v python3 &>/dev/null; then
        print_error "Python3 not installed; run with --languages or --python first."
        return
    fi

    # Upgrade pip itself
    sudo python3 -m pip install --upgrade pip

    # Install the defined package lists globally
    sudo python3 -m pip install "${PIP_PKGS[@]}"
    print_status "Global pip packages installed."
}

install_java() {
    # Install build tooling for Java (Maven/Gradle) via package manager
    pkg_install "${JAVA_PKGS[@]}"

    print_status "Installing Java runtimes via SDKMAN ..."
    # Install/Update SDKMAN if missing
    if [[ ! -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        curl -s "https://get.sdkman.io" | bash
    fi
    # shellcheck disable=SC1090
    source "$HOME/.sdkman/bin/sdkman-init.sh"

    # Iterate over JAVA_VERSIONS array defined at top
    for ver in "${JAVA_VERSIONS[@]}"; do
        print_status "Installing Java $ver via SDKMAN ..."
        sdk install java "$ver" || true
    done
    # Set default Java version to the first entry
    sdk default java "${JAVA_VERSIONS[0]}" || true
}

install_go() {
    print_status "Installing Go..."
    case "$DETECTED_PM" in
    apt) pkg_install golang ;;
    dnf | yum) pkg_install golang ;;
    yay | pacman) pkg_install go ;;
    esac
    mkdir -p "$HOME/go/bin"
    echo 'export GOPATH=$HOME/go' >>~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >>~/.bashrc
}

install_ides() {
    print_status "Installing editors & IDEs..."
    pkg_install "${IDE_PKGS[@]}"
}

install_containers() {
    print_status "Installing Docker & Podman..."
    case "$DETECTED_PM" in
    apt) pkg_install docker.io docker-compose podman ;;
    dnf | yum) pkg_install docker docker-compose podman ;;
    yay | pacman) pkg_install docker docker-compose podman ;;
    esac
    sudo systemctl enable --now docker || true
    ensure_group_membership docker "$DOCKER_GROUP_USER"
}

install_virtualization() {
    print_status "Installing virtualization stack..."
    case "$DETECTED_PM" in
    apt) pkg_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ;;
    dnf | yum) pkg_install "@Virtualization" virt-manager ;;
    yay | pacman) pkg_install qemu virt-manager libvirt edk2-ovmf ;;
    esac
    sudo systemctl enable --now libvirtd || true
    ensure_group_membership libvirt "$USER"
}

install_utils() {
    print_status "Installing miscellaneous CLI utilities..."
    pkg_install "${UTILS_PKGS[@]}"
}

install_ai_ml() {
    print_status "Installing AI/ML system packages..."
    pkg_install "${AI_ML_PKGS[@]}"
    install_ai_ml_pip
}

install_ai_ml_pip() {
    print_status "Installing AI/ML Python packages in virtualenv $AI_VENV_DIR ..."
    if ! command -v python3 &>/dev/null; then
        print_error "Python3 not installed; ensure --languages or --python ran."
        return
    fi
    python3 -m venv "$AI_VENV_DIR"
    source "$AI_VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install "${PIP_PKGS[@]}" "${PIP_AI_PKGS[@]}"
    deactivate
}

install_db() {
    print_status "Installing database packages..."
    pkg_install "${DB_PKGS[@]}"
    case "$DETECTED_PM" in
    apt) sudo systemctl enable --now postgresql || true ;;
    dnf | yum) sudo systemctl enable --now postgresql || true ;;
    yay | pacman) sudo systemctl enable --now postgresql || true ;;
    esac
}

install_security() {
    print_status "Installing security tools..."
    pkg_install "${SEC_PKGS[@]}"
}

install_ai_archon() {
    print_status "Installing Archon (AI agent builder)..."

    # Ensure Docker is installed and running
    if ! command -v docker &>/dev/null; then
        print_warn "Docker not found – installing via install_containers()"
        install_containers
    fi
    sudo systemctl is-active --quiet docker || sudo systemctl start docker

    # Ensure Python3 available
    if ! command -v python3 &>/dev/null; then
        print_warn "Python3 not found – installing base language runtimes"
        install_python_pyenv
    fi

    git clone https://github.com/coleam00/Archon.git ~/Archon || true
    (cd ~/Archon && python3 run_docker.py)
}

install_rust() {
    print_status "Installing Rust toolchain..."
    pkg_install "${RUST_PKGS[@]}"
}

install_csharp() {
    print_status "Installing .NET SDK & runtime..."
    pkg_install "${C_SHARP_PKGS[@]}"
}

install_javascript() {
    print_status "Installing Node.js & JS tooling..."
    case "$DETECTED_PM" in
    apt) pkg_install nodejs npm ;;
    dnf | yum) pkg_install nodejs npm ;;
    yay | pacman) pkg_install nodejs npm ;;
    esac
    pkg_install "${JS_PKGS[@]}"
}

install_c() {
    print_status "Installing C toolchain..."
    pkg_install gcc
}

install_cpp() {
    print_status "Installing C++ toolchain..."
    pkg_install gcc clang
}

install_assembly() {
    print_status "Installing Assembly tooling..."
    pkg_install "${ASSEMBLY_PKGS[@]}"
}

# ----------------------- Configuration Functions -----------------------------------
configure_git() {
    print_status "Configuring git globals..."
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global core.editor "vim"
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.cm commit
}

# ----------------------- Shell, Config and Directory-Structure Functions ---------------------
setup_project_structure() {
    print_status "Setting up project folder structure..."

    local base_dir="$HOME/Development"

    mkdir -p "$base_dir/Projects"/{Personal,Work,Learning,OpenSource}
    mkdir -p "$base_dir/Tools"/{Scripts,Configs,Templates}
    mkdir -p "$base_dir/Resources"/{Documentation,References,Assets}
    mkdir -p "$base_dir/Environments"/{Docker,VM,Containers}
    mkdir -p "$base_dir/"{Backup,Archive}

    local languages=(Python Java CSharp JavaScript Go Rust C-CPP Assembly AI-ML Security Web Mobile GameDev Research)
    local lang_dirs=$(printf "$base_dir/Projects/%s " "${languages[@]}")
    mkdir -p $lang_dirs
}

setup_zoxide_fzf() {
    print_status "Setting up zoxide and fzf..."
    pkg_install zoxide fzf
    echo 'eval "$(zoxide init zsh)"' >>~/.zshrc
    echo "source <(fzf --zsh)" >>~/.zshrc
    echo 'eval "$(fzf --bash)"' >>~/.bashrc
}

setup_zsh_omz() {
    print_status "Setting up oh-my-zsh..."

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    chsh -s "$(command -v zsh)"

    local zshrc="$HOME/.zshrc"

    # Ensure theme is set
    if ! grep -q "^ZSH_THEME=\"${ZSH_THEME}\"" "$zshrc"; then
        sed -i -e "s/^ZSH_THEME=.*$/ZSH_THEME=\"${ZSH_THEME}\"/" "$zshrc" || echo "ZSH_THEME=\"${ZSH_THEME}\"" >>"$zshrc"
    fi

    # Add plugins
    if ! grep -q "plugins=(" "$zshrc"; then
        echo "plugins=(git ${ZSH_PLUGINS[*]})" >>"$zshrc"
    else
        # Replace existing plugins line
        sed -i -e "s/^plugins=(.*)$/plugins=(git ${ZSH_PLUGINS[*]})/" "$zshrc"
    fi

    print_status "oh-my-zsh configured with theme '${ZSH_THEME}' and plugins: ${ZSH_PLUGINS[*]}"
}

setup_zsh_aliases() {
    print_status "Setting up zsh aliases..."
    cat <<EOF >~/.config/zsh/aliases.zsh
# Development aliases
alias ls='exa'
alias la='exa -la'
alias ll='exa -l'
alias lah='exa -lah'

alias grep='rg'
alias find='fd'

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
EOF

    if [[ -f ~/.zshrc ]]; then
        if [[ -f ~/.config/zsh/aliases.zsh ]]; then
            if ! grep -q "source ~/.config/zsh/aliases.zsh" ~/.zshrc; then
                print_status "source ~/.config/zsh/aliases.zsh" >>~/.zshrc
            fi
        fi
    else
        print_warning "No .zshrc file found. Aliases might not be properly configured."
    fi
}

# ----------------------- Script and Template creation ---------------------
function create_archlinux_java_sdkman_manager_script() {
    echo "==> Creating java-sdkman script (jsdk) in ~/.local/bin..."
    mkdir -p ~/.local/bin
    cat <<'EOS' >~/.local/bin/jsdk
#!/usr/bin/env bash
# Simple Java version manager for Arch Linux (system-wide and SDKMAN)

function usage() {
    echo "Usage: jsdk [list|set|sdk-list|sdk-install|sdk-use] [version]"
}

case "$1" in
    list)
        echo "System Java versions:"
        archlinux-java status
        ;;
    set)
        if [ -z "$2" ]; then usage; exit 1; fi
        sudo archlinux-java set "$2"
        archlinux-java status
        ;;
    sdk-list)
        if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
            sdk list java
        else
            echo "SDKMAN not found."
        fi
        ;;
    sdk-install)
        if [ -z "$2" ]; then usage; exit 1; fi
        if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
            sdk install java "$2"
        else
            echo "SDKMAN not found."
        fi
        ;;
    sdk-use)
        if [ -z "$2" ]; then usage; exit 1; fi
        if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
            sdk use java "$2"
        else
            echo "SDKMAN not found."
        fi
        ;;
    *)
        usage
        ;;
esac
EOS
    chmod +x ~/.local/bin/jsdk
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
    fi
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.zshrc
    fi
}

# ===========================================================================
# Main execution – order of categories
# ===========================================================================

$INSTALL_BASE && install_base
$INSTALL_LANGUAGES && install_languages
$INSTALL_IDES && install_ides
$INSTALL_LSP && install_lsp
$INSTALL_DATABASES && install_db
$INSTALL_SECURITY && install_security
$INSTALL_AI_ML && install_ai_ml
$INSTALL_UTILS && install_utils
$SETUP_PROJECTS && setup_project_structure
$CONFIGURE_GIT && configure_git
$ARCHON_AGENT_BUILDER && install_ai_archon
$INSTALL_ZSH && setup_zsh_omz
$INSTALL_ZOXIDE_FZF && setup_zoxide_fzf
$INSTALL_ZSH_ALIASES && setup_zsh_aliases
$INSTALL_PIP_GLOBAL && install_pip_global
$CREATE_ARCH_JAVA_SDKMAN_MANAGER_HELPER && create_archlinux_java_sdkman_manager_script

print_status "Developer environment setup completed successfully!"
