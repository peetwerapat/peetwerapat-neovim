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

<!-- ### Clone to local config -->
<!-- ```bash -->
<!-- git clone https://github.com/peetwerapat/neovim ~/.config/nvim -->
<!-- ``` -->
<!---->
<!-- ### For linux setup ollama ENV -->
<!-- ```bash -->
<!-- mkdir -p ~/.config/environment.d -->
<!-- ``` -->
<!---->
<!-- ```bash -->
<!-- sudo nano ~/.config/environment.d/ollama.conf -->
<!---->
<!-- ```bash -->
<!-- OLLAMA_HOST=your-ollama-host -->
<!-- OLLAMA_MODEL_ASK=your-model-ask -->
<!-- OLLAMA_MODEL_CODE=your-model-code -->
<!-- ``` -->
<!---->
<!-- ### Open neovim -->
<!-- ```bash -->
<!-- nvim -->
<!-- ``` -->
<!---->
<!-- ### Install tree-sitter-cli -->
<!-- #### For macOs -->
<!-- ```bash -->
<!-- brew install tree-sitter-cli -->
<!-- ``` -->
<!-- #### For Arch linux -->
<!-- ```bash -->
<!-- sudo pacman -S tree-sitter-cli -->
<!-- ``` -->
<!---->
<!-- ### Install treesiter parser -->
<!-- ```bash -->
<!-- :TSInstall lua vim vimdoc query javascript typescript tsx html css json yaml go markdown markdown_inline -->
<!-- ``` -->
## Installation Steps:
```markdown
1. Clone Peet Werapat's Neovim Configuration Repo locally for a full configuration set up 
(Linux): 
   ```bash
   git clone https://github.com/peetwerapat/neovim ~/.config/nvim
   cd ~/.config/nvim
   
2. Setup Ollama environment variables needed to connect with OpenAI's language models on 
Linux:
   ```bash
   mkdir -p ~/.config/environment.d
   echo "OLLAMA_HOST=your-ollama-host" | sudo tee 
/home/$USERNAME/.config/environment.d/ollama.conf > /dev/null
   echo "OLLAMA_MODEL_ASK=llama:medium" >> ~/.config/environment.d/ollama.conf
   ```
   
3. Open Neovim with the shorthand command for quick access (both macOS and Linux):
   ```bash
   nvim
   ```
   
4. Install `tree-sitter` CLI to enable syntax highlighting across multiple languages: 
   - **macOS** users should run Homebrew's installation script or use the package manager 
directly with Neovim command line mode (neoterminal plugin): 
     ```bash
     brew tap tree-sitter/cli && \
       tsc install --tree-sitter all || git clone https://github.com/tree-sitter/tree-sitter; 
fi
     % cd nvim_installer/.nvim/pack/asdf/*lsp* && asdf plugin 'language-lua' + refresh 2> 
/dev/null
    ```  
   - **Linux** users can manually install using their package manager: `sudo apt-get install 
tree-sitter` (e.g., Arch Linux) or with pacman if you are on Manjaro, Fedora etc.: `pacmdt 
autoinstall && echo "tree-sitter" | sudo yay -S --noconfirm`, and for custom language support 
include Lua installation like: 
     ```bash
     curl -Lo lua.tgz https://github.com/yann-favreault/lua8js/archive/master.zip && \
       mkdir -p ~/.local/share/nvim/lua && mv nvm/lua*~ ~/.local/share/nvim/lua 
     % cd nvim_installer/.nvim/pack/asdf/*lsp* && asdf plugin 'language-lua' + refresh 2> 
/dev/null
     ```   
   - Note: For the treeSitter parser installation, enter Neovim and execute this command 
directly within it for a complete setup. Use `:TSInstall` to install specific lua vim plugins 
or your preferred languages as needed (for example, Lisp with `tsParseLisp`) after you have 
set up Tree-sitter CLI: 
     ```bash
     :TSInstall luajson nvim-cmp query javascript typescript tsx html css json yaml go 
markdown markdown_inline lua vimdoc fzf tree siterdmark2 rst docstrings pyright mypy eslint 
black autopep8 coc.nvim neosnips
     ``` 
   
5. To open Neovim with Peet's configuration, run: `nvim +TreeSitter+TSInstall` from the 
command line or directly within NERD Tree if you have that plugin installed to avoid 
accidental modifications of your local config files while exploring and customizing further! :🎉


> Note: Replace placeholder values with actual details specific to your setup. Always backup 
before making significant changes, especially when setting up environment variables or 
modifying configurations for a new system like Ollama (or any similar services). Happy coding 
in Peet's Neovim configuration wonderland! 🌈✨

