#!/usr/bin/env bats

# Exercises the repo-aware wrapper against a fixture shaped like:
#   repo/
#     bin/booty
#     bin/gitbooty
#     profiles/archlinux/
#       users/nesta/home/...
#       hosts/hartford/users/nesta/home/...
#       root/...
#   home/            rendered user tree
#   root/            rendered root-mode tree
#   state/           manifest output

setup() {
  export TEST_ROOT="$(mktemp -d /tmp/booty-test.XXXXXX)"
  export FIXTURE_REPO="$TEST_ROOT/repo"
  export FIXTURE_SECRETS="$TEST_ROOT/secrets"
  export FIXTURE_HOME="$TEST_ROOT/home"
  export FIXTURE_ROOT="$TEST_ROOT/root"
  export FIXTURE_STATE="$TEST_ROOT/state"

  mkdir -p \
    "$FIXTURE_REPO/bin" \
    "$FIXTURE_REPO/profiles/archlinux/users/nesta/home/.config" \
    "$FIXTURE_REPO/profiles/archlinux/hosts/hartford/users/nesta/home/.config" \
    "$FIXTURE_REPO/profiles/archlinux/root/etc" \
    "$FIXTURE_SECRETS/profiles/archlinux/users/nesta/home/.config" \
    "$FIXTURE_HOME" \
    "$FIXTURE_ROOT" \
    "$FIXTURE_STATE"

  cp /work/bin/booty /work/bin/gitbooty "$FIXTURE_REPO/bin/"
  git -C "$FIXTURE_REPO" init -q

  printf '%s\n' base > \
    "$FIXTURE_REPO/profiles/archlinux/users/nesta/home/.config/app.conf"
  printf '%s\n' override > \
    "$FIXTURE_REPO/profiles/archlinux/hosts/hartford/users/nesta/home/.config/app.conf"
  printf '%s\n' shell > \
    "$FIXTURE_REPO/profiles/archlinux/users/nesta/home/.bashrc"
  printf '%s\n' root-base > \
    "$FIXTURE_REPO/profiles/archlinux/root/etc/example.conf"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

booty_env() {
  env \
    HOME="$FIXTURE_HOME" \
    BOOTY_SOURCE_DIR="$FIXTURE_REPO" \
    BOOTY_OS=archlinux \
    BOOTY_HOST=hartford \
    "$@"
}

booty_home() {
  # bats runs as root in CI, so force home mode for the user-scope tests.
  booty_env \
    USER=nesta \
    BOOTY_SCOPE=home \
    XDG_DATA_HOME="$FIXTURE_STATE" \
    "$FIXTURE_REPO/bin/booty" "$@"
}

booty_home_secrets() {
  booty_env \
    USER=nesta \
    BOOTY_SCOPE=home \
    BOOTY_SECRETS_DIR="$FIXTURE_SECRETS" \
    XDG_DATA_HOME="$FIXTURE_STATE" \
    "$FIXTURE_REPO/bin/booty" "$@"
}

booty_root_shell() {
  booty_env \
    USER=root \
    BOOTY_TARGET_ROOT="$FIXTURE_ROOT" \
    BOOTY_SYSTEM_DATA_DIR="$FIXTURE_STATE/system" \
    "$FIXTURE_REPO/bin/booty" "$@"
}

booty_root_sudo() {
  booty_env \
    USER=root \
    SUDO_USER=nesta \
    BOOTY_TARGET_ROOT="$FIXTURE_ROOT" \
    BOOTY_SYSTEM_DATA_DIR="$FIXTURE_STATE/system" \
    "$FIXTURE_REPO/bin/booty" "$@"
}

@test "booty pull applies repo-shaped home layers" {
  run booty_home pull

  [ "$status" -eq 0 ]
  [ "$(cat "$FIXTURE_HOME/.config/app.conf")" = "override" ]
  [ "$(cat "$FIXTURE_HOME/.bashrc")" = "shell" ]
  [ -f "$FIXTURE_STATE/booty/home.manifest.tsv" ]
}

@test "booty status reports clean after pull on repo-shaped tree" {
  booty_home pull >/dev/null

  run booty_home status

  [ "$status" -eq 0 ]
}

@test "booty secrets layers override public home layers" {
  printf '%s\n' secret > \
    "$FIXTURE_SECRETS/profiles/archlinux/users/nesta/home/.config/app.conf"

  run booty_home_secrets pull

  [ "$status" -eq 0 ]
  [ "$(cat "$FIXTURE_HOME/.config/app.conf")" = "secret" ]
}

@test "booty pull applies repo-shaped root files into an overridden root target" {
  run booty_root_shell pull

  [ "$status" -eq 0 ]
  [ "$(cat "$FIXTURE_ROOT/etc/example.conf")" = "root-base" ]
  [ -f "$FIXTURE_STATE/system/root.manifest.tsv" ]
}

@test "booty defaults to root mode in a root shell" {
  booty_root_shell pull >/dev/null

  run booty_root_shell status

  [ "$status" -eq 0 ]
}

@test "booty defaults to root mode under sudo" {
  booty_root_sudo pull >/dev/null

  run booty_root_sudo status

  [ "$status" -eq 0 ]
}
