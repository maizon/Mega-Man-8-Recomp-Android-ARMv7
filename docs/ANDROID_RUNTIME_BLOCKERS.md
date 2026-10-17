# Android ARMv7 runtime integration findings

Date: 2026-10-17

## Exact upstream pins

The current public Mega Man 8 Recomp repository's `main` tree points to:

- Game source: `omegakatana92/Mega-Man-8-Recomp`, commit `e9f808fa40c04592d1d95808c658c460c1c808d9`
- `psxrecomp` submodule: `omegakatana92/psxrecomp`, commit `001ea94717874704a925b85be9739265e0d60477`
- `recomp-ui` submodule: `mstan/recomp-ui`, commit `655d77d5858aa677f88e7b19cd70460773a17476`

These are audit references, not yet vendored or pinned in this Android repository. Re-check the upstream tree before using them for a build.

## Confirmed Android integration blockers

### 1. The upstream runtime helper creates a desktop executable

In the pinned PSXRecomp runtime helper, `psxrecomp_add_runtime_target(target)` creates the target with `add_executable(...)`. Android's SDL Java bridge in this repository expects a shared native library named `main`, loaded by SDLActivity, with the SDL entry-point contract. Simply including upstream `CMakeLists.txt` in the current Android CMake project will not produce the required Android library.

**Required engineering change:** introduce an explicit Android target path (or a carefully maintained local patch to the runtime target helper) that builds the runtime and generated game sources into the expected shared library and preserves SDLActivity's entry-point/lifecycle contract. Do not rename an executable target and assume this is solved.

### 2. Desktop UI and platform dependencies are not optional by accident

The game's top-level CMake forces `PSX_LAUNCHER=ON` and `PSX_RECOMP_UI=ON`. The runtime helper includes desktop-oriented window, input, renderer, networking, and dependency logic. The Android target must explicitly disable or replace unsupported UI and host-only integrations; otherwise CMake may find desktop OpenGL or platform libraries inappropriate for Android.

### 3. Generated game code is absent from this repository

The upstream game CMake expects source files matching:

- `generated/*_full.c` and `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

These outputs are not tracked in the upstream tree snapshot. The Android project must not silently report a game build success while these inputs are absent. The existing SDL3 shell build does not compile any of them.

### 4. ARMv7 needs separate proof

An Android/ARM64 build or a successful CMake configure is not evidence of 32-bit ARM support. Generated code and native dependencies must compile for `armeabi-v7a`; final APK inspection must verify ELF32 ARM libraries; runtime startup and gameplay must be tested on a physical 32-bit ARM device.

## Safe implementation order

1. Keep the current shell APK as an infrastructure test only.
2. Add a separate Android runtime target design instead of forcing the desktop executable target into the Android Gradle build.
3. Pin upstream source/submodule revisions in the integration build.
4. Disable or replace desktop-only UI/features explicitly and document each setting.
5. Build the runtime with a small compile-only fixture before requiring game-generated C.
6. Add a user-provided game-data workflow and generated source checks.
7. Verify actual game startup and gameplay on ARMv7 hardware.

## Truthful status

The existing shell APK build is confirmed by GitHub Actions. The real PSXRecomp runtime is not yet integrated. This document deliberately does not claim a playable port or a 99% success probability.
