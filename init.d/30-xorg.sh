#!/usr/bin/env shell-helpers

xorg(){
  xorg/$BOOTY_DISTRO

  file/interpolate '^for f in ~/\.xinit\.d/.*$' \
    "for f in ~/.xinit.d/*; do source \"\$f\"; done" "$HOME/.xinitrc"
}

xorg/archlinux(){
  pkgs=(
    acpi
    dmenu
    gtk3
    xmonad
    xmonad-contrib
    xorg-apps
    xorg-server
    xorg-xinit
    mesa
    mesa-demos
  )

  case "$BOOTY_ENV" in
    hartford)
      pkgs+=( xf86-video-amdgpu libva-mesa-driver ) ;;
    toshiba)
      pkgs+=( xf86-video-intel ) ;;
    *)
      p/warn "unsupported environment: $BOOTY_ENV" ;;
  esac

  sudo pacman --noconfirm -S ${pkgs[@]}
}
