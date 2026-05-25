log(){ echo "$*" >&2; }
dbg(){ if [ "${DEBUG:-0}" = 1 ]; then echo "  [debug:$(basename "$0")] $*" >&2; fi; }
die(){
  log "$*"
  [ "${DEBUG:-0}" = 1 ] || log "  (re-run with DEBUG=1 for a full trace)"
  exit 1
}

source_file(){
  # shellcheck source=/dev/null
  . "$1"
}

BOOTY_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
export BOOTY_ROOT

booty_user_home(){
  local h; h="$(getent passwd "${SUDO_USER:-}" 2>/dev/null | cut -d: -f6)"
  [ "${USER:-}" = root ] && [ -n "$h" ] && { echo "$h"; return; }
  echo "$HOME"
}

BOOTY_HOME="${BOOTY_HOME:-$(booty_user_home)/.booty}"
booty_home="$BOOTY_HOME"
booty_config="$BOOTY_HOME/config"
[ ! -f "$booty_config" ] || source_file "$booty_config"
BOOTY_HOME="$booty_home"
booty_gpg_home="${GNUPGHOME:-$HOME/.gnupg}"
booty_repo="$BOOTY_HOME/booty"
booty_secrets_repo="$BOOTY_HOME/booty-secrets"
booty_gpg_usage="usage: booty gpg <export|import> [archive.tar.gz.age]"
export BOOTY_HOME

detect_os(){
  [ -r /etc/os-release ] || die "cannot detect operating system"
  . /etc/os-release
  [ -n "${ID:-}" ] || die "cannot detect operating system"
  [ "$ID" = arch ] && echo archlinux || echo "$ID"
}

export BOOTY_OS="${BOOTY_OS:-$(detect_os)}"
BOOTY_HOST="${BOOTY_HOST:-$(uname -n)}"
BOOTY_USER="${BOOTY_USER:-${USER:-$(id -un)}}"

booty_gpg_ready(){
  command -v gpg >/dev/null &&
    GNUPGHOME="$booty_gpg_home" gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec'
}

booty_tmp_root="$BOOTY_HOME/tmp/booty.$$"
booty_tmp_env(){
  mkdir -p "$booty_tmp_root"
  chmod 700 "$BOOTY_HOME/tmp" "$booty_tmp_root"
  export TMPDIR="$booty_tmp_root"
}

booty_tmp(){
  local var="$1" prefix="${2:-tmp}" dir
  booty_tmp_env
  dir="$(mktemp -d "$TMPDIR/$prefix.XXXXXX")"
  printf -v "$var" %s "$dir"
}

booty_cleanup(){ [ ! -e "$booty_tmp_root" ] || rm -rf "$booty_tmp_root"; }
trap booty_cleanup EXIT

booty_gpg(){
  local cmd="${1:-help}" archive="${2:-$BOOTY_HOME/gnupg.tar.gz.age}" tmp
  [ $# -le 2 ] || die "$booty_gpg_usage"
  case "$cmd" in
    help|--help|-h) echo "$booty_gpg_usage" ;;
    export)
      command -v age >/dev/null || die "age is required"
      booty_gpg_ready || die "no GPG secret key found in $booty_gpg_home"
      booty_tmp tmp gpg-archive
      mkdir -p "$(dirname "$archive")"
      GNUPGHOME="$booty_gpg_home" gpg --armor --export > "$tmp/public.asc"
      GNUPGHOME="$booty_gpg_home" gpg --armor --export-secret-keys > "$tmp/secret.asc"
      GNUPGHOME="$booty_gpg_home" gpg --export-ownertrust > "$tmp/ownertrust.txt"
      tar -C "$tmp" -czf "$tmp/gnupg.tar.gz" public.asc secret.asc ownertrust.txt
      if [ -n "${BOOTY_AGE_IDENTITY:-}" ]; then
        age -r "$(age-keygen -y "$BOOTY_AGE_IDENTITY")" -o "$archive" "$tmp/gnupg.tar.gz"
      else
        age -p -o "$archive" "$tmp/gnupg.tar.gz"
      fi
      ;;
    import)
      [ -f "$archive" ] || die "missing archive: $archive"
      command -v age >/dev/null || die "age is required"
      booty_tmp tmp gpg-archive
      if [ -n "${BOOTY_AGE_IDENTITY:-}" ]; then
        age -d -i "$BOOTY_AGE_IDENTITY" -o "$tmp/gnupg.tar.gz" "$archive"
      else
        age -d -o "$tmp/gnupg.tar.gz" "$archive"
      fi
      tar -xzf "$tmp/gnupg.tar.gz" -C "$tmp"
      mkdir -p "$booty_gpg_home"
      chmod 700 "$booty_gpg_home"
      GNUPGHOME="$booty_gpg_home" gpg --import "$tmp/public.asc"
      GNUPGHOME="$booty_gpg_home" gpg --import "$tmp/secret.asc"
      [ ! -s "$tmp/ownertrust.txt" ] || GNUPGHOME="$booty_gpg_home" gpg --import-ownertrust "$tmp/ownertrust.txt"
      booty_gpg_ready || die "GPG import did not restore a secret key"
      ;;
    *) die "$booty_gpg_usage" ;;
  esac
}

