#!/usr/bin/env bash
# relies on xbacklight, https://gitlab.com/wavexx/acpilight
# relies on xsct, https://github.com/faf0/sct

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

min_temp=3200
max_temp=6500
range=$((max_temp - min_temp)) 
cur=$(xbacklight -get)

# get with a mathmetician to do this properly.
if [ $cur -gt 80 ]; then
  color=$max_temp
elif [ $cur -gt 60 ]; then
  color=$((min_temp + (range * 75 / 100) ))
elif [ $cur -gt 40 ]; then
  color=$((min_temp + (range * 50 / 100) ))
elif [ $cur -gt 20 ]; then
  color=$((min_temp + (range * 25 / 100)  ))
else 
  color=$min_temp
fi

xsct $color 1
mkdir -p ~/.local/state
echo $color > ~/.local/state/brightness-temp

