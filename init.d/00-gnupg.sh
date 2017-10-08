#!/usr/bin/env shell-helpers

gnupg(){
  gnupg/$BOOTY_DISTRO

  p/log "import brice@iceburg.net public key ($GPG_PUBKEY)"
  gpg --recv-keys "$GPG_PUBKEY"

  p/log "import $GPG_PUBKEY 'laptop' subkeys"
  gnupg/import "$BOOTY_TMPDIR/master.subkeys"

  gnupg/gpg-agent

  p/log "import $GPG_PUBKEY secret key"
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


gnupg/gpg-agent(){
  p/log "configure gpg-agent as ssh-agent"
  file/interpolate '^enable-ssh-support.*$' \
                   'enable-ssh-support' "$HOME/.gnupg/gpg-agent.conf"
  file/interpolate '^max-cache-ttl.*$' \
                   'max-cache-ttl 10800' "$HOME/.gnupg/gpg-agent.conf"
  file/interpolate '^default-cache-ttl.*$' \
                   'default-cache-ttl 10800' "$HOME/.gnupg/gpg-agent.conf"

  file/interpolate '^SSH_AGENT_PID.*$' \
                   'SSH_AGENT_PID	DEFAULT=' "$HOME/.pam_environment"
  file/interpolate '^default-cache-ttl.*$' \
                   'SSH_AUTH_SOCK	DEFAULT="${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh' "$HOME/.pam_environment"

  file/interpolate '^export GPG_TTY=.*$' \
                   'export GPG_TTY=$(tty)' "$HOME/.bashrc"
  file/interpolate '^gpg-connect-agent updatestartuptty.*$' \
                   'gpg-connect-agent updatestartuptty /bye >/dev/null' "$HOME/.bashrc"

  p/log "add authentication key to gpg-agent"
  AUTHKEY_KEYGRIP="${AUTHKEY_KEYGRIP:-$(gpg --with-keygrip -k $GPG_PUBKEY | grep -A1 -B0 '\[A\]' | tail -n1 |  awk '{print $NF}')}"
  file/interpolate "^$AUTHKEY_KEYGRIP.*$" "$AUTHKEY_KEYGRIP" "$HOME/.gnupg/sshcontrol"

  p/log "reload gpg-agent"
  gpg-connect-agent reloadagent /bye

  p/log "export ~/.ssh/gpg-agent-keys.pub (for use as authorized keys)"
}
