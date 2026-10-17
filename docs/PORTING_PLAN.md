# Android ARMv7 port plan

## Current status

- [x] Create the Android Gradle module and SDL3 ARMv7 shell.
- [x] Pin the game source and Android-enabled PSXRecomp framework.
- [x] Add a local generation script for the user's own matching disc.
- [x] Add the Android framework launcher, touch pad and OpenBIOS asset staging to the app.
- [x] Add strict CMake mode that refuses to silently build the shell as the game.
- [x] Add CI checks for the shell APK's ELF32 ARM libraries and SDL entry point.
- [ ] Pass the new framework runtime smoke build for `armeabi-v7a`.
- [ ] Compile the real generated Mega Man 8 C and OpenBIOS sources for ARMv7.
- [ ] Install and reach gameplay on a physical ARMv7 Android device.

## Key architecture decisions

1. Use the audited game source commit `e9f808fa40c04592d1d95808c658c460c1c808d9`.
2. Use the Android-enabled PSXRecomp framework commit `58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a`, rather than assuming the game's original framework gitlink supports Android.
3. Build SDL3 3.4.10 statically into `libmain.so`, matching the Android framework activity's library-loading contract.
4. Use the framework's Android Java launcher and touch/gamepad layer. Disable the desktop recomp-ui launcher, Vulkan and rewind in the Android-only local CMake patch for the initial baseline.
5. Keep the legal disc, generated game C, prepared disc and generated OpenBIOS C local and ignored by Git.
6. Run a runtime-only ARMv7 smoke build in CI even though the public repository cannot contain the generated copyrighted game code.

## Required local build

```bash
bash scripts/prepare-upstream.sh
bash scripts/generate-game.sh "/path/to/your/Mega Man 8 (USA).cue"
gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug
```

Do not call the result playable until the strict generated-game build succeeds and a physical ARMv7 device reaches gameplay with working controls, video and audio. A 99.9% confidence claim is not supported before those checks.
