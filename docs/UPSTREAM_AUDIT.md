# Upstream and Android build audit — 2026-10-17

## Repositories and revisions

- Game: [omegakatana92/Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), pinned at `e9f808fa40c04592d1d95808c658c460c1c808d9`.
- Android-enabled PSXRecomp framework: [dguillot-gh/psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android), pinned at `58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a`.
- SDL3 3.4.10, pinned at `8e37db5e797b6167f3a00d697d816a684bd259c7`.
- Android integration reference: [dguillot-gh/psx-android](https://github.com/dguillot-gh/psx-android).

## Proven build results before the next workflow revision

Run #36 (commit `c23bb19`) passed the ARMv7 runtime smoke link and shell APK build. The smoke output was an ELF32 ARM `libmain.so` with a global `SDL_main` symbol. The APK contained `libmain.so` and `libc++_shared.so`, both ELF32/ARM. It was uploaded as a debug artifact. The workflow did not test on a physical device.

Run #35 failed at the final runtime shared-library link after compiling 404/405 objects; #36 passed after the source fixes. The full game was not compiled because no game-generated C files were available.

## Android integration choices

- ABI: `armeabi-v7a`, minSdk 26, targetSdk 28.
- Java 17, Gradle 8.9, Android Gradle Plugin 8.7.3.
- SDK platform 35, Build Tools 35.0.0, NDK 27.2.12479018, CMake 3.22.1.
- SDL3 static in `libmain.so`; the shell activity extends SDLActivity and loads only `main`.
- Runtime smoke compiles and links the actual PSXRecomp framework without game-generated C. It is intentionally not represented as a playable game.

## Framework-specific findings

The Android framework has an Android shared-library path that outputs `libmain.so`. Its Java layer provides a launcher/activity and touch/gamepad controls. The desktop-oriented `recomp-ui`, Vulkan and rewind paths are disabled for the initial Android build. The project keeps these settings local to the ignored upstream checkout instead of changing the public upstream repository.

ARMv7-specific fixes are applied to the pinned framework:
- MDEC reduction: AArch64-only `vaddvq_s32` replaced with an ARMv7 four-lane sum under a platform guard.
- OpenXR native-copy: desktop `glReadBuffer` implementation excluded from Android GLES; desktop behavior remains under the non-Android branch.
The preparation script requires one known source block and verifies the result rather than applying ambiguous global substitutions.

## Strict game path

The game configuration identifies Mega Man 8 USA as product ID `SLUS-00453`. The full build requires generated game full/dispatch C and generated OpenBIOS full/dispatch C at the paths consumed by the upstream CMake. The validation script checks the cue's referenced files and the exact track-01 identity configured upstream. Generated sources remain local and ignored.

## Next validation

The updated GitHub Actions workflow splits shell and runtime smoke into independent jobs. The shell job validates APK archive/signature/metadata/ABI/ELF/symbol/dependencies and verifies that strict mode fails closed when game-generated inputs are absent before upload. The runtime job validates the framework shared library and exports a separate non-game artifact. Both results must be checked after the workflow runs. Full-game compilation and device gameplay remain separate milestones.
