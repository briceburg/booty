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
    gtk2fontsel
    lxappearance
    pcmanfm
    redshift
    rxvt-unicode
    rxvt-unicode-terminfo
    xsel
    xterm
  )

  sudo pacman --noconfirm -S ${pkgs[@]}
}
