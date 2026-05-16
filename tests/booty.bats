#!/usr/bin/env bats

load test_helper

setup() { setup_booty_public; }
teardown() { teardown_tmp; }

booty() { "$BOOTY_ROOT/bin/booty" "$@"; }

@test "booty pull applies repo-shaped home and rootfs files" {
  writef "$FIXTURE_REPO" "dotfiles/archlinux/rootfs/home/foo/.bashrc" wrong-user

  run booty pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" override
  file_eq "$FIXTURE_HOME/.bashrc" shell
  file_eq "$FIXTURE_ROOT/etc/example.conf" root-base
  [ ! -e "$FIXTURE_ROOT/home/foo/.bashrc" ]
  [ -f "$FIXTURE_STATE/booty/home.manifest.tsv" ]
  [ -f "$FIXTURE_STATE/booty/rootfs.manifest.tsv" ]
}

@test "booty derives repo root from BOOTY_HOME" {
  run env BOOTY_HOME="$BOOTY_HOME" "$BOOTY_ROOT/bin/booty" pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.bashrc" shell
}

@test "booty pull prunes files removed from rootfs sources" {
  booty pull >/dev/null
  [ -f "$FIXTURE_ROOT/etc/example.conf" ]

  rm -f "$FIXTURE_REPO/dotfiles/archlinux/rootfs/etc/example.conf"

  run booty pull
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/etc/example.conf" ]
}

@test "booty sync clones public checkout, applies it, and sets up secrets" {
  public_remote="$TEST_ROOT/public-remote"
  secrets_remote="$TEST_ROOT/secrets-remote"
  fixture dotfiles/archlinux "$public_remote/dotfiles/archlinux"
  writef "$secrets_remote" "dotfiles/archlinux/rootfs/home/nesta/.private" secrets-bootstrap
  git -C "$public_remote" init -q
  git_id "$public_remote"
  git_commit_all "$public_remote" "seed public"
  git -C "$secrets_remote" init -q
  git_id "$secrets_remote"
  git_commit_all "$secrets_remote" "seed secrets"
  rm -rf "$FIXTURE_REPO" "$BOOTY_HOME/booty-secrets"
  fake gcrypt
  fake gpg

  run env \
    BOOTY_REPO_URL="file://$public_remote" \
    BOOTY_SECRETS_URL="gcrypt::file://$secrets_remote" \
    "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -eq 0 ]
  [ "$(git -C "$FIXTURE_REPO" remote get-url origin)" = "file://$public_remote" ]
  [ -d "$BOOTY_HOME/booty-secrets/.git" ]
  file_eq "$FIXTURE_HOME/.bashrc" shell
  file_eq "$FIXTURE_HOME/.private" secrets-bootstrap
}

@test "booty sync retargets an existing public checkout remote" {
  old_remote="$TEST_ROOT/old-public"
  new_remote="$TEST_ROOT/new-public"
  fixture dotfiles/archlinux "$old_remote/dotfiles/archlinux"
  git -C "$old_remote" init -q
  git_id "$old_remote"
  git_commit_all "$old_remote" "seed old public"
  rm -rf "$FIXTURE_REPO"
  git clone -q "$old_remote" "$FIXTURE_REPO"
  git clone -q "$old_remote" "$new_remote"
  git_id "$new_remote"
  writef "$new_remote" "dotfiles/archlinux/rootfs/home/nesta/.bashrc" retargeted
  git_commit_all "$new_remote" "retarget public"
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL="file://$new_remote" "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -eq 0 ]
  [ "$(git -C "$FIXTURE_REPO" remote get-url origin)" = "file://$new_remote" ]
  file_eq "$FIXTURE_HOME/.bashrc" retargeted
}

@test "booty sync rejects a public checkout with no dotfiles" {
  public_remote="$TEST_ROOT/minimal-public"
  mkdir -p "$public_remote"
  writef "$public_remote" README.md minimal
  git -C "$public_remote" init -q
  git_id "$public_remote"
  git_commit_all "$public_remote" "minimal public"
  rm -rf "$FIXTURE_REPO"
  git clone -q "$public_remote" "$FIXTURE_REPO"
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL="file://$public_remote" BOOTY_SECRETS_URL= "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"public checkout has no dotfiles"* ]]
  [[ "$output" == *"README.md#layout"* ]]
  [ "$(git -C "$FIXTURE_REPO" remote get-url origin)" = "file://$public_remote" ]
}

