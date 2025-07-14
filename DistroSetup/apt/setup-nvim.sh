#!/usr/bin/env bash

set -e

# 1. Install dependencies
sudo apt update
sudo apt install -y git curl gcc g++ make ripgrep unzip

# 2. Install latest Neovim (if not present or too old)
if ! command -v nvim >/dev/null 2>&1 || [[ "$(nvim --version | head -n1 | grep -o '[0-9]\.[0-9]\+' | head -n1)" < "0.10" ]]; then
    echo "Installing latest Neovim AppImage..."
    NVIM_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep browser_download_url | grep appimage | cut -d '"' -f 4)
    curl -Lo ~/nvim.appimage "$NVIM_URL"
    chmod u+x ~/nvim.appimage
    sudo mv ~/nvim.appimage /usr/local/bin/nvim
fi

# 3. Backup existing config
if [ -d "$HOME/.config/nvim" ]; then
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)"
fi

# 4. Setup Neovim config directory
mkdir -p "$HOME/.config/nvim"

# 5. Install lazy.nvim plugin manager
git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
    "$HOME/.local/share/nvim/site/pack/lazy/start/lazy.nvim"

# 6. Write Neovim config (init.lua)
cat > "$HOME/.config/nvim/init.lua" << 'EOF'
require("lazy").setup({
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", lazy = false },
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "Saghen/blink.cmp" },
  { "stevearc/conform.nvim" },
  {
    "folke/snacks.nvim",
    opts = {
      picker = { enabled = true },
      explorer = { replace_netrw = true },
      indent = {},
      dashboard = {},
    },
    lazy = false,
    priority = 1000,
  },
  {
    "romgrk/barbar.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "lewis6991/gitsigns.nvim",
    },
    init = function() vim.g.barbar_auto_setup = false end,
    opts = {},
    version = "^1.0.0",
  },
  { "nvim-lualine/lualine.nvim" },
  { "echasnovski/mini.autopairs" },
  { "echasnovski/mini.hipatterns" },
  { "folke/which-key.nvim" },
  { "folke/tokyonight.nvim" },
})

-- Treesitter
require'nvim-treesitter.configs'.setup {
  highlight = { enable = true },
  indent = { enable = true },
}

-- Mason & LSP
require("mason").setup()
require("mason-lspconfig").setup()
require("lspconfig").pyright.setup{} -- Example: Python LSP

-- blink.cmp completion
require("blink.cmp").setup({})

-- Conform (formatter)
require("conform").setup({ format_on_save = true })

-- Snacks
require("snacks").setup({
  picker = { enabled = true },
  explorer = { replace_netrw = true },
  indent = {},
  dashboard = {},
})

-- Barbar
require("barbar").setup({})

-- Lualine
require("lualine").setup({})

-- Mini plugins
require("mini.autopairs").setup()
require("mini.hipatterns").setup()

-- WhichKey
require("which-key").setup({})

-- Theme
vim.cmd[[colorscheme tokyonight]]
EOF

echo "Neovim and plugins are set up! Start Neovim with: nvim"
echo "On first run, plugins will be installed automatically by lazy.nvim."
