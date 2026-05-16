#!/usr/bin/env bats

load test_helper

setup() { setup_gitbooty; }

teardown() { teardown_tmp; }

gitbooty() { GITBOOTY_EXCLUDES="${GITBOOTY_EXCLUDES:-}" "$BOOTY_ROOT/bin/gitbooty" "$@"; }

gitbooty_layered() {
  GITBOOTY_LAYERS="$GITBOOTY_LAYERS"$'\n'"$FIXTURE_REPO/layer2" gitbooty "$@"
}

@test "gitbooty shows help with no args" {
  run "$BOOTY_ROOT/bin/gitbooty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: gitbooty"* ]]
}

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

@test "gitbooty pull updates the repo before applying files" {
  remote="$TEST_ROOT/remote"
  work="$TEST_ROOT/work"
  git_init "$remote"
  writef "$remote" "layer1/pulled.conf" original
  git_commit_all "$remote" "seed"
  git clone -q "$remote" "$work"
  rm -rf "$FIXTURE_REPO"
  mv "$work" "$FIXTURE_REPO"

  writef "$remote" "layer1/pulled.conf" updated
  git -C "$remote" commit -qam "update"

  run gitbooty pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_TARGET/pulled.conf" updated
}

@test "gitbooty prunes managed files removed from later pulls" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell

  run gitbooty pull
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_TARGET/.bashrc" ]

  rm -f "$FIXTURE_REPO/layer1/.bashrc"

  run gitbooty pull
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_TARGET/.bashrc" ]
}

@test "gitbooty pull preserves executable mode and symlinks" {
  xwritef "$FIXTURE_REPO" "layer1/bin/tool" tool
  ln -s bin/tool "$FIXTURE_REPO/layer1/tool-link"

  run gitbooty pull
  [ "$status" -eq 0 ]
  [ -x "$FIXTURE_TARGET/bin/tool" ]
  [ -L "$FIXTURE_TARGET/tool-link" ]
  [ "$(readlink "$FIXTURE_TARGET/tool-link")" = "bin/tool" ]
}

@test "gitbooty excludes matching source paths" {
  writef "$FIXTURE_REPO" "layer1/etc/app.conf" system
  writef "$FIXTURE_REPO" "layer1/home/nesta/.bashrc" home

  GITBOOTY_EXCLUDES='home/*' run gitbooty pull
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_TARGET/etc/app.conf" system
  [ ! -e "$FIXTURE_TARGET/home/nesta/.bashrc" ]
  ! grep -Fq "home/nesta/.bashrc" "$FIXTURE_STATE/home.manifest.tsv"
}

@test "gitbooty status and diff report target drift" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" original

  gitbooty pull >/dev/null

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

@test "gitbooty rm removes tracked target, source, and manifest entry" {
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell
  git_init "$FIXTURE_REPO"

  gitbooty pull >/dev/null

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

  gitbooty pull >/dev/null

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
}

@test "gitbooty commit writes target changes, mode, and symlinks to source" {
  xwritef "$FIXTURE_REPO" "layer1/bin/tool" original
  writef "$FIXTURE_REPO" "layer1/plain.conf" source
  git_init "$FIXTURE_REPO"

  gitbooty pull >/dev/null

  xwritef "$FIXTURE_TARGET" "bin/tool" changed
  rm -f "$FIXTURE_TARGET/plain.conf"
  ln -s bin/tool "$FIXTURE_TARGET/plain.conf"

  run gitbooty commit -m "write back target changes"
  [ "$status" -eq 0 ]
  file_eq "$FIXTURE_REPO/layer1/bin/tool" changed
  [ -x "$FIXTURE_REPO/layer1/bin/tool" ]
  [ -L "$FIXTURE_REPO/layer1/plain.conf" ]
  [ "$(readlink "$FIXTURE_REPO/layer1/plain.conf")" = "bin/tool" ]
  git -C "$FIXTURE_REPO" diff --exit-code --cached
}

@test "gitbooty mv rejects untracked files" {
  writef "$FIXTURE_TARGET" ".bashrc" shell

  run gitbooty mv "$FIXTURE_TARGET/.bashrc" "$FIXTURE_TARGET/.bash_profile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not tracked"* ]]
}

@test "gitbooty passes repo-only git commands through" {
  git_init "$FIXTURE_REPO"
  writef "$FIXTURE_REPO" "layer1/.bashrc" shell
  git -C "$FIXTURE_REPO" add layer1/.bashrc
  git -C "$FIXTURE_REPO" commit -qm "seed"

  run gitbooty branch --show-current
  [ "$status" -eq 0 ]
  [[ "$(last_output_line)" == "master" || "$(last_output_line)" == "main" ]]

  run gitbooty config user.name
  [ "$status" -eq 0 ]
  [ "$(last_output_line)" = "Test User" ]

  run gitbooty log --oneline -1
  [ "$status" -eq 0 ]
  [[ "$output" == *"seed"* ]]
}

@test "gitbooty does not pass through repo worktree commands" {
  git_init "$FIXTURE_REPO"

  run gitbooty checkout -b risky
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported command 'checkout'"* ]]
}
