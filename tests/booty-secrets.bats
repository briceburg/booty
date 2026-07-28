#!/usr/bin/env bats

load test_helper

setup() { setup_booty_secrets; }
teardown() { teardown_tmp; }

secrets() { "$BOOTY_ROOT/bin/booty-secrets" "$@"; }

# Secrets mirror public dotfile behavior but use the secrets checkout only.

@test "booty-secrets pull applies and lists only secret sources" {
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/nesta/.config/app.conf" secrets

  run secrets pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" secrets
  file_eq "$FIXTURE_ROOT/etc/secret.conf" secrets-root
  [ -f "$FIXTURE_STATE/booty/secrets.system.paths" ]

  run secrets ls
  [ "$status" -eq 0 ]
  [[ "$output" == *".config/app.conf"* ]]
  [[ "$output" == *"/etc/secret.conf"* ]]
  [[ "$output" != *".bashrc"* ]]
  [[ "$output" != *"/etc/example.conf"* ]]
}

@test "booty-secrets warns when checkout has no dotfiles" {
  rm -rf "$FIXTURE_SECRETS/dotfiles"

  run secrets ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: no secrets for archlinux/hartford/nesta"* ]]
  [[ "$output" == *"check BOOTY_SECRETS_URL in ~/.booty/config"* ]]
  [[ "$output" != *".bashrc"* ]]
  [[ "$output" != *"/etc/example.conf"* ]]
}

@test "booty-secrets add stages secrets without reporting public drift" {
  secrets pull >/dev/null
  writef "$FIXTURE_HOME" ".private" private
  secrets add "$FIXTURE_HOME/.private"
  writef "$FIXTURE_HOME" ".bashrc" changed-public

  file_eq "$FIXTURE_SECRETS/dotfiles/archlinux/rootfs/home/nesta/.private" private
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.private" ]

  run secrets status
  [ "$status" -eq 0 ]
  [[ "$output" != *"Live file changes:"* ]]
  [[ "$output" == *"Repo changes:"* ]]
  [[ "$output" == *"A  dotfiles/archlinux/rootfs/home/nesta/.private"* ]]
  [[ "$output" != *".bashrc"* ]]
  [[ "$output" != *"etc/example.conf"* ]]

  run secrets diff
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "public status ignores secrets-owned live changes" {
  writef "$FIXTURE_SECRETS" "dotfiles/archlinux/rootfs/home/nesta/.aws/config" secret
  secrets pull >/dev/null
  writef "$FIXTURE_HOME" ".aws/config" changed-secret

  run "$BOOTY_ROOT/bin/booty" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to commit, managed files clean"* ]]
  [[ "$output" != *".aws/config"* ]]

  run secrets status
  [ "$status" -ne 0 ]
  [[ "$output" == *"modified:   .aws/config"* ]]
}

@test "booty-secrets status handles legacy combined applied state" {
  secrets pull >/dev/null
  rm "$FIXTURE_STATE/booty/secrets.home.paths" "$FIXTURE_STATE/booty/secrets.system.paths"

  run secrets status
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to commit, managed files clean"* ]]
  [[ "$output" != *"Live file changes:"* ]]
}

@test "booty-secrets restore cannot remove a public managed file" {
  secrets pull >/dev/null

  run secrets restore "$FIXTURE_HOME/.bashrc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"did not match any managed files"* ]]
  file_eq "$FIXTURE_HOME/.bashrc" shell
}

@test "booty-secrets restore reveals a public file beneath a deleted secret" {
  secret_source="dotfiles/archlinux/hosts/hartford/rootfs/home/nesta/.config/app.conf"
  writef "$FIXTURE_SECRETS" "$secret_source" secret
  secrets pull >/dev/null
  file_eq "$FIXTURE_HOME/.config/app.conf" secret
  rm "$FIXTURE_SECRETS/$secret_source"

  run secrets status "$FIXTURE_HOME/.config/app.conf"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Live file changes:"* ]]
  [[ "$output" == *"added:      .config/app.conf"* ]]
  [[ "$output" == *'use "booty-secrets restore <file>..."'* ]]

  run secrets restore "$FIXTURE_HOME/.config/app.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" override
}

@test "booty-secrets rm reveals lower secret and public layers" {
  base_source="dotfiles/archlinux/rootfs/home/nesta/.config/app.conf"
  host_source="dotfiles/archlinux/hosts/hartford/rootfs/home/nesta/.config/app.conf"
  writef "$FIXTURE_SECRETS" "$base_source" secret-base
  writef "$FIXTURE_SECRETS" "$host_source" secret-host
  secrets pull >/dev/null
  file_eq "$FIXTURE_HOME/.config/app.conf" secret-host

  run secrets rm "$FIXTURE_HOME/.config/app.conf"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_SECRETS/$host_source" ]
  file_eq "$FIXTURE_HOME/.config/app.conf" secret-base

  run secrets rm "$FIXTURE_HOME/.config/app.conf"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_SECRETS/$base_source" ]
  file_eq "$FIXTURE_HOME/.config/app.conf" override
}

@test "booty-secrets commands require a secrets checkout" {
  rm -rf "$FIXTURE_SECRETS"

  run secrets status
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing secrets checkout"* ]]
  [[ "$output" == *"booty sync"* ]]
}

@test "booty-secrets honors explicit BOOTY_HOME" {
  custom_home="$TEST_ROOT/custom-home"
  secrets_dir="$custom_home/booty-secrets"
  writef "$secrets_dir" "dotfiles/archlinux/rootfs/home/nesta/.private" custom
  git_init "$secrets_dir"

  run env BOOTY_HOME="$custom_home" "$BOOTY_ROOT/bin/booty-secrets" pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.private" custom
}
