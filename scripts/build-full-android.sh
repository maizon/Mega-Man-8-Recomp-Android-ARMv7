#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${ROOT}/third_party/Mega-Man-8-Recomp"
SDL_ROOT="${ROOT}/third_party/SDL"
SDL_URL="https://github.com/libsdl-org/SDL.git"
SDL_TAG="release-3.4.10"
SDL_COMMIT="8e37db5e797b6167f3a00d697d816a684bd259c7"
APK="${ROOT}/android/app/build/outputs/apk/debug/app-debug.apk"

usage() {
  echo "Usage: bash scripts/build-full-android.sh /path/to/your/legal/Mega-Man-8.cue" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi
if [[ ! -f "$1" ]]; then
  echo "ERROR: supplied disc cue does not exist: $1" >&2
  exit 2
fi

for cmd in git python3 java gradle bash sha256sum unzip awk readelf; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 2
  fi
done

echo "== 1/5: Prepare pinned public sources and Android compatibility patches =="
bash "${ROOT}/scripts/prepare-upstream.sh"

echo
echo "== 2/5: Verify pinned SDL3 source =="
if [[ ! -d "${SDL_ROOT}/.git" ]]; then
  if [[ -e "${SDL_ROOT}" ]]; then
    echo "ERROR: ${SDL_ROOT} exists but is not a Git checkout; refusing to overwrite it." >&2
    exit 1
  fi
  git clone --depth 1 --branch "${SDL_TAG}" "${SDL_URL}" "${SDL_ROOT}"
fi
actual_sdl="$(git -C "${SDL_ROOT}" rev-parse HEAD)"
if [[ "${actual_sdl}" != "${SDL_COMMIT}" ]]; then
  echo "ERROR: SDL pin mismatch; expected ${SDL_COMMIT}, got ${actual_sdl}." >&2
  echo "Move the local checkout aside and rerun to obtain the audited release." >&2
  exit 1
fi
test -s "${SDL_ROOT}/CMakeLists.txt"

echo
echo "== 3/5: Validate the disc and generate local game sources =="
bash "${ROOT}/scripts/generate-game.sh" "$1"

echo
echo "== 4/5: Build strict ARMv7 game APK (shell fallback prohibited) =="
gradle -p "${ROOT}/android" --no-daemon --no-build-cache \
  -PMM8_REQUIRE_GAME_RUNTIME=true clean assembleDebug

echo
echo "== 5/5: Verify final APK and real-game launcher =="
if [[ ! -s "${APK}" ]]; then
  echo "ERROR: Gradle reported success but the APK is missing or empty." >&2
  exit 1
fi
APK_SHA256="$(sha256sum "${APK}" | awk '{print $1}')"
unzip -t "${APK}" >/dev/null
unzip -Z1 "${APK}" > "${ROOT}/android/app/build/mm8-final-apk-files.txt"
APK_FILES="${ROOT}/android/app/build/mm8-final-apk-files.txt"
for abi in armeabi-v7a arm64-v8a; do
  grep -Fxq "lib/${abi}/libmain.so" "${APK_FILES}"
  grep -Fxq "lib/${abi}/libc++_shared.so" "${APK_FILES}"
done
if grep -Eq '^lib/(x86|x86_64|riscv64)/' "${APK_FILES}"; then
  echo "ERROR: unexpected non-ARM native ABI in final APK." >&2
  exit 1
fi
if grep -Eq '^lib/(armeabi-v7a|arm64-v8a)/libSDL3[.]so
  echo "ERROR: SDL3 should be statically linked into libmain.so." >&2
  exit 1
fi
NATIVE_DIR="${ROOT}/android/app/build/mm8-final-native"
rm -rf "${NATIVE_DIR}"
mkdir -p "${NATIVE_DIR}"
for abi in armeabi-v7a arm64-v8a; do
  mkdir -p "${NATIVE_DIR}/${abi}"
  unzip -jo "${APK}" "lib/${abi}/*.so" -d "${NATIVE_DIR}/${abi}"
  test -s "${NATIVE_DIR}/${abi}/libmain.so"
  for lib in "${NATIVE_DIR}/${abi}"/*.so; do
    header="$(readelf -h "${lib}")"
    if [[ "${abi}" == "armeabi-v7a" ]]; then
      grep -Eq 'Class:.*ELF32' <<< "${header}"
      grep -Eq 'Machine:.*ARM' <<< "${header}"
    else
      grep -Eq 'Class:.*ELF64' <<< "${header}"
      grep -Eq 'Machine:.*AArch64' <<< "${header}"
    fi
  done
  readelf --dyn-syms -W "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynsyms.txt"
  grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  readelf -d "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynamic.txt"
  if grep -Fq 'libSDL3.so' "${NATIVE_DIR}/${abi}/dynamic.txt"; then
    echo "ERROR: libmain.so has an unexpected dynamic SDL3 dependency." >&2
    exit 1
  fi
done

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "${SDK_ROOT}" ]]; then
  echo "ERROR: set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK directory." >&2
  exit 2
fi
BUILD_TOOLS="${SDK_ROOT}/build-tools/35.0.0"
for tool in aapt apksigner zipalign; do
  if [[ ! -x "${BUILD_TOOLS}/${tool}" ]]; then
    echo "ERROR: required Android Build Tool is missing: ${BUILD_TOOLS}/${tool}" >&2
    exit 2
  fi
done
"${BUILD_TOOLS}/zipalign" -c -v 4 "${APK}"
"${BUILD_TOOLS}/apksigner" verify --verbose --print-certs "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apksigner.txt"
"${BUILD_TOOLS}/aapt" dump badging "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "package: name='com.maizon.megaman8recomp'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "sdkVersion:'26'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "targetSdkVersion:'28'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "launchable-activity: name='com.psxrecomp.android.LauncherActivity'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"

REPORT="${ROOT}/android/app/build/mm8-final-build-report.txt"
{
  echo "Result: PASS — strict Mega Man 8 Android universal ARMv7 + ARM64 APK build."
  echo "This report proves compilation/package validation for both ARM ABIs, not physical-device gameplay."
  echo "APK: ${APK}"
  echo "APK SHA-256: ${APK_SHA256}"
  echo "Game source pin: $(git -C "${UPSTREAM}" rev-parse HEAD)"
  echo "Framework pin: $(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
  echo "SDL pin: ${actual_sdl}"
  echo
  echo "APK signature:"
  cat "${ROOT}/android/app/build/mm8-final-apksigner.txt"
  echo
  echo "Native libraries and OpenBIOS assets:"
  grep -E '^lib/(armeabi-v7a|arm64-v8a)/.*\.so$|^assets/bios/' "${ROOT}/android/app/build/mm8-final-apk-files.txt"
  echo
  echo "Exported SDL_main:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  done
  echo
  echo "Native dynamic dependencies:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    cat "${NATIVE_DIR}/${abi}/dynamic.txt"
  done
  if [[ -x "${BUILD_TOOLS}/aapt" ]]; then
    echo
    echo "Package and launcher:"
    grep -E '^(package:|sdkVersion:|targetSdkVersion:|launchable-activity:)' "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
  fi
} | tee "${REPORT}"

echo
echo "FINAL APK: ${APK}"
echo "SHA-256:   ${APK_SHA256}"
echo "REPORT:    ${REPORT}"
 "${APK_FILES}"; then
  echo "ERROR: SDL3 should be statically linked into libmain.so." >&2
  exit 1
fi
NATIVE_DIR="${ROOT}/android/app/build/mm8-final-native"
rm -rf "${NATIVE_DIR}"
mkdir -p "${NATIVE_DIR}"
for abi in armeabi-v7a arm64-v8a; do
  mkdir -p "${NATIVE_DIR}/${abi}"
  unzip -jo "${APK}" "lib/${abi}/*.so" -d "${NATIVE_DIR}/${abi}"
  test -s "${NATIVE_DIR}/${abi}/libmain.so"
  for lib in "${NATIVE_DIR}/${abi}"/*.so; do
    header="$(readelf -h "${lib}")"
    if [[ "${abi}" == "armeabi-v7a" ]]; then
      grep -Eq 'Class:.*ELF32' <<< "${header}"
      grep -Eq 'Machine:.*ARM' <<< "${header}"
    else
      grep -Eq 'Class:.*ELF64' <<< "${header}"
      grep -Eq 'Machine:.*AArch64' <<< "${header}"
    fi
  done
  readelf --dyn-syms -W "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynsyms.txt"
  grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  readelf -d "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynamic.txt"
  if grep -Fq 'libSDL3.so' "${NATIVE_DIR}/${abi}/dynamic.txt"; then
    echo "ERROR: libmain.so has an unexpected dynamic SDL3 dependency." >&2
    exit 1
  fi
done

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "${SDK_ROOT}" ]]; then
  echo "ERROR: set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK directory." >&2
  exit 2
fi
BUILD_TOOLS="${SDK_ROOT}/build-tools/35.0.0"
for tool in aapt apksigner zipalign; do
  if [[ ! -x "${BUILD_TOOLS}/${tool}" ]]; then
    echo "ERROR: required Android Build Tool is missing: ${BUILD_TOOLS}/${tool}" >&2
    exit 2
  fi
done
"${BUILD_TOOLS}/zipalign" -c -v 4 "${APK}"
"${BUILD_TOOLS}/apksigner" verify --verbose --print-certs "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apksigner.txt"
"${BUILD_TOOLS}/aapt" dump badging "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "package: name='com.maizon.megaman8recomp'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "sdkVersion:'26'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "targetSdkVersion:'28'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "launchable-activity: name='com.psxrecomp.android.LauncherActivity'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"

REPORT="${ROOT}/android/app/build/mm8-final-build-report.txt"
{
  echo "Result: PASS — strict Mega Man 8 Android universal ARMv7 + ARM64 APK build."
  echo "This report proves compilation/package validation for both ARM ABIs, not physical-device gameplay."
  echo "APK: ${APK}"
  echo "APK SHA-256: ${APK_SHA256}"
  echo "Game source pin: $(git -C "${UPSTREAM}" rev-parse HEAD)"
  echo "Framework pin: $(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
  echo "SDL pin: ${actual_sdl}"
  echo
  echo "APK signature:"
  cat "${ROOT}/android/app/build/mm8-final-apksigner.txt"
  echo
  echo "Native libraries and OpenBIOS assets:"
  grep -E '^lib/(armeabi-v7a|arm64-v8a)/.*\.so$|^assets/bios/' "${ROOT}/android/app/build/mm8-final-apk-files.txt"
  echo
  echo "Exported SDL_main:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  done
  echo
  echo "Native dynamic dependencies:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    cat "${NATIVE_DIR}/${abi}/dynamic.txt"
  done
  if [[ -x "${BUILD_TOOLS}/aapt" ]]; then
    echo
    echo "Package and launcher:"
    grep -E '^(package:|sdkVersion:|targetSdkVersion:|launchable-activity:)' "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
  fi
} | tee "${REPORT}"

echo
echo "FINAL APK: ${APK}"
echo "SHA-256:   ${APK_SHA256}"
echo "REPORT:    ${REPORT}"
 "${APK_FILES}"; then
  echo "ERROR: SDL3 should be statically linked into libmain.so." >&2
  exit 1
fi
NATIVE_DIR="${ROOT}/android/app/build/mm8-final-native"
rm -rf "${NATIVE_DIR}"
mkdir -p "${NATIVE_DIR}"
for abi in armeabi-v7a arm64-v8a; do
  mkdir -p "${NATIVE_DIR}/${abi}"
  unzip -jo "${APK}" "lib/${abi}/*.so" -d "${NATIVE_DIR}/${abi}"
  test -s "${NATIVE_DIR}/${abi}/libmain.so"
  for lib in "${NATIVE_DIR}/${abi}"/*.so; do
    header="$(readelf -h "${lib}")"
    if [[ "${abi}" == "armeabi-v7a" ]]; then
      grep -Eq 'Class:.*ELF32' <<< "${header}"
      grep -Eq 'Machine:.*ARM' <<< "${header}"
    else
      grep -Eq 'Class:.*ELF64' <<< "${header}"
      grep -Eq 'Machine:.*AArch64' <<< "${header}"
    fi
  done
  readelf --dyn-syms -W "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynsyms.txt"
  grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  readelf -d "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynamic.txt"
  if grep -Fq 'libSDL3.so' "${NATIVE_DIR}/${abi}/dynamic.txt"; then
    echo "ERROR: libmain.so has an unexpected dynamic SDL3 dependency." >&2
    exit 1
  fi
done

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "${SDK_ROOT}" ]]; then
  echo "ERROR: set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK directory." >&2
  exit 2
fi
BUILD_TOOLS="${SDK_ROOT}/build-tools/35.0.0"
for tool in aapt apksigner zipalign; do
  if [[ ! -x "${BUILD_TOOLS}/${tool}" ]]; then
    echo "ERROR: required Android Build Tool is missing: ${BUILD_TOOLS}/${tool}" >&2
    exit 2
  fi
done
"${BUILD_TOOLS}/zipalign" -c -v 4 "${APK}"
"${BUILD_TOOLS}/apksigner" verify --verbose --print-certs "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apksigner.txt"
"${BUILD_TOOLS}/aapt" dump badging "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "package: name='com.maizon.megaman8recomp'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "sdkVersion:'26'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "targetSdkVersion:'28'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "launchable-activity: name='com.psxrecomp.android.LauncherActivity'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"

REPORT="${ROOT}/android/app/build/mm8-final-build-report.txt"
{
  echo "Result: PASS — strict Mega Man 8 Android universal ARMv7 + ARM64 APK build."
  echo "This report proves compilation/package validation for both ARM ABIs, not physical-device gameplay."
  echo "APK: ${APK}"
  echo "APK SHA-256: ${APK_SHA256}"
  echo "Game source pin: $(git -C "${UPSTREAM}" rev-parse HEAD)"
  echo "Framework pin: $(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
  echo "SDL pin: ${actual_sdl}"
  echo
  echo "APK signature:"
  cat "${ROOT}/android/app/build/mm8-final-apksigner.txt"
  echo
  echo "Native libraries and OpenBIOS assets:"
  grep -E '^lib/(armeabi-v7a|arm64-v8a)/.*\.so$|^assets/bios/' "${ROOT}/android/app/build/mm8-final-apk-files.txt"
  echo
  echo "Exported SDL_main:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  done
  echo
  echo "Native dynamic dependencies:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    cat "${NATIVE_DIR}/${abi}/dynamic.txt"
  done
  if [[ -x "${BUILD_TOOLS}/aapt" ]]; then
    echo
    echo "Package and launcher:"
    grep -E '^(package:|sdkVersion:|targetSdkVersion:|launchable-activity:)' "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
  fi
} | tee "${REPORT}"

echo
echo "FINAL APK: ${APK}"
echo "SHA-256:   ${APK_SHA256}"
echo "REPORT:    ${REPORT}"
 "${APK_FILES}"; then
  echo "ERROR: SDL3 should be statically linked into libmain.so." >&2
  exit 1
fi
NATIVE_DIR="${ROOT}/android/app/build/mm8-final-native"
rm -rf "${NATIVE_DIR}"
mkdir -p "${NATIVE_DIR}"
for abi in armeabi-v7a arm64-v8a; do
  mkdir -p "${NATIVE_DIR}/${abi}"
  unzip -jo "${APK}" "lib/${abi}/*.so" -d "${NATIVE_DIR}/${abi}"
  test -s "${NATIVE_DIR}/${abi}/libmain.so"
  for lib in "${NATIVE_DIR}/${abi}"/*.so; do
    header="$(readelf -h "${lib}")"
    if [[ "${abi}" == "armeabi-v7a" ]]; then
      grep -Eq 'Class:.*ELF32' <<< "${header}"
      grep -Eq 'Machine:.*ARM' <<< "${header}"
    else
      grep -Eq 'Class:.*ELF64' <<< "${header}"
      grep -Eq 'Machine:.*AArch64' <<< "${header}"
    fi
  done
  readelf --dyn-syms -W "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynsyms.txt"
  grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  readelf -d "${NATIVE_DIR}/${abi}/libmain.so" > "${NATIVE_DIR}/${abi}/dynamic.txt"
  if grep -Fq 'libSDL3.so' "${NATIVE_DIR}/${abi}/dynamic.txt"; then
    echo "ERROR: libmain.so has an unexpected dynamic SDL3 dependency." >&2
    exit 1
  fi
done

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "${SDK_ROOT}" ]]; then
  echo "ERROR: set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK directory." >&2
  exit 2
fi
BUILD_TOOLS="${SDK_ROOT}/build-tools/35.0.0"
for tool in aapt apksigner zipalign; do
  if [[ ! -x "${BUILD_TOOLS}/${tool}" ]]; then
    echo "ERROR: required Android Build Tool is missing: ${BUILD_TOOLS}/${tool}" >&2
    exit 2
  fi
done
"${BUILD_TOOLS}/zipalign" -c -v 4 "${APK}"
"${BUILD_TOOLS}/apksigner" verify --verbose --print-certs "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apksigner.txt"
"${BUILD_TOOLS}/aapt" dump badging "${APK}" \
  > "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "package: name='com.maizon.megaman8recomp'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "sdkVersion:'26'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "targetSdkVersion:'28'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
grep -Fq "launchable-activity: name='com.psxrecomp.android.LauncherActivity'" "${ROOT}/android/app/build/mm8-final-apk-badging.txt"

REPORT="${ROOT}/android/app/build/mm8-final-build-report.txt"
{
  echo "Result: PASS — strict Mega Man 8 Android universal ARMv7 + ARM64 APK build."
  echo "This report proves compilation/package validation for both ARM ABIs, not physical-device gameplay."
  echo "APK: ${APK}"
  echo "APK SHA-256: ${APK_SHA256}"
  echo "Game source pin: $(git -C "${UPSTREAM}" rev-parse HEAD)"
  echo "Framework pin: $(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
  echo "SDL pin: ${actual_sdl}"
  echo
  echo "APK signature:"
  cat "${ROOT}/android/app/build/mm8-final-apksigner.txt"
  echo
  echo "Native libraries and OpenBIOS assets:"
  grep -E '^lib/(armeabi-v7a|arm64-v8a)/.*\.so$|^assets/bios/' "${ROOT}/android/app/build/mm8-final-apk-files.txt"
  echo
  echo "Exported SDL_main:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    grep -E 'FUNC.*GLOBAL.*SDL_main' "${NATIVE_DIR}/${abi}/dynsyms.txt"
  done
  echo
  echo "Native dynamic dependencies:"
  for abi in armeabi-v7a arm64-v8a; do
    echo "  ABI: ${abi}"
    cat "${NATIVE_DIR}/${abi}/dynamic.txt"
  done
  if [[ -x "${BUILD_TOOLS}/aapt" ]]; then
    echo
    echo "Package and launcher:"
    grep -E '^(package:|sdkVersion:|targetSdkVersion:|launchable-activity:)' "${ROOT}/android/app/build/mm8-final-apk-badging.txt"
  fi
} | tee "${REPORT}"

echo
echo "FINAL APK: ${APK}"
echo "SHA-256:   ${APK_SHA256}"
echo "REPORT:    ${REPORT}"
