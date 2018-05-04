#!/usr/bin/env shell-helpers

development(){
  development/$BOOTY_DISTRO

  apm install package-sync
}

development/archlinux(){
  pkgs=(
    atom
    docker
    go
    go-tools
    python
    shellcheck
    vim
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
