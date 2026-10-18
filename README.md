# Mega Man 8 Recomp — Android (ARMv7 + ARM64)

**Maintainer:** Maizon — [GitHub](https://github.com/maizon) · [Instagram](https://instagram.com/maicon_nasciment0)

An experimental Android porting project built around [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), the Android-enabled [PSXRecomp framework](https://github.com/dguillot-gh/psxrecomp-android), and [SDL3](https://github.com/libsdl-org/SDL).

> **Status: experimental.** CI validates the Android shell APK and compiles a runtime smoke target. The shell APK is **not the playable game**. A successful compile or valid APK package does not prove gameplay or acceptable performance on a physical device.

## Important legal and distribution notice

- This repository does **not** include a PlayStation disc image, BIOS, proprietary game assets, or generated game code.
- Mega Man and Mega Man 8 are trademarks/copyrighted works of their respective rights holders. This is an independent, unofficial fan/technical project and is not affiliated with, endorsed by, or sponsored by Capcom.
- To build a full game locally, use only game media you are legally entitled to use. The build scripts validate a local disc image and generate game-derived source files on your machine.
- **Do not commit, upload to Actions artifacts, or publish a release containing a disc image, BIOS, generated proprietary game code, or an APK that redistributes copyrighted game content unless you have explicit authorization from the rights holder.** CI is intentionally limited to the shell/runtime smoke checks.
- No project-wide open-source license is currently granted by this repository. Review the licenses of the upstream projects and dependencies before redistributing or reusing code. See [Third-party notices](docs/THIRD_PARTY_NOTICES.md).

## Current capabilities

- Android package targeting ARMv7 (32-bit ARM/NEON) and ARM64 (64-bit ARMv8).
- Universal shell APK build and package validation in GitHub Actions.
- Pinned Android toolchain and public source revisions for repeatable builds.
- A local-only full-game build path that requires the user's own compatible disc image.
- Performance and graphics investigations documented in [docs/ANDROID-ARMV7-PERFORMANCE.md](docs/ANDROID-ARMV7-PERFORMANCE.md).

### Known limitations

- The CI shell APK is a build/launcher validation artifact, **not a playable Mega Man 8 release**.
- Runtime smoke tests do not include generated game code.
- No claim is made that the game reaches 60 FPS, or that it is playable on every Mali GPU.
- Vulkan and device-specific performance remain experimental. Physical-device testing is required.
- The recent Allwinner H726 report of approximately 1–2 FPS has not yet been diagnosed or resolved. Selecting OpenGL in configuration does not by itself prove that the GL renderer initialized successfully.

## Latest CI artifacts

Open [GitHub Actions](https://github.com/maizon/Mega-Man-8-Recomp-Android-ARMv7/actions) and select a successful run. The shell artifact is named similar to **Universal ARMv7+ARM64 SHELL-debug**. It is intended for package/launcher testing and must not be advertised as a complete playable game.

The latest validated full-game build is not being published as a public release here because its workflow previously fetched game-disc files from a separate release and built a game-derived APK. That automated distribution path is being removed from this branch. A public release must not contain copyrighted game data without authorization.

## Toolchain

- Java/JDK 17
- Gradle 8.9
- Android Gradle Plugin 8.7.3
- Android SDK platform 35 / Build Tools 35.0.0
- Android NDK 27.2.12479018
- CMake 3.22.1
- SDL3 3.4.10, pinned to commit 8e37db5e797b6167f3a00d697d816a684bd259c7

The public game/framework revisions and Android compatibility patches are pinned by scripts/prepare-upstream.sh.

## Build the shell APK

With Java 17, Git, Python 3, Gradle 8.9, Android SDK/NDK, and the required CMake version installed, run from the repository root:

    bash scripts/prepare-upstream.sh
    git clone --depth 1 --branch release-3.4.10 https://github.com/libsdl-org/SDL.git third_party/SDL
    gradle -p android --no-daemon clean assembleDebug

The Android shell build does not require or include game-disc data. GitHub Actions performs additional APK integrity, signature, manifest, native ABI, and entry-point checks.

## Build the full game locally

This optional workflow requires a compatible, legally obtained local disc image. It does not make the result safe to redistribute.

    bash scripts/build-full-android.sh "/path/to/your/Mega Man 8 (USA).cue"

The script validates the cue and referenced track, prepares pinned sources, generates game code locally, requires strict full-game mode, builds the universal APK, and writes a SHA-256 report. Keep the disc image, generated game sources, BIOS data, and any game-derived binaries out of this public repository and its public CI artifacts.

## Repository layout

- .github/workflows/android.yml — public-source shell build and validation.
- scripts/prepare-upstream.sh — pinned upstream checkout and Android patches.
- scripts/generate-game.sh — local disc validation and game-code generation.
- scripts/build-full-android.sh — local strict full-game build driver.
- docs/ — porting, performance, runtime blockers, and dependency notices.

## Credits

- Maizon — Android port integration, build automation, and performance investigation.
- [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp) — upstream recompiler project.
- [PSXRecomp Android framework fork](https://github.com/dguillot-gh/psxrecomp-android) — Android runtime integration.
- [SDL](https://github.com/libsdl-org/SDL) — cross-platform multimedia library.

All upstream authors retain their respective rights. Please consult the upstream repositories and licenses for attribution and redistribution terms.
