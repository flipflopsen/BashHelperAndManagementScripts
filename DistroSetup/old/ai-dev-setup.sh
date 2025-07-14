#!/bin/bash

# Old script, dev_setup is same in better

set -e

echo "Updating system..."
sudo pacman -Syu --noconfirm

echo "Installing system dependencies..."
sudo pacman -S --noconfirm python python-pip python-virtualenv python-uv git docker bzip2

echo "Enabling Docker..."
sudo systemctl enable --now docker

# Optionally install yay for AUR packages
if ! command -v yay &>/dev/null; then
  echo "Installing yay (AUR helper)..."
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
fi

echo "Installing Python development tools..."
pip install --upgrade pip uv virtualenv

echo "Creating Python virtual environment for AI projects..."
python -m venv ~/ai-dev-env
source ~/ai-dev-env/bin/activate

echo "Installing Hugging Face Hub and Transformers..."
pip install --upgrade huggingface_hub transformers

echo "Installing LangChain and integrations..."
pip install langchain langchain-openai langchain-community

echo "Installing Langflow..."
uv pip install langflow

echo "Installing Aider (AI pair programming CLI)..."
pip install aider-install
aider-install

echo "Installing Codename Goose (agentic dev tool)..."
yay -S --noconfirm codename-goose

echo "Installing Goose Desktop (optional, for UI)..."
yay -S --noconfirm goose-desktop

echo "Installing Archon (AI agent builder)..."
git clone https://github.com/coleam00/Archon.git ~/Archon
cd ~/Archon
# For Docker-based setup (recommended for isolation)
sudo docker compose up -d
cd ~

echo "Installing OpenHands (All Hands) agent platform..."
sudo docker pull docker.all-hands.dev/all-hands-ai/openhands:latest
sudo docker run -it --rm -v ~/.openhands:/.openhands -p 3000:3000 --name openhands-app docker.all-hands.dev/all-hands-ai/openhands:latest

echo "Setup complete!"
echo "Activate your Python environment with: source ~/ai-dev-env/bin/activate"
echo "Start Langflow with: uv run langflow run"
echo "Start Aider with: aider"
echo "Start Goose CLI with: goose"
echo "Access Archon and OpenHands via Docker as above."

