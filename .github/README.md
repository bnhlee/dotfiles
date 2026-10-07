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
are moved to `~/.dotfiles-backup`), installs the Nerd Font, delta, xcape and
the language servers, applies the GNOME settings below, and installs the Neovim
plugins and treesitter parsers, so nvim is ready on first start.

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
compiled treesitter parsers, the language servers, the font, and the delta
and xcape binaries. The compiled parts only run on the same CPU architecture as
the machine that built the package.

After either install, create `~/.gitconfig.local` with your `[user]` name and
email.

### Updating

Run the same command again: the curl one online, or `apply` with a newer
package. Either one:

- Fast-forwards the dotfiles. Local commits, or local edits to files the
  update changes, stop it with a warning instead; nothing is overwritten.
  Untracked files in the way of new dotfiles go to `~/.dotfiles-backup`.
- Restores tracked files missing from `$HOME`.
- Online: moves the Neovim plugins to the revisions in the lockfile, updates
  delta, xcape and the language servers (the npm ones within their pinned
  major versions), and continues with the updated bootstrap script if it
  changed.
- Offline: installs the package's plugins, language servers, delta and xcape
  over the current ones. Copies installed elsewhere, e.g. with apt, are left
  alone.

## Requirements

- Neovim 0.12+, git, curl
- Node 22+ and npm, for the bash and JS/TS language servers. Offline targets
  only need Node; the servers come in the package
- [pwsh](https://learn.microsoft.com/powershell/scripting/install/install-debian),
  for the PowerShell language server. Without it, PowerShell files get no LSP
- `gopls` and `dlv` for Go LSP and debugging:
  `go install golang.org/x/tools/gopls@latest github.com/go-delve/delve/cmd/dlv@latest`
- Optional: golangci-lint, for errcheck and other linters on open/save
  (`curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b ~/go/bin`)
- ripgrep and fd, for telescope search
- xclip (or wl-clipboard), for copying from tmux and nvim to the system clipboard
- Online installs only: `build-essential` (C compiler, libc headers, `make`)
  and the `tree-sitter` CLI, to build the treesitter parsers and
  telescope-fzf-native on first start

## What it configures

| | |
|---|---|
| **Bash** | `~/.bash/*.sh` is sourced from `.bashrc`: git aliases (`gs`, `ga`, `gc`, `gp`, `gl`, …), the `dotfiles` alias with git's tab completion, `~/.local/bin` and `~/go/bin` on `PATH`. History is written after every command, so new shells and tmux panes see it |
| **Git** | `main` as the default branch, nvim as the editor, rebase on pull (autostashing local changes), prune on fetch, rerere (staging replayed resolutions), histogram diffs with moved lines highlighted (zebra), zdiff3 conflict markers, [delta](https://github.com/dandavison/delta) as the pager (`n`/`N` jump between files; falls back to less), the diff shown in the commit message editor. Personal settings go in `~/.gitconfig.local` |
| **tmux** | Prefix `Ctrl-Space`, `v`/`s` to split, `Alt-hjkl` to move between panes and Neovim splits, `Alt-HJKL` to resize, `Alt-1…9` for windows, vi copy mode that also copies to the system clipboard, mouse on |
| **Language servers** | Installed to `~/.local/share/lsp` and linked into `~/.local/bin`: bash-language-server with shellcheck, lua-language-server, typescript-language-server (with TypeScript 6, or the project's own), and PowerShellEditorServices with PSScriptAnalyzer (run by the system's pwsh). Re-running the bootstrap updates them |
| **Neovim** | Go IDE setup using the built-in LSP and `vim.pack`: gopls with format/organize imports on save; LSP for bash, Lua (aware of the `vim` API and plugins when editing this config), JS/TS and PowerShell, each enabled only if installed and formatted with `gq`; blink.cmp completion (LSP, paths, snippets, buffer words, `:` commands) and signature help; golangci-lint via nvim-lint; treesitter highlighting and folding; telescope; gitsigns and fugitive; nvim-dap debugging; a Go test runner (`<leader>r…`); oil file explorer. `<leader>fk` searches all keymaps. Splits open right/below, and `:s` previews its changes live |
| **Font** | JetBrainsMono Nerd Font in `~/.local/share/fonts`, set as the GNOME Terminal font unless a custom font is already chosen |
| **Keyboard** | Caps Lock acts as Ctrl (GNOME `xkb-options`), so `Caps+[` works as Escape. An existing Caps Lock option is left alone. In X11 sessions, [xcape](https://github.com/alols/xcape) also makes a tap of Caps Lock send Escape (autostarted from `~/.config/autostart/xcape.desktop`). It's installed from the Debian package without root, so it needs apt; under Wayland it doesn't run |
