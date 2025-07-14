#!/usr/bin/env bash
# Old script, dev_setup is same in better

set -o errexit -o nounset -o pipefail

# Import distro abstraction helpers
source "$(dirname "$0")/distro_utils.sh"

# ---------- User-configurable variables ----------
GIT_USER_NAME="${GIT_USER_NAME:-flopsendopsen}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-copyit0@gmail.com}"
DOCKER_GROUP_USER="${DOCKER_GROUP_USER:-$USER}"
# -------------------------------------------------

# =========================
#  Arch Linux Dev Setup
# =========================
# Installs Java (multiple versions), Python (pyenv), Go, virtualization, containers, editors, and more.
# Also sets up Java version management using archlinux-java and SDKMAN.

# ===========
#  Functions
# ===========

install_base_tools() {
    echo "==> Updating system and installing base tools..."
    pkg_update
    local common=(git curl wget unzip zip tar openssh htop neofetch tree lsof strace vim neovim tmux)
    case "$DETECTED_PM" in
        apt)   extra=(build-essential);;
        dnf|yum) extra=(@"Development Tools" gcc gcc-c++ make);;
        yay|pacman) extra=(base-devel);;
    esac
    pkg_install "${common[@]}" "${extra[@]}"
}

install_aur_helper() {
    [[ "$DETECTED_PM" == yay || "$DETECTED_PM" == pacman ]] || return 0
    if ! command -v yay &>/dev/null; then
        echo "==> Installing yay (AUR helper)..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
    fi
}

install_java_versions() {
    echo "==> Installing OpenJDK (8, 17, 21) and SDKMAN..."
    case "$DETECTED_PM" in
        apt)
            pkg_install openjdk-8-jdk openjdk-17-jdk openjdk-21-jdk
            ;;
        dnf|yum)
            pkg_install java-1.8.0-openjdk-devel java-17-openjdk java-21-openjdk
            ;;
        yay|pacman)
            pkg_install jdk8-openjdk jdk17-openjdk jdk21-openjdk
            ;;
    esac
    # Install SDKMAN (works same across distros)
    curl -s "https://get.sdkman.io" | bash
    # shellcheck disable=SC1090
    source "$HOME/.sdkman/bin/sdkman-init.sh" || true
}
    echo "==> Installing OpenJDK versions (8, 17, 21, 24, 25)..."
    sudo pacman -S --needed --noconfirm \
        jdk8-openjdk jdk17-openjdk jdk21-openjdk

    # For JDK 24 and 25, use AUR (if available)
    yay -S --needed --noconfirm jdk24-openjdk-bin jdk25-openjdk-bin || true

    echo "==> Installing SDKMAN for user-specific Java management..."
    curl -s "https://get.sdkman.io" | bash
    # shellcheck disable=SC1090
    source "$HOME/.sdkman/bin/sdkman-init.sh" || true
    sdk install java 8.0.392-zulu || true
    sdk install java 17.0.8-zulu || true
    sdk install java 21.0.3-zulu || true
    sdk install java 24.0.0-zulu || true
    sdk install java 25.0.0-zulu || true
}

install_python_pyenv() {
    echo "==> Installing pyenv and latest Python versions..."
    # Dependencies for building Python
    case "$DETECTED_PM" in
        apt)    pkg_install make build-essential libssl-dev zlib1g-dev libbz2-dev \
                        libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev \
                        libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev ;;
        dnf|yum) pkg_install @"Development Tools" zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
                        openssl-devel tk-devel libffi-devel xz-devel ;;
        yay|pacman) pkg_install zlib bzip2 openssl libffi readline sqlite xz tk ;;
    esac

    if ! command -v pyenv &>/dev/null; then
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Install Python versions
    for ver in 3.13.0 3.12.3 3.10.14; do
        pyenv install -s "$ver"
    done
    pyenv global 3.13.0
}
    echo "==> Installing pyenv and Python versions..."
    sudo pacman -S --needed --noconfirm \
        zlib bzip2 openssl libffi readline sqlite xz tk

    if ! command -v pyenv &>/dev/null; then
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Install Python versions
    pyenv install -s 3.13.0
    pyenv install -s 3.12.3
    pyenv install -s 3.10.14
    pyenv install -s 2.7.18
    pyenv global 3.13.0
}

