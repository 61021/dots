# dots — git for the $HOME dotfiles repo (detached git dir, no fallthrough)
# The repo lives at ~/.dots.git so plain `git` never discovers it from
# random directories under $HOME; only this explicit command touches it.
function dots --wraps git --description 'git for the home dotfiles repo'
    git --git-dir=$HOME/.dots.git --work-tree=$HOME $argv
end
