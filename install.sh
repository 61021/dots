#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Dotfiles installer
#
# Clones this repo into $HOME using a bare-repo workflow so the
# whole home directory is tracked without nesting a .git folder.
#
#   curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash
#
# Or, if already cloned somewhere:
#   ./install.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/61021/dots.git}"
BRANCH="${DOTFILES_BRANCH:-main}"
DOTGIT="$HOME/.dotfiles.git"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

c_blue=$'\033[1;34m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'
c_red=$'\033[1;31m'; c_dim=$'\033[2m';        c_reset=$'\033[0m'

log()  { printf '%s==>%s %s\n' "$c_blue"   "$c_reset" "$*"; }
ok()   { printf '%s ok%s %s\n' "$c_green"  "$c_reset" "$*"; }
warn() { printf '%s !!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s xx%s %s\n' "$c_red"    "$c_reset" "$*" >&2; exit 1; }

dot() { git --git-dir="$DOTGIT" --work-tree="$HOME" "$@"; }

# ─── 0. Sanity ───────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] || die "Do not run as root."
command -v git >/dev/null || die "git is required."

# ─── 1. Clone bare repo ──────────────────────────────────────
if [[ -d "$DOTGIT" ]]; then
  log "Existing bare repo found at $DOTGIT — pulling latest"
  dot fetch --depth=1 origin "$BRANCH"
else
  log "Cloning $REPO_URL → $DOTGIT"
  git clone --bare --depth=1 --branch "$BRANCH" "$REPO_URL" "$DOTGIT"
fi

# Don't show untracked files (the home dir is full of them)
dot config --local status.showUntrackedFiles no

# ─── 2. Back up conflicts, then check out ────────────────────
log "Checking out files into \$HOME"
mkdir -p "$BACKUP_DIR"

set +e
checkout_out=$(dot checkout "$BRANCH" 2>&1)
checkout_rc=$?
set -e

if [[ $checkout_rc -ne 0 ]]; then
  warn "Conflicts with existing files — backing them up to:"
  echo "    $c_dim$BACKUP_DIR$c_reset"

  # Parse files git refused to overwrite, then move them aside.
  echo "$checkout_out" \
    | awk '/^\t/ {sub(/^\t/, ""); print}' \
    | while IFS= read -r f; do
        [[ -z "$f" || ! -e "$HOME/$f" ]] && continue
        mkdir -p "$BACKUP_DIR/$(dirname "$f")"
        mv "$HOME/$f" "$BACKUP_DIR/$f"
      done

  dot checkout "$BRANCH"
fi

dot reset --hard "origin/$BRANCH" >/dev/null

# Remove backup dir if nothing landed in it
rmdir "$BACKUP_DIR" 2>/dev/null || true
[[ -d "$BACKUP_DIR" ]] && warn "Backups stored at $BACKUP_DIR"

# ─── 3. Helpful shell alias ──────────────────────────────────
log "You can manage dotfiles with:"
echo "    $c_dim git --git-dir=\$HOME/.dotfiles.git --work-tree=\$HOME <cmd>$c_reset"
echo "    $c_dim # or add an alias:  alias dot='git --git-dir=\$HOME/.dotfiles.git --work-tree=\$HOME'$c_reset"

# ─── 4. Install packages (Arch / pacman + paru) ──────────────
if command -v pacman >/dev/null; then
  REPO_LIST="$HOME/.config/packages/repo.txt"
  AUR_LIST="$HOME/.config/packages/aur.txt"

  if [[ -f "$REPO_LIST" ]]; then
    log "Installing official-repo packages from $(basename "$REPO_LIST")"
    # Filter to only packages not already installed
    mapfile -t to_install < <(comm -23 \
      <(sort -u "$REPO_LIST") \
      <(pacman -Qq | sort -u))
    if (( ${#to_install[@]} )); then
      sudo pacman -S --needed --noconfirm "${to_install[@]}"
    else
      ok "All repo packages already installed."
    fi
  fi

  # Bootstrap paru if we need AUR packages and it's missing
  if [[ -f "$AUR_LIST" && -s "$AUR_LIST" ]] && ! command -v paru >/dev/null; then
    log "Bootstrapping paru (AUR helper)"
    sudo pacman -S --needed --noconfirm base-devel git
    tmp=$(mktemp -d)
    git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
  fi

  if [[ -f "$AUR_LIST" ]] && command -v paru >/dev/null; then
    log "Installing AUR packages from $(basename "$AUR_LIST")"
    mapfile -t to_install < <(comm -23 \
      <(sort -u "$AUR_LIST") \
      <(pacman -Qq | sort -u))
    if (( ${#to_install[@]} )); then
      paru -S --needed --noconfirm "${to_install[@]}"
    else
      ok "All AUR packages already installed."
    fi
  fi
else
  warn "pacman not found — skipping package install (not on Arch?)"
fi

# ─── 5. Refresh font cache (if fonts were checked out) ───────
if [[ -d "$HOME/.local/share/fonts" ]] && command -v fc-cache >/dev/null; then
  log "Rebuilding font cache"
  fc-cache -f >/dev/null
fi

ok "Dotfiles installed."
