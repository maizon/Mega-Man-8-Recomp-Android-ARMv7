#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${ROOT}/third_party/Mega-Man-8-Recomp"
GAME_URL="https://github.com/omegakatana92/Mega-Man-8-Recomp.git"
FRAMEWORK_URL="https://github.com/dguillot-gh/psxrecomp-android.git"
GAME_COMMIT="e9f808fa40c04592d1d95808c658c460c1c808d9"
FRAMEWORK_COMMIT="58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a"

if [[ ! -d "${UPSTREAM}/.git" && ! -f "${UPSTREAM}/.git" ]]; then
  if [[ -e "${UPSTREAM}" ]]; then
    echo "ERROR: ${UPSTREAM} exists but is not a Git checkout; refusing to overwrite it." >&2
    exit 1
  fi
  mkdir -p "${ROOT}/third_party"
  git clone --no-recurse-submodules "${GAME_URL}" "${UPSTREAM}"
fi

git -C "${UPSTREAM}" remote set-url origin "${GAME_URL}"
git -C "${UPSTREAM}" fetch origin "${GAME_COMMIT}"
git -C "${UPSTREAM}" checkout --detach "${GAME_COMMIT}"

# The original framework gitlink is not Android-ready. Pin the audited Android
# fork locally; no framework source or game data is copied into this repository.
if [[ -d "${UPSTREAM}/psxrecomp/.git" || -f "${UPSTREAM}/psxrecomp/.git" ]]; then
  git -C "${UPSTREAM}/psxrecomp" remote set-url origin "${FRAMEWORK_URL}"
  git -C "${UPSTREAM}/psxrecomp" fetch origin android
  git -C "${UPSTREAM}/psxrecomp" fetch origin "${FRAMEWORK_COMMIT}"
  git -C "${UPSTREAM}/psxrecomp" checkout --detach "${FRAMEWORK_COMMIT}"
