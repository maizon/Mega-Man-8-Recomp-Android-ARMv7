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

# The game's original psxrecomp gitlink is not Android-ready. Pin the audited
# Android runtime fork in that local submodule path; no framework code is copied
# into this repository and no game data is downloaded.
if [[ -d "${UPSTREAM}/psxrecomp/.git" || -f "${UPSTREAM}/psxrecomp/.git" ]]; then
  git -C "${UPSTREAM}/psxrecomp" remote set-url origin "${FRAMEWORK_URL}"
  git -C "${UPSTREAM}/psxrecomp" fetch origin android
  git -C "${UPSTREAM}/psxrecomp" fetch origin "${FRAMEWORK_COMMIT}"
  git -C "${UPSTREAM}/psxrecomp" checkout --detach "${FRAMEWORK_COMMIT}"
else
  # Only remove an empty, uninitialized submodule directory. Never erase an
  # unexpected directory that might contain local work or generated inputs.
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
# Keep the upstream UI submodule available for desktop-side inspection, even
# though the Android CMake patch below disables its desktop launcher target.
git -C "${UPSTREAM}" submodule update --init recomp-ui

# Patch only the local ignored checkout. The Android app has its own Java start
# menu and touch pad, so it must not compile the desktop recomp-ui launcher.
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

if new in source:
    print("Android CMake options already patched.")
elif old in source:
    path.write_text(source.replace(old, new, 1), encoding="utf-8")
    print("Patched Android CMake options in the local upstream checkout.")
else:
    raise SystemExit(
        "ERROR: upstream CMake layout changed; refusing an unsafe automatic patch."
    )
PY

# The pinned framework's NEON dot-product uses vaddvq_s32, an AArch64-only
# intrinsic. ARMv7 NEON has no horizontal add intrinsic with that name, so use
# an equivalent four-lane sum there while preserving the AArch64 fast path.
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

if new in source:
    print("ARMv7 MDEC NEON reduction already patched.")
elif old in source:
    path.write_text(source.replace(old, new, 1), encoding="utf-8")
    print("Patched AArch64-only MDEC NEON reduction for ARMv7.")
else:
    raise SystemExit(
        "ERROR: expected MDEC NEON reduction not found; refusing an unsafe automatic patch."
    )
PY

# OpenXR's desktop back-buffer copier calls glReadBuffer, which is not exported
# by Android GLESv2. OpenXR is disabled for this Android baseline, so keep the
# function signature but compile its desktop implementation out on Android.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
start = source.find("static int openxr_copy_native(")
end = source.find("\nstatic void openxr_present_native", start)
if start < 0 or end < 0:
    raise SystemExit("ERROR: OpenXR native-copy function layout changed; refusing an unsafe patch.")

block = source[start:end]
if "#if defined(__ANDROID__)" in block and "return 0;" in block:
    print("Android OpenXR native-copy guard already patched.")
else:
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
    path.write_text(source[:start] + replacement + source[end:], encoding="utf-8")
    print("Disabled the desktop OpenXR native-copy path on Android GLES.")

PY

test -s "${UPSTREAM}/psxrecomp/runtime/runtime.cmake"
test -s "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxGameActivity.java"
test -s "${UPSTREAM}/psxrecomp/bios/openbios.bin"
test -s "${UPSTREAM}/psxrecomp/bios/OpenBIOS.LICENSE"
grep -q 'vgetq_lane_s32(sum, 3)' "${UPSTREAM}/psxrecomp/runtime/src/mdec.c"
grep -q '#if defined(__ANDROID__)' "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c"

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
