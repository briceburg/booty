#!/usr/bin/env bats

load test_helper

setup() { setup_gitbooty; }

teardown() { teardown_tmp; }

gitbooty() { GITBOOTY_EXCLUDES="${GITBOOTY_EXCLUDES:-}" "$BOOTY_ROOT/bin/gitbooty" "$@"; }

gitbooty_layered() {
  GITBOOTY_LAYERS="$GITBOOTY_LAYERS"$'\n'"$FIXTURE_REPO/layer2" gitbooty "$@"
}

# Rendering keeps the target tree in sync with layered source paths.

@test "gitbooty apply renders layered files and writes a manifest" {
  writef "$FIXTURE_REPO" "layer1/.config/app.conf" base
  writef "$FIXTURE_REPO" "layer2/.config/app.conf" override
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell

  run gitbooty_layered apply
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_TARGET/.config/app.conf" override
  file_eq "$FIXTURE_TARGET/.bashrc" shell
  grep -Fq ".config/app.conf" "$FIXTURE_STATE/home.manifest.tsv"
}

@test "gitbooty prunes managed files removed from later applies" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell

  run gitbooty apply
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_TARGET/.bashrc" ]

  rm -f "$FIXTURE_REPO/layer1/.bashrc"

  run gitbooty apply
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_TARGET/.bashrc" ]
}

@test "gitbooty apply preserves executable mode and symlinks" {
  xwritef "$FIXTURE_REPO" "layer1/bin/tool" tool
  ln -s bin/tool "$FIXTURE_REPO/layer1/tool-link"

  run gitbooty apply
  [ "$status" -eq 0 ]
  [ -x "$FIXTURE_TARGET/bin/tool" ]
  [ -L "$FIXTURE_TARGET/tool-link" ]
  [ "$(readlink "$FIXTURE_TARGET/tool-link")" = "bin/tool" ]
}

@test "gitbooty excludes matching source paths" {
  writef "$FIXTURE_REPO" "layer1/etc/app.conf" system
  writef "$FIXTURE_REPO" "layer1/home/nesta/.bashrc" home

  GITBOOTY_EXCLUDES='home/*' run gitbooty apply
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_TARGET/etc/app.conf" system
  [ ! -e "$FIXTURE_TARGET/home/nesta/.bashrc" ]
  ! grep -Fq "home/nesta/.bashrc" "$FIXTURE_STATE/home.manifest.tsv"
}

@test "gitbooty status and diff report target drift" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" original

  gitbooty apply >/dev/null

  writef "$FIXTURE_TARGET" ".bashrc" changed

  run gitbooty status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'M\t.bashrc'* ]]

  run gitbooty diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"diff --git booty/.bashrc target/.bashrc"* ]]
  [[ "$output" == *"-original"* ]]
  [[ "$output" == *"+changed"* ]]
}

# Writeback commands update the source tree and manifest from target paths.

@test "gitbooty rm removes tracked target, source, and manifest entry" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell
  git_init "$FIXTURE_REPO"

  gitbooty apply >/dev/null

  run gitbooty rm "$FIXTURE_TARGET/.bashrc"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_TARGET/.bashrc" ]
  [ ! -e "$FIXTURE_REPO/layer1/.bashrc" ]
  ! grep -Fq ".bashrc" "$FIXTURE_STATE/home.manifest.tsv"
}

@test "gitbooty mv preserves symlink source and manifest mapping" {
  writef "$FIXTURE_REPO" "layer1/bin/tool" tool
  ln -s bin/tool "$FIXTURE_REPO/layer1/tool-link"
  git_init "$FIXTURE_REPO"

  gitbooty apply >/dev/null

  run gitbooty mv "$FIXTURE_TARGET/tool-link" "$FIXTURE_TARGET/tool-renamed"
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_TARGET/tool-link" ]
  [ -L "$FIXTURE_TARGET/tool-renamed" ]
  [ "$(readlink "$FIXTURE_TARGET/tool-renamed")" = "bin/tool" ]
  [ ! -e "$FIXTURE_REPO/layer1/tool-link" ]
  [ -L "$FIXTURE_REPO/layer1/tool-renamed" ]
  grep -Fq $'tool-renamed\tlayer1/tool-renamed' "$FIXTURE_STATE/home.manifest.tsv"
}

