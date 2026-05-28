#!/usr/bin/env bats

load test_helper

setup() { setup_booty_secrets; }
teardown() { teardown_tmp; }

secrets() { "$BOOTY_ROOT/bin/booty-secrets" "$@"; }

# Secrets mirror public dotfile behavior but use the secrets checkout only.

@test "booty-secrets uses the configured secrets checkout" {
  fake gpg
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/nesta/.config/app.conf" secrets

  run secrets pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" secrets
  file_eq "$FIXTURE_ROOT/etc/secret.conf" secrets-root
  [ -f "$FIXTURE_STATE/booty/home.paths" ]
  [ -f "$FIXTURE_STATE/booty/system.paths" ]
}

@test "booty-secrets add writes new files to the secrets checkout" {
  fake gpg
  writef "$FIXTURE_HOME" ".private" private

  run secrets add "$FIXTURE_HOME/.private"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_SECRETS/dotfiles/archlinux/rootfs/home/nesta/.private" private
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.private" ]
}

@test "booty-secrets commands require a secrets checkout" {
  rm -rf "$FIXTURE_SECRETS"

  run secrets pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing secrets checkout"* ]]
  [[ "$output" == *"booty sync"* ]]

  run secrets status
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing secrets checkout"* ]]
}

@test "booty-secrets honors explicit BOOTY_HOME" {
  fake gpg
  custom_home="$TEST_ROOT/custom-home"
  secrets_dir="$custom_home/booty-secrets"
  writef "$secrets_dir" "dotfiles/archlinux/rootfs/home/nesta/.private" custom
  git_init "$secrets_dir"

  run env BOOTY_HOME="$custom_home" "$BOOTY_ROOT/bin/booty-secrets" pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.private" custom
}
