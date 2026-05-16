export BOOTSTRAP_ROOT="${BOOTSTRAP_ROOT:-$BOOTY_HOME/booty/bootstrap/$BOOTY_OS}"
export BOOTSTRAP_CONFIG_DIR="${BOOTSTRAP_CONFIG_DIR:-$BOOTY_HOME/bootstrap}"
export BOOTSTRAP_CONFIG="$BOOTSTRAP_CONFIG_DIR/$BOOTY_OS.yaml"

has(){ local x="$1" y; shift; for y; do [ "$x" = "$y" ] && return 0; done; return 1; }
add(){ declare -n a="$1"; local x; shift; for x; do [ -n "$x" ] && ! has "$x" "${a[@]:-}" && a+=("$x"); done; }
yaml(){ yq eval -r "$2" "$1" 2>/dev/null | sed '/^null$/d;/^$/d'; }

own_config(){
  [ "$EUID" -eq 0 ] && [ -n "${BOOTSTRAP_USER:-}" ] && id -u "$BOOTSTRAP_USER" >/dev/null 2>&1 || return 0
  chown -h "$BOOTSTRAP_USER:" "$@"
}

prep_config_dir(){
  [ ! -L "$BOOTSTRAP_CONFIG_DIR" ] || die "refusing symlinked bootstrap config dir: $BOOTSTRAP_CONFIG_DIR"
  mkdir -p "$BOOTSTRAP_CONFIG_DIR"
  own_config "$BOOTSTRAP_CONFIG_DIR"
}

# shellcheck disable=SC2016 # yq expression, not a shell expansion
yaml_merge(){
  prep_config_dir
  yq eval-all -o=yaml '. as $item ireduce ({}; . *+ $item)' "$@" > "$BOOTSTRAP_CONFIG"
  own_config "$BOOTSTRAP_CONFIG"
}

ask(){
  local file="$BOOTSTRAP_CONFIG_DIR/$1" default="$2" answer
  prep_config_dir
  [ -e "$file" ] || echo "$default" > "$file"
  if [ -t 0 ]; then read -rp "$1? : " -i "$(<"$file")" -e answer; else answer="$(<"$file")"; fi
  echo "${answer:-$default}" > "$file"
  own_config "$file"
}

add_yaml(){
  local item
  while IFS= read -r item; do add "$1" "$item"; done < <(yaml "$BOOTSTRAP_CONFIG" "$2[]")
}

bootstrap_need_yq(){
  yq --version 2>/dev/null | grep -qi mikefarah || die "booty expects Mike Farah yq"
}

bootstrap_common_config(){
  BOOTSTRAP_USER="${BOOTSTRAP_USER:-${SUDO_USER:-${USER:-$(id -un)}}}"
  [ "$BOOTSTRAP_USER" != root ] || die "run booty-bootstrap as the target sudo-capable user, not root"
  BOOTY_USER="$BOOTSTRAP_USER"
  ask timezone "US/Mountain"
  BOOTSTRAP_TIMEZONE="$(<"$BOOTSTRAP_CONFIG_DIR/timezone")"
  export BOOTSTRAP_USER BOOTSTRAP_TIMEZONE BOOTY_USER
}

bootstrap_dump_env(){
  compgen -A variable | awk '/^(BOOTY|BOOTSTRAP)_/' | sort | while read -r name; do
    declare -p "$name"
  done
}

as_user(){
  local env=() name user="$1"
  shift
  for name in \
    BOOTY_AGE_IDENTITY \
    BOOTY_HOME \
    BOOTY_HOST \
    BOOTY_OS \
    BOOTY_REPO_URL \
    BOOTY_ROOT \
    BOOTY_SECRETS_URL \
    BOOTY_USER \
    DEBUG
  do
    env+=("$name=${!name:-}")
  done
  sudo -H -u "$user" env "${env[@]}" "$@"
}

sudo_env_exec(){
  local env=() name
  while [ "$1" != -- ]; do
    name="$1"; env+=("$name=${!name:-}"); shift
  done
  shift
  exec sudo env "${env[@]}" "$@"
}

add_user_groups(){
  local user="$1" group
  shift
  for group; do
    getent group "$group" >/dev/null && usermod -aG "$group" "$user"
  done
}

source_bootstrap(){
  local script="$1"
  [ -f "$script" ] || return 0
  log "running ${script#"$BOOTSTRAP_ROOT/"}"
  # shellcheck source=/dev/null
  . "$script"
}