@test "gitbooty add accepts tilde and target-relative paths" {
  export HOME="$FIXTURE_TARGET"
  writef "$FIXTURE_TARGET" ".bashrc" shell
  writef "$FIXTURE_TARGET" "relative.conf" config
  ln -s missing "$FIXTURE_TARGET/broken-link"
  git_init "$FIXTURE_REPO"

  run gitbooty add "~/.bashrc"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/layer1/.bashrc" shell
  grep -Fq $'.bashrc\tlayer1/.bashrc' "$FIXTURE_STATE/home.manifest.tsv"

  (
    cd "$FIXTURE_TARGET"
    gitbooty add relative.conf
  )
  file_eq "$FIXTURE_REPO/layer1/relative.conf" config
  grep -Fq $'relative.conf\tlayer1/relative.conf' "$FIXTURE_STATE/home.manifest.tsv"

  run gitbooty add "$FIXTURE_TARGET/broken-link"
  [ "$status" -eq 0 ]
  [ -L "$FIXTURE_REPO/layer1/broken-link" ]
}

@test "gitbooty commit stages target changes, mode, and symlinks to source" {
  xwritef "$FIXTURE_REPO" "layer1/bin/tool" original
  writef "$FIXTURE_REPO" "layer1/plain.conf" source
  git_init "$FIXTURE_REPO"

  gitbooty apply >/dev/null

  xwritef "$FIXTURE_TARGET" "bin/tool" changed
  rm -f "$FIXTURE_TARGET/plain.conf"
  ln -s bin/tool "$FIXTURE_TARGET/plain.conf"

  run gitbooty commit
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/layer1/bin/tool" changed
  [ -x "$FIXTURE_REPO/layer1/bin/tool" ]
  [ -L "$FIXTURE_REPO/layer1/plain.conf" ]
  [ "$(readlink "$FIXTURE_REPO/layer1/plain.conf")" = "bin/tool" ]
  ! git -C "$FIXTURE_REPO" diff --cached --quiet --exit-code
}

# Rejected commands fail without changing tracked files.

@test "gitbooty mv rejects an existing destination" {
  writef "$FIXTURE_REPO" "layer1/source.conf" source
  writef "$FIXTURE_REPO" "layer1/dest.conf" dest

  gitbooty apply >/dev/null

  run gitbooty mv "$FIXTURE_TARGET/source.conf" "$FIXTURE_TARGET/dest.conf"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
  file_eq "$FIXTURE_TARGET/source.conf" source
  file_eq "$FIXTURE_TARGET/dest.conf" dest
}

@test "gitbooty mv rejects untracked files" {
  writef "$FIXTURE_TARGET" ".bashrc" shell

  run gitbooty mv "$FIXTURE_TARGET/.bashrc" "$FIXTURE_TARGET/.bash_profile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not tracked"* ]]
}

@test "gitbooty rejects normalized paths outside the target" {
  writef "$TEST_ROOT" outside.conf outside

  run gitbooty add "$FIXTURE_TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"target root"* ]]

  run gitbooty add "$FIXTURE_TARGET/../outside.conf"
  [ "$status" -ne 0 ]
  [[ "$output" == *"outside $FIXTURE_TARGET"* ]]

  printf 'outside.conf\t../outside.conf\n' > "$GITBOOTY_MANIFEST"
  run gitbooty status
  [ "$status" -ne 0 ]
  [[ "$output" == *"outside $FIXTURE_REPO"* ]]

  printf '../outside.conf\tlayer1/outside.conf\n' > "$GITBOOTY_MANIFEST"
  run gitbooty status
  [ "$status" -ne 0 ]
  [[ "$output" == *"outside $FIXTURE_TARGET"* ]]
}

@test "gitbooty rejects non-engine commands" {
  local cmd
  git_init "$FIXTURE_REPO"

  for cmd in config checkout switch restore pull; do
    run gitbooty "$cmd" risky
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported command '$cmd'"* ]]
  done
}
