#!/usr/bin/env bats

load test_helper

setup() {
  setup_archlinux
}

teardown() {
  teardown_tmp
}

arch_config() {
  env BOOTY_HOST="${1:-plain}" "$BOOTY_ROOT/bin/booty-bootstrap" config
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

@test "archlinux config prints resolved bootstrap variables" {
  run arch_config plain
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTY_HOST="plain"'* ]]
  [[ "$output" == *'declare -x BOOTSTRAP_CMD="config"'* ]]
  [[ "$output" == *'declare -x BOOTSTRAP_USER="nesta"'* ]]
  [[ "$output" == *'declare -x BOOTSTRAP_BOOTY_URL="file:///tmp/booty"'* ]]
  [[ "$output" == *'declare -x BOOTSTRAP_SECRETS_URL="gcrypt::file:///tmp/booty-secrets"'* ]]
  [[ "$output" == *'declare -x BOOTSTRAP_MULTILIB="false"'* ]]
  [[ "$output" != *"lib32-mesa"* ]]
  [[ "$output" == *'declare -a BOOTSTRAP_FEATURES=([0]="core" [1]="printing")'* ]]
  [[ "$output" == *'declare -a BOOTSTRAP_PACMAN='* ]]
  [[ "$output" == *'"base"'* ]]
  [[ "$output" == *'"cups"'* ]]
  [[ "$output" == *'"host-tool"'* ]]
  [[ "$output" == *'declare -a BOOTSTRAP_AUR=([0]="yay-bin")'* ]]
  [[ "$output" == *'declare -a BOOTSTRAP_SERVICES='* ]]
  [[ "$output" == *'"cups.service"'* ]]
  [[ "$output" == *'"resolved.service"'* ]]

  run env BOOTY_HOST=plain "$BOOTY_ROOT/bin/booty-bootstrap" config
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTSTRAP_CMD="config"'* ]]
}

@test "archlinux config adds multilib packages only for multilib features" {
  run arch_config multilib
  [ "$status" -eq 0 ]
  [[ "$output" == *'declare -x BOOTSTRAP_MULTILIB="true"'* ]]
  [[ "$output" == *'declare -a BOOTSTRAP_PACMAN='* ]]
  [[ "$output" == *'"base"'* ]]
  [[ "$output" == *'"steam"'* ]]
  [[ "$output" == *'"lib32-mesa"'* ]]
}

@test "booty-bootstrap runs the flat bootstrap scripts in order" {
  export BOOTY_HOST=plain
  export USER=root
  export BOOTY_ROOT="$FIXTURE_REPO/runtime"
  mkdir -p "$BOOTY_ROOT/bin" "$BOOTY_ROOT/lib"
  cp "$TEST_REPO/bin/booty-bootstrap" "$BOOTY_ROOT/bin/"
  cp "$TEST_REPO/lib/booty.sh" "$BOOTY_ROOT/lib/"
  cp "$TEST_REPO/lib/booty-bootstrap.sh" "$BOOTY_ROOT/lib/"
  writef "$FIXTURE_REPO/bootstrap/archlinux" 00-config.sh 'export BOOTSTRAP_USER=nesta' 'echo 00-config >> "$BOOTY_ORDER"'
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
    writef "$FIXTURE_REPO/bootstrap/archlinux" "$script.sh" "echo $script >> \"\$BOOTY_ORDER\""
  done
  writef "$FIXTURE_REPO/bootstrap/archlinux" "users/nesta.sh" 'echo users/nesta >> "$BOOTY_ORDER"'
  writef "$FIXTURE_REPO/bootstrap/archlinux" "hosts/plain.sh" 'echo hosts/plain >> "$BOOTY_ORDER"'

  run "$BOOTY_ROOT/bin/booty-bootstrap"
  [ "$status" -eq 0 ]
  [ "$(cat "$BOOTY_ORDER")" = $'00-config\n10-install\nusers/nesta\nhosts/plain' ]
}
