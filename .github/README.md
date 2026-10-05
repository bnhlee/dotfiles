# dotfiles

Bash, git, tmux and Neovim config, kept in a bare git repo at `~/.dotfiles`
with `$HOME` as the work tree. Manage it with the `dotfiles` alias, which works
like `git`:

```sh
dotfiles status
dotfiles add ~/.config/nvim/init.lua
dotfiles commit -m "..."
```

Untracked files are hidden from `dotfiles status`, so new files have to be
added explicitly.

## Install

### With internet

```sh
curl -fsSL https://raw.githubusercontent.com/bnhlee/dotfiles/main/.local/bin/dotfiles-bootstrap | bash
```

This clones the repo, checks it out into `$HOME` (existing files that differ
are moved to `~/.dotfiles-backup`), installs the Nerd Font, applies the GNOME
settings below, and installs the Neovim plugins and treesitter parsers, so nvim
is ready on first start.

### Without internet

On a machine with internet, build a package:

```sh
dotfiles-bootstrap pack            # -> ./dotfiles-offline-<arch>-<date>.tar.gz
```

Copy it over, then:

```sh
tar xzf dotfiles-offline-*.tar.gz
dotfiles-offline/dotfiles-bootstrap apply dotfiles-offline
```

The package contains the repo (committed changes only), the Neovim plugins and
compiled treesitter parsers, and the font. The compiled parts only run on the
same CPU architecture as the machine that built the package. Re-running `apply`
is safe.

After either install, create `~/.gitconfig.local` with your `[user]` name and
email.

## Requirements

- Neovim 0.12+, git, curl
- `gopls` and `dlv` for Go LSP and debugging:
  `go install golang.org/x/tools/gopls@latest github.com/go-delve/delve/cmd/dlv@latest`
- Optional: golangci-lint, for errcheck and other linters on open/save
  (`curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b ~/go/bin`)
- ripgrep and fd, for telescope search
- Online installs only: `build-essential` (C compiler, libc headers, `make`)
  and the `tree-sitter` CLI, to build the treesitter parsers and
  telescope-fzf-native on first start

## What it configures

| | |
|---|---|
| **Bash** | `~/.bash/*.sh` is sourced from `.bashrc`: git aliases (`gs`, `ga`, `gc`, `gp`, `gl`, …), the `dotfiles` alias, `~/.local/bin` and `~/go/bin` on `PATH` |
| **Git** | `main` as the default branch, nvim as the editor, rebase on pull, prune on fetch, rerere. Personal settings go in `~/.gitconfig.local` |
| **tmux** | Prefix `Ctrl-Space`, `v`/`s` to split, `Alt-hjkl` to move between panes and Neovim splits, `Alt-HJKL` to resize, `Alt-1…9` for windows, vi copy mode, mouse on |
| **Neovim** | Go IDE setup using the built-in LSP and `vim.pack`: gopls with format/organize imports on save; blink.cmp completion (LSP, paths, snippets, buffer words, `:` commands) and signature help; golangci-lint via nvim-lint; treesitter highlighting and folding; telescope; gitsigns and fugitive; nvim-dap debugging; a Go test runner (`<leader>r…`); oil file explorer. `<leader>fk` searches all keymaps |
| **Font** | JetBrainsMono Nerd Font in `~/.local/share/fonts`, set as the GNOME Terminal font unless a custom font is already chosen |
| **Keyboard** | Caps Lock acts as Ctrl (GNOME `xkb-options`), so `Caps+[` works as Escape. An existing Caps Lock option is left alone |
