#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${ROOT}/third_party/Mega-Man-8-Recomp"

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/generate-game.sh /path/to/your/legal/Mega-Man-8.cue" >&2
  exit 2
fi

DISC="$(realpath "$1")"
if [[ ! -f "${DISC}" ]]; then
  echo "Disc cue not found: ${DISC}" >&2
  exit 2
fi
if [[ "${DISC,,}" != *.cue ]]; then
  echo "Please provide the full multi-track .cue file, not a single .bin track." >&2
  exit 2
fi
if [[ ! -f "${UPSTREAM}/psxrecomp/psxrecomp_cli.py" ]]; then
  echo "Upstream checkout missing. Run: bash scripts/prepare-upstream.sh" >&2
  exit 2
fi

echo "Generating local Mega Man 8 sources from the supplied disc."
echo "The disc and generated copyrighted game sources remain local; they are not uploaded by this script."

python3 "${UPSTREAM}/psxrecomp/psxrecomp_cli.py" generate \
  --config "${UPSTREAM}/game.toml" \
  --project-root "${UPSTREAM}" \
  --disc "${DISC}"

shopt -s nullglob
game_full=("${UPSTREAM}"/generated/*_full.c "${UPSTREAM}"/generated/*_full_*.c)
game_dispatch=("${UPSTREAM}"/generated/*_dispatch.c)
bios_source="${UPSTREAM}/psxrecomp/generated"
bios_full_source="${bios_source}/OpenBIOS_full.c"
bios_dispatch_source="${bios_source}/OpenBIOS_dispatch.c"
bios_output="${UPSTREAM}/bios-generated"

if (( ${#game_full[@]} == 0 )); then
  echo "ERROR: no generated game full C source found under ${UPSTREAM}/generated" >&2
  exit 1
fi
if (( ${#game_dispatch[@]} == 0 )); then
  echo "ERROR: no generated game dispatch C source found under ${UPSTREAM}/generated" >&2
  exit 1
fi
if [[ ! -s "${bios_full_source}" || ! -s "${bios_dispatch_source}" ]]; then
  echo "ERROR: OpenBIOS generated C files are missing under ${bios_source}" >&2
  exit 1
fi

# This game project's legacy CMakeLists.txt expects its BIOS C files under
# <game-root>/bios-generated, while current psxrecomp_cli.py emits them under
# the framework submodule's generated/ directory. Stage local copies into the
# path the game's CMake actually consumes.
mkdir -p "${bios_output}"
cp "${bios_full_source}" "${bios_output}/OpenBIOS_full.c"
cp "${bios_dispatch_source}" "${bios_output}/OpenBIOS_dispatch.c"

if [[ ! -s "${bios_output}/OpenBIOS_full.c" || ! -s "${bios_output}/OpenBIOS_dispatch.c" ]]; then
  echo "ERROR: failed to stage OpenBIOS C files for the game CMake target" >&2
  exit 1
fi

echo
echo "Generation checks passed:"
printf '  game full source files: %s\n' "${#game_full[@]}"
printf '  game dispatch files:   %s\n' "${#game_dispatch[@]}"
echo "  OpenBIOS full + dispatch: staged into bios-generated/"
echo
echo "Next: gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug"
