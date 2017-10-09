#!/usr/bin/env shell-helpers

# defaults
readonly BOOTY_ROOT="$(cd "$(dirname ${BASH_SOURCE[0]})/../" ; pwd -P )"
readonly GPG_PUBKEY="${GPG_PUBKEY:-2E543DCEBC9A6B971510A9A0D0532DD2254E4188}"

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

ensure/dir "${BOOTY_TMPDIR:=$BOOTY_ROOT/tmp}"
ensure/dir "${BOOTY_GITDIR:=$HOME/git}"
