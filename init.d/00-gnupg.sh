#!/usr/bin/env shell-helpers

init/00-gnupg(){
  gnupg/$BOOTY_DISTRO

  # import brice@iceburg.net public key
  local master_key_id="2E543DCEBC9A6B971510A9A0D0532DD2254E4188"
  gpg --recv-keys "$master_key_id"

  files=()
  for i in 1 2 3; do
    file="$BOOTY_TMPDIR/master.key.crypt.$i"
    while [ ! -f "$file" ]; do
      prompt/confirm "Please provide \e[1m$file\e[21m" || return 1
    done
    files+=( "$file" )
  done

  cat ${files[@]} | "$BOOTY_ROOT/bin/bcrypt" > "$BOOTY_TMPDIR/master.key" && \
    gpg --import "$BOOTY_TMPDIR/master.key"
}

gnupg/archlinux(){
  pkgs=(
    gnupg
    libgcrypt
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
}
