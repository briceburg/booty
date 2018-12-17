#!/usr/bin/env shell-helpers

environment(){
  export BOOTY_ENV="${BOOTY_ENV:-$(environment/select)}"

  p/log "registering environment"
  file/interpolate '^export BOOTY_ENV=.*$' \
    "export BOOTY_ENV=$BOOTY_ENV" "$HOME/.bashrc"

  environment/bootstap
}

environment/select(){
  p/log "which environment is this machine?"
  local env=
  local envs=(
    hartford
    toshiba
    pm1001
  )

  select env in "${envs[@]}"; do
    echo "$env"
    return 0
  done
}

environment/bootstap(){
  case "$BOOTY_ENV" in
    hartford)
      sudo systemctl enable dhcpcd.service
      sudo systemctl enable ntpdate.service
      ;;
  esac
}
