TEST_REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

setup_tmp() {
  TEST_ROOT="$(mktemp -d "/tmp/$1.XXXXXX")"
  export TEST_ROOT BOOTY_ROOT="$TEST_REPO"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
}

teardown_tmp() { rm -rf "${TEST_ROOT:-}"; }
file_eq() { [ "$(cat "$1")" = "$2" ]; }

fixture() {
  mkdir -p "$2"
  cp -R "$TEST_REPO/tests/fixtures/$1/." "$2/"
}

fake() {
  fixture "../helpers/$1" "$TEST_ROOT/bin"
  export PATH="$TEST_ROOT/bin:$PATH"
}

writef() {
  local root="$1" rel="$2"
  shift 2
  mkdir -p "$(dirname "$root/$rel")"
  printf '%s\n' "$@" > "$root/$rel"
}

xwritef() {
  writef "$@"
  chmod +x "$1/$2"
}

git_id() {
  git -C "$1" config user.email test@example.invalid
  git -C "$1" config user.name "Test User"
}

git_init() {
  mkdir -p "$1"
  git -C "$1" init -q
  git_id "$1"
}

git_commit_all() {
  git -C "$1" add .
  git -C "$1" commit -qm "$2"
}

setup_booty_public() {
  setup_tmp booty-test
  export FIXTURE_HOME="$TEST_ROOT/home"
  export BOOTY_HOME="$FIXTURE_HOME/.booty"
  export FIXTURE_REPO="$BOOTY_HOME/booty"
  export FIXTURE_ROOT="$TEST_ROOT/root"
  export FIXTURE_STATE="$TEST_ROOT/state"
  export BOOTY_OS=archlinux BOOTY_HOST=hartford USER=nesta
  export BOOTY_TARGET_ROOT="$FIXTURE_ROOT"
  export HOME="$FIXTURE_HOME" XDG_DATA_HOME="$FIXTURE_STATE"

  mkdir -p "$FIXTURE_HOME" "$FIXTURE_ROOT" "$FIXTURE_STATE" "$BOOTY_HOME"
  writef "$BOOTY_HOME" config \
    "BOOTY_REPO_URL=\${BOOTY_REPO_URL:-file://$FIXTURE_REPO}" \
    "BOOTY_SECRETS_URL=\${BOOTY_SECRETS_URL:-gcrypt::file://$TEST_ROOT/secrets-remote}"
  fixture dotfiles/archlinux "$FIXTURE_REPO/dotfiles/archlinux"
  git_init "$FIXTURE_REPO"
  git_commit_all "$FIXTURE_REPO" "seed public"
}

setup_booty_secrets() {
  setup_booty_public
  export FIXTURE_SECRETS="$BOOTY_HOME/booty-secrets"
  fixture dotfiles/secrets/archlinux "$FIXTURE_SECRETS/dotfiles/archlinux"
  git_init "$FIXTURE_SECRETS"
  git_commit_all "$FIXTURE_SECRETS" "seed secrets"
}

setup_archlinux() {
  setup_tmp booty-archlinux-test
  export BOOTY_HOME="$TEST_ROOT/.booty"
  export FIXTURE_REPO="$BOOTY_HOME/booty"
  export BOOTSTRAP_CONFIG_DIR="$TEST_ROOT/booty"
  export BOOTY_OS=archlinux BOOTSTRAP_USER=nesta
  mkdir -p "$BOOTSTRAP_CONFIG_DIR"
  fixture bootstrap "$FIXTURE_REPO/bootstrap"
  cp "$TEST_REPO/bootstrap/archlinux/00-config.sh" "$FIXTURE_REPO/bootstrap/archlinux/00-config.sh"
}
