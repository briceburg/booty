#!/usr/bin/env shell-helpers

init/00-gnupg(){
  MASTER_KEY_ID="${MASTER_KEY_ID:-2E543DCEBC9A6B971510A9A0D0532DD2254E4188}"
  gnupg/$BOOTY_DISTRO

  p/log "import brice@iceburg.net public key ($MASTER_KEY_ID)"
  gpg --recv-keys "$MASTER_KEY_ID"

  p/log "import $MASTER_KEY_ID 'laptop' subkeys"
  gnupg/import "$BOOTY_TMPDIR/master.subkeys"

  p/log "import $MASTER_KEY_ID secret key"
  prompt/confirm "continue importing MASTER KEY? usually no." || return 0
  gnupg/import "$BOOTY_TMPDIR/master.key"
}

gnupg/archlinux(){
  pkgs=(
    gnupg
    libgcrypt
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
}

gnupg/import(){
  local files=()
  local file="$1"
  for i in 1 2 3; do
    input="$file.crypt.$i"
    while [ ! -f "$input" ]; do
      prompt/confirm "Please provide input file \e[1m$input\e[21m" || return 1
    done
    files+=( "$input" )
  done

  cat ${files[@]} | "$BOOTY_ROOT/bin/bcrypt" > "$file" &&  gpg --import "$file"
}
