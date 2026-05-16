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
      booty_gpg_ready && return 0
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
      booty_gpg_ready
      ;;
    *) die "$booty_gpg_usage" ;;
  esac
}

booty_sync(){
  dbg "booty_sync: BOOTY_HOME=$BOOTY_HOME BOOTY_REPO_URL=${BOOTY_REPO_URL:-} BOOTY_HOST=$BOOTY_HOST BOOTY_USER=$BOOTY_USER"
  mkdir -p "$BOOTY_HOME"
  if [ -d "$booty_repo/.git" ]; then
    if [ -n "${BOOTY_REPO_URL:-}" ]; then
      log "updating public checkout remote: $BOOTY_REPO_URL"
      git -C "$booty_repo" remote set-url origin "$BOOTY_REPO_URL" 2>/dev/null ||
        git -C "$booty_repo" remote add origin "$BOOTY_REPO_URL"
    fi
  else
    [ -n "${BOOTY_REPO_URL:-}" ] ||
      die "missing public checkout: $booty_repo; set BOOTY_REPO_URL or run install"
    log "cloning public checkout: $BOOTY_REPO_URL -> $booty_repo"
    git clone "$BOOTY_REPO_URL" "$booty_repo"
  fi

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
    if [ -d "$booty_secrets_repo/.git" ]; then
      log "updating secrets checkout remote: $BOOTY_SECRETS_URL"
      git -C "$booty_secrets_repo" remote set-url origin "$BOOTY_SECRETS_URL"
    else
      log "cloning secrets checkout: $BOOTY_SECRETS_URL -> $booty_secrets_repo"
      git clone "$BOOTY_SECRETS_URL" "$booty_secrets_repo"
    fi
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

abs_path(){
  case "$1" in
    /*) echo "$1" ;;
    \~) echo "$HOME" ;;
    \~/*) echo "$HOME/${1#\~/}" ;;
    *) echo "$PWD/$1" ;;
  esac
}

path_area(){
  local p; p="$(abs_path "$1")"
  if [ "$BOOTY_USER" = root ]; then
    case "$p" in /root|/root/*) echo home; return ;; esac
  fi
  case "$p" in
    "$HOME"|"$HOME"/*|/home/"$BOOTY_USER"|/home/"$BOOTY_USER"/*) echo home ;;
    /home/*) die "refusing to manage another user's home: $p" ;;
    *) echo rootfs ;;
  esac
}

rootfs_rel(){
  local p="$1" root; root="$(rootfs_target)"
  case "$root" in
    /) case "$p" in /*) echo "${p#/}" ;; *) return 1 ;; esac ;;
    *) case "$p" in "$root"/*) echo "${p#"$root"/}" ;; *) return 1 ;; esac ;;
  esac
}

source_dirs(){
  local repo="$1" area="$2" root dir roots=()
  roots+=("$(dotfiles "$booty_repo")")
  [ "$repo" = "$booty_repo" ] || roots+=("$(dotfiles "$repo")")

  for root in "${roots[@]}"; do
    case "$area" in
      home) for dir in "$root/rootfs/home/$BOOTY_USER" "$root/hosts/$BOOTY_HOST/rootfs/home/$BOOTY_USER"; do [ -d "$dir" ] && echo "$dir"; done ;;
      rootfs) for dir in "$root/rootfs" "$root/hosts/$BOOTY_HOST/rootfs"; do [ -d "$dir" ] && echo "$dir"; done ;;
    esac
  done
}

has_sources(){
  [ -n "$(source_dirs "$1" "$2")" ]
}

require_sources(){
  local repo="$1" label="$2"
  has_sources "$repo" home || has_sources "$repo" rootfs ||
    die "$label checkout has no dotfiles for $BOOTY_OS/$BOOTY_HOST/$BOOTY_USER in $repo/dotfiles/$BOOTY_OS; see README.md#layout"
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
      target="${BOOTY_HOME_TARGET_ROOT:-$HOME}"
      writeback="$repo/dotfiles/$BOOTY_OS/rootfs/home/$BOOTY_USER"
      ;;
    rootfs)
      target="$(rootfs_target)"
      writeback="$repo/dotfiles/$BOOTY_OS/hosts/$BOOTY_HOST/rootfs"
      ;;
  esac

  while IFS= read -r dir; do dirs+=("$dir"); done < <(source_dirs "$repo" "$area")
  ((${#dirs[@]})) || dirs=("$writeback")
  dbg "gitbooty $area: layers=(${dirs[*]}) exclude=$exclude target=$target"

  booty_tmp_env
  layers="$(printf '%s\n' "${dirs[@]}")"
  [ "$area" = rootfs ] && exclude='home/*'
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
  mkdir -p "$(dirname "$dst")"
  if live_rootfs; then
    rootfs_sudo
    rootfs_cmd rsync -a --chown="$(rsync_user)" -- "$src" "$dst"
  else
    cp -a -- "$src" "$dst"
  fi
}

copy_live_rootfs(){
  local tmp="$1" p rel dst rels=()
  shift
  for p in "$@"; do
    rel="${p#/}"; dst="$tmp/$rel"
    rels+=("$rel")
    echo "$dst"
  done
  ((${#rels[@]})) &&
    printf '%s\n' "${rels[@]}" |
      rootfs_cmd rsync -a --ignore-missing-args --files-from=- --chown="$(rsync_user)" / "$tmp/"
}

snapshot_rootfs(){
  local repo="$1" tmp rel _ paths=(); shift
  booty_tmp tmp rootfs
  if [ -f "$(manifest rootfs)" ]; then
    while IFS=$'\t' read -r rel _; do
      [ -n "$rel" ] || continue
      paths+=("/$rel")
    done < "$(manifest rootfs)"
  fi
  if ((${#paths[@]})); then
    rootfs_sudo
    copy_live_rootfs "$tmp" "${paths[@]}" >/dev/null
  fi
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs "$@"
}

apply_rootfs(){
  local repo="$1" tmp render old new rel _ rsync_opts=(-rlptD)
  shift
  live_rootfs || { gitbooty "$repo" rootfs "$@"; return; }

  rootfs_sudo
  if [ "${DEBUG:-0}" = 1 ]; then rsync_opts+=(--verbose); fi

  booty_tmp tmp apply
  render="$tmp/root"
  mkdir -p "$render"
  new="$(manifest rootfs)"
  old=""; [ -f "$new" ] && { old="$tmp/old.tsv"; cp "$new" "$old"; }
  dbg "apply_rootfs: rendering to $render"
  BOOTY_TARGET_ROOT="$render" gitbooty "$repo" rootfs "$@"
  if [ "${DEBUG:-0}" = 1 ]; then
    dbg "apply_rootfs: rendered files: $(find "$render" -type f | sort | tr '\n' ' ')"
  fi
  dbg "apply_rootfs: rootfs rsync ${rsync_opts[*]} $render/ /"
  rootfs_cmd rsync "${rsync_opts[@]}" "$render"/ /
  if [ -f "$old" ]; then
    awk -F '\t' 'FILENAME == ARGV[1] { keep[$1]=1; next } $1 && !($1 in keep) { print $1 }' "$new" "$old" |
      while IFS= read -r rel; do rootfs_cmd rm -f -- "/$rel"; done
  fi
}

add_rootfs(){
  local repo="$1" p="$2" tmp f
  live_rootfs || { gitbooty "$repo" rootfs add "$p"; return; }
  booty_tmp tmp add
  rootfs_sudo
  f="$(copy_live_rootfs "$tmp" "$p")"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs add "$f"
}

rm_rootfs(){
  local repo="$1" p tmp args=()
  shift
  live_rootfs || { gitbooty "$repo" rootfs rm "$@"; return; }
  booty_tmp tmp rm
  rootfs_sudo
  while IFS= read -r p; do args+=("$p"); done < <(copy_live_rootfs "$tmp" "$@")
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs rm "${args[@]}"
  for p in "$@"; do rootfs_cmd rm -f -- "$p"; done
}

mv_rootfs(){
  local repo="$1" src="$2" dst="$3" drel tmp staged
  live_rootfs || { gitbooty "$repo" rootfs mv "$src" "$dst"; return; }
  drel="${dst#/}"; booty_tmp tmp mv
  rootfs_sudo
  staged="$(copy_live_rootfs "$tmp" "$src")"
  BOOTY_TARGET_ROOT="$tmp" gitbooty "$repo" rootfs mv "$staged" "$tmp/$drel"
  rootfs_cmd mkdir -p "$(dirname "$dst")"
  rootfs_cmd mv -- "$src" "$dst"
}

home_to_rootfs(){
  local repo="$1" src="$2" dst="$3" rel tmp f
  rel="$(rootfs_rel "$dst")" || die "rootfs destination '$dst' is outside $(rootfs_target)"
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
      ;&
    apply)
      if [ "${BOOTY_SKIP_HOME:-0}" != 1 ] && has_sources "$repo" home; then
        gitbooty "$repo" home apply
      fi
      if [ "${BOOTY_SKIP_ROOTFS:-0}" != 1 ] && has_sources "$repo" rootfs; then
        apply_rootfs "$repo" apply
      fi
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
        homerootfs) home_to_rootfs "$repo" "$1" "$2"; gitbooty "$repo" home rm "$1" ;;
        rootfshome) copy_from_rootfs "$1" "$2"; gitbooty "$repo" home add "$2"; rm_rootfs "$repo" "$1" ;;
      esac
      ;;
    *) gitbooty "$repo" home "$cmd" "$@" ;;
  esac
}
