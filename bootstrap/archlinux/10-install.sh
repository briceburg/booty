grep -qF "Include = /etc/pacman.d/booty" /etc/pacman.conf ||
  printf '\nInclude = /etc/pacman.d/booty\n' >> /etc/pacman.conf

: > /etc/pacman.d/booty

if $BOOTSTRAP_MULTILIB; then
  printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist\n\n' >> /etc/pacman.d/booty
fi

pacman -Syu --noconfirm
if [ "${BOOTSTRAP_SKIP_REFLECTOR:-0}" = 1 ]; then
  log "skipping mirror rating"
else
  command -v reflector >/dev/null || pacman -S --noconfirm --needed reflector
  reflector_flags=(
    --country US
    --protocol https
    --latest 20
    --score 5
    --sort rate
    --save /etc/pacman.d/mirrorlist
  )
  mkdir -p /etc/xdg/reflector
  echo "${reflector_flags[@]}" > /etc/xdg/reflector/reflector.conf

  grep -qF Reflector /etc/pacman.d/mirrorlist || {
    log "building mirrorlist. please wait while mirrors are rated."
    reflector "${reflector_flags[@]}" --verbose
  }
fi

if has warp-terminal "${BOOTSTRAP_PACMAN[@]}"; then
  printf '%s\n' '[warpdotdev]' "Server = https://releases.warp.dev/linux/pacman/\$repo/\$arch" '' >> /etc/pacman.d/booty
  pacman-key -f linux-maintainers@warp.dev || {
    pacman-key -r "linux-maintainers@warp.dev"
    pacman-key --lsign-key "linux-maintainers@warp.dev"
  }
fi

((${#BOOTSTRAP_PACMAN[@]})) && pacman -S --noconfirm --needed "${BOOTSTRAP_PACMAN[@]}"

log "configuring existing user: $BOOTSTRAP_USER"

id -u "$BOOTSTRAP_USER" &>/dev/null || die "missing user: $BOOTSTRAP_USER"

user_home="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)"
[ -n "$user_home" ] || die "cannot find home directory for $BOOTSTRAP_USER"
BOOTY_HOME="$user_home/.booty"
export BOOTY_HOME

add_user_groups "$BOOTSTRAP_USER" docker log libvirt rfkill video uucp wheel

as_user "$BOOTSTRAP_USER" mkdir -p "$user_home/git/AUR" "$user_home/bin" "$user_home/tmp"
if ((${#BOOTSTRAP_AUR[@]})); then
  as_user "$BOOTSTRAP_USER" sudo -v
  as_user "$BOOTSTRAP_USER" "$BOOTY_ROOT/dotfiles/$BOOTY_OS/rootfs/usr/local/bin/aur-install" "${BOOTSTRAP_AUR[@]}"
fi

as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME"
{
  printf "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-%q}\n" "$BOOTY_REPO_URL"
  [ -z "$BOOTY_SECRETS_URL" ] || printf "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-%q}\n" "$BOOTY_SECRETS_URL"
} | sudo -H -u "$BOOTSTRAP_USER" tee "$BOOTY_HOME/config" >/dev/null
log "wrote booty runtime config: $BOOTY_HOME/config"

[ ! -e /run/systemd/resolve/stub-resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ln -sf "/usr/share/zoneinfo/$BOOTSTRAP_TIMEZONE" /etc/localtime
ln -sf /usr/bin/vim /usr/bin/vi

if systemctl list-units >/dev/null 2>&1; then
  if ((${#BOOTSTRAP_SERVICES[@]})); then systemctl enable --now "${BOOTSTRAP_SERVICES[@]}"; fi
else
  log "skipping service enablement: systemd is not running"
fi

if has steam "${BOOTSTRAP_FEATURES[@]}"; then
  [ -e "/etc/sysctl.d/80-gamecompatibility.conf" ] || {
    echo "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf
    sysctl --system
  }
fi
