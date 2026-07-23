# Environment (exported for all fish sessions, interactive or not)
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SSH_AUTH_SOCK /run/user/(id -u)/ssh-agent.socket

if status is-interactive
  set fish_greeting "Welcome to the Batcave, Master Wayne. How can I assist you today?"

  # general — wrappers that add flags stay aliases
  alias cp='cp -iv'
  alias mv='mv -iv'
  alias wget='wget -c'
  alias rm='rm -v'
  alias yeet='rm -rf'
  alias yeeet='sudo rm -rf'
  alias mkdir='mkdir -pv'
  alias ls='eza --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lsl='ls -l'
  alias lsla='ls -la'
  alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
  alias ls-storage="du -hsx -- * | sort -rh | head -10"
  alias compress='tar -czvf'
  alias extract='tar -xzvf'
  alias cat='bat'
  alias lspcifzf="lspci | fzf --preview-window='top:50%:nowrap' --preview=\"echo {} | grep -o '[0-9a-zA-Z][0-9a-zA-Z]:[0-9a-zA-Z][0-9a-zA-Z]\.[0-9a-zA-Z]' | xargs -I[] lspci -k -s [] | grep -z --color=always -e '[0-9a-zA-Z][0-9a-zA-Z]:[0-9a-zA-Z][0-9a-zA-Z]\.[0-9a-zA-Z]'\""
  alias ipsbs="pacman -Qi | awk '/^Name/ {name=$3} /^Installed Size/ {print $4 $5, name}' | sort -hr | less"

  # shorthands — abbr so they expand inline and stay honest in history
  abbr -a v nvim
  abbr -a vim nvim
  abbr -a nano nvim
  abbr -a emacs nvim
  abbr -a s sudo
  abbr -a se 'sudo -E'
  abbr -a vv 'sudo -E nvim'
  abbr -a die 'sudo shutdown -h now'
  abbr -a reyeet 'sudo reboot'
  abbr -a obey sudo
  abbr -a obey_as_me 'sudo -E'
  abbr -a say yes
  abbr -a where pwd
  abbr -a myip 'curl ipinfo.io/ip'
  abbr -a weather 'curl wttr.in'

  # paru
  abbr -a i 'paru -S'
  abbr -a aa paru
  abbr -a update paru
  abbr -a remove 'paru -R'
  abbr -a removeall 'paru -Rcsn'
  abbr -a search paru

  # yt-dlp
  abbr -a get-audio 'yt-dlp --extract-audio -f bestaudio'
  abbr -a get-video 'yt-dlp -f bestvideo+bestaudio'

  # pacman
  alias pac-unlock='sudo rm /var/lib/pacman/db.lck'
  alias pac-clean='sudo pacman -Rns (pacman -Qtdq)'

  # paths
  alias fishc="cd ~/.config/fish && nvim config.fish"
  alias hyprc="nvim ~/.config/hypr/hyprland.conf"
  alias codef='cd ~/stuff/code/'

  # funny
  alias yeetermeter='btop'
  alias rr='curl -s -L https://raw.githubusercontent.com/keroserene/rickrollrc/master/roll.sh | bash'
end
