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

@test "booty-bootstrap shows help without dispatching" {
  run "$BOOTY_ROOT/bin/booty-bootstrap" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: booty-bootstrap"* ]]
}

@test "archlinux config fails clearly for an unknown host" {
  run arch_config missing-host
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing host definition"* ]]
}

@test "archlinux config dumps resolved bootstrap variables" {
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

@test "archlinux config accepts an ad hoc user when repo url is supplied" {
  rm -f "$FIXTURE_REPO/bootstrap/archlinux/config/users/nesta.yaml"

  run env BOOTY_REPO_URL=file:///tmp/ad-hoc BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTY_REPO_URL="file:///tmp/ad-hoc"'* ]]
}

@test "archlinux config requires repo url when user config is missing" {
  rm -f "$FIXTURE_REPO/bootstrap/archlinux/config/users/nesta.yaml"

  run env BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing BOOTY_REPO_URL or repo_url"* ]]
}

@test "archlinux config refuses a symlinked config dir" {
  rm -rf "$BOOTSTRAP_CONFIG_DIR"
  ln -s "$TEST_ROOT" "$BOOTSTRAP_CONFIG_DIR"

  run arch_config plain
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing symlinked bootstrap config dir"* ]]
}

@test "booty-bootstrap runs the flat bootstrap scripts in order" {
  export BOOTY_HOST=plain
  export USER=root
  export BOOTY_ROOT="$FIXTURE_REPO/runtime"
  mkdir -p "$BOOTY_ROOT/bin" "$BOOTY_ROOT/lib"
  cp "$TEST_REPO/bin/booty-bootstrap" "$BOOTY_ROOT/bin/"
  cp "$TEST_REPO/lib/booty.sh" "$BOOTY_ROOT/lib/"
  cp "$TEST_REPO/lib/booty-bootstrap.sh" "$BOOTY_ROOT/lib/"
  mkdir -p "$BOOTY_HOME/booty/bin"
  writef "$BOOTY_HOME/booty/bin" booty '#!/usr/bin/env bash' 'echo "booty $*" >> "$BOOTY_ORDER"'
  chmod +x "$BOOTY_HOME/booty/bin/booty"
  writef "$FIXTURE_REPO/bootstrap/archlinux" 00-config.sh 'export BOOTSTRAP_USER=root' 'echo 00-config >> "$BOOTY_ORDER"'
  chmod +x "$BOOTY_ROOT/bin/booty-bootstrap"
  writef "$TEST_ROOT/bin" sudo \
    '#!/usr/bin/env bash' \
    'while [ "$1" != env ]; do shift; done' \
    'shift' \
    'exec env "$@"'
  chmod +x "$TEST_ROOT/bin/sudo"
  export PATH="$TEST_ROOT/bin:$PATH"
  export BOOTY_ORDER="$TEST_ROOT/order"

  for script in 10-install; do
    writef "$FIXTURE_REPO/bootstrap/archlinux" "$script.sh" "echo $script >> \"\$BOOTY_ORDER\"" "export BOOTSTRAP_TARGET_READY=1"
  done
  writef "$FIXTURE_REPO/bootstrap/archlinux" "users/root.sh" 'echo users/root >> "$BOOTY_ORDER"'
  writef "$FIXTURE_REPO/bootstrap/archlinux" "hosts/plain.sh" 'echo hosts/plain >> "$BOOTY_ORDER"'

  run "$BOOTY_ROOT/bin/booty-bootstrap"
  [ "$status" -eq 0 ]
  [ "$(cat "$BOOTY_ORDER")" = $'00-config\n10-install\nbooty apply\nusers/root\nhosts/plain\nbooty sync' ]
}
