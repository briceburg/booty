#!/usr/bin/env bash

case "$1" in
  cal)
    DAY=$(date +'%e')
    dunstify -h string:x-dunst-stack-tag:cal -u low 'Calendar' "$(cal -3 -c1 | sed -e "s/$DAY\b/<u><b>$DAY<\/b><\/u>/g")"
    ;;
  info)
    batinfo="$(acpi | grep -v 'Unknown\|unavailable' | cut -d':' -f2-)"
    if [ -n "$batinfo" ]; then
      arr=(${batinfo//,/ })
      batinfo="\n<b>battery</b>\n${arr[0]} (<b>${arr[1]}</b>)\n${arr[*]:2}"
    fi

    wifiinfo=$(iw dev wlan0 link | awk '
    $1=="SSID:" {ssid = $2}
    $1=="signal:" {signal = $2$3}
    $1=="rx" {rx = $3}
    $1=="tx" {tx = $3$4}
    END {if (ssid){print ssid, signal, "\n", rx, "rx/tx", tx}}')
    if [ -n "$wifiinfo" ]; then
      wifiinfo="\n\n<b>wifi</b>\n$wifiinfo"
    else
      wifiinfo="\n\n<b>wifi</b>\nNot Connected.\n\`ip a\` for more."
    fi

    dunstify -h string:x-dunst-stack-tag:info -u low "$(date '+%a %b %d %I:%M %p %Z')" "\n$(cal -c1)$batinfo$wifiinfo"
    ;;
  *)
    notify-send -u critical "$(basename "$0")" "unknown argument"
    ;;
esac
