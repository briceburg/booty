#!/usr/bin/env bats

load test_helper

setup() { setup_booty_public; }
teardown() { teardown_tmp; }

booty() { "$BOOTY_ROOT/bin/booty" "$@"; }

profile_path() {
  env -i HOME="$FIXTURE_HOME" PATH="$1" bash -c ". '$FIXTURE_ROOT/etc/profile.d/booty.sh'; printf '%s' \"\$PATH\""
}

seed_public_remote() {
  fixture dotfiles/archlinux "$1/dotfiles/archlinux"
  git_init "$1"
  git_commit_all "$1" "${2:-seed public}"
}

sync_secrets_url() {
  : > "$BOOTY_HOME/config"
  fake gcrypt
  fake gpg
  run env BOOTY_REPO_URL= BOOTY_SECRETS_URL="$1" "$BOOTY_ROOT/bin/booty" sync
}

assert_secrets_hint() {
  has_output "check BOOTY_SECRETS_URL in ~/.booty/config"
}

# Apply from an existing checkout.

@test "booty pull applies repo-shaped home and rootfs files" {
  writef "$FIXTURE_REPO" "dotfiles/archlinux/rootfs/home/foo/.bashrc" wrong-user

  run booty pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.config/app.conf" override
  file_eq "$FIXTURE_HOME/.bashrc" shell
  file_eq "$FIXTURE_ROOT/etc/example.conf" root-base
  [ ! -e "$FIXTURE_ROOT/home/foo/.bashrc" ]
  [ -f "$FIXTURE_STATE/booty/home.paths" ]
  [ -f "$FIXTURE_STATE/booty/system.paths" ]

  run booty ls
  [ "$status" -eq 0 ]
  has_output "$FIXTURE_HOME/.bashrc" "$FIXTURE_ROOT/etc/example.conf"
}

@test "booty applies profile path for checkout commands" {
  booty pull >/dev/null
  mkdir -p "$FIXTURE_REPO/bin"

  run profile_path /bin:/usr/bin
  [ "$status" -eq 0 ]
  [ "$output" = "$FIXTURE_REPO/bin:/bin:/usr/bin" ]

  run profile_path "$FIXTURE_REPO/bin:/bin:/usr/bin"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIXTURE_REPO/bin:/bin:/usr/bin" ]
}

@test "booty restore restores selected managed pathspecs" {
  booty pull >/dev/null
  writef "$FIXTURE_HOME" ".bashrc" changed-home
  writef "$FIXTURE_ROOT" "etc/example.conf" changed-root

  run booty restore "$FIXTURE_ROOT/etc/*.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_ROOT/etc/example.conf" root-base
  file_eq "$FIXTURE_HOME/.bashrc" changed-home

  run booty restore "$FIXTURE_HOME/.bashrc"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.bashrc" shell

  rm -rf "$FIXTURE_REPO/dotfiles/archlinux/rootfs" "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs"

  run booty restore "$FIXTURE_ROOT/etc/example.conf"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/etc/example.conf" ]
  [ -e "$FIXTURE_HOME/.bashrc" ]

  run booty restore "$FIXTURE_HOME/.bashrc"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/.bashrc" ]
}

# Sync manages deterministic checkouts and optional secrets.

