#!/usr/bin/env bash
set -eo pipefail

eval "$(fnm env --shell bash)"

if ! fnm default >/dev/null 2>&1; then
  fnm install 24
  fnm default 24
fi

fnm use default --install-if-missing --silent-if-unchanged >/dev/null
command -v codex >/dev/null || npm i -g @openai/codex
command -v copilot >/dev/null || npm i -g @github/copilot
