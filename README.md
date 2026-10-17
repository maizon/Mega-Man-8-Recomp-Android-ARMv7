# Mega Man 8 Recomp — Android ARMv7

Android porting project for [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), using the Android-enabled [PSXRecomp framework fork](https://github.com/dguillot-gh/psxrecomp-android).

> **Current proven state:** workflow run #36 built the Android shell APK and separately compiled/linked the PSXRecomp runtime for 32-bit ARM. The shell is not the game; the runtime smoke artifact contains no generated Mega Man 8 game code. New CI splits these checks into independent jobs and validates the APK's package metadata, signature, ZIP structure, ABI and native entry point.

## Target and pinned toolchain

- Android ABI: `armeabi-v7a` (32-bit ARM), minimum API 26
- Java/JDK: 17; Gradle 8.9; Android Gradle Plugin 8.7.3
- Android SDK platform 35; Build Tools 35.0.0
- Android NDK 27.2.12479018; CMake 3.22.1; Ninja 1.11.1.3 (runtime smoke job)
- SDL3 3.4.10, pinned to commit `8e37db5e797b6167f3a00d697d816a684bd259c7`
- The public game and Android-framework source revisions are pinned in `scripts/prepare-upstream.sh`.

## CI jobs

The workflow at [GitHub Actions](https://github.com/maizon/Mega-Man-8-Recomp-Android-ARMv7/actions) has two independent jobs:

1. **android-shell** builds a debug APK without a disc image or generated game C, then checks ZIP integrity, zip alignment, development signature, package ID, min/target SDK, launcher activity, ARMv7 ELF headers, `SDL_main` export and native dependencies. It also runs a negative CMake test to prove strict mode rejects missing generated game/OpenBIOS inputs. The artifact is explicitly named `SHELL-debug`.
2. **android-runtime-smoke** compiles and links the real PSXRecomp runtime against SDL3 for ARMv7 without game-generated C. It publishes a separate `RUNTIME-SMOKE-NOT-GAME` library/report artifact. It is not an APK and not a playable game.

Both jobs use a clean CMake/native build directory, fixed tool versions and pinned action commit SHAs. The shell job does not depend on the runtime job. The workflow supports push, pull request and manual `workflow_dispatch`.

## Build the shell locally

From the repository root, with Git, Python 3, Bash, Java 17, Gradle 8.9 and Android SDK/NDK installed:

```bash
bash scripts/prepare-upstream.sh
git clone --depth 1 --branch release-3.4.10 https://github.com/libsdl-org/SDL.git third_party/SDL
gradle -p android --no-daemon --no-build-cache clean assembleDebug
```

The CI uses the exact SDL commit listed above and verifies it after checkout. `prepare-upstream.sh` pins the game/framework sources and applies validated Android-only patches to the ignored `third_party/Mega-Man-8-Recomp/` checkout. It does not download a disc image or generated game C.

## One-command full-game Android build (requires the user's own legal disc)

Run the build driver to prepare pinned public sources, validate the matching disc, generate game code locally, compile in strict mode, and verify the final ARMv7 APK. It refuses to silently fall back to the shell and keeps generated copyrighted sources local.

```bash
bash scripts/build-full-android.sh "/path/to/your/Mega Man 8 (USA).cue"
```

The script expects Java 17, Git, Python 3, Gradle 8.9, and an Android SDK/NDK configured in the environment. It verifies the game/framework/SDL source pins, strict-mode result, APK signature, package metadata, ARMv7 ELF headers and exported `SDL_main`, then writes a SHA-256 build report under `android/app/build/mm8-final-build-report.txt`. It still does not prove physical-device gameplay.

## Prepare the full game build (requires the user's own legal disc)

The pinned game configuration targets **Mega Man 8 USA, product ID SLUS-00453**. The generator script first verifies that every file referenced by the supplied `.cue` exists and that track 01's size, SHA-1 and MD5 match the identity values in the pinned upstream `game.toml`.

```bash
bash scripts/generate-game.sh "/path/to/your/Mega Man 8 (USA).cue"
gradle -p android --no-daemon -PMM8_REQUIRE_GAME_RUNTIME=true clean assembleDebug
```

The script invokes the upstream-supported `psxrecomp_cli.py generate` command, validates non-empty game/OpenBIOS C outputs, and stages OpenBIOS C at the location expected by the game CMake. Disc files and generated copyrighted game sources remain local and ignored; do not upload them to public repositories, CI artifacts or logs.

Strict mode verifies the exact pinned source revisions and rejects missing or empty generated C inputs. It never silently falls back to the shell when `MM8_REQUIRE_GAME_RUNTIME=ON`.

## What is not yet proven

- The shell APK is build-validated by CI, but it has not been claimed as installed on a physical ARMv7 device.
- Runtime smoke proves native compilation/linking of the framework without generated game C, not full-game compilation.
- A complete game requires the matching local disc, generated sources, a strict full build, installation and real gameplay checks on compatible hardware.
- No honest 99.9% playability guarantee is possible before those tests pass.