install_go() {
    echo "==> Installing Go..."
    case "$DETECTED_PM" in
        apt) pkg_install golang ;;
        dnf|yum) pkg_install golang ;;
        yay|pacman) pkg_install go ;;
    esac
    mkdir -p "$HOME/go/bin"
    { echo 'export GOPATH=$HOME/go'; echo 'export PATH=$PATH:$GOPATH/bin'; } >> ~/.bashrc
}
    echo "==> Installing Go and setting up workspace..."
    sudo pacman -S --needed --noconfirm go
    mkdir -p "$HOME/go/bin"
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
}

install_editors_ides() {
    echo "==> Installing editors and IDEs..."
    case "$DETECTED_PM" in
        apt)
            pkg_install code ;; # VSCode via repo assumed added elsewhere
        dnf|yum)
            pkg_install code ;; # rpm fusion or ms repo
        yay|pacman)
            pkg_install code yay && yay -S --needed --noconfirm intellij-idea-community-edition ;;
    esac
}
    echo "==> Installing editors and IDEs..."
    sudo pacman -S --needed --noconfirm code
    yay -S --needed --noconfirm intellij-idea-community-edition
    sudo pacman -S --needed --noconfirm eclipse-java || true
}

install_build_tools() {
    echo "==> Installing build tools and debuggers..."
    pkg_install cmake make gcc gdb valgrind
}
    echo "==> Installing build tools and debuggers..."
    sudo pacman -S --needed --noconfirm \
        cmake make gcc gdb valgrind
}

configure_git_config() {
    echo "==> Configuring git global settings..."
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global core.editor "vim"
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.cm commit
}
    echo "==> Installing and configuring git..."
    git config --global user.name "flopsendopsen"
    git config --global user.email "copyit0@gmail.com"
    git config --global core.editor "vim"
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.cm commit
}

install_virtualization() {
    echo "==> Installing virtualization stack (KVM/QEMU/libvirt) ..."
    case "$DETECTED_PM" in
        apt)   pkg_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf ;;
        dnf|yum) pkg_install @"Virtualization" virt-manager ;;
        yay|pacman) pkg_install qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt edk2-ovmf ;;
    esac
    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt "$USER"
}
    echo "==> Installing virtualization tools (KVM, QEMU, libvirt, virt-manager)..."
    sudo pacman -S --needed --noconfirm \
        qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt edk2-ovmf
    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt "$USER"
    echo "==> Virtualization setup complete. You may need to reboot for group changes."
}

install_containers() {
    echo "==> Installing container tooling (Docker & Podman)..."
    case "$DETECTED_PM" in
        apt)   pkg_install docker.io docker-compose podman ;;
        dnf|yum) pkg_install docker docker-compose podman ;;
        yay|pacman) pkg_install docker docker-compose podman ;;
    esac
    sudo systemctl enable --now docker || true
    sudo usermod -aG docker "$DOCKER_GROUP_USER"
}
    echo "==> Installing Docker and Podman..."
    sudo pacman -S --needed --noconfirm docker docker-compose podman
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    echo "==> Docker/Podman setup complete. You may need to reboot for group changes."
}

install_shell_enhancements() {
    echo "==> Installing zsh and Oh My Zsh..."
    pkg_install zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    chsh -s "$(command -v zsh)" || true

    # Add useful plugins and theme
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc
    sed -i 's/^plugins=(git)/plugins=(git python pip docker)/' ~/.zshrc
}

function create_java_sdkman_manager_script() {
    echo "==> Creating java-sdkman script in ~/.local/bin..."
    mkdir -p ~/.local/bin
    cat <<'EOS' > ~/.local/bin/java-sdkman
#!/usr/bin/env bash
# Simple Java version manager for Arch Linux (system-wide and SDKMAN)

function usage() {
    echo "Usage: java-sdkman [list|set|sdk-list|sdk-install|sdk-use] [version]"
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
    chmod +x ~/.local/bin/java-sdkman
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    fi
}

# ================
#  Main Execution
# ================

install_base_tools
# Arch only
install_aur_helper
create_java_sdkman_manager_script

install_java_versions
install_python_pyenv
install_go
install_editors_ides
install_build_tools

configure_git_config

install_virtualization
install_containers
install_shell_enhancements



echo
echo "=============================================="
echo "  Arch Linux Development Environment Ready!   "
echo "  Please restart your terminal session.       "
echo "  Use 'java-manager' to manage Java versions. "
echo "=============================================="
