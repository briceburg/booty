#!/usr/bin/env shell-helpers

util(){
  util/$BOOTY_DISTRO
  sudo timedatectl set-timezone America/New_York

}

util/archlinux(){
  pkgs=(
    gnu-netcat
    hunspell-en
    ntp
    rclone
    sshfs
    whois
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
  sudo systemctl enable docker
}
