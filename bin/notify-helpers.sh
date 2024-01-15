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
    dunstify -h string:x-dunst-stack-tag:info -u low "$(date '+%a %b %d %I:%M %p %Z')" "\n$(cal -3 -c1)$batinfo"
    ;;
  *)
    notify-send -u critical "$(basename "$0")" "unknown argument"
    ;;
esac