@test "booty sync skips secrets checkout when gpg is unconfigured" {
  rm -rf "$BOOTY_HOME/booty-secrets"
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL= BOOTY_SECRETS_URL="gcrypt::file://$TEST_ROOT/secrets-remote" "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping secrets checkout"* ]]
  [ ! -e "$BOOTY_HOME/booty-secrets" ]
}

@test "booty sync rejects non-gcrypt secrets repo urls" {
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL= BOOTY_SECRETS_URL="$TEST_ROOT/plain-remote" "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -ne 0 ]
  [[ "$output" == *"BOOTY_SECRETS_URL must use gcrypt::"* ]]
}

@test "booty bootstrap points to the unambiguous commands" {
  run booty bootstrap
  [ "$status" -ne 0 ]
  [[ "$output" == *"use 'booty sync'"* ]]
  [[ "$output" == *"booty-bootstrap"* ]]
}

@test "booty help shows booty usage" {
  run booty help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: booty"* ]]
}

@test "booty config passes through to git config" {
  git -C "$FIXTURE_REPO" config user.name "Test User"

  run booty config user.name
  [ "$status" -eq 0 ]
  [ "$output" = "Test User" ]
}

@test "booty status reports clean after pull on repo-shaped tree" {
  booty pull >/dev/null

  run booty status
  [ "$status" -eq 0 ]

  run booty
  [ "$status" -eq 0 ]
}

@test "booty status reports system drift by default" {
  booty pull >/dev/null
  writef "$FIXTURE_ROOT" "etc/example.conf" changed

  run booty status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'M\tetc/example.conf'* ]]
}

@test "booty add routes relative and absolute home paths to dotfiles home" {
  writef "$FIXTURE_HOME" "relative.conf" relative
  writef "$FIXTURE_HOME" "absolute.conf" absolute

  ( cd "$FIXTURE_HOME" && booty add relative.conf )
  run booty add "$FIXTURE_HOME/absolute.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/relative.conf" relative
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/absolute.conf" absolute
}

@test "booty add routes absolute system paths to host system dotfiles" {
  writef "$FIXTURE_ROOT" "etc/routed.conf" routed

  run booty add "$FIXTURE_ROOT/etc/routed.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/etc/routed.conf" routed
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/etc/routed.conf" ]
}

@test "booty refuses another user's home path" {
  run booty add /home/foo/.bashrc
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to manage another user's home"* ]]
}

@test "booty add accepts mixed user and system paths" {
  writef "$FIXTURE_HOME" ".gitconfig" user-gitconfig
  writef "$FIXTURE_ROOT" "root/.bashrc" root-bashrc

  run booty add "$FIXTURE_HOME/.gitconfig" "$FIXTURE_ROOT/root/.bashrc"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.gitconfig" user-gitconfig
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/root/.bashrc" root-bashrc
}

@test "booty mv can move tracked files between user and system paths" {
  writef "$FIXTURE_HOME" ".gitconfig" moved-to-system
  booty add "$FIXTURE_HOME/.gitconfig"

  run booty mv "$FIXTURE_HOME/.gitconfig" "$FIXTURE_ROOT/root/.bashrc"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/.gitconfig" ]
  file_eq "$FIXTURE_ROOT/root/.bashrc" moved-to-system
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.gitconfig" ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/root/.bashrc" moved-to-system

  run booty mv "$FIXTURE_ROOT/root/.bashrc" "$FIXTURE_HOME/.root-bashrc"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/root/.bashrc" ]
  file_eq "$FIXTURE_HOME/.root-bashrc" moved-to-system
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/root/.bashrc" ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.root-bashrc" moved-to-system
}

@test "booty refuses direct root execution" {
  run env USER=root "$BOOTY_ROOT/bin/booty" pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"run booty as your regular user"* ]]
}

@test "booty requires checkout under BOOTY_HOME" {
  rm -rf "$FIXTURE_REPO"

  run booty status
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing public checkout"* ]]
}
