#!/usr/bin/env bats

load test_helper

setup() {
  setup_tmp gpg-test
  export HOME="$TEST_ROOT/home" BOOTY_HOME="$TEST_ROOT/.booty"
  mkdir -p "$HOME"
}
teardown() {
  for home in "$TEST_ROOT/source-gnupg" "$TEST_ROOT/restored-gnupg/.gnupg"; do
    [ ! -d "$home" ] || GNUPGHOME="$home" gpgconf --kill all >/dev/null 2>&1 || true
  done
  teardown_tmp
}

@test "booty gpg exports and imports gpg home through age" {
  archive="$TEST_ROOT/gnupg.tar.gz.age"
  restored="$TEST_ROOT/restored-gnupg"

  export GNUPGHOME="$TEST_ROOT/source-gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key test@example.invalid default default never

  run env USER=nesta ARCHIVE="$archive" expect -c '
    set timeout 10
    spawn $env(BOOTY_ROOT)/bin/booty gpg export $env(ARCHIVE)
    expect -re "(?i)passphrase"
    send "test-passphrase\r"
    expect -re "(?i)passphrase"
    send "test-passphrase\r"
    expect eof
    catch wait result
    exit [lindex $result 3]
  '
  [ "$status" -eq 0 ]
  [ -s "$archive" ]
  [ "$(stat -c %a "$BOOTY_HOME/tmp")" = 700 ]
  [ -z "$(find "$BOOTY_HOME/tmp" -mindepth 1 -maxdepth 1 -print -quit)" ]
  GNUPGHOME="$GNUPGHOME" gpgconf --kill all
  rm -rf "$GNUPGHOME"
  mkdir -p "$restored"

  run env USER=nesta GNUPGHOME="$restored/.gnupg" ARCHIVE="$archive" expect -c '
    set timeout 10
    spawn $env(BOOTY_ROOT)/bin/booty gpg import $env(ARCHIVE)
    expect -re "(?i)passphrase"
    send "test-passphrase\r"
    expect eof
    catch wait result
    exit [lindex $result 3]
  '
  [ "$status" -eq 0 ]
  GNUPGHOME="$restored/.gnupg" gpg --list-secret-keys --with-colons | grep -q '^sec'

  run env USER=nesta GNUPGHOME="$restored/.gnupg" "$BOOTY_ROOT/bin/booty" gpg import "$archive"
  [ "$status" -eq 0 ]
}
