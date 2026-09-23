#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
. "$HOME/.cargo/env"

# Added by Teamwork Graph CLI installer
export PATH="/home/khaled/.local/bin:$PATH"
