# Android ARMv7 build status and runtime blockers

Last audited: 2026-10-17

## Proven baseline

GitHub Actions run [#36](https://github.com/maizon/Mega-Man-8-Recomp-Android-ARMv7/actions/runs/39037651883), commit `c23bb19`, completed successfully. Its runtime smoke step compiled and linked the PSXRecomp runtime to `libmain.so` for `armeabi-v7a`, verified ELF32/ARM and the exported `SDL_main` symbol. The same run produced a debug APK, verified the two packaged native libraries as ELF32/ARM, and uploaded artifact ID `12102972028`.

Run [#35](https://github.com/maizon/Mega-Man-8-Recomp-Android-ARMv7/actions/runs/39037058430) failed at the final link of `libmain.so` after 404 of 405 build actions. The next run, #36, passed the same runtime smoke and symbol checks. This is evidence that the previously reported link failure is resolved for the pinned framework/toolchain; it does not prove full-game linking.

## Pinned sources and tools

- Game source: `omegakatana92/Mega-Man-8-Recomp`, commit `e9f808fa40c04592d1d95808c658c460c1c808d9`
- Android-enabled framework: `dguillot-gh/psxrecomp-android`, commit `58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a`
- SDL3 3.4.10: commit `8e37db5e797b6167f3a00d697d816a684bd259c7`
- JDK 17, Gradle 8.9, Android SDK platform 35, Build Tools 35.0.0, NDK 27.2.12479018, CMake 3.22.1; Ninja 1.11.1.3 for the runtime smoke job.
- Workflow actions are pinned to full commit SHAs.

## Runtime integration

- SDL3 is linked statically into the Android shared library named `libmain.so`.
- The Android framework provides the game activity, launcher, file selection and touch/gamepad UI.
- The local Android CMake setup disables desktop launcher UI, Vulkan and rewind for the baseline and compiles the runtime with `-O2`.
- The original desktop-oriented game/framework CMake configuration is patched only inside the ignored local checkout by `scripts/prepare-upstream.sh`; the script now checks exact source-block counts and post-patch content before accepting the patches.

## ARMv7/GLES compatibility corrections

1. The MDEC NEON reduction used `vaddvq_s32`, which is AArch64-only. The local patch preserves that path for AArch64 and explicitly sums the four lanes for ARMv7.
2. The OpenXR native-copy function called desktop `glReadBuffer`, which is not part of Android GLESv2. The local patch retains the function interface but returns early on Android and preserves the desktop implementation.
3. Both patches are applied only to the pinned ignored framework checkout and are checked for expected function/source matches.

## Strict full-game requirements

The upstream game CMake consumes non-empty:
- `generated/*_full.c` and/or `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

These game-generated files are not committed. `scripts/validate-cue.py` verifies that every cue-referenced track exists and checks track 01's size/SHA-1/MD5 against the pinned USA game configuration. `scripts/generate-game.sh` then invokes the supported upstream generation command and rejects empty outputs. CMake strict mode checks source pins and non-empty C inputs, and fails rather than producing the shell if required inputs are absent.

## CI separation and validation

The revised workflow separates the two independent jobs and runs a strict-mode negative configuration test in the shell job. That test must fail for the documented missing generated inputs and pass only when the expected CMake diagnostic is present.

The workflow separates the two independent jobs:
- **android-shell**: builds and validates a shell APK without ISO/game C; checks ZIP integrity, alignment, debug signature, package ID, min/target SDK, launch activity, ABI, ELF32/ARM, `SDL_main`, C++ runtime dependency and artifact existence.
- **android-runtime-smoke**: builds and links the actual framework runtime for ARMv7 without generated game code; checks the shared library and symbol and publishes a clearly labeled non-game artifact.

The workflow result after this revision must be checked before declaring the revised jobs green. CI cannot install on the user's physical device, and no full-game build has yet been proven.

## Honest completion criteria

A validated shell APK is not a playable game. A successful runtime smoke link is not a full-game build. The remaining evidence is a strict build using the user's matching legal disc, followed by installation and actual gameplay on a physical ARMv7 Android device.
