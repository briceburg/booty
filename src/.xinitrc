for f in /etc/X11/xinit/xinitrc.d/*; do source "$f"; done
for f in ~/.xinit.d/*; do source "$f"; done

# Start a window compositor. Ensures Chromium + Virtualbox paint correctly.
xcompmgr -n &

pulseaudio --start --log-target=syslog &
exec xmonad
