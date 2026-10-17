#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/third_party/Mega-Man-8-Recomp"
GAME_COMMIT="e9f808fa40c04592d1d95808c658c460c1c808d9"

if [[ ! -d "${DEST}/.git" ]]; then
  mkdir -p "${ROOT}/third_party"
  git clone https://github.com/omegakatana92/Mega-Man-8-Recomp.git "${DEST}"
fi

git -C "${DEST}" fetch origin "${GAME_COMMIT}"
git -C "${DEST}" checkout --detach "${GAME_COMMIT}"
git -C "${DEST}" submodule sync --recursive
git -C "${DEST}" submodule update --init --recursive

echo
echo "Upstream game checkout pinned at:"
git -C "${DEST}" rev-parse HEAD
echo
echo "Submodule revisions:"
git -C "${DEST}" submodule status --recursive
echo
echo "This script does not generate game code and does not include a game disc or BIOS dump."
echo "The real Android runtime activates only after generated game and OpenBIOS C sources exist."
echo "Do not commit or distribute generated copyrighted game code, disc images, or BIOS dumps."
