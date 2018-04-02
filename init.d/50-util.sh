#!/usr/bin/env shell-helpers

util(){
  util/$BOOTY_DISTRO
  sudo timedatectl set-timezone America/New_York

}

util/archlinux(){
  pkgs=(
    docker
    gnu-netcat
    hunspell-en
    ntp
    rclone
    sshfs
    vim
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
