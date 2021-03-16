#!/usr/bin/env shell-helpers

common(){
  common/$BOOTY_DISTRO
}

common/archlinux(){
  pkgs=(
    f2fs-tools
    fzf
    man-db
    ntp
    reflector
    the_silver_searcher
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
  sudo reflector -c US -n 16 > /etc/pacman.d/mirrorlist
}
