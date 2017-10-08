#!/usr/bin/env shell-helpers

# defaults
readonly BOOTY_ROOT="$(cd "$(dirname ${BASH_SOURCE[0]})/../" ; pwd -P )"
BOOTY_TMPDIR="${BOOTY_TMPDIR:-$BOOTY_ROOT/tmp}"
BOOTY_DISTRO="${BOOTY_DIST:-archlinux}"

[ -d "$BOOTY_TMPDIR" ] || mkdir -p "$BOOTY_TMPDIR" || die "TMPDIR: $BOOTY_TMPDIR must be a directory"
[ -w "$BOOTY_TMPDIR" ] || die "TMPDIR: $BOOTY_TMPDIR is not writable"

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
