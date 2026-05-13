# CI stub for bootstrap/archlinux/10-install.sh
#
# Skips things that do not work in a headless container:
#   - reflector mirror rating
#   - usermod with groups that do not exist in a minimal image
#   - systemd symlinks / systemctl
#
# Everything else runs for real: pacman installs, user creation,
# sudoers, booty setup, dotfile application.

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
BOOTY_HOME="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)/.booty"
export BOOTY_HOME

grep -qF "/usr/bin/rsync" "/etc/sudoers.d/user-$BOOTSTRAP_USER" 2>/dev/null || cat << EOF >> "/etc/sudoers.d/user-$BOOTSTRAP_USER"
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/mkdir
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/mv
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/rm
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/rsync
EOF

as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME"
{
  printf "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-%q}\n" "$BOOTSTRAP_BOOTY_URL"
  [ -z "$BOOTSTRAP_SECRETS_URL" ] || printf "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-%q}\n" "$BOOTSTRAP_SECRETS_URL"
} | sudo -H -u "$BOOTSTRAP_USER" tee "$BOOTY_HOME/config" >/dev/null

as_user "$BOOTSTRAP_USER" "$BOOTY_ROOT/bin/booty" setup || die "failed to setup booty"
