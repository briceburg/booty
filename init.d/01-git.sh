#!/usr/bin/env shell-helpers

fn=init/git

init/git()(
  git/$BOOTY_DISTRO

  p/log "git: set global authorship and signing key"
  git config --global user.name "Brice Burgess"
  git config --global user.email "nesta@iceburg.net"
  git config --global user.signingkey "$GPG_PUBKEY"

  p/log "git: support encrypted remotes via git-remote-gcrypt"
  [ -d "$BOOTY_GITDIR/git-remote-gcrypt" ] || \
    git -C "$BOOTY_GITDIR" clone git@github.com:spwhitton/git-remote-gcrypt.git

  cd "$BOOTY_GITDIR/git-remote-gcrypt"
  sudo DESTDIR= prefix="/usr" ./install.sh && {
    git config --global --add gcrypt.gpg-args "--use-agent"
    git config --global --add gcrypt.publish-participants true
    git config --global --add gcrypt.participants "$GPG_PUBKEY"
  }
)

git/archlinux(){
  pkgs=(
    git
    python-docutils
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
}