ensure_checkout(){
  local label="$1" repo="$2" url="$3" required="$4"
  if [ -d "$repo/.git" ]; then
    [ -z "$url" ] && return 0
    log "updating $label checkout remote: $url"
    git -C "$repo" remote set-url origin "$url" 2>/dev/null ||
      git -C "$repo" remote add origin "$url"
  elif [ -n "$url" ]; then
    log "cloning $label checkout: $url -> $repo"
    git clone "$url" "$repo"
  elif [ "$required" = 1 ]; then
    die "missing $label checkout: $repo; set BOOTY_REPO_URL or run install"
  else
    return 1
  fi
}

booty_sync(){
  dbg "booty_sync: BOOTY_HOME=$BOOTY_HOME BOOTY_REPO_URL=${BOOTY_REPO_URL:-} BOOTY_HOST=$BOOTY_HOST BOOTY_USER=$BOOTY_USER"
  mkdir -p "$BOOTY_HOME"
  ensure_checkout public "$booty_repo" "${BOOTY_REPO_URL:-}" 1

  log "updating public checkout: $booty_repo"
  pull_repo "$booty_repo" public
  require_sources "$booty_repo" public
  log "applying public checkout: $booty_repo"
  booty_run "$booty_repo" apply

  if [ -n "${BOOTY_SECRETS_URL:-}" ]; then
    dbg "booty_sync: BOOTY_SECRETS_URL=$BOOTY_SECRETS_URL"
    case "$BOOTY_SECRETS_URL" in
      gcrypt::*) ;;
      *) die "BOOTY_SECRETS_URL must use gcrypt::" ;;
    esac
    if ! booty_gpg_ready; then
      [ -f "$BOOTY_HOME/gnupg.tar.gz.age" ] || {
        log "skipping secrets checkout: copy GPG archive to $BOOTY_HOME/gnupg.tar.gz.age or run 'booty gpg import <archive>'; then rerun 'booty sync'"
        return 0
      }
      booty_gpg import "$BOOTY_HOME/gnupg.tar.gz.age"
    fi
    booty_gpg_ready || die "booty sync requires a GPG secret key for secrets checkout"
    command -v git-remote-gcrypt >/dev/null 2>&1 ||
      die "booty sync requires git-remote-gcrypt for secrets checkout"
    ensure_checkout secrets "$booty_secrets_repo" "$BOOTY_SECRETS_URL" 0
  elif [ ! -d "$booty_secrets_repo/.git" ]; then
    log "skipping secrets checkout: no BOOTY_SECRETS_URL"
    return 0
  fi

  log "updating secrets checkout: $booty_secrets_repo"
  pull_repo "$booty_secrets_repo" secrets
  log "applying secrets checkout: $booty_secrets_repo"
  BOOTY_MANIFEST_PREFIX=secrets booty_run "$booty_secrets_repo" apply
}