else
  if [[ -L "${UPSTREAM}/psxrecomp" || -e "${UPSTREAM}/psxrecomp" ]]; then
    if [[ ! -d "${UPSTREAM}/psxrecomp" ]] ||
       [[ -n "$(find "${UPSTREAM}/psxrecomp" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      echo "ERROR: ${UPSTREAM}/psxrecomp exists without Git metadata and is not empty; refusing to delete it." >&2
      exit 1
    fi
    rmdir "${UPSTREAM}/psxrecomp"
  fi
  git clone --branch android --single-branch "${FRAMEWORK_URL}" "${UPSTREAM}/psxrecomp"
  git -C "${UPSTREAM}/psxrecomp" checkout --detach "${FRAMEWORK_COMMIT}"
fi

git -C "${UPSTREAM}/psxrecomp" submodule sync --recursive
git -C "${UPSTREAM}/psxrecomp" submodule update --init --recursive
git -C "${UPSTREAM}" submodule update --init recomp-ui

# All source patches are local to this ignored checkout. Each patch requires
# one exact upstream match (or one exact already-patched match); ambiguity fails.
python3 - "${UPSTREAM}/CMakeLists.txt" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = 'set(PSX_LAUNCHER ON CACHE BOOL "" FORCE)\nset(PSX_RECOMP_UI ON CACHE BOOL "" FORCE)'
new = '''set(PSX_LAUNCHER ON CACHE BOOL "" FORCE)
if(ANDROID)
    set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
    set(PSX_ENABLE_VULKAN OFF CACHE BOOL "" FORCE)
    set(PSX_REWIND OFF CACHE BOOL "" FORCE)
else()
    set(PSX_RECOMP_UI ON CACHE BOOL "" FORCE)
endif()'''

if source.count(new) == 1:
    print("Android CMake options already patched exactly once.")
elif source.count(old) == 1:
    patched = source.replace(old, new, 1)
    if patched.count(new) != 1 or patched.count(old) != 0:
        raise SystemExit("ERROR: Android CMake option patch did not validate.")
    path.write_text(patched, encoding="utf-8")
    print("Patched Android CMake options in the local upstream checkout.")
else:
    raise SystemExit(
        f"ERROR: expected exactly one known CMake block; old={source.count(old)}, patched={source.count(new)}. Refusing an unsafe patch."
    )
PY

# vaddvq_s32 is AArch64-only; ARMv7 NEON sums the same four lanes explicitly.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/mdec.c" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = "    return vaddvq_s32(vaddq_s32(lo, hi));"
new = '''    int32x4_t sum = vaddq_s32(lo, hi);
#if defined(__aarch64__)
    return vaddvq_s32(sum);
#else
    return vgetq_lane_s32(sum, 0) + vgetq_lane_s32(sum, 1) +
           vgetq_lane_s32(sum, 2) + vgetq_lane_s32(sum, 3);
#endif'''

if source.count(new) == 1:
    print("ARMv7 MDEC NEON reduction already patched exactly once.")
elif source.count(old) == 1:
    patched = source.replace(old, new, 1)
    if patched.count(new) != 1 or patched.count(old) != 0:
        raise SystemExit("ERROR: ARMv7 NEON patch did not validate.")
    path.write_text(patched, encoding="utf-8")
    print("Patched AArch64-only MDEC NEON reduction for ARMv7.")
else:
    raise SystemExit(
        f"ERROR: expected exactly one known MDEC reduction; old={source.count(old)}, patched={source.count(new)}. Refusing an unsafe patch."
    )
PY

# Android GLESv2 lacks desktop glReadBuffer. OpenXR is disabled for this target.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
start_signature = "static int openxr_copy_native("
end_signature = "\nstatic void openxr_present_native(void) {"
if source.count(start_signature) != 1 or source.count(end_signature) != 1:
    raise SystemExit(
        "ERROR: expected exactly one OpenXR native-copy function and following present function; refusing an unsafe patch."
    )
start = source.find(start_signature)
end = source.find(end_signature, start)
block = source[start:end]

if "#if defined(__ANDROID__)" in block:
    if block.count("#if defined(__ANDROID__)") != 1 or "glReadBuffer" not in block:
        raise SystemExit("ERROR: existing Android OpenXR guard is ambiguous or incomplete.")
    print("Android OpenXR GLES guard already present exactly once.")
else:
    if "glReadBuffer" not in block:
        raise SystemExit("ERROR: expected desktop glReadBuffer call not found in native-copy function.")
    brace = block.find("{")
    close = block.rfind("}")
    if brace < 0 or close < brace:
        raise SystemExit("ERROR: could not parse OpenXR native-copy function.")
    signature = block[:brace + 1]
    body = block[brace + 1:close]
    replacement = signature + '''
#if defined(__ANDROID__)
    (void)eye;
    (void)texture;
    (void)w;
    (void)h;
    return 0;
#else
''' + body + '''
#endif
}
'''
    patched = source[:start] + replacement + source[end:]
    patched_start = patched.find(start_signature)
    patched_end = patched.find(end_signature, patched_start)
    patched_block = patched[patched_start:patched_end]
    if patched_block.count("#if defined(__ANDROID__)") != 1 or "glReadBuffer" not in patched_block:
        raise SystemExit("ERROR: OpenXR Android guard failed post-patch validation.")
    path.write_text(patched, encoding="utf-8")
    print("Disabled the desktop OpenXR native-copy path on Android GLES.")

PY

test -s "${UPSTREAM}/psxrecomp/runtime/runtime.cmake"
test -s "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxGameActivity.java"
test -s "${UPSTREAM}/psxrecomp/bios/openbios.bin"
test -s "${UPSTREAM}/psxrecomp/bios/OpenBIOS.LICENSE"
grep -Fq 'vgetq_lane_s32(sum, 3)' "${UPSTREAM}/psxrecomp/runtime/src/mdec.c"
grep -Fq '#if defined(__ANDROID__)' "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c"

actual_game="$(git -C "${UPSTREAM}" rev-parse HEAD)"
actual_framework="$(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
if [[ "${actual_game}" != "${GAME_COMMIT}" || "${actual_framework}" != "${FRAMEWORK_COMMIT}" ]]; then
  echo "ERROR: upstream pin verification failed." >&2
  echo "Game: ${actual_game}" >&2
  echo "Framework: ${actual_framework}" >&2
  exit 1
fi

echo
echo "Pinned game:      ${actual_game}"
echo "Pinned framework: ${actual_framework}"
echo "Android Java layer, OpenBIOS assets and ARMv7/GLES compatibility patches: present"
echo "No disc image, retail BIOS dump, or generated game C was downloaded."
echo "Next, generate from your own matching disc with:"
echo "  bash scripts/generate-game.sh /path/to/your/Mega-Man-8.cue"
