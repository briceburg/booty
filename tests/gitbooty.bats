#!/usr/bin/env bats

# Exercises a layered source tree like:
#   repo/
#     layer1/        base files and writeback root
#     layer2/        later layer overrides
#   target/          rendered live tree
#   state/           manifest output
setup() {
  export TEST_ROOT="$(mktemp -d /tmp/gitbooty-test.XXXXXX)"
  export REPO_ROOT="$TEST_ROOT/repo"
  export TARGET_ROOT="$TEST_ROOT/target"
  export STATE_ROOT="$TEST_ROOT/state"

  mkdir -p "$REPO_ROOT/layer1/.config" "$REPO_ROOT/layer2/.config"
  mkdir -p "$TARGET_ROOT" "$STATE_ROOT"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "gitbooty shows help with no args" {
  run /work/bin/gitbooty
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: gitbooty"* ]]
}

@test "gitbooty applies layered files and writes a manifest" {
  printf '%s\n' base > "$REPO_ROOT/layer1/.config/app.conf"
  printf '%s\n' override > "$REPO_ROOT/layer2/.config/app.conf"
  printf '%s\n' shell > "$REPO_ROOT/layer1/.bashrc"

  run /work/bin/gitbooty \
    --repo-root "$REPO_ROOT" \
    --writeback-root "$REPO_ROOT/layer1" \
    --target-root "$TARGET_ROOT" \
    --manifest "$STATE_ROOT/home.manifest.tsv" \
    --layer "$REPO_ROOT/layer1" \
    --layer "$REPO_ROOT/layer2" \
    pull

  [ "$status" -eq 0 ]
  [ "$(cat "$TARGET_ROOT/.config/app.conf")" = "override" ]
  [ "$(cat "$TARGET_ROOT/.bashrc")" = "shell" ]
  grep -Fq ".config/app.conf" "$STATE_ROOT/home.manifest.tsv"
}

@test "gitbooty prunes managed files removed from later pulls" {
  printf '%s\n' shell > "$REPO_ROOT/layer1/.bashrc"

  run /work/bin/gitbooty \
    --repo-root "$REPO_ROOT" \
    --writeback-root "$REPO_ROOT/layer1" \
    --target-root "$TARGET_ROOT" \
    --manifest "$STATE_ROOT/home.manifest.tsv" \
    --layer "$REPO_ROOT/layer1" \
    pull
  [ "$status" -eq 0 ]
  [ -f "$TARGET_ROOT/.bashrc" ]

  rm -f "$REPO_ROOT/layer1/.bashrc"

  run /work/bin/gitbooty \
    --repo-root "$REPO_ROOT" \
    --writeback-root "$REPO_ROOT/layer1" \
    --target-root "$TARGET_ROOT" \
    --manifest "$STATE_ROOT/home.manifest.tsv" \
    --layer "$REPO_ROOT/layer1" \
    pull
  [ "$status" -eq 0 ]
  [ ! -e "$TARGET_ROOT/.bashrc" ]
}

@test "gitbooty mv rejects untracked files" {
  printf '%s\n' shell > "$TARGET_ROOT/.bashrc"

  run /work/bin/gitbooty \
    --repo-root "$REPO_ROOT" \
    --writeback-root "$REPO_ROOT/layer1" \
    --target-root "$TARGET_ROOT" \
    --manifest "$STATE_ROOT/home.manifest.tsv" \
    --layer "$REPO_ROOT/layer1" \
    mv "$TARGET_ROOT/.bashrc" "$TARGET_ROOT/.bash_profile"

  [ "$status" -ne 0 ]
  [[ "$output" == *"is not tracked"* ]]
}
