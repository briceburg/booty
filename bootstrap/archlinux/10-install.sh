grep -qF "Include = /etc/pacman.d/booty" /etc/pacman.conf || cat << EOF >> /etc/pacman.conf

Include = /etc/pacman.d/booty
EOF

: > /etc/pacman.d/booty

if $BOOTSTRAP_MULTILIB; then
  cat << EOF >> /etc/pacman.d/booty
[multilib]
Include = /etc/pacman.d/mirrorlist

EOF
fi

pacman -S --noconfirm --needed reflector
reflector_flags=(
  --country US
  --protocol https
  --latest 20
  --score 5
  --sort rate
  --save /etc/pacman.d/mirrorlist
)
echo "${reflector_flags[@]}" > /etc/xdg/reflector/reflector.conf

grep -qF Reflector /etc/pacman.d/mirrorlist || {
  log "building mirrorlist. please wait while they're rated."
  reflector "${reflector_flags[@]}" --verbose
}

if has warp-terminal "${BOOTSTRAP_PACMAN[@]}"; then
  cat << 'EOF' >> /etc/pacman.d/booty
[warpdotdev]
Server = https://releases.warp.dev/linux/pacman/$repo/$arch

EOF
  pacman-key -f linux-maintainers@warp.dev || {
    pacman-key -r "linux-maintainers@warp.dev"
    pacman-key --lsign-key "linux-maintainers@warp.dev"
  }
fi

((${#BOOTSTRAP_PACMAN[@]})) && pacman -S --noconfirm --needed "${BOOTSTRAP_PACMAN[@]}"

log "configuring user: $BOOTSTRAP_USER"

id -u "$BOOTSTRAP_USER" &>/dev/null || {
  useradd --create-home "$BOOTSTRAP_USER"
  passwd -l "$BOOTSTRAP_USER" >/dev/null
}

# Ensure BOOTY_HOME is under the target user's home, not root's
BOOTY_HOME="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)/.booty"
export BOOTY_HOME

usermod -aG docker,log,libvirt,rfkill,video,uucp,wheel "$BOOTSTRAP_USER"

grep -qF "/usr/bin/pacman" "/etc/sudoers.d/user-$BOOTSTRAP_USER" 2>/dev/null || cat << EOF >> "/etc/sudoers.d/user-$BOOTSTRAP_USER"
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/makepkg
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/mkdir
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/mv
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/rm
$BOOTSTRAP_USER ALL=(ALL:ALL) NOPASSWD: /usr/bin/rsync
EOF

as_user "$BOOTSTRAP_USER" mkdir -p "\$HOME/git/AUR" "\$HOME/bin" "\$HOME/tmp"
if ((${#BOOTSTRAP_AUR[@]})); then
  as_user "$BOOTSTRAP_USER" "$BOOTY_HOME/booty/dotfiles/$BOOTY_OS/rootfs/usr/local/bin/aur-install" "${BOOTSTRAP_AUR[@]}"
fi

as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME"
{
  printf "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-%q}\n" "$BOOTSTRAP_BOOTY_URL"
  [ -z "$BOOTSTRAP_SECRETS_URL" ] || printf "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-%q}\n" "$BOOTSTRAP_SECRETS_URL"
} | sudo -H -u "$BOOTSTRAP_USER" tee "$BOOTY_HOME/config" >/dev/null

as_user "$BOOTSTRAP_USER" "$BOOTY_ROOT/bin/booty" setup || die "failed to setup booty"

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ln -sf "/usr/share/zoneinfo/$BOOTSTRAP_TIMEZONE" /etc/localtime
ln -sf /usr/bin/vim /usr/bin/vi

for service in "${BOOTSTRAP_SERVICES[@]}"; do
  systemctl enable --now "$service"
done

if has steam "${BOOTSTRAP_FEATURES[@]}"; then
  [ -e "/etc/sysctl.d/80-gamecompatibility.conf" ] || {
    echo "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf
    sysctl --system
  }
fi
