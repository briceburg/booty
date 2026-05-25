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

log "configuring user: $BOOTSTRAP_USER"

id -u "$BOOTSTRAP_USER" &>/dev/null || {
  useradd --create-home --shell /bin/bash "$BOOTSTRAP_USER"
  passwd -l "$BOOTSTRAP_USER" >/dev/null
}

user_home="$(passwd_home "$BOOTSTRAP_USER")"
BOOTY_HOME="$user_home/.booty"
export BOOTY_HOME

[ "$BOOTSTRAP_USER" = root ] || add_user_groups "$BOOTSTRAP_USER" docker log libvirt rfkill video uucp wheel

as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME" "$BOOTY_HOME/tmp" "$user_home/bin" "$user_home/git/AUR" "$user_home/tmp" "$user_home/.local/share/booty"
{
  printf "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-%q}\n" "$BOOTY_REPO_URL"
  [ -z "$BOOTY_SECRETS_URL" ] || printf "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-%q}\n" "$BOOTY_SECRETS_URL"
} | as_user "$BOOTSTRAP_USER" tee "$BOOTY_HOME/config" >/dev/null
log "wrote booty runtime config: $BOOTY_HOME/config"

if [ ! -d "$BOOTY_HOME/booty/.git" ]; then
  log "cloning target checkout: $BOOTY_REPO_URL -> $BOOTY_HOME/booty"
  as_user "$BOOTSTRAP_USER" git clone "$BOOTY_REPO_URL" "$BOOTY_HOME/booty"
fi

export BOOTSTRAP_TARGET_READY=1
