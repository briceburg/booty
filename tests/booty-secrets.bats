#!/usr/bin/env bats

load test_helper

setup() { setup_booty_secrets; }
teardown() { teardown_tmp; }

secrets() { "$BOOTY_ROOT/bin/booty-secrets" "$@"; }

@test "booty-secrets uses the configured secrets checkout" {
  fake gpg
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/nesta/.config/app.conf" secrets

  run secrets pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" secrets
  file_eq "$FIXTURE_ROOT/etc/secret.conf" secrets-root
  [ -f "$FIXTURE_STATE/booty/secrets-home.manifest.tsv" ]
  [ -f "$FIXTURE_STATE/booty/secrets-rootfs.manifest.tsv" ]
  [ "$(stat -c %a "$BOOTY_HOME/tmp")" = 700 ]
  [ -z "$(find "$BOOTY_HOME/tmp" -mindepth 1 -maxdepth 1 -print -quit)" ]
  [ "$(git -C "$FIXTURE_SECRETS" config --get gcrypt.participants || true)" = "" ]
  [ "$(git -C "$FIXTURE_SECRETS" config --get user.signingkey || true)" = "" ]
}

@test "booty-secrets add writes new files to the secrets checkout" {
  fake gpg
  writef "$FIXTURE_HOME" ".private" private

  run secrets add "$FIXTURE_HOME/.private"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_SECRETS/dotfiles/archlinux/rootfs/home/nesta/.private" private
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.private" ]
}

@test "booty-secrets pull requires a secrets checkout" {
  rm -rf "$FIXTURE_SECRETS"

  run secrets pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing secrets checkout"* ]]
  [[ "$output" == *"booty sync"* ]]
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

@test "booty-secrets help does not clone missing secrets checkout" {
  secrets_remote="$TEST_ROOT/secrets-remote"
  git_init "$secrets_remote"
  rm -rf "$FIXTURE_SECRETS"

  run env BOOTY_SECRETS_URL="$secrets_remote" "$BOOTY_ROOT/bin/booty-secrets" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: booty"* ]]
  [ ! -e "$FIXTURE_SECRETS" ]
}

@test "booty-secrets non-pull commands require a secrets checkout" {
  rm -rf "$FIXTURE_SECRETS"

  run secrets status
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing secrets checkout"* ]]
}

@test "booty-secrets supports root as a dotfile user" {
  fake gpg
  root_home="$FIXTURE_ROOT/root"
  mkdir -p "$root_home"
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/root/.private" root-secret

  run env USER=root BOOTY_USER=root HOME="$root_home" BOOTY_HOME="$BOOTY_HOME" BOOTY_HOME_TARGET_ROOT="$root_home" "$BOOTY_ROOT/bin/booty-secrets" pull
  [ "$status" -eq 0 ]
  file_eq "$root_home/.private" root-secret
}
