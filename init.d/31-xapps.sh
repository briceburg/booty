#!/usr/bin/env shell-helpers

xapps(){
  xapps/$BOOTY_DISTRO
}

xapps/archlinux(){
  pkgs=(
    chromium
    firefox-developer-edition
    gnome-themes-standard
    flameshot
    gpick
    gtk2fontsel
    lxappearance
    pavucontrol-qt
    pcmanfm
    polkit-gnome
    pulseaudio
    redshift
    rxvt-unicode
    rxvt-unicode-terminfo
    ttf-hack
    xsel
    xterm
  )

  sudo pacman --noconfirm -S ${pkgs[@]}

  git -C "$BOOTY_GITDIR" clone https://aur.archlinux.org/hsetroot.git
  cd "$BOOTY_GITDIR/hsetroot"

  makepkg -si --noconfirm
}
