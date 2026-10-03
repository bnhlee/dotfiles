alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gf='git fetch'
alias gd='git diff'
alias gl='git log --oneline --decorate --graph --all'

alias gco='git checkout'

# Tab-complete gco like git checkout. Git's completion is lazy-loaded, so
# load it now to get __git_complete.
if ! declare -F __git_complete >/dev/null && [ -f /usr/share/bash-completion/completions/git ]; then
    . /usr/share/bash-completion/completions/git
fi
declare -F __git_complete >/dev/null && __git_complete gco _git_checkout
