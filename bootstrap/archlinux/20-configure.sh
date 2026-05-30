if ((${#BOOTSTRAP_AUR[@]})); then
  aur_install="$BOOTY_HOME/booty/dotfiles/$BOOTY_OS/rootfs/usr/local/bin/aur-install"
  [ "$BOOTSTRAP_USER" != root ] || die "AUR packages require a non-root BOOTSTRAP_USER"
  [ -x "$aur_install" ] || die "missing AUR installer: $aur_install"
  as_user "$BOOTSTRAP_USER" "$aur_install" "${BOOTSTRAP_AUR[@]}"
fi

[ ! -e /run/systemd/resolve/stub-resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ln -sf "/usr/share/zoneinfo/$BOOTSTRAP_TIMEZONE" /etc/localtime
ln -sf /usr/bin/vim /usr/bin/vi

if ! systemctl list-units >/dev/null 2>&1; then
  log "skipping service enablement: systemd is not running"
elif ((${#BOOTSTRAP_SERVICES[@]})); then
  systemctl enable --now "${BOOTSTRAP_SERVICES[@]}"
fi

if has steam "${BOOTSTRAP_FEATURES[@]}"; then
  [ -e "/etc/sysctl.d/80-gamecompatibility.conf" ] || {
    echo "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf
    sysctl --system
  }
fi
