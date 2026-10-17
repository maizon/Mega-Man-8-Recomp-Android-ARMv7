# Android ARMv7 runtime integration findings

Date: 2026-10-17

## Upstream revisions

- Game source: `omegakatana92/Mega-Man-8-Recomp`, commit `e9f808fa40c04592d1d95808c658c460c1c808d9`
- Android-enabled framework: `dguillot-gh/psxrecomp-android`, branch `android`, commit `58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a`
- Game's `recomp-ui` submodule is retained for reference/desktop builds, but the Android-only local CMake patch disables that desktop launcher UI.
- SDL3: release `3.4.10`

The upstream game repository's original `psxrecomp` gitlink points at a framework revision whose runtime helper creates an executable and derives its output name from the desktop window title. That revision is not the right Android integration target. The pinned Android fork contains an explicit `if(ANDROID)` path that builds a shared library and names it `main`, matching SDLActivity's `libmain.so` contract.

## Android build architecture

- SDL3 is built static and linked into `libmain.so`; the Android game activity loads only `main`.
- The Android fork's Java layer supplies a disc picker/start menu, app-private game data, touch pad, and game screen.
- The local upstream game CMake patch disables `PSX_RECOMP_UI`, Vulkan and rewind for Android. The Java launcher replaces the desktop ImGui launcher; software rendering is the initial baseline.
- The real runtime target is compiled with `-O2` even in the debug APK to avoid the extreme slowdown of `-O0` for a CPU-bound static recompilation.
- CMake rejects non-Android builds and non-`armeabi-v7a` ABIs for this app.

## Generation requirements

The game CMake consumes:

- `generated/*_full.c` and/or `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

These files are absent from the public game source tree. `scripts/generate-game.sh` invokes the pinned framework's `psxrecomp_cli.py generate` command using a user-supplied matching `.cue`, verifies that game and OpenBIOS C files were generated, and stages the OpenBIOS files where the game CMake expects them. It does not upload or commit game data.

## CI checks

CI now has two different responsibilities:

1. Build the shell APK, then inspect its packaged native libraries for ELF32 ARM and exported `SDL_main`.
2. Configure, compile and link the actual PSXRecomp runtime against SDL3 using the Android NDK for `armeabi-v7a`, without any generated game C or disc image.

The second check is a meaningful runtime/NDK compatibility test, but it is still not a full game build. The generated game sources may reveal additional ARMv7 compiler, linker or runtime issues.

## Truthful status

A shell APK is not a playable game. A runtime smoke build is not a full game build. The remaining proof is a strict build with generated game/OpenBIOS C, followed by installation and actual gameplay on a physical ARMv7 device. The Android framework's own public notes primarily document testing on a 64-bit device; ARMv7 support must be established by this project's CI and device tests rather than assumed.
