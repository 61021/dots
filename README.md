# dots

Arch + Hyprland dotfiles, managed as a detached git dir over `$HOME`.

## How it works

- The git dir lives at `~/.dots.git`, the work tree is `$HOME`. Plain `git`
  never discovers it — all interaction goes through the `dots` fish function
  ([.config/fish/conf.d/dots.fish](.config/fish/conf.d/dots.fish)).
- [.gitignore](.gitignore) ignores everything (`/*`) and explicitly
  allow-lists what gets tracked.
- A gitleaks pre-push hook ([.config/git-hooks/pre-push](.config/git-hooks/pre-push))
  scans every outgoing commit for secrets.
- No font files, no vendored blobs: everything installable comes from the
  package lists in [.config/packages](.config/packages) (`repo.txt` = explicit
  native, `aur.txt` = explicit AUR). Regenerate them with the `pkgsync` fish
  function.

## What's here

Hyprland, eww (bar / sidebar / calendar), kitty, fish, neovim, rofi, dunst,
btop, mpv, GTK/Qt theming, fontconfig (IBM Plex + JetBrainsMono Nerd Font,
Arabic → IBM Plex Sans Arabic), and assorted scripts under `stuff/scripts`.

## New machine

```fish
git clone --no-checkout https://github.com/61021/dots.git ~/.dots.tmp
mv ~/.dots.tmp/.git ~/.dots.git; rm -rf ~/.dots.tmp
git --git-dir=$HOME/.dots.git --work-tree=$HOME config core.worktree $HOME
git --git-dir=$HOME/.dots.git --work-tree=$HOME config core.hooksPath '~/.config/git-hooks'
git --git-dir=$HOME/.dots.git --work-tree=$HOME checkout main
paru -S --needed - < ~/.config/packages/repo.txt
paru -S --needed - < ~/.config/packages/aur.txt
```

`checkout` refuses to overwrite existing files — move them aside first.
