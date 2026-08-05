# fzf key bindings: Ctrl-R history, Ctrl-T files, Alt-C cd
if status is-interactive; and command -q fzf
    fzf --fish | source
end
