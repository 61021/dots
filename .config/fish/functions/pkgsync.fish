function pkgsync --description 'sync .config/packages lists with installed packages, show drift'
    pacman -Qqen >$HOME/.config/packages/repo.txt
    pacman -Qqem >$HOME/.config/packages/aur.txt
    dots --no-pager diff --stat -- .config/packages
    dots --no-pager diff -- .config/packages
end
