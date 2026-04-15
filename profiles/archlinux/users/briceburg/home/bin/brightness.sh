#!/usr/bin/env bash
# relies on xbacklight, as provided by https://gitlab.com/wavexx/acpilight

min=5
inc=10

case $1 in
  up)
    xbacklight -inc $inc
    ;;
  down)
    cur=$(xbacklight -get)
    if [ $((cur - inc)) -le $min ]; then
      xbacklight -set $min
    else
      xbacklight -dec $inc
    fi
    ;;
  *)
    xbacklight -get
    ;;
esac
