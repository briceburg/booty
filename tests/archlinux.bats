#!/usr/bin/env bats

load test_helper

setup() { setup_archlinux; }
teardown() { teardown_tmp; }

arch_config() {
  env BOOTY_HOST="${1:-plain}" "$BOOTY_ROOT/bin/booty-bootstrap" config
}

has_output() {
  local text
  for text in "$@"; do [[ "$output" == *"$text"* ]] || return; done
}

# Config resolution is pure and cheap, so these tests keep bootstrap inputs legible.

@test "archlinux config fails clearly for an unknown host" {
  run arch_config missing-host
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing host definition"* ]]
}

@test "archlinux config resolves bootstrap variables" {
  run arch_config plain
  [ "$status" -eq 0 ]
  has_output \
    'declare -x BOOTY_REPO_URL="file:///tmp/booty"' \
    'declare -x BOOTY_SECRETS_URL="gcrypt::file:///tmp/booty-secrets"' \
    'declare -x BOOTSTRAP_MULTILIB="false"' \
    'declare -a BOOTSTRAP_FEATURES=([0]="core" [1]="printing")' \
    '"base"' '"cups"' '"host-tool"' \
    'declare -a BOOTSTRAP_AUR=([0]="yay-bin")' \
    '"cups.service"' '"resolved.service"'
  [[ "$output" != *"lib32-mesa"* ]]
  [ -f "$BOOTSTRAP_CONFIG_DIR/archlinux.yaml" ]

  run env BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTSTRAP_CMD="config"'* ]]
}

@test "archlinux config adds multilib packages only for multilib features" {
  run arch_config multilib
  [ "$status" -eq 0 ]
  has_output 'declare -x BOOTSTRAP_MULTILIB="true"' '"base"' '"steam"' '"lib32-mesa"'
}

@test "archlinux config handles users without config only when repo url is supplied" {
  rm -f "$FIXTURE_REPO/bootstrap/archlinux/config/users/nesta.yaml"

  run env BOOTY_REPO_URL=file:///tmp/ad-hoc BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTY_REPO_URL="file:///tmp/ad-hoc"'* ]]

  run env BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing BOOTY_REPO_URL or repo_url"* ]]
}

@test "archlinux config refuses symlinked config paths" {
  rm -rf "$BOOTSTRAP_CONFIG_DIR"
  ln -s "$TEST_ROOT" "$BOOTSTRAP_CONFIG_DIR"

  run arch_config plain
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing symlinked bootstrap config dir"* ]]

  rm -rf "$BOOTSTRAP_CONFIG_DIR"
  mkdir -p "$BOOTSTRAP_CONFIG_DIR"
  ln -s "$TEST_ROOT/user-target" "$BOOTSTRAP_CONFIG_DIR/user"

  run env -u BOOTSTRAP_USER BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing symlinked bootstrap config file"* ]]
}

@test "archlinux config preserves existing merge output when yq fails" {
  writef "$BOOTSTRAP_CONFIG_DIR" archlinux.yaml keep
  writef "$FIXTURE_REPO/bootstrap/archlinux/config/hosts" plain.yaml ':'

  run arch_config plain
  [ "$status" -ne 0 ]
  [ "$(cat "$BOOTSTRAP_CONFIG_DIR/archlinux.yaml")" = keep ]
}

# Bootstrap dispatch is order-sensitive because OS scripts are sourced in one shell.

@test "sudo_env_exec requires an env separator" {
  run bash -c ". '$BOOTY_ROOT/lib/booty.sh'; . '$BOOTY_ROOT/lib/booty-bootstrap.sh'; sudo_env_exec BOOTY_HOME"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sudo_env_exec missing --"* ]]
}

@test "booty-bootstrap runs the flat bootstrap scripts in order" {
  export BOOTY_HOST=plain
  export USER=root
  export BOOTY_ROOT="$FIXTURE_REPO/runtime"
  mkdir -p "$BOOTY_ROOT"/{bin,lib}
  cp "$TEST_REPO/bin/booty-bootstrap" "$BOOTY_ROOT/bin/"
  cp "$TEST_REPO"/lib/booty{,-bootstrap}.sh "$BOOTY_ROOT/lib/"
  mkdir -p "$BOOTY_HOME/booty/bin"
  xwritef "$BOOTY_HOME/booty/bin" booty '#!/usr/bin/env bash' 'echo "booty $*" >> "$BOOTY_ORDER"'
  writef "$FIXTURE_REPO/bootstrap/archlinux" 00-config.sh 'export BOOTSTRAP_USER=root' 'echo 00-config >> "$BOOTY_ORDER"'
  chmod +x "$BOOTY_ROOT/bin/booty-bootstrap"
  xwritef "$TEST_ROOT/bin" sudo \
    '#!/usr/bin/env bash' \
    'while [ "$1" != env ]; do shift; done' \
    'shift' \
    'exec env "$@"'
  export PATH="$TEST_ROOT/bin:$PATH"
  export BOOTY_ORDER="$TEST_ROOT/order"

  writef "$FIXTURE_REPO/bootstrap/archlinux" 10-install.sh 'echo 10-install >> "$BOOTY_ORDER"' 'export BOOTSTRAP_TARGET_READY=1'
  writef "$FIXTURE_REPO/bootstrap/archlinux" "users/root.sh" 'echo users/root >> "$BOOTY_ORDER"'
  writef "$FIXTURE_REPO/bootstrap/archlinux" "hosts/plain.sh" 'echo hosts/plain >> "$BOOTY_ORDER"'

  run "$BOOTY_ROOT/bin/booty-bootstrap"
  [ "$status" -eq 0 ]
  [ "$(cat "$BOOTY_ORDER")" = $'00-config\n10-install\nbooty apply\nusers/root\nhosts/plain\nbooty sync' ]
}
