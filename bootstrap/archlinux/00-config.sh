# shellcheck disable=SC2034 # sourced bootstrap state consumed by later fragments and config output
command -v yq >/dev/null || pacman -Syu --noconfirm --needed go-yq
bootstrap_common_config

BOOTSTRAP_MULTILIB=false
BOOTSTRAP_FEATURES=()
BOOTSTRAP_PACMAN=()
BOOTSTRAP_AUR=()
BOOTSTRAP_SERVICES=()

host_config="$BOOTSTRAP_ROOT/config/hosts/$BOOTY_HOST.yaml"
user_config="$BOOTSTRAP_ROOT/config/users/$BOOTSTRAP_USER.yaml"
bootstrap_need_yq
[ -f "$host_config" ] || die "missing host definition: $host_config"
[ -f "$user_config" ] || die "missing user definition: $user_config"
[ -f "$BOOTSTRAP_ROOT/config/base.yaml" ] || die "missing base config: $BOOTSTRAP_ROOT/config/base.yaml"

yaml_merge "$BOOTSTRAP_ROOT/config/base.yaml" "$host_config" "$user_config"
add_yaml BOOTSTRAP_FEATURES .enabled_features
add_yaml BOOTSTRAP_PACMAN .pacman
add_yaml BOOTSTRAP_AUR .aur
add_yaml BOOTSTRAP_SERVICES .services
multilib_packages=()
add_yaml multilib_packages .multilib

for feature in "${BOOTSTRAP_FEATURES[@]}"; do
  add_yaml BOOTSTRAP_PACMAN ".features.$feature.pacman"
  add_yaml BOOTSTRAP_AUR ".features.$feature.aur"
  add_yaml BOOTSTRAP_SERVICES ".features.$feature.services"
  [ "$(yaml "$BOOTSTRAP_CONFIG" ".features.$feature.multilib // \"\"")" = true ] && BOOTSTRAP_MULTILIB=true
done

if $BOOTSTRAP_MULTILIB; then
  add BOOTSTRAP_PACMAN "${multilib_packages[@]}"
fi

BOOTSTRAP_BOOTY_URL="$(yaml "$BOOTSTRAP_CONFIG" .booty_url)"
BOOTSTRAP_SECRETS_URL="$(yaml "$BOOTSTRAP_CONFIG" .secrets_url)"
[ -n "$BOOTSTRAP_BOOTY_URL" ] || die "missing booty_url in $user_config"

export BOOTSTRAP_BOOTY_URL BOOTSTRAP_SECRETS_URL BOOTSTRAP_MULTILIB BOOTSTRAP_TIMEZONE BOOTSTRAP_USER

if [ "${BOOTSTRAP_CMD:-}" = config ]; then
  compgen -A variable | awk '/^(BOOTY|BOOTSTRAP)_/' | sort | while read -r name; do
    declare -p "$name"
  done
  exit 0
fi
