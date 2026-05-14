# CI stub for bootstrap/archlinux/10-install.sh.
#
# Skips reflector, systemd, and usermod operations that do not work in a
# headless container. Everything else runs for real.

grep -qF "Include = /etc/pacman.d/booty" /etc/pacman.conf || cat << EOF >> /etc/pacman.conf

Include = /etc/pacman.d/booty
EOF

: > /etc/pacman.d/booty

((${#BOOTSTRAP_PACMAN[@]})) && pacman -S --noconfirm --needed "${BOOTSTRAP_PACMAN[@]}"

log "configuring user: $BOOTSTRAP_USER"

id -u "$BOOTSTRAP_USER" &>/dev/null || {
  useradd --create-home "$BOOTSTRAP_USER"
  passwd -l "$BOOTSTRAP_USER" >/dev/null
}

# Ensure BOOTY_HOME is under the target user's home, not root's.
user_home="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)"
[ -n "$user_home" ] || die "cannot find home directory for $BOOTSTRAP_USER"
BOOTY_HOME="$user_home/.booty"
export BOOTY_HOME

sudoers="/etc/sudoers.d/user-$BOOTSTRAP_USER"
grep -qF "/usr/bin/rsync" "$sudoers" 2>/dev/null || {
  mkdir -p /etc/sudoers.d
  for cmd in makepkg pacman mkdir mv rm rsync; do
    printf '%s ALL=(ALL:ALL) NOPASSWD: /usr/bin/%s\n' "$BOOTSTRAP_USER" "$cmd"
  done >> "$sudoers"
}

as_user "$BOOTSTRAP_USER" mkdir -p "$user_home/git/AUR" "$user_home/bin" "$user_home/tmp"
if ((${#BOOTSTRAP_AUR[@]})); then
  as_user "$BOOTSTRAP_USER" "$BOOTY_ROOT/dotfiles/archlinux/rootfs/usr/local/bin/aur-install" "${BOOTSTRAP_AUR[@]}"
fi

as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME"
{
  printf "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-%q}\n" "$BOOTSTRAP_BOOTY_URL"
  [ -z "$BOOTSTRAP_SECRETS_URL" ] || printf "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-%q}\n" "$BOOTSTRAP_SECRETS_URL"
} | sudo -H -u "$BOOTSTRAP_USER" tee "$BOOTY_HOME/config" >/dev/null

as_user "$BOOTSTRAP_USER" "$BOOTY_ROOT/bin/booty" setup || die "failed to setup booty"
