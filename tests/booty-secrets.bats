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
  [ -f "$FIXTURE_STATE/booty/secrets-home.manifest.tsv" ]
  [ -f "$FIXTURE_STATE/booty/secrets-rootfs.manifest.tsv" ]
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

# User selection follows the same contract as public dotfiles.

@test "booty-secrets supports root as a dotfile user" {
  fake gpg
  root_home="$FIXTURE_ROOT/root"
  mkdir -p "$root_home"
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/root/.private" root-secret

  run env USER=root BOOTY_USER=root HOME="$root_home" BOOTY_HOME="$BOOTY_HOME" "$BOOTY_ROOT/bin/booty-secrets" pull
  [ "$status" -eq 0 ]
  file_eq "$root_home/.private" root-secret
}
