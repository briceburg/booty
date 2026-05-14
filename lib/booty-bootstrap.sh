export BOOTSTRAP_ROOT="${BOOTSTRAP_ROOT:-$BOOTY_HOME/booty/bootstrap/$BOOTY_OS}"
export BOOTSTRAP_CONFIG_DIR="${BOOTSTRAP_CONFIG_DIR:-/etc/booty}"
export BOOTSTRAP_CONFIG="$BOOTSTRAP_CONFIG_DIR/$BOOTY_OS.yaml"

has(){ local x="$1" y; shift; for y in "$@"; do [ "$x" = "$y" ] && return 0; done; return 1; }
add(){ declare -n a="$1"; local x; shift; for x in "$@"; do [ -n "$x" ] && ! has "$x" "${a[@]:-}" && a+=("$x"); done; }
yaml(){ yq eval -r "$2" "$1" 2>/dev/null | sed '/^null$/d;/^$/d'; }

# shellcheck disable=SC2016 # yq expression, not a shell expansion
yaml_merge(){ yq eval-all -o=yaml '. as $item ireduce ({}; . *+ $item)' "$@" > "$BOOTSTRAP_CONFIG"; }

ask(){
  local file="$BOOTSTRAP_CONFIG_DIR/$1" default="$2" answer
  [ -e "$file" ] || echo "$default" > "$file"
  if [ -t 0 ]; then read -rp "$1? : " -i "$(<"$file")" -e answer; else answer="$(<"$file")"; fi
  echo "${answer:-$default}" > "$file"
}

add_yaml(){
  local item
  while IFS= read -r item; do add "$1" "$item"; done < <(yaml "$BOOTSTRAP_CONFIG" "$2[]")
}

bootstrap_need_yq(){
  yq --version 2>/dev/null | grep -qi mikefarah || die "booty expects Mike Farah yq"
}

bootstrap_common_config(){
  mkdir -p "$BOOTSTRAP_CONFIG_DIR"
  ask user "${SUDO_USER:-nesta}"
  ask timezone "US/Mountain"
  BOOTSTRAP_USER="$(<"$BOOTSTRAP_CONFIG_DIR/user")"
  BOOTSTRAP_TIMEZONE="$(<"$BOOTSTRAP_CONFIG_DIR/timezone")"
  export BOOTSTRAP_USER BOOTSTRAP_TIMEZONE
}

as_user(){
  local user="$1"
  shift
  sudo -H -u "$user" env \
    BOOTY_HOME="$BOOTY_HOME" \
    BOOTY_ROOT="$BOOTY_ROOT" \
    BOOTY_OS="$BOOTY_OS" \
    BOOTY_HOST="$BOOTY_HOST" \
    BOOTSTRAP_CONFIG_DIR="${BOOTSTRAP_CONFIG_DIR:-}" \
    BOOTY_AGE_IDENTITY="${BOOTY_AGE_IDENTITY:-}" \
    BOOTY_REPO_URL="${BOOTY_REPO_URL:-}" \
    DEBUG="${DEBUG:-0}" \
    "$@"
}

source_bootstrap(){
  local script="$1"
  [ -f "$script" ] || return 0
  log "running ${script#"$BOOTSTRAP_ROOT/"}"
  # shellcheck source=/dev/null
  . "$script"
}
