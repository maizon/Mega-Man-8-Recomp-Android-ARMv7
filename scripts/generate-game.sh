#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${ROOT}/third_party/Mega-Man-8-Recomp"
GAME_COMMIT="e9f808fa40c04592d1d95808c658c460c1c808d9"
FRAMEWORK_COMMIT="58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a"

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/generate-game.sh /path/to/your/legal/Mega-Man-8.cue" >&2
  exit 2
fi
if [[ ! -f "$1" ]]; then
  echo "Disc cue not found: $1" >&2
  exit 2
fi
DISC="$(realpath "$1")"
if [[ ! -f "${UPSTREAM}/psxrecomp/psxrecomp_cli.py" || ! -f "${UPSTREAM}/game.toml" ]]; then
  echo "Upstream checkout missing. Run: bash scripts/prepare-upstream.sh" >&2
  exit 2
fi

actual_game="$(git -C "${UPSTREAM}" rev-parse HEAD)"
actual_framework="$(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
if [[ "${actual_game}" != "${GAME_COMMIT}" || "${actual_framework}" != "${FRAMEWORK_COMMIT}" ]]; then
  echo "ERROR: upstream pins do not match the audited versions." >&2
  echo "Game: expected ${GAME_COMMIT}, got ${actual_game}" >&2
  echo "Framework: expected ${FRAMEWORK_COMMIT}, got ${actual_framework}" >&2
  echo "Run: bash scripts/prepare-upstream.sh" >&2
  exit 1
fi

python3 "${ROOT}/scripts/validate-cue.py" "${DISC}" "${UPSTREAM}/game.toml"

# Android performance defaults: use the real GPU renderer and native internal
# resolution for frame-rate headroom. The 16:9 projection hack is enabled at
# generation time; per-title visual coverage still requires device testing.
python3 - "${UPSTREAM}/game.toml" <<'PYCFG'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = '[video]\nrenderer = "software"'
new = '[video]\nrenderer = "opengl"\naspect_ratio = "16:9"\nsupersampling = 1'
already = '[video]\nrenderer = "opengl"\naspect_ratio = "16:9"\nsupersampling = 1'
if text.count(already) == 1:
    print("Android video defaults already applied: OpenGL, 16:9, native internal scale, Vulkan hidden.")
elif text.count(old) == 1:
    text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")
    print("Applied Android video defaults: OpenGL, 16:9, native internal scale, Vulkan hidden.")
else:
    raise SystemExit(
        f"ERROR: expected exactly one known [video] block (original={text.count(old)}, tuned={text.count(already)}); refusing unsafe config edit."
    )
PYCFG

echo "Generating local Mega Man 8 sources from the validated disc."
echo "The disc and generated copyrighted game sources stay local; this script does not upload or commit them."
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
for source in "${game_full[@]}" "${game_dispatch[@]}"; do
  if [[ ! -s "${source}" ]]; then
    echo "ERROR: generated game source is empty: $(basename "${source}")" >&2
    exit 1
  fi
done
if [[ ! -s "${bios_full_source}" || ! -s "${bios_dispatch_source}" ]]; then
  echo "ERROR: non-empty OpenBIOS C files are missing under ${bios_source}" >&2
  exit 1
fi

mkdir -p "${bios_output}"
cp "${bios_full_source}" "${bios_output}/OpenBIOS_full.c"
cp "${bios_dispatch_source}" "${bios_output}/OpenBIOS_dispatch.c"
test -s "${bios_output}/OpenBIOS_full.c"
test -s "${bios_output}/OpenBIOS_dispatch.c"

echo
echo "Generation checks passed:"
printf '  game full C files:       %s\n' "${#game_full[@]}"
printf '  game dispatch C files:   %s\n' "${#game_dispatch[@]}"
echo "  OpenBIOS full + dispatch: staged and non-empty"
echo
echo "Next: gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug"
