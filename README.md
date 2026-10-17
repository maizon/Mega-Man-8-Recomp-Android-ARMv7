# Mega Man 8 Recomp — Android ARMv7

Android porting project for [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), using the Android-enabled [PSXRecomp framework fork](https://github.com/dguillot-gh/psxrecomp-android) and its shared Android launcher/touch controls.

> **Status: runtime integration is being validated.** CI builds an ARMv7 SDL shell and separately compiles the PSXRecomp runtime for ARMv7 without game code. Neither test alone proves the game is playable. The real game build requires locally generated C from a matching legal disc and a physical-device gameplay test.

## Target and build setup

- Android ABI: `armeabi-v7a` (32-bit ARM)
- Minimum Android API: 26
- Native build: Android NDK 27.2.12479018 + CMake
- SDL3: 3.4.10, statically linked into `libmain.so`
- Java UI: framework-provided start menu, file picker and touch/gamepad overlay
- Game data: supplied by the user; this repository does not contain a disc image or generated game C.

Run these commands from the repository root on a machine with Git, Python 3, Bash, CMake, Ninja and a supported C/C++ toolchain:

```bash
bash scripts/prepare-upstream.sh
bash scripts/generate-game.sh "/path/to/your/Mega Man 8 (USA).cue"
gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug
```

The first script pins the game source and Android-enabled PSXRecomp framework and initializes its public submodules. It applies Android-only CMake settings to the ignored local checkout (disable the desktop recomp-ui launcher, Vulkan and rewind), an ARMv7 compatibility fix for an AArch64-only NEON reduction intrinsic, and a guard around a desktop OpenXR path that references `glReadBuffer` unavailable in Android GLESv2. It does not modify tracked upstream files in this repository.

The second script invokes the pinned framework's supported `psxrecomp_cli.py generate` workflow, validates the game and OpenBIOS outputs, and stages the generated OpenBIOS C files at the path expected by the game's CMake. Generation can download/build the framework's host-side emitters and toolchain. Use a matching USA multi-track `.cue` with its track files.

Generated C, prepared disc data and the framework checkout remain under the ignored `third_party/Mega-Man-8-Recomp/` directory. Do not commit or distribute disc images, generated game C, retail BIOS dumps or APKs containing generated game code.

## CI and strict mode

- GitHub Actions builds a debug ARMv7 shell APK and verifies the ELF architecture and exported `SDL_main` entry point.
- A separate smoke build compiles and links the Android-enabled PSXRecomp runtime for `armeabi-v7a` without generated game code.
- To build the real game, use `-PMM8_REQUIRE_GAME_RUNTIME=true`. This makes CMake fail if the Android framework or generated game/OpenBIOS inputs are missing, rather than silently producing the shell.
- The downloadable CI APK is a development shell, not a playable Mega Man 8 build.

## Upstream projects

- Game recompilation: https://github.com/omegakatana92/Mega-Man-8-Recomp
- Android-enabled PSXRecomp framework: https://github.com/dguillot-gh/psxrecomp-android
- Android build orchestration reference: https://github.com/dguillot-gh/psx-android
- SDL3: https://github.com/libsdl-org/SDL

## Remaining proof required

1. Pass the runtime smoke build for Android ARMv7.
2. Generate the real game C and OpenBIOS sources from the user's matching disc.
3. Compile the full runtime and generated game C in strict mode for `armeabi-v7a`.
4. Install on a physical ARMv7 Android device and verify startup, touch/gamepad input, rendering, audio and actual gameplay.

A 99.9% success claim is not justified until the full generated-game build and device gameplay checks pass.
