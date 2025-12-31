# 🧠 Peet Werapat's Neovim Configuration

> A fast, modern, and minimal Neovim setup — built for speed and clarity with a full-featured plugin ecosystem.

---

## ✨ Features

- ⚡ **Blazingly Fast** — Lazy-loaded plugins using [`lazy.nvim`](https://github.com/folke/lazy.nvim)
- 🧩 **Full LSP Support** — Built-in LSP with null-ls, autoformatting, and diagnostics
- 🧠 **Autocomplete & Snippets** — `nvim-cmp`, `LuaSnip`, and intelligent suggestions
- 🪄 **Fuzzy Finder** — Powered by [`fzf-lua`](https://github.com/ibhagwan/fzf-lua)
- 🎨 **Beautiful UI** — Tree-sitter syntax, custom colorscheme, statusline, and icons
- 📦 **Modern Terminal** — Integrated terminal using `ToggleTerm`
- 🛠️ **Developer Ready** — Git signs, code actions, diagnostics, formatting, and more

---

## Installation Steps:

### 1. Clone to local config
```bash
git clone https://github.com/peetwerapat/neovim ~/.config/nvim
```

### 2. Setup ollama ENV
```bash
mkdir -p ~/.config/environment.d

cat <<EOF > ~/.config/environment.d/ollama.conf
OLLAMA_HOST=your-ollama-host
OLLAMA_MODEL_ASK=your-ollama-model-ask
OLLAMA_MODEL_CODE=your-ollama-model-code
EOF
```

### 3.Install tree-sitter-cli
##### For macOs
```bash
brew install tree-sitter-cli
```
##### For Arch linux
```bash
sudo pacman -S tree-sitter-cli
```

### 4. Open neovim
```bash
nvim
```

### 5. Install treesiter parser
```bash
:TSInstall lua vim vimdoc query javascript typescript tsx html css json yaml go markdown markdown_inline
```

> Note: Replace placeholder values with actual details specific to your setup. Always backup 
before making significant changes, especially when setting up environment variables or 
modifying configurations for a new system like Ollama (or any similar services). Happy coding 
in Peet's Neovim configuration wonderland! 🌈✨

