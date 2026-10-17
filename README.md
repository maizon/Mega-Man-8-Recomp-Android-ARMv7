# Mega Man 8 Recomp — Android ARMv7

Independent Android porting effort for [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), using [CTR Native Android](https://github.com/Simon358/ctr-native-android) as an architectural reference.

> **Status: early porting scaffold. Not yet a playable port.** The first milestone is a reproducible Android ARMv7 build pipeline. PSXRecomp runtime integration, game launch, rendering, audio, input mapping, and real-device validation remain work in progress.

## Target

- Android ABI: `armeabi-v7a` (32-bit ARM)
- Native build: Android NDK + CMake
- App packaging: Gradle
- CI: GitHub Actions; APK uploaded as a workflow artifact
- Input goal: touchscreen + physical gamepads
- Game data: users must provide their own legally obtained game dump; no ROM, BIOS dump, or copyrighted game assets are included.

## Build

Pushes and pull requests run the Android workflow in **Actions**. When a build succeeds, download the APK from the workflow run's **Artifacts** section.

The CI build currently validates the Android application scaffold. It does **not** establish that the game runtime has been ported or that the APK can run Mega Man 8.

## Upstream projects

- Game recompilation: https://github.com/omegakatana92/Mega-Man-8-Recomp
- Android reference: https://github.com/Simon358/ctr-native-android
- SDL: https://github.com/libsdl-org/SDL

## Porting milestones

1. Establish reproducible Android ARMv7 build and artifact upload.
2. Audit upstream CMake, generated sources, PSXRecomp runtime, launcher/UI, and platform assumptions.
3. Integrate SDL3 Android activity and native lifecycle.
4. Port the PSXRecomp runtime and generated game sources, fixing Android/ARMv7 compiler incompatibilities.
5. Add user-selected game data, touch/gamepad controls, audio and graphics configuration.
6. Test startup and gameplay on a real ARMv7 device; document known issues and performance.

## License and assets

This repository does not distribute game data. Check each upstream project's license and preserve third-party notices before redistributing binaries or source. Mega Man is a trademark of its respective owner; this is an unofficial community project.
