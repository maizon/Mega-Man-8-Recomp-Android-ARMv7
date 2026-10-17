# Android ARMv7 runtime integration findings

Date: 2026-10-17

## Exact upstream pins audited

The public Mega Man 8 Recomp repository's audited `main` tree points to:

- Game source: `omegakatana92/Mega-Man-8-Recomp`, commit `e9f808fa40c04592d1d95808c658c460c1c808d9`
- `psxrecomp` submodule: `omegakatana92/psxrecomp`, commit `001ea94717874704a925b85be9739265e0d60477`
- `recomp-ui` submodule: `mstan/recomp-ui`, commit `655d77d5858aa677f88e7b19cd70460773a17476`
- SDL3 version required by the pinned PSXRecomp dependency manifest: `3.4.10`

These are upstream audit references. The Android repository does not vendor the game checkout or its generated outputs.

## Corrected runtime findings

The pinned `psxrecomp/runtime/runtime.cmake` **does** contain an `if(ANDROID)` path that creates a shared runtime target and sets its output name to `main`. The earlier note that it only creates a desktop executable was incorrect; that claim has been corrected here.

The pinned `recomp-ui` CMake helper also has an Android path that links GLESv2/EGL/log and selects the GLES2 ImGui backend. However, its common target definitions include `SDL_MAIN_HANDLED`. SDL3's Android activity calls the exported `SDL_main` symbol, and defining `SDL_MAIN_HANDLED` suppresses the SDL header's normal Android entry-point mapping. The Android CMake integration now removes only that definition from the completed upstream runtime target, preserving the rest of the launcher UI while allowing SDL3's Android header to export `SDL_main`.

That entry-point adjustment is a source-level fix, not yet proof of a successful real-runtime build. It must be confirmed by building with the generated sources and checking the resulting `libmain.so` exports / startup on device.

## Remaining requirements

The integration still must prove that:
- SDL3 native code and the SDL Android Java bridge both use version 3.4.10;
- the actual game and OpenBIOS generated C sources exist and are linked;
- all upstream runtime dependencies compile with the Android NDK for `armeabi-v7a`;
- the final ARMv7 APK starts, accepts input, renders, plays audio, and reaches gameplay on a physical device.

## Generated inputs required for the real game

The upstream game CMake expects:

- `generated/*_full.c` and/or `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

These outputs are not tracked in the public upstream tree snapshot. The added `scripts/generate-game.sh` calls the upstream `psxrecomp_cli.py generate` workflow using a user-supplied legal `.cue`, then stages the generated OpenBIOS C files from the framework submodule's `generated/` directory into the game root's legacy `bios-generated/` directory, which the game's current CMakeLists actually references. It checks that all required outputs exist and exits on a missing file. Generated game code and disc images must not be committed or distributed.

## Implementation added in this repository

The Android CMake file now has two explicit modes:

1. **Real runtime mode:** if a local upstream checkout and all required generated game/OpenBIOS files are present, it builds SDL3 3.4.10 as a shared library, adds the upstream game CMake project, removes the Android-incompatible `SDL_MAIN_HANDLED` definition, and checks that the runtime target outputs `libmain.so`.
2. **Bring-up shell mode:** if those inputs are missing, it builds only the SDL shell and emits a prominent CMake warning. Set `MM8_REQUIRE_GAME_RUNTIME=ON` to make missing game inputs a hard configuration error instead of allowing the shell build.

The CI shell APK is only a toolchain/ABI test, not a playable game.

## ARMv7 verification requirements

A successful Android/ARM64 build or successful CMake configure is not evidence of 32-bit ARM support. The generated game code and all native dependencies must compile for `armeabi-v7a`; APK inspection must verify ELF32 ARM libraries; startup, controls, audio/video, and gameplay must be tested on physical ARMv7 hardware.

## Truthful status

The shell APK build has succeeded in GitHub Actions with SDL3 3.4.10 and ELF32 ARM library checks. The real runtime path is wired conditionally, but it has not yet been compiled with the real generated game sources and has not been runtime-tested. No 99.9% success claim is justified until those tests pass.
