yaml_merge(){
  local output="$1"
  shift

  yq ea -o=yaml '. as $item ireduce ({}; . *+ $item)' "$@" > "$output"
}

yaml_list(){
  local file="$1"
  local path="$2"
  yq -r "${path}[]?" "$file" 2>/dev/null | sed '/^null$/d;/^$/d'
}

yaml_value(){
  local file="$1"
  local path="$2"
  yq -r "${path} // \"\"" "$file" 2>/dev/null | sed '/^null$/d;/^$/d'
}

append_yaml_list(){
  local dest_name="$1"
  local file="$2"
  local path="$3"
  local item
  while IFS= read -r item; do
    append_unique "$dest_name" "$item"
  done < <(yaml_list "$file" "$path")
}
