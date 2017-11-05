#!/usr/bin/env shell-helpers

atom(){
  xapps/$BOOTY_DISTRO

  apm install package-sync
}

atom/archlinux(){
  pkgs=(
    atom
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
