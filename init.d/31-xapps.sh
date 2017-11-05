#!/usr/bin/env shell-helpers

xapps(){
  xapps/$BOOTY_DISTRO
}

xapps/archlinux(){
  pkgs=(
    chromium
    gnome-themes-standard
    gpick
    lxappearance
    pcmanfm
    redshift
    rxvt-unicode
    rxvt-unicode-terminfo
    thunderbird
    xterm
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
