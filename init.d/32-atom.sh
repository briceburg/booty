#!/usr/bin/env shell-helpers

atom(){
  atom/$BOOTY_DISTRO

  apm install package-sync
}

atom/archlinux(){
  pkgs=(
    atom
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
