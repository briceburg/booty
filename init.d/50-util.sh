#!/usr/bin/env shell-helpers

util(){
  util/$BOOTY_DISTRO
  sudo timedatectl set-timezone America/New_York

}

util/archlinux(){
  pkgs=(
    docker
    hunspell-en
    ntp
    rclone
    vim
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
