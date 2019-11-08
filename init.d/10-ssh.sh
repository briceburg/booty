#!/usr/bin/env shell-helpers

fn=init/ssh

init/ssh()(
  [ -d "$HOME/.ssh" ] || { mkdir "$HOME/.ssh"; chmod 0700 "$HOME/.ssh" ;}
  cd "$HOME/.ssh"
  . "$HOME/.bashrc"
  gpg --export-ssh-key "$GPG_PUBKEY" > gpg-key
  ssh-add -L > id_rsa.gpg-key.pub 
)
