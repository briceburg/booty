#!/usr/bin/env shell-helpers

# defaults
readonly BOOTY_ROOT="$(cd "$(dirname ${BASH_SOURCE[0]})/../" ; pwd -P )"
ensure/dir "${BOOTY_TMPDIR:=$BOOTY_ROOT/tmp}"
ensure/dir "${BOOTY_GITDIR:=$HOME/git}"

run(){
  local f="$1"
  local name="${2:-$f}"
  p/header "$name"
  if $f; then
    p/success "completed \e[1m$name\e[21m"
  else
    p/error "failed \e[1m$name\e[21m"
  fi
}

ensure/dir(){
  [ -d "$1" ] || mkdir -p "$1" || die "failed to create $1"
  [ -w "$1" ] || die "$1 is not writable"
}
