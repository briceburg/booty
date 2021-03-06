#!/usr/bin/env shell-helpers

xorg(){
  "xorg/$BOOTY_DISTRO"
  cp "$BOOTY_ROOT/src/.xinitrc" "$HOME/.xinitrc"
}

xorg/archlinux(){
  pkgs=(
    acpi
    dmenu
    gtk3
    gvfs
    mesa
    mesa-demos
    noto-fonts
    qt5-base
    vkd3d
    vulkan-icd-loader
    vulkan-tools
    xcompmgr
    xmonad
    xmonad-contrib
    xorg-apps
    xorg-server
    xorg-xinit
  )

  case "$BOOTY_ENV" in
    hartford)
      pkgs+=( xf86-video-amdgpu libva-mesa-driver vulkan-radeon ) ;;
    toshiba)
      pkgs+=( xf86-video-intel ) ;;
    carbon|htpc)
      pkgs+=(  xf86-video-intel vulkan-intel ) ;;
    *)
      p/warn "unsupported environment: $BOOTY_ENV" ;;
  esac

  sudo pacman --noconfirm -S ${pkgs[@]}
}
