#!/usr/bin/env bash
set -eo pipefail

pass()   { echo "  ok: $1" >&2; }
fail()   { echo "  FAIL: $1" >&2; ((FAILURES++)) || true; }
check()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi; }
finish() { ((FAILURES == 0)) || { echo "==> $FAILURES assertion(s) failed" >&2; exit 1; }; echo "==> all $1 passed" >&2; }
ci_booty() { sudo -H -u ci env BOOTY_HOME=/home/ci/.booty BOOTY_AGE_IDENTITY=/tmp/ci-age-key.txt /usr/local/bin/booty "$@"; }
FAILURES=0

# Sync package DB and install git. This mirrors the first actions on a fresh
# Arch system before running the install one-liner.
pacman -Sy --noconfirm --needed git >/dev/null 2>&1

# Pre-seed bootstrap_common_config so booty-bootstrap is non-interactive.
mkdir -p /etc/booty
printf 'ci\n' > /etc/booty/user

# Build a merged bootstrap dir: real 00-config.sh + configs, stub 10-install.sh.
mkdir -p /tmp/ci-bootstrap
ln -s /work/bootstrap/archlinux/00-config.sh /tmp/ci-bootstrap/00-config.sh
ln -s /work/bootstrap/archlinux/config /tmp/ci-bootstrap/config
[ -d /work/bootstrap/archlinux/users ] && ln -s /work/bootstrap/archlinux/users /tmp/ci-bootstrap/users || true
[ -d /work/bootstrap/archlinux/hosts ] && ln -s /work/bootstrap/archlinux/hosts /tmp/ci-bootstrap/hosts || true
cp /work/tests/archlinux/fixtures/10-install.sh /tmp/ci-bootstrap/10-install.sh

# Use BOOTY_HOME=/tmp/booty-bootstrap so the initial clone lands in a
# world-accessible path. The 10-install fixture switches BOOTY_HOME to
# /home/ci/.booty for the user checkout.
BOOTY_HOME=/tmp/booty-bootstrap BOOTY_HOST=ci BOOTSTRAP_ROOT=/tmp/ci-bootstrap BOOTY_REPO_URL=file:///work \
  bash /work/install

check "booty symlink exists" test -L /usr/local/bin/booty
check "booty symlink points to ci home" bash -c '[[ "$(readlink /usr/local/bin/booty)" == /home/ci/* ]]'
check "booty status exits 0 as ci user" sudo -H -u ci /usr/local/bin/booty status
check "home dotfile applied" test -f /home/ci/.bashrc
check "system dotfile applied" test -f /etc/ci-test.conf

finish "bootstrap assertions"

echo "==> GPG round-trip" >&2

pacman -S --noconfirm --needed age gnupg >/dev/null 2>&1

sudo -H -u ci gpg --batch --gen-key <<'GPGEOF' >/dev/null 2>&1
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: CI Test
Name-Email: ci@localhost
Expire-Date: 0
GPGEOF

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

pacman -S --noconfirm --needed git-remote-gcrypt >/dev/null 2>&1

CI_GPG_KEY=$(sudo -H -u ci gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^fpr/{print $10;exit}')

printf '%s:6:\n' "$CI_GPG_KEY" | sudo -H -u ci gpg --import-ownertrust >/dev/null 2>&1

sudo -H -u ci bash -s <<INNEREOF
set -eo pipefail
tmp=\$(mktemp -d)
mkdir -p "\$tmp/dotfiles/archlinux/rootfs/home/ci"
echo "ci-secrets-test" > "\$tmp/dotfiles/archlinux/rootfs/home/ci/.ci-secrets"
git -C "\$tmp" init -q
git -C "\$tmp" config user.email "ci@localhost"
git -C "\$tmp" config user.name "CI"
git -C "\$tmp" config gcrypt.participants "$CI_GPG_KEY"
git -C "\$tmp" add .
git -C "\$tmp" commit -q -m "ci secrets"
git -C "\$tmp" remote add origin "gcrypt::file:///tmp/ci-secrets-remote"
git -C "\$tmp" push -q origin HEAD:master
rm -rf "\$tmp"
INNEREOF

printf 'BOOTY_SECRETS_URL=${BOOTY_SECRETS_URL:-gcrypt::file:///tmp/ci-secrets-remote}\n' \
  >> /home/ci/.booty/config

sudo -H -u ci env \
  BOOTY_HOME=/home/ci/.booty \
  /usr/local/bin/booty setup

check "secrets checkout cloned" test -d /home/ci/.booty/booty-secrets/.git
check "secrets dotfile applied" test -f /home/ci/.ci-secrets

finish "secrets assertions"
