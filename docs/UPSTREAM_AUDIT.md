# Upstream audit — 2026-10-17

## Source project

Repository: https://github.com/omegakatana92/Mega-Man-8-Recomp

The current upstream root CMake file:

- Requires CMake 3.20 and C11/C++17.
- Sets `PSXRECOMP_ROOT` to the `psxrecomp` submodule.
- Forces `PSX_LAUNCHER=ON` and `PSX_RECOMP_UI=ON`.
- Includes `psxrecomp/runtime/runtime.cmake`.
- Collects generated game C files from `generated/*_full*.c` and `generated/*_dispatch.c`.
- Adds generated OpenBIOS C files from `bios-generated/`.
- Calls `psxrecomp_add_runtime_target(...)`.
- Adds `NOMINMAX` and `WIN32_LEAN_AND_MEAN` compile definitions, which must be reviewed for non-Windows builds.

The upstream `.gitmodules` declares:
- `psxrecomp` → https://github.com/omegakatana92/psxrecomp.git
- `recomp-ui` → https://github.com/mstan/recomp-ui.git

The game configuration identifies the target as Mega Man 8 USA, product ID `SLUS-00453`, and uses generated recompilation output. The project README says it is playable on its original supported desktop environment, but that is not proof of Android compatibility.

## Android reference

The CTR Native Android project documents SDL3, the `armeabi-v7a` ABI, touchscreen/gamepad input, and user-supplied game assets. We use these as architectural reference points only; the PSXRecomp runtime still needs its own Android adaptation.

## Current state in this repository

The initial commits establish a Gradle/NDK/CMake project, fetch SDL3 in CI, target `armeabi-v7a`, and upload a debug APK artifact. The native entry point is only an SDL3 bring-up shell.

**Not yet implemented:** PSXRecomp runtime linkage, generated Mega Man 8 sources, game launch/configuration, touch controls, game-specific asset picker, graphics/audio parity, and device gameplay tests.

## Required next audit before runtime integration

1. Pin and inspect the exact `psxrecomp` and `recomp-ui` revisions referenced by upstream.
2. Trace the target creation function in `runtime/runtime.cmake` and identify desktop-only source files, compiler flags, dependencies, and platform guards.
3. Determine whether launcher/UI can be disabled or replaced cleanly for Android.
4. Configure SDL3 and all runtime dependencies for Android NDK/ARMv7.
5. Compile generated C sources in manageable CI steps and fix ARMv7/Android-specific assumptions.
6. Add a user-provided disc image/config flow without redistributing game content.
7. Verify the produced APK starts on a real ARMv7 device before claiming gameplay support.


## CTR Native Android architecture review (additional findings)

Reviewed the reference repository's Android Gradle module, manifest, custom Activity, root CMake and Android README.

Useful patterns to adapt:
- Keep SDL3's Android Java bridge in the app source set from the SDL source tree.
- Build the native entry point as a shared library named `main` for the stock SDLActivity loader, and load SDL3 before the app library.
- Link Android platform libraries explicitly; enable OpenGL ES for Android and disable unnecessary SDL subsystems/tests/examples for the port.
- Restrict the Android ABI explicitly. This project intentionally starts with `armeabi-v7a` only, unlike CTR Native's two ABI configuration.
- Use an SDLActivity subclass when game-specific Java behavior (such as file selection and lifecycle integration) is required.

Important differences:
- CTR Native has its own decompiled CTR game source and `platform/native_*` compatibility layer. That layer is not a PSXRecomp runtime and cannot be copied as the Mega Man 8 engine.
- Mega Man 8 Recomp relies on PSXRecomp's runtime, generated C, BIOS HLE/OpenBIOS configuration, and disc/game configuration. Those must be integrated and tested separately.
- CTR's source includes its own memory model and PS1 facade; these assumptions do not automatically match PSXRecomp's runtime contracts.

## Build-cache review

GitHub Actions now caches the SDL3 checkout and Android CMake state (`.cxx`), while `gradle/actions/setup-gradle` manages Gradle dependency/build caches. Gradle is invoked with `--build-cache`. The APK output directory is deliberately not cached, preventing an old APK from being mistaken for the current build output. Cache keys include the host OS, target ABI, SDL version, and relevant Android/CMake source inputs.

This improves repeat-build performance but does not remove the need to download SDK/NDK packages on fresh hosted runners. It also does not prove a successful build; the workflow run must be checked after each CI change.
