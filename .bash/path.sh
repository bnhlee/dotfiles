# Prepend a directory to PATH if it exists and isn't already there.
path_prepend() {
    [ -d "$1" ] || return
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

path_prepend "${GOPATH:-$HOME/go}/bin"
path_prepend "$HOME/.local/bin"

export PATH
unset -f path_prepend
