# shellcheck disable=SC2034 # sourced bootstrap state consumed by later fragments and config output
if ! command -v yq >/dev/null; then
  [ "${BOOTSTRAP_CMD:-}" != config ] || die "yq is required to resolve bootstrap config"
  pacman -Syu --noconfirm --needed go-yq
fi
bootstrap_common_config

BOOTSTRAP_MULTILIB=false
BOOTSTRAP_FEATURES=()
BOOTSTRAP_PACMAN=()
BOOTSTRAP_AUR=()
BOOTSTRAP_SERVICES=()

host_config="$BOOTSTRAP_ROOT/config/hosts/$BOOTY_HOST.yaml"
user_config="$BOOTSTRAP_ROOT/config/users/$BOOTSTRAP_USER.yaml"
base_config="$BOOTSTRAP_ROOT/config/base.yaml"
configs=("$base_config" "$host_config")
bootstrap_need_yq
[ -f "$host_config" ] || die "missing host definition: $host_config"
[ -f "$base_config" ] || die "missing base config: $base_config"
[ -f "$user_config" ] && configs+=("$user_config")

yaml_merge "${configs[@]}"
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

$BOOTSTRAP_MULTILIB && add BOOTSTRAP_PACMAN "${multilib_packages[@]}"

BOOTY_REPO_URL="${BOOTY_REPO_URL:-$(yaml "$BOOTSTRAP_CONFIG" .repo_url)}"
BOOTY_SECRETS_URL="${BOOTY_SECRETS_URL:-$(yaml "$BOOTSTRAP_CONFIG" .secrets_url)}"
[ -n "$BOOTY_REPO_URL" ] || die "missing BOOTY_REPO_URL or repo_url in $user_config"

export BOOTY_REPO_URL BOOTY_SECRETS_URL BOOTSTRAP_MULTILIB BOOTSTRAP_TIMEZONE BOOTSTRAP_USER
