log(){ echo "$*" >&2 ; }
die(){ log "$*"; exit 1; }

append_unique(){
  local -n dest="$1"
  shift
  local item existing found
  for item in "$@"; do
    [ -n "$item" ] || continue
    found=false
    for existing in "${dest[@]:-}"; do
      if [ "$existing" = "$item" ]; then
        found=true
        break
      fi
    done
    $found || dest+=("$item")
  done
}

list_contains(){
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

prompt_cfg(){
  local id="$1"
  local default="$2"
  local answer
  [ -e "$id" ] || echo "$default" > "$id"
  if [ -t 0 ]; then
    read -rp "$id? : " -i "$(cat "$id")" -e answer
  else
    answer="$(cat "$id")"
  fi
  echo "${answer:-$default}" > "$id"
}

run_source_dir(){
  local dir="$1"
  shift || true
  local script
  [ -d "$dir" ] || return 0
  while IFS= read -r script; do
    [ -f "$script" ] || continue
    log "running ${script##*/}"
    # shellcheck disable=SC1090
    . "$script" "$@"
  done < <(find "$dir" -maxdepth 1 -type f | sort)
}
