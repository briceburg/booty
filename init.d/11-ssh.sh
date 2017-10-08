#!/usr/bin/env shell-helpers

fn=init/ssh

init/ssh(){
  [ -d "$HOME/.ssh" ] || { mkdir "$HOME/.ssh"; chmod 0700 "$HOME/.ssh" ;}

  p/log "adding gpg public keys to $HOME/.ssh/"
  gpg --export-ssh-key "$GPG_PUBKEY" > "$HOME/.ssh/gpg-key.pub"
  ssh-add -L > "$HOME/.ssh/gpg-agent-keys.pub"
}
