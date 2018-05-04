#!/usr/bin/env shell-helpers

development(){
  development/$BOOTY_DISTRO

  apm install package-sync

  mkdir -p "$HOME/go/bin"
  file/interpolate '^export PATH="$PATH:$HOME/go/bin"$' \
                   'export PATH="$PATH:$HOME/go/bin"' "$HOME/.bashrc"
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
