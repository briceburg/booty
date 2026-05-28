user_home="$(lookup_home "$BOOTSTRAP_USER")" || die "cannot find home directory for $BOOTSTRAP_USER"

install_aur(){
  local aur="$1" aur_dir pkg aur_packages=()
  aur_dir="$user_home/git/AUR/$aur"
  if [ -d "$aur_dir/.git" ]; then
    as_user "$BOOTSTRAP_USER" git -C "$aur_dir" pull --ff-only
  else
    as_user "$BOOTSTRAP_USER" git -C "$user_home/git/AUR" clone "https://aur.archlinux.org/$aur.git" "$aur"
  fi
  as_user_in "$BOOTSTRAP_USER" "$aur_dir" makepkg --noconfirm --force
  while IFS= read -r pkg; do
    [[ "$pkg" = /* ]] || pkg="$aur_dir/$pkg"
    [ ! -f "$pkg" ] || aur_packages+=("$pkg")
  done < <(as_user_in "$BOOTSTRAP_USER" "$aur_dir" makepkg --packagelist)
  ((${#aur_packages[@]})) || die "AUR build produced no packages: $aur"
  pacman -U --noconfirm --needed "${aur_packages[@]}"
}

if ((${#BOOTSTRAP_AUR[@]})); then
  [ "$BOOTSTRAP_USER" != root ] || die "AUR packages require a non-root BOOTSTRAP_USER"
  for aur in "${BOOTSTRAP_AUR[@]}"; do install_aur "$aur"; done
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
