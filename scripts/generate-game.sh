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
bios_full="${UPSTREAM}/bios-generated/OpenBIOS_full.c"
bios_dispatch="${UPSTREAM}/bios-generated/OpenBIOS_dispatch.c"

if (( ${#game_full[@]} == 0 )); then
  echo "ERROR: no generated game full C source found under ${UPSTREAM}/generated" >&2
  exit 1
fi
if (( ${#game_dispatch[@]} == 0 )); then
  echo "ERROR: no generated game dispatch C source found under ${UPSTREAM}/generated" >&2
  exit 1
fi
if [[ ! -s "${bios_full}" || ! -s "${bios_dispatch}" ]]; then
  echo "ERROR: OpenBIOS generated C files are missing under ${UPSTREAM}/bios-generated" >&2
  exit 1
fi

echo
echo "Generation checks passed:"
printf '  game full source files: %s\n' "${#game_full[@]}"
printf '  game dispatch files:   %s\n' "${#game_dispatch[@]}"
echo "  OpenBIOS full + dispatch: present"
echo
echo "Next: gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug"
