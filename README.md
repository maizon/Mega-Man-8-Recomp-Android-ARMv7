# Mega Man 8 Recomp — Android ARMv7

Independent Android porting effort for [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), using [CTR Native Android](https://github.com/Simon358/ctr-native-android) as an architectural reference.

> **Status: real-runtime integration is in progress; not yet confirmed playable.** GitHub Actions has validated the Android ARMv7 SDL shell. The CMake project now has a guarded path to the upstream PSXRecomp runtime, but it activates only when all required generated game/OpenBIOS C files are present. A successful shell APK is not a playable game.

## Target

- Android ABI: `armeabi-v7a` (32-bit ARM)
- Native build: Android NDK + CMake
- App packaging: Gradle
- CI: GitHub Actions; APK uploaded as a workflow artifact
- SDL3: 3.4.10, matching the audited PSXRecomp dependency pin
- Input goal: touchscreen + physical gamepads
- Game data: users must provide their own legally obtained game dump; no disc image, BIOS dump, or copyrighted game assets are included.

## Build the CI shell

Pushes and pull requests run the Android workflow in **Actions**. When a build succeeds, download the APK from the workflow run's **Artifacts** section.

Unless the real upstream checkout and generated inputs are present, this APK is only an SDL/Android/ARMv7 bring-up shell. It does not run Mega Man 8.

## Prepare and generate the real game

First clone the audited upstream project and initialize its submodules:

```bash
bash scripts/prepare-upstream.sh
```

Then, on a machine with the full legal multi-track disc dump, pass its `.cue` file to the generation script:

```bash
bash scripts/generate-game.sh "/path/to/your/Mega Man 8 (USA).cue"
```

This calls the upstream `psxrecomp_cli.py generate` workflow, which prepares the disc, builds/locates the emitters, generates OpenBIOS, and emits the game C code. The disc and generated sources remain local; the script does not upload them.

The generated files are expected under `third_party/Mega-Man-8-Recomp/`:

- `generated/*_full.c` and/or `generated/*_full_*.c`
- `generated/*_dispatch.c`
- `bios-generated/OpenBIOS_full.c`
- `bios-generated/OpenBIOS_dispatch.c`

The generation script validates these outputs and stops if any required files are missing. Do not create placeholder C files to bypass the checks. Generated game code and disc images are ignored by Git and must not be committed or distributed.

Build in strict mode so Gradle/CMake refuses to fall back to the shell if the game inputs are missing:

```bash
gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true assembleDebug
```

When the real inputs exist, CMake builds SDL3 3.4.10 as a shared library, adds the upstream game project, and verifies that the runtime target's output name is `main` for SDLActivity. This integration path still requires a successful NDK build and real-device gameplay validation.

## Upstream projects

- Game recompilation: https://github.com/omegakatana92/Mega-Man-8-Recomp
- PSXRecomp framework: https://github.com/omegakatana92/psxrecomp
- Android reference: https://github.com/Simon358/ctr-native-android
- SDL: https://github.com/libsdl-org/SDL

## Porting milestones

1. Establish reproducible Android ARMv7 build and artifact upload. **Done for the shell.**
2. Audit upstream CMake, generated sources, PSXRecomp runtime, launcher/UI, and platform assumptions. **Initial audit done.**
3. Integrate SDL3 Android activity and a guarded native runtime path. **CMake path added; real target still needs validation.**
4. Compile the actual PSXRecomp runtime and generated game sources for ARMv7, fixing NDK/compiler incompatibilities.
5. Add/verify user-selected game data, touch/gamepad controls, audio and graphics configuration.
6. Test startup and gameplay on a real ARMv7 device; document issues and performance.

## License and assets

This repository does not distribute game data. Check each upstream project's license and preserve third-party notices before redistributing binaries or source. Mega Man is a trademark of its respective owner; this is an unofficial community project.
