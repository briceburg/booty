#!/usr/bin/env bats

load test_helper

setup() { setup_tmp booty-install-test; }
teardown() { teardown_tmp; }

setup_install_remote() {
  remote="$TEST_ROOT/remote"
  home="$TEST_ROOT/home"
  mkdir -p "$remote/bin" "$home"
  xwritef "$remote/bin" booty-bootstrap '#!/usr/bin/env bash' "$1"
  git_init "$remote"
}

@test "install clones checkout and runs checkout-local bootstrap" {
  setup_install_remote 'echo "BOOTY_HOME=$BOOTY_HOME" > "$INSTALL_MARKER"'
  git_commit_all "$remote" seed

  run env HOME="$home" BOOTY_REPO_URL="file://$remote" INSTALL_MARKER="$TEST_ROOT/marker" "$TEST_REPO/install"
  [ "$status" -eq 0 ]
  [ -d "$home/.booty/booty/.git" ]
  [ "$(cat "$TEST_ROOT/marker")" = "BOOTY_HOME=$home/.booty" ]
}

@test "install updates existing checkout before bootstrap" {
  setup_install_remote 'echo old > "$INSTALL_MARKER"'
  git_commit_all "$remote" old

  env HOME="$home" BOOTY_REPO_URL="file://$remote" INSTALL_MARKER="$TEST_ROOT/marker" "$TEST_REPO/install"

  xwritef "$remote/bin" booty-bootstrap '#!/usr/bin/env bash' 'echo new > "$INSTALL_MARKER"'
  git_commit_all "$remote" new

  run env HOME="$home" BOOTY_REPO_URL="file://$remote" INSTALL_MARKER="$TEST_ROOT/marker" "$TEST_REPO/install"
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/marker")" = new ]
}

@test "install from piped stdin runs bootstrap after opening tty" {
  command -v expect >/dev/null || skip "expect is required"
  setup_install_remote 'echo piped > "$INSTALL_MARKER"'
  git_commit_all "$remote" seed

  run env HOME="$home" BOOTY_REPO_URL="file://$remote" INSTALL_MARKER="$TEST_ROOT/marker" INSTALL_SCRIPT="$TEST_REPO/install" expect -c '
    set timeout 10
    spawn sh -c {cat "$INSTALL_SCRIPT" | bash}
    expect {
      eof {}
      timeout { exit 124 }
    }
    catch wait result
    exit [lindex $result 3]
  '
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/marker")" = piped ]
}
