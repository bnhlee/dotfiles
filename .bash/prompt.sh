# Prompt: working directory, then the git branch with * for unstaged and +
# for staged changes, then the last command's exit code if it failed:
#   ~/src/project (main *+) [1]$
# Long branch names are cut short with an ellipsis. Over ssh, user@host
# comes first, so a remote shell can't be mistaken for a local one.

# __git_ps1 comes with git; bash-completion only loads it lazily
if ! declare -F __git_ps1 >/dev/null && [ -f /usr/lib/git-core/git-sh-prompt ]; then
    . /usr/lib/git-core/git-sh-prompt
fi
GIT_PS1_SHOWDIRTYSTATE=1

__prompt_branch_max=12

# Runs before each prompt, setting the variables PS1 shows. PS1 references them
# rather than including their text, so a branch name containing $(...) or
# backslashes is shown as it is, not run or interpreted.
__prompt_update() {
    local status=$?
    __prompt_status=
    [ "$status" -ne 0 ] && __prompt_status=$status

    __prompt_git=
    declare -F __git_ps1 >/dev/null || return
    local git
    git=$(__git_ps1 '%s')
    [ -n "$git" ] || return
    # The branch comes first, then the markers after a space, then
    # "|REBASE 1/3" and the like
    local branch=${git%%[ |]*}
    if [ "${#branch}" -gt "$__prompt_branch_max" ]; then
        git="${branch:0:__prompt_branch_max-1}…${git#"$branch"}"
    fi
    __prompt_git=$git
}

# First, so it sees the exit code before the other commands (history -a in
# .bashrc) replace it
case "$PROMPT_COMMAND" in
    *__prompt_update*) ;;
    *) PROMPT_COMMAND="__prompt_update${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

# Set by sshd, and passed on into tmux panes (tmux's update-environment)
__prompt_ssh=
[ -n "$SSH_CONNECTION" ] && __prompt_ssh=1

case "$TERM" in
    # screen and tmux: inside tmux, where older versions set TERM=screen
    xterm-color|*-256color|screen*|tmux*)
        PS1='${__prompt_ssh:+\[\e[01;32m\]\u@\h\[\e[00m\]:}\[\e[01;34m\]\w\[\e[00m\]'
        PS1+='${__prompt_git:+ \[\e[33m\](${__prompt_git})\[\e[00m\]}'
        PS1+='${__prompt_status:+ \[\e[31m\][${__prompt_status}]\[\e[00m\]}'
        PS1+='\$ ' ;;
    *)
        PS1='${__prompt_ssh:+\u@\h:}\w${__prompt_git:+ (${__prompt_git})}${__prompt_status:+ [${__prompt_status}]}\$ ' ;;
esac
