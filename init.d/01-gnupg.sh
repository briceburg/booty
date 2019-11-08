#!/usr/bin/env shell-helpers

gnupg()(
  set -e
  gnupg/$BOOTY_DISTRO

  p/log "gnupg: import brice@iceburg.net public key ($GPG_PUBKEY)"
  gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys "$GPG_PUBKEY"

  # set trustlevel to ultimate
  gpg -k "$GPG_PUBKEY" | grep -A1 -B0 "$GPG_PUBKEY" | tail -n1 | grep -q 'ultimate' || \
    expect -c "spawn gpg --edit-key $GPG_PUBKEY trust quit; send \"5\ry\r\"; expect eof"

  p/log "gnupg: import $GPG_PUBKEY 'laptop' subkeys"
  gnupg/import "$BOOTY_TMPDIR/master.subkeys"

  p/log "gnupg: configure gpg-agent as ssh-agent"
  gnupg/gpg-agent

  p/log "gnupg: import $GPG_PUBKEY secret key"
  prompt/confirm "continue importing MASTER KEY? usually no." || return 0
  gnupg/import "$BOOTY_TMPDIR/master.key"
)

gnupg/archlinux(){
  pkgs=(
    expect
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
  file/interpolate '^enable-ssh-support.*$' \
                   'enable-ssh-support' "$HOME/.gnupg/gpg-agent.conf"

  file/interpolate '^max-cache-ttl.*$' \
                   'max-cache-ttl 10800' "$HOME/.gnupg/gpg-agent.conf"

  file/interpolate '^default-cache-ttl.*$' \
                   'default-cache-ttl 10800' "$HOME/.gnupg/gpg-agent.conf"

  file/interpolate '^export SSH_AGENT_PID=.*$' \
                   'export SSH_AGENT_PID=' "$HOME/.bashrc"

  file/interpolate '^export SSH_AUTH_SOCK=.*$' \
                   'export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh"' "$HOME/.bashrc"

  file/interpolate '^export GPG_TTY=.*$' \
                   'export GPG_TTY=$(tty)' "$HOME/.bashrc"

  file/interpolate '^gpg-connect-agent updatestartuptty.*$' \
                   'gpg-connect-agent updatestartuptty /bye >/dev/null' "$HOME/.bashrc"

  p/log "gnupg: add authentication key to gpg-agent"
  AUTHKEY_KEYGRIP="${AUTHKEY_KEYGRIP:-$(gpg --with-keygrip -k $GPG_PUBKEY | grep -A1 -B0 '\[A\]' | tail -n1 |  awk '{print $NF}')}"
  file/interpolate "^$AUTHKEY_KEYGRIP.*$" "$AUTHKEY_KEYGRIP" "$HOME/.gnupg/sshcontrol"

  p/log "gnupg: reload gpg-agent"
  gpg-connect-agent reloadagent /bye

  . "$HOME/.bashrc"
}
