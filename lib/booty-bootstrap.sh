export BOOTSTRAP_ROOT="${BOOTSTRAP_ROOT:-$BOOTY_HOME/booty/bootstrap/$BOOTY_OS}"
export BOOTSTRAP_CONFIG_DIR="${BOOTSTRAP_CONFIG_DIR:-$BOOTY_HOME/bootstrap}"
export BOOTSTRAP_CONFIG="$BOOTSTRAP_CONFIG_DIR/$BOOTY_OS.yaml"

has(){ local x="$1" y; shift; for y; do [ "$x" = "$y" ] && return 0; done; return 1; }
add(){ declare -n a="$1"; local x; shift; for x; do [ -n "$x" ] && ! has "$x" "${a[@]:-}" && a+=("$x"); done; }
yaml(){ yq eval -r "$2" "$1" 2>/dev/null | sed '/^null$/d;/^$/d'; }

BOOTSTRAP_ENV=(
  BOOTSTRAP_CONFIG_DIR
  BOOTSTRAP_ROOT
  BOOTSTRAP_SKIP_REFLECTOR
  BOOTSTRAP_USER
  BOOTY_AGE_IDENTITY
  BOOTY_HOME
  BOOTY_HOST
  BOOTY_OS
  BOOTY_REPO_URL
  BOOTY_ROOT
  BOOTY_SECRETS_URL
  BOOTY_SKIP_ROOTFS
  BOOTY_USER
  DEBUG
)

own_config(){
  [ "$EUID" -eq 0 ] && [ -n "${BOOTSTRAP_USER:-}" ] && id -u "$BOOTSTRAP_USER" >/dev/null 2>&1 || return 0
  chown -h "$BOOTSTRAP_USER:" "$@"
}

own_user_paths(){
  local path user="$1"
  shift
  for path in "$@"; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    [ ! -L "$path" ] || die "refusing symlinked bootstrap-owned path: $path"
    chown -h "$user:" "$path"
  done
}

prep_config_dir(){
  [ ! -L "$BOOTSTRAP_CONFIG_DIR" ] || die "refusing symlinked bootstrap config dir: $BOOTSTRAP_CONFIG_DIR"
  mkdir -p "$BOOTSTRAP_CONFIG_DIR"
  own_config "$BOOTSTRAP_CONFIG_DIR"
}

write_config(){
  local file="$1" tmp
  [ ! -L "$file" ] || die "refusing symlinked bootstrap config file: $file"
  tmp="$(mktemp "$(dirname "$file")/.${file##*/}.XXXXXX")"
  cat > "$tmp"
  own_config "$tmp"
  mv "$tmp" "$file"
}

yaml_merge(){
  local tmp
  prep_config_dir
  [ ! -L "$BOOTSTRAP_CONFIG" ] || die "refusing symlinked bootstrap config file: $BOOTSTRAP_CONFIG"
  tmp="$(mktemp "$(dirname "$BOOTSTRAP_CONFIG")/.${BOOTSTRAP_CONFIG##*/}.XXXXXX")"
  yq eval-all -o=yaml ". as \$item ireduce ({}; . *+ \$item)" "$@" > "$tmp"
  own_config "$tmp"
  mv "$tmp" "$BOOTSTRAP_CONFIG"
}

ask(){
  local file="$BOOTSTRAP_CONFIG_DIR/$1" default="$2" answer
  prep_config_dir
  [ ! -L "$file" ] || die "refusing symlinked bootstrap config file: $file"
  [ -e "$file" ] || printf '%s\n' "$default" | write_config "$file"
  if [ -t 0 ]; then
    read -rp "$1? : " -i "$(<"$file")" -e answer
  else
    answer="$(<"$file")"
  fi
  printf '%s\n' "${answer:-$default}" | write_config "$file"
}

add_yaml(){
  local item
  while IFS= read -r item; do add "$1" "$item"; done < <(yaml "$BOOTSTRAP_CONFIG" "$2[]")
}

passwd_home(){
  local home
  home="$(getent passwd "$1" | cut -d: -f6)"
  [ -n "$home" ] || die "cannot find home directory for $1"
  echo "$home"
}

bootstrap_need_yq(){
  yq --version 2>/dev/null | grep -qi mikefarah || die "booty expects Mike Farah yq"
}

bootstrap_common_config(){
  [ -n "${BOOTSTRAP_USER:-}" ] || {
    ask user ""
    BOOTSTRAP_USER="$(<"$BOOTSTRAP_CONFIG_DIR/user")"
  }
  [ -n "$BOOTSTRAP_USER" ] || die "set BOOTSTRAP_USER to the target dotfile user"
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
  for name in "${BOOTSTRAP_ENV[@]}"; do
    env+=("$name=${!name:-}")
  done
  if [ "$EUID" -eq 0 ] && [ "$user" = root ]; then
    env "${env[@]}" "$@"
  else
    sudo -H -u "$user" env "${env[@]}" "$@"
  fi
}

as_user_in(){
  local user="$1" dir="$2"
  shift 2
  as_user "$user" env BOOTY_WORKDIR="$dir" bash -c "cd \"\$BOOTY_WORKDIR\" && exec \"\$@\"" bash "$@"
}

sudo_env_exec(){
  local env=() name
  (($#)) || die "sudo_env_exec missing --"
  while [ "$1" != -- ]; do
    (($# > 1)) || die "sudo_env_exec missing --"
    name="$1"
    env+=("$name=${!name:-}")
    shift
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
  source_file "$script"
}

bootstrap_apply_rootfs(){
  local user_home
  [ "${BOOTSTRAP_TARGET_READY:-0}" = 1 ] || return 0
  [ "${BOOTSTRAP_ROOTFS_APPLIED:-0}" != 1 ] || return 0
  user_home="$(passwd_home "$BOOTSTRAP_USER")"
  [ -x "$BOOTY_HOME/booty/bin/booty" ] || die "missing target checkout command: $BOOTY_HOME/booty/bin/booty"

  log "applying bootstrap rootfs from target checkout"
  env BOOTY_USER="$BOOTSTRAP_USER" HOME="$user_home" BOOTY_HOME="$BOOTY_HOME" BOOTY_SKIP_HOME=1 "$BOOTY_HOME/booty/bin/booty" apply
  if [ "$EUID" -eq 0 ]; then
    as_user "$BOOTSTRAP_USER" mkdir -p "$BOOTY_HOME/tmp" "$user_home/.local/share/booty"
    own_user_paths "$BOOTSTRAP_USER" \
      "$BOOTY_HOME/tmp" \
      "$user_home/.local" \
      "$user_home/.local/share" \
      "$user_home/.local/share/booty" \
      "$user_home/.local/share/booty/rootfs.manifest.tsv"
  fi
  BOOTSTRAP_ROOTFS_APPLIED=1
}
