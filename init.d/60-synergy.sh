#!/usr/bin/env shell-helpers

synergy(){
  synergy/$BOOTY_DISTRO

  # synergy conf is in dotfiles.  
}

synergy/archlinux(){
  pkgs=(
    synergy
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
}
