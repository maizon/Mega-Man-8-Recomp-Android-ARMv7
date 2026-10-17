# Android ARMv7 runtime integration findings

Date: 2026-10-17

## Exact upstream pins audited

The public Mega Man 8 Recomp repository's audited `main` tree points to:

- Game source: `omegakatana92/Mega-Man-8-Recomp`, commit `e9f808fa40c04592d1d95808c658c460c1c808d9`
- `psxrecomp` submodule: `omegakatana92/psxrecomp`, commit `001ea94717874704a925b85be9739265e0d60477`
- `recomp-ui` submodule: `mstan/recomp-ui`, commit `655d77d5858aa677f88e7b19cd70460773a17476`
- SDL3 version required by the pinned PSXRecomp dependency manifest: `3.4.10`

These are upstream audit references. The Android repository does not vendor the game checkout or its generated outputs.

## Corrected runtime finding

The pinned `psxrecomp/runtime/runtime.cmake` **does** contain an `if(ANDROID)` path that creates a shared runtime target and sets its output name to `main`. The earlier note that it only creates a desktop executable was incorrect; that claim has been corrected here.

The remaining integration work is not solved merely by calling the upstream CMake file. We must ensure that:
- the Android app uses the same SDL3 version as the runtime (3.4.10);
- SDL3 is built as a shared library for the SDL Android Java bridge;
- the actual game and OpenBIOS generated C sources exist;
- the upstream runtime's dependencies and UI compile with the Android NDK;
- the final ARMv7 APK starts and can reach gameplay on a physical device.

## Generated inputs required for the real game

The upstream game CMake expects:

- `generated/*_full.c` and/or `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

These outputs are not tracked in the public upstream tree snapshot. They must be generated locally through the upstream project using the user's own legally obtained game disc and required tooling. They must not be fabricated or silently omitted while calling the result playable.

## Implementation added in this repository

The Android CMake file now has two explicit modes:

1. **Real runtime mode:** if a local upstream checkout and all required generated game/OpenBIOS files are present, it builds SDL3 3.4.10 as a shared library, adds the upstream game CMake project, and checks that the runtime target outputs `libmain.so`.
2. **Bring-up shell mode:** if those inputs are missing, it builds only the SDL shell and emits a prominent CMake warning. Set `MM8_REQUIRE_GAME_RUNTIME=ON` to make missing game inputs a hard configuration error instead of allowing the shell build.

This distinction is important: the CI shell APK is only a toolchain/ABI test, not a playable game.

## ARMv7 verification requirements

A successful Android/ARM64 build or successful CMake configure is not evidence of 32-bit ARM support. The generated game code and all native dependencies must compile for `armeabi-v7a`; APK inspection must verify ELF32 ARM libraries; startup, controls, audio/video, and gameplay must be tested on physical ARMv7 hardware.

## Truthful status

The existing shell APK build has succeeded in GitHub Actions. The real runtime path is now wired conditionally in CMake, but it has not yet been compiled with the real generated game sources and has not been runtime-tested. No 99.9% success claim is justified until those tests pass.
