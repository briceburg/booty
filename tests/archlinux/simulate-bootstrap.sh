#!/usr/bin/env bash
set -eo pipefail

pass()   { echo "  ok: $1" >&2; }
fail()   { echo "  FAIL: $1" >&2; ((FAILURES++)) || true; }
check()  {
  local d="$1"; shift
  local out
  if out=$("$@" 2>&1); then
    pass "$d"
  else
    fail "$d: $out"
    [ "${DEBUG:-0}" = 1 ] || echo "    (re-run with DEBUG=1 for a full trace)" >&2
  fi
}
finish() { ((FAILURES == 0)) || { echo "==> $FAILURES assertion(s) failed" >&2; exit 1; }; echo "==> all $1 passed" >&2; }
ci_booty() { sudo -H -u ci env BOOTY_HOME=/home/ci/.booty BOOTY_HOST=ci BOOTY_AGE_IDENTITY=/tmp/ci-age-key.txt /home/ci/.booty/booty/bin/booty "$@"; }
has_content() { [ "$(cat "$1")" = "$2" ]; }
contains_text() { grep -qF "$2" "$1"; }
lacks_text() { ! grep -qF "$2" "$1"; }
owned_by() { [ "$(stat -c '%U:%G' "$1")" = "$2" ]; }
git_id() { git -C "$1" config user.email ci@localhost; git -C "$1" config user.name CI; }
copy_tree() { mkdir -p "$2"; cp -r "$1"/. "$2"/; }
build_sim_repo() {
  local repo="$1"
  mkdir -p "$repo"
  cp -r /work/bin /work/lib /work/install "$repo/"
  copy_tree /work/bootstrap "$repo/bootstrap"
  copy_tree /work/tests/fixtures/bootstrap "$repo/bootstrap"
  copy_tree /work/tests/fixtures/dotfiles/archlinux "$repo/dotfiles/archlinux"
  git -C "$repo" init -q
  git_id "$repo"
  git -C "$repo" add .
  git -C "$repo" commit -qm "ci simulation repo"
  chmod -R a+rX "$repo"
}
FAILURES=0

pacman -Sy --noconfirm --needed git sudo >/dev/null 2>&1

sim_repo=/tmp/sim-booty
build_sim_repo "$sim_repo"
env BOOTSTRAP_USER=ci BOOTY_HOST=ci BOOTY_REPO_URL="file://$sim_repo" BOOTSTRAP_SKIP_REFLECTOR=1 \
  bash /work/install

check "bootstrap created ci user" id -u ci
check "booty symlink is absent" test ! -e /usr/local/bin/booty
check "booty resolves from login PATH" sudo -H -u ci bash -lc 'command -v booty | grep -q "^/home/ci/.booty/booty/bin/booty$"'
check "booty status exits 0 as ci user" sudo -H -u ci bash -lc 'booty status'
check "home dotfile applied" test -f /home/ci/.bashrc
check "home dotfile owned by ci" owned_by /home/ci/.bashrc ci:ci
check "user helper pulled executable" sudo -H -u ci test -x /home/ci/bin/create-secrets-remote
check "system dotfile applied" test -f /etc/ci-test.conf
check "system dotfile owned by root" owned_by /etc/ci-test.conf root:root
check "system helper pulled executable" /usr/local/bin/ci-system-probe
check "system helper owned by root" owned_by /usr/local/bin/ci-system-probe root:root
check "AUR checkout cloned as ci" test -f /home/ci/git/AUR/git-remote-gcrypt/PKGBUILD
check "AUR checkout owned by ci" owned_by /home/ci/git/AUR/git-remote-gcrypt ci:ci
check "AUR package installed by bootstrap" command -v git-remote-gcrypt
check "runtime config writes canonical repo url" contains_text /home/ci/.booty/config "BOOTY_REPO_URL="
check "runtime config does not leak bootstrap vars" lacks_text /home/ci/.booty/config "BOOTSTRAP_"
check "bootstrap did not create legacy command sudoers" test ! -e /etc/sudoers.d/user-ci
check "bootstrap did not create AUR sudoers" test ! -e /etc/sudoers.d/booty-bootstrap-aur-ci

finish "bootstrap assertions"

echo "==> Live rootfs mutation" >&2

live_src=/etc/booty-live-add.conf
live_dst=/etc/booty-live-moved.conf
repo_src=/home/ci/.booty/booty/dotfiles/archlinux/hosts/ci/rootfs/etc/booty-live-add.conf
repo_dst=/home/ci/.booty/booty/dotfiles/archlinux/hosts/ci/rootfs/etc/booty-live-moved.conf

printf 'live-rootfs-test\n' > "$live_src"

check "booty add captures live rootfs file" ci_booty add "$live_src"
check "rootfs add writes host source" has_content "$repo_src" live-rootfs-test
check "rootfs add source owned by ci" owned_by "$repo_src" ci:ci
check "rootfs add leaves live target owned by root" owned_by "$live_src" root:root

check "booty mv moves live rootfs file" ci_booty mv "$live_src" "$live_dst"
check "rootfs mv moves live target" has_content "$live_dst" live-rootfs-test
check "rootfs mv removes old source" test ! -e "$repo_src"
check "rootfs mv moves host source" has_content "$repo_dst" live-rootfs-test

check "booty rm removes live rootfs file" ci_booty rm "$live_dst"
check "rootfs rm removes live target" test ! -e "$live_dst"
check "rootfs rm removes host source" test ! -e "$repo_dst"
check "booty status clean after live rootfs mutation" ci_booty status

finish "live rootfs mutation assertions"

echo "==> GPG round-trip" >&2

sudo -H -u ci gpg --batch --gen-key /work/tests/fixtures/gpg/ci-batch.txt >/dev/null 2>&1

age-keygen -o /tmp/ci-age-key.txt 2>/dev/null
chmod 644 /tmp/ci-age-key.txt

ci_booty gpg export /home/ci/.booty/gnupg.tar.gz.age

check "GPG archive created" test -f /home/ci/.booty/gnupg.tar.gz.age

sudo -H -u ci rm -rf /home/ci/.gnupg

ci_booty gpg import /home/ci/.booty/gnupg.tar.gz.age

check "GPG key restored from archive" \
  sudo -H -u ci gpg --list-secret-keys ci@localhost

finish "GPG assertions"

echo "==> Secrets / gcrypt round-trip" >&2

CI_GPG_KEY=$(sudo -H -u ci gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr/{print $10;exit}')

printf '%s:6:\n' "$CI_GPG_KEY" | sudo -H -u ci gpg --import-ownertrust >/dev/null 2>&1

sudo -H -u ci /home/ci/bin/create-secrets-remote "$CI_GPG_KEY"

ci_booty sync

check "secrets checkout cloned" test -d /home/ci/.booty/booty-secrets/.git
check "secrets dotfile applied" test -f /home/ci/.ci-secrets

finish "secrets assertions"
