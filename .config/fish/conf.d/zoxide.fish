# zoxide — smarter cd; `j <dir>` keeps the old jump muscle memory
if status is-interactive; and command -q zoxide
    zoxide init fish --cmd j | source
end