dotfiles(){ echo "$1/dotfiles/$BOOTY_OS"; }
rootfs_target(){ echo "${BOOTY_TARGET_ROOT:-/}"; }
live_rootfs(){ [ "$(rootfs_target)" = / ]; }
manifest(){ echo "${XDG_DATA_HOME:-$HOME/.local/share}/booty/${BOOTY_MANIFEST_PREFIX:+$BOOTY_MANIFEST_PREFIX-}$1.manifest.tsv"; }
rsync_user(){ echo "$(id -u):$(id -g)"; }
rootfs_sudo(){ [ "$EUID" -eq 0 ] || sudo -v || die "sudo is required to manage live rootfs files"; }
rootfs_cmd(){
  if [ "$EUID" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

clean_path(){
  local path="$1" part parts=() out=()
  IFS=/ read -r -a parts <<< "${path#/}"
  for part in "${parts[@]}"; do
    case "$part" in
      ""|.) ;;
      ..) ((${#out[@]} == 0)) || unset "out[$((${#out[@]} - 1))]" ;;
      *) out+=("$part") ;;
    esac
  done
  local IFS=/
  echo "/${out[*]}"
}

abs_path(){
  local path
  case "$1" in
    /*) path="$1" ;;
    \~) path="$HOME" ;;
    \~/*) path="$HOME/${1#\~/}" ;;
    *) path="$PWD/$1" ;;
  esac
  clean_path "$path"
}

path_area(){
  local p home
  p="$(abs_path "$1")"
  home="$(abs_path "$HOME")"
  if [ "$BOOTY_USER" = root ]; then
    case "$p" in /root|/root/*) echo home; return ;; esac
  fi
  case "$p" in
    "$home"|"$home"/*|/home/"$BOOTY_USER"|/home/"$BOOTY_USER"/*) echo home ;;
    /home/*) die "refusing to manage another user's home: $p" ;;
    *) echo rootfs ;;
  esac
}

rootfs_rel(){
  local p root
  p="$(abs_path "$1")"
  root="$(abs_path "$(rootfs_target)")"
  case "$root" in
    /) case "$p" in /*) echo "${p#/}" ;; *) return 1 ;; esac ;;
    *) case "$p" in "$root") echo "" ;; "$root"/*) echo "${p#"$root"/}" ;; *) return 1 ;; esac ;;
  esac
}

managed_rel(){
  local rel="$1" part parts=()
  if [ -z "$rel" ] || [[ "$rel" = /* ]]; then
    die "managed path '$rel' is outside rootfs"
  fi
  IFS=/ read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    case "$part" in
      ""|.|..) die "managed path '$rel' is outside rootfs" ;;
    esac
  done
  echo "$rel"
}

managed_rootfs_rel(){
  local rel
  rel="$(rootfs_rel "$1")" || die "rootfs path '$(abs_path "$1")' is outside $(rootfs_target)"
  [ -n "$rel" ] || die "refusing to manage rootfs target root"
  echo "$rel"
}

source_dirs(){
  local repo="$1" area="$2" root dir roots=() dirs=()
  roots+=("$(dotfiles "$booty_repo")")
  [ "$repo" = "$booty_repo" ] || roots+=("$(dotfiles "$repo")")

  for root in "${roots[@]}"; do
    case "$area" in
      home) dirs=("$root/rootfs/home/$BOOTY_USER" "$root/hosts/$BOOTY_HOST/rootfs/home/$BOOTY_USER") ;;
      rootfs) dirs=("$root/rootfs" "$root/hosts/$BOOTY_HOST/rootfs") ;;
    esac
    for dir in "${dirs[@]}"; do
      [ -d "$dir" ] && echo "$dir"
    done
  done
}

has_sources(){
  [ -n "$(source_dirs "$1" "$2")" ]
}

require_sources(){
  local repo="$1" label="$2"
  has_sources "$repo" home || has_sources "$repo" rootfs ||
    die "$label checkout has no dotfiles for $BOOTY_OS/$BOOTY_HOST/$BOOTY_USER in $repo/dotfiles/$BOOTY_OS; see README.md#dotfiles-repository-layout"
}

pull_repo(){
  local repo="$1" label="$2" url
  url="$(git -C "$repo" remote get-url origin 2>/dev/null)" || return 0
  git -C "$repo" pull --ff-only || die "failed to update $label checkout from $url"
}

gitbooty(){
  local repo="$1" area="$2" target writeback dir dirs=() layers exclude=
  shift 2
  dbg "gitbooty $area: repo=$repo BOOTY_HOST=$BOOTY_HOST BOOTY_USER=$BOOTY_USER"

  case "$area" in
    home)
      target="$HOME"
      writeback="$repo/dotfiles/$BOOTY_OS/rootfs/home/$BOOTY_USER"
      ;;
    rootfs)
      target="$(rootfs_target)"
      writeback="$repo/dotfiles/$BOOTY_OS/hosts/$BOOTY_HOST/rootfs"
      ;;
  esac

  while IFS= read -r dir; do dirs+=("$dir"); done < <(source_dirs "$repo" "$area")
  ((${#dirs[@]})) || dirs=("$writeback")
  [ "$area" = rootfs ] && exclude='home/*'
  dbg "gitbooty $area: layers=(${dirs[*]}) exclude=$exclude target=$target"

  booty_tmp_env
  layers="$(printf '%s\n' "${dirs[@]}")"
  GITBOOTY_REPO_ROOT="$repo" \
  GITBOOTY_WRITEBACK_ROOT="$writeback" \
  GITBOOTY_TARGET_ROOT="$target" \
  GITBOOTY_MANIFEST="$(manifest "$area")" \
  GITBOOTY_LAYERS="$layers" \
  GITBOOTY_EXCLUDES="$exclude" \
    "$BOOTY_ROOT/bin/gitbooty" "$@"
}

copy_from_rootfs(){
  local src="$1" dst="$2"
  src="$(abs_path "$src")"
  dst="$(abs_path "$dst")"
  managed_rootfs_rel "$src" >/dev/null
  mkdir -p "$(dirname "$dst")"
  if live_rootfs; then
    rootfs_sudo
    rootfs_cmd rsync -a --chown="$(rsync_user)" -- "$src" "$dst"
  else
    cp -a -- "$src" "$dst"
  fi
}

staged_rootfs_path(){
  echo "$1/${2#/}"
}

stage_rootfs_paths(){
  local tmp="$1" p rels=()
  shift
  for p in "$@"; do
    rels+=("${p#/}")
  done
  ((${#rels[@]})) || return 0
  printf '%s\n' "${rels[@]}" |
    rootfs_cmd rsync -a --ignore-missing-args --files-from=- --chown="$(rsync_user)" / "$tmp/"
}

stage_manifest_rootfs(){
  local tmp="$1" rel _ paths=()
  if [ -f "$(manifest rootfs)" ]; then
    while IFS=$'\t' read -r rel _; do
      [ -n "$rel" ] || continue
      rel="$(managed_rel "$rel")"
      paths+=("/$rel")
    done < "$(manifest rootfs)"
  fi
  if ((${#paths[@]})); then
    rootfs_sudo
    stage_rootfs_paths "$tmp" "${paths[@]}"
  fi
}

snapshot_rootfs(){
  local repo="$1" tmp; shift
  booty_tmp tmp rootfs
  stage_manifest_rootfs "$tmp"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs "$@"
}

commit_rootfs(){
  local repo="$1" tmp
  live_rootfs || { gitbooty "$repo" rootfs commit; return; }
  booty_tmp tmp rootfs
  stage_manifest_rootfs "$tmp"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs commit
}

apply_rootfs(){
  local repo="$1" tmp render previous_manifest current_manifest rel _ rsync_opts=(-rlptD)
  shift
  live_rootfs || { gitbooty "$repo" rootfs "$@"; return; }

  rootfs_sudo
  if [ "${DEBUG:-0}" = 1 ]; then rsync_opts+=(--verbose); fi

  booty_tmp tmp apply
  render="$tmp/root"
  mkdir -p "$render"
  current_manifest="$(manifest rootfs)"
  previous_manifest=""
  if [ -f "$current_manifest" ]; then
    previous_manifest="$tmp/old.tsv"
    cp "$current_manifest" "$previous_manifest"
  fi
  dbg "apply_rootfs: rendering to $render"
  BOOTY_TARGET_ROOT="$render" gitbooty "$repo" rootfs "$@"
  if [ "${DEBUG:-0}" = 1 ]; then
    dbg "apply_rootfs: rendered files: $(find "$render" -type f | sort | tr '\n' ' ')"
  fi
  dbg "apply_rootfs: rootfs rsync ${rsync_opts[*]} $render/ /"
  rootfs_cmd rsync "${rsync_opts[@]}" "$render"/ /
  if [ -f "$previous_manifest" ]; then
    awk -F '\t' 'FILENAME == ARGV[1] { keep[$1]=1; next } $1 && !($1 in keep) { print $1 }' "$current_manifest" "$previous_manifest" |
      while IFS= read -r rel; do
        rel="$(managed_rel "$rel")"
        rootfs_cmd rm -f -- "/$rel"
      done
  fi
}

add_rootfs(){
  local repo="$1" p="$2" tmp f
  p="$(abs_path "$p")"
  managed_rootfs_rel "$p" >/dev/null
  live_rootfs || { gitbooty "$repo" rootfs add "$p"; return; }
  booty_tmp tmp add
  rootfs_sudo
  stage_rootfs_paths "$tmp" "$p"
  f="$(staged_rootfs_path "$tmp" "$p")"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs add "$f"
}

rm_rootfs(){
  local repo="$1" p tmp args=()
  shift
  for p in "$@"; do
    managed_rootfs_rel "$p" >/dev/null
    args+=("$(abs_path "$p")")
  done
  set -- "${args[@]}"
  args=()
  live_rootfs || { gitbooty "$repo" rootfs rm "$@"; return; }
  booty_tmp tmp rm
  rootfs_sudo
  stage_rootfs_paths "$tmp" "$@"
  for p in "$@"; do
    args+=("$(staged_rootfs_path "$tmp" "$p")")
  done
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs rm "${args[@]}"
  for p in "$@"; do
    rootfs_cmd rm -f -- "$p"
  done
}

mv_rootfs(){
  local repo="$1" src="$2" dst="$3" drel tmp staged
  src="$(abs_path "$src")"
  dst="$(abs_path "$dst")"
  managed_rootfs_rel "$src" >/dev/null
  managed_rootfs_rel "$dst" >/dev/null
  live_rootfs || { gitbooty "$repo" rootfs mv "$src" "$dst"; return; }
  drel="${dst#/}"; booty_tmp tmp mv
  rootfs_sudo
  stage_rootfs_paths "$tmp" "$src"
  staged="$(staged_rootfs_path "$tmp" "$src")"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs mv "$staged" "$tmp/$drel"
  rootfs_cmd mkdir -p "$(dirname "$dst")"
  rootfs_cmd mv -- "$src" "$dst"
}

home_to_rootfs(){
  local repo="$1" src="$2" dst="$3" rel tmp f
  src="$(abs_path "$src")"
  dst="$(abs_path "$dst")"
  rel="$(managed_rootfs_rel "$dst")"
  booty_tmp tmp add
  f="$tmp/$rel"
  mkdir -p "$(dirname "$f")"
  cp -a -- "$src" "$f"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs add "$f"
  if live_rootfs; then
    rootfs_sudo
    rootfs_cmd mkdir -p "$(dirname "$dst")"
    rootfs_cmd rsync -a -- "$f" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp -a -- "$f" "$dst"
  fi
}

apply_checkout(){
  local repo="$1"
  if [ "${BOOTY_SKIP_HOME:-0}" != 1 ] && { [ -f "$(manifest home)" ] || has_sources "$repo" home; }; then
    gitbooty "$repo" home apply
  fi
  if [ "${BOOTY_SKIP_ROOTFS:-0}" != 1 ] && { [ -f "$(manifest rootfs)" ] || has_sources "$repo" rootfs; }; then
    apply_rootfs "$repo" apply
  fi
}

edit_paths(){
  local repo="$1" cmd="$2" p area
  shift 2
  [ $# -gt 0 ] || die "usage: booty $cmd <path>..."
  for p in "$@"; do
    area="$(path_area "$p")"
    case "$area" in
      home) gitbooty "$repo" home "$cmd" "$p" ;;
      rootfs) "${cmd}_rootfs" "$repo" "$p" ;;
    esac
  done
}

booty_run(){
  local repo="$1" cmd="$2" src_area dst_area rc
  shift 2
  case "$cmd" in
    pull)
      git -C "$repo" remote get-url origin >/dev/null 2>&1 &&
        git -C "$repo" pull --ff-only
      apply_checkout "$repo"
      ;;
    apply)
      apply_checkout "$repo"
      ;;
    status|diff)
      rc=0
      if [ -f "$(manifest home)" ] || has_sources "$repo" home; then
        gitbooty "$repo" home "$cmd" "$@" || rc=$?
      fi
      if [ -f "$(manifest rootfs)" ] || has_sources "$repo" rootfs; then
        if live_rootfs; then
          snapshot_rootfs "$repo" "$cmd" "$@" || rc=$?
        else
          gitbooty "$repo" rootfs "$cmd" "$@" || rc=$?
        fi
      fi
      if [ "$cmd" = status ] && git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$repo" status --short
      fi
      return "$rc"
      ;;
    add|rm)
      edit_paths "$repo" "$cmd" "$@"
      ;;
    mv)
      [ $# -eq 2 ] || die "usage: booty mv <src> <dst>"
      src_area="$(path_area "$1")"; dst_area="$(path_area "$2")"
      case "$src_area$dst_area" in
        homehome) gitbooty "$repo" home mv "$1" "$2" ;;
        rootfsrootfs) mv_rootfs "$repo" "$1" "$2" ;;
        homerootfs)
          home_to_rootfs "$repo" "$1" "$2"
          gitbooty "$repo" home rm "$1"
          ;;
        rootfshome)
          copy_from_rootfs "$1" "$2"
          gitbooty "$repo" home add "$2"
          rm_rootfs "$repo" "$1"
          ;;
      esac
      ;;
    commit)
      gitbooty "$repo" home commit
      commit_rootfs "$repo"
      git -C "$repo" commit "$@"
      ;;
    branch|config|remote|log|show|fetch|tag|push)
      git -C "$repo" "$cmd" "$@"
      ;;
    *) die "unsupported command '$cmd'" ;;
  esac
}