@test "booty sync clones public checkout, applies it, and sets up secrets" {
  public_remote="$TEST_ROOT/public-remote"
  secrets_remote="$TEST_ROOT/secrets-remote"
  seed_public_remote "$public_remote"
  writef "$secrets_remote" "dotfiles/archlinux/rootfs/home/nesta/.private" secrets-bootstrap
  git_init "$secrets_remote"
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

@test "booty sync and pull refuse to overwrite live changes unless forced" {
  booty pull >/dev/null
  writef "$FIXTURE_HOME" ".bashrc" unsaved
  : > "$BOOTY_HOME/config"

  run booty sync
  [ "$status" -ne 0 ]
  has_output "refusing to overwrite live changes" "modified:  ~/.bashrc" "booty sync --force"
  file_eq "$FIXTURE_HOME/.bashrc" unsaved

  run booty pull
  [ "$status" -ne 0 ]
  has_output "booty pull --force"
  file_eq "$FIXTURE_HOME/.bashrc" unsaved

  run booty sync --force
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_HOME/.bashrc" shell
}

@test "booty sync retargets an existing public checkout remote" {
  old_remote="$TEST_ROOT/old-public"
  new_remote="$TEST_ROOT/new-public"
  seed_public_remote "$old_remote" "seed old public"
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
  writef "$public_remote" README.md minimal
  git_init "$public_remote"
  git_commit_all "$public_remote" "minimal public"
  rm -rf "$FIXTURE_REPO"
  git clone -q "$public_remote" "$FIXTURE_REPO"
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL="file://$public_remote" BOOTY_SECRETS_URL= "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -ne 0 ]
  has_output "public checkout has no dotfiles" "README.md#dotfiles-repository-layout"
}

@test "booty sync skips secrets checkout when gpg is unconfigured" {
  rm -rf "$BOOTY_HOME/booty-secrets"
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL= BOOTY_SECRETS_URL="gcrypt::file://$TEST_ROOT/secrets-remote" "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -eq 0 ]
  has_output "skipping secrets checkout"
  assert_secrets_hint
  [ ! -e "$BOOTY_HOME/booty-secrets" ]
}

@test "booty sync warns when secrets checkout has no dotfiles" {
  secrets_remote="$TEST_ROOT/empty-secrets"
  writef "$secrets_remote" README.md empty
  git_init "$secrets_remote"
  git_commit_all "$secrets_remote" "empty secrets"
  rm -rf "$BOOTY_HOME/booty-secrets"

  sync_secrets_url "gcrypt::file://$secrets_remote"
  [ "$status" -eq 0 ]
  has_output "WARNING: no secrets for archlinux/hartford/nesta"
  assert_secrets_hint
}

@test "booty sync warns and continues when secrets clone fails" {
  rm -rf "$BOOTY_HOME/booty-secrets"

  sync_secrets_url "gcrypt::file://$TEST_ROOT/missing-secrets"
  [ "$status" -eq 0 ]
  has_output "WARNING: could not clone secrets checkout"
  assert_secrets_hint
  file_eq "$FIXTURE_HOME/.bashrc" shell
}

@test "booty sync warns and uses existing secrets when update fails" {
  FIXTURE_SECRETS="$BOOTY_HOME/booty-secrets"
  fixture dotfiles/secrets/archlinux "$FIXTURE_SECRETS/dotfiles/archlinux"
  git_init "$FIXTURE_SECRETS"
  git -C "$FIXTURE_SECRETS" remote add origin "$TEST_ROOT/missing-secrets"

  sync_secrets_url "gcrypt::file://$TEST_ROOT/missing-secrets"
  [ "$status" -eq 0 ]
  has_output "WARNING: could not update secrets checkout; using existing copy"
  assert_secrets_hint
  file_eq "$FIXTURE_ROOT/etc/secret.conf" secrets-root
}

@test "booty sync gives one warning when empty secrets cannot update" {
  FIXTURE_SECRETS="$BOOTY_HOME/booty-secrets"
  writef "$FIXTURE_SECRETS" README.md empty
  git_init "$FIXTURE_SECRETS"
  git -C "$FIXTURE_SECRETS" remote add origin "$TEST_ROOT/missing-secrets"

  sync_secrets_url "gcrypt::file://$TEST_ROOT/missing-secrets"
  [ "$status" -eq 0 ]
  has_output "WARNING: secrets checkout unavailable; using public dotfiles only"
  assert_secrets_hint
  lacks_output "WARNING: no secrets for archlinux/hartford/nesta"
  file_eq "$FIXTURE_HOME/.bashrc" shell
}

@test "booty sync rejects non-gcrypt secrets repo urls" {
  : > "$BOOTY_HOME/config"

  run env BOOTY_REPO_URL= BOOTY_SECRETS_URL="$TEST_ROOT/plain-remote" "$BOOTY_ROOT/bin/booty" sync
  [ "$status" -ne 0 ]
  has_output "BOOTY_SECRETS_URL must use gcrypt::" "~/.booty/config"
}

# Git-facing commands operate on rendered dotfiles, not arbitrary worktrees.

@test "booty config passes through to git config" {
  git -C "$FIXTURE_REPO" config user.name "Test User"

  run booty config user.name
  [ "$status" -eq 0 ]
  [ "$output" = "Test User" ]
}

@test "booty status reports system drift by default" {
  booty pull >/dev/null
  writef "$FIXTURE_HOME" ".bashrc" changed-home
  writef "$FIXTURE_ROOT" "etc/example.conf" changed

  run booty status "$FIXTURE_ROOT/etc"
  [ "$status" -ne 0 ]
  has_output "Live file changes:" "modified:   etc/example.conf"
  lacks_output ".bashrc"

  run booty diff "$FIXTURE_ROOT/etc"
  [ "$status" -eq 0 ]
  has_output "diff --git booty/etc/example.conf target/etc/example.conf" "+changed"
  lacks_output "changed-home"

  rm "$FIXTURE_ROOT/etc/example.conf"
  mkdir "$FIXTURE_ROOT/etc/example.conf"
  run booty status
  [ "$status" -ne 0 ]
  has_output "modified:   etc/example.conf"
}

@test "booty commit writes target changes to the checkout" {
  booty pull >/dev/null
  writef "$FIXTURE_HOME" ".bashrc" committed
  writef "$FIXTURE_ROOT" "etc/example.conf" committed-root

  run booty commit -am "write target changes"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.bashrc" committed
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/etc/example.conf" committed-root
  [[ "$(git -C "$FIXTURE_REPO" log --oneline -1)" == *"write target changes"* ]]
}

# Path routing decides which dotfiles tree receives each source path.

@test "booty add routes relative, absolute, directory, and globbed home paths" {
  writef "$FIXTURE_HOME" "relative.conf" relative
  writef "$FIXTURE_HOME" "absolute.conf" absolute
  writef "$FIXTURE_HOME" ".config/new/one.conf" one
  writef "$FIXTURE_HOME" ".config/new/two.txt" two
  writef "$FIXTURE_HOME" ".config/glob/three.conf" three
  writef "$FIXTURE_HOME" ".config/glob/ignored.txt" ignored

  ( cd "$FIXTURE_HOME" && booty add relative.conf )
  run booty add "$FIXTURE_HOME/absolute.conf" "$FIXTURE_HOME/.config/new" "$FIXTURE_HOME/.config/glob/*.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/relative.conf" relative
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/absolute.conf" absolute
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/new/one.conf" one
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/new/two.txt" two
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/glob/three.conf" three
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/glob/ignored.txt" ]

  rm -r "$FIXTURE_HOME/.config/new"
  run booty add "$FIXTURE_HOME/.config/new"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/new/one.conf" ]
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/new/two.txt" ]

  run booty rm "$FIXTURE_HOME/.config/glob"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/.config/glob/three.conf" ]
  [ -e "$FIXTURE_HOME/.config/glob/ignored.txt" ]
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/.config/glob/three.conf" ]
}

@test "booty add routes absolute system paths to host system dotfiles" {
  writef "$FIXTURE_ROOT" "etc/routed.conf" routed

  run booty add "$FIXTURE_ROOT/etc/routed.conf"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/etc/routed.conf" routed
  [ ! -e "$FIXTURE_REPO/dotfiles/archlinux/rootfs/home/nesta/etc/routed.conf" ]
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

@test "booty mv can move rootfs-only files" {
  writef "$FIXTURE_ROOT" "etc/rootfs-source.conf" rootfs-moved
  booty add "$FIXTURE_ROOT/etc/rootfs-source.conf"

  run booty mv "$FIXTURE_ROOT/etc/rootfs-source.conf" "$FIXTURE_ROOT/etc/rootfs-dest.conf"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_ROOT/etc/rootfs-source.conf" ]
  file_eq "$FIXTURE_ROOT/etc/rootfs-dest.conf" rootfs-moved
  file_eq "$FIXTURE_REPO/dotfiles/archlinux/hosts/hartford/rootfs/etc/rootfs-dest.conf" rootfs-moved
}

# User boundaries and unsupported commands fail before mutating state.

@test "booty treats /root as system dotfiles" {
  root_home="$FIXTURE_ROOT/root"
  mkdir -p "$root_home"
  writef "$FIXTURE_REPO" "dotfiles/archlinux/rootfs/root/.bashrc" root-shell

  run env USER=root BOOTY_USER=root HOME="$root_home" BOOTY_HOME="$BOOTY_HOME" "$BOOTY_ROOT/bin/booty" pull
  [ "$status" -eq 0 ]
  file_eq "$root_home/.bashrc" root-shell
}

@test "booty refuses another user's home path" {
  run booty add /home/foo/.bashrc
  [ "$status" -ne 0 ]
  has_output "refusing to manage another user's home"
}

@test "booty rejects simulated rootfs paths outside the target" {
  writef "$FIXTURE_HOME" "to-rootfs.conf" home-to-rootfs
  writef "$TEST_ROOT" "outside-rootfs.conf" outside-rootfs

  run booty add "$FIXTURE_ROOT"
  [ "$status" -ne 0 ]
  has_output "target root"

  run booty mv "$FIXTURE_HOME/to-rootfs.conf" "$FIXTURE_ROOT/../outside.conf"
  [ "$status" -ne 0 ]
  has_output "outside $FIXTURE_ROOT"
  file_eq "$FIXTURE_HOME/to-rootfs.conf" home-to-rootfs

  run booty mv "$TEST_ROOT/outside-rootfs.conf" "$FIXTURE_HOME/from-rootfs.conf"
  [ "$status" -ne 0 ]
  has_output "outside $FIXTURE_ROOT"
  [ ! -e "$FIXTURE_HOME/from-rootfs.conf" ]
}

@test "booty requires checkout under BOOTY_HOME" {
  rm -rf "$FIXTURE_REPO"

  run booty status
  [ "$status" -ne 0 ]
  has_output "missing public checkout"
}

@test "booty rejects unsupported commands" {
  run booty checkout -b risky
  [ "$status" -ne 0 ]
  has_output "unsupported command 'checkout'"
}
