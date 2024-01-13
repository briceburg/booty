#!/bin/sh
. /etc/X11/xinit/xinitrc

case $(hostname) in
  zb14x)
    # disable touchscreen
    xinput list --name-only | grep ELAN | while read  -r name; do
      xinput disable "$name"
    done

    # set to 60hz TODO: use systemd or tlp to switch when on battery/ac?
    xrandr --output eDP-1 --mode 2880x1800 --rate 60
    ;;
esac

# use lxappearance-gtk3 package to set theme to adiwata-dark (gnome-themes-extra package)
# export GTK_THEME=Adwaita:dark
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

picom --daemon --config ~/.config/picom.conf

# restore color temp
[ -e ~/.local/state/brightness-temp ] && \
  xsct "$(cat ~/.local/state/brightness-temp)" 1

pgreg polkit-gnome-authentication-agent || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
  
exec xmonad
