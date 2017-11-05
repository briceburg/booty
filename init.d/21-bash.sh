#!/usr/bin/env shell-helpers

bash(){
  bash/$BOOTY_DISTRO

  file/interpolate '^for f in ~/\.bash\.d/.*$' \
    "for f in ~/.bash.d/*; do source \"\$f\"; done" "$HOME/.bashrc"
}

bash/archlinux(){
  pkgs=(
    bash-completion
    fzf
    the_silver_searcher
  )
  sudo pacman --noconfirm -S ${pkgs[@]}
}
