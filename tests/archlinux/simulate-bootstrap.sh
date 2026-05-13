#!/usr/bin/env bash
set -eo pipefail

# Simulate a full Arch Linux bootstrap in a fresh archlinux container.
# Exercises install -> booty-bootstrap -> booty setup end-to-end against
# real pacman; only reflector, systemctl, and usermod with container-absent
# groups are skipped via a drop-in fixture.
#
# Prerequisites: the new host/user configs and ci dotfiles must be committed
# in the repo, since BOOTY_REPO_URL=file:///work clones committed state.
#
# Usage:
#   bash tests/archlinux/simulate-bootstrap.sh
#
# Environment:
#   BOOTSTRAP_ARCHLINUX_IMAGE  base image to use (default: archlinux:latest)

IMAGE="${BOOTSTRAP_ARCHLINUX_IMAGE:-archlinux:latest}"
cd "$(dirname "$(readlink -f "$0")")/../.."

echo "==> archlinux bootstrap simulation (image: $IMAGE)" >&2

docker run --rm -i \
  --volume "$PWD:/work:ro" \
  "$IMAGE" \
  bash /work/tests/archlinux/bootstrap-container.sh
