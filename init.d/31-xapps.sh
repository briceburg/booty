#!/usr/bin/env shell-helpers

xapps(){
  xapps/$BOOTY_DISTRO
}

xapps/archlinux(){
  pkgs=(
    chromium
    firefox-developer-edition
    gnome-themes-standard
    gpick
    lxappearance
    pcmanfm
    redshift
    rxvt-unicode
    rxvt-unicode-terminfo
    xterm
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
