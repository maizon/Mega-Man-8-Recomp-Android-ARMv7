# Android ARMv7 port plan

## Current verified status (2026-10-17)

- [x] Create Android Gradle module.
- [x] Restrict native ABI to `armeabi-v7a`.
- [x] Integrate SDL3 Android Java activity and native CMake build shell.
- [x] GitHub Actions builds a debug APK and uploads an artifact.
- [x] Build run #12 completed the APK build, existence check, and artifact upload.
- [ ] Verify the APK on a physical ARMv7 device.
- [ ] Verify the new CI check confirms the APK contains 32-bit ARM native libraries only.

The successful APK is still a **SDL3 shell**, not a playable game. The current `main.cpp` only initializes SDL, creates a fullscreen window, and polls events.

## Milestone 1 — Runtime audit

- [x] Inspect upstream game's root CMake and game configuration.
- [x] Identify upstream submodules: `psxrecomp` and `recomp-ui`.
- [x] Inspect Android reference project `dguillot-gh/psxrecomp-android` and orchestration repo `dguillot-gh/psx-android`.
- [x] Review `Simon358/ctr-native-android` as an Android/SDL3/ARMv7 structural reference.
- [ ] Pin upstream game and submodule revisions in this repository.
- [ ] Map all PSXRecomp target dependencies and platform-specific sources/options.
- [ ] Determine the minimum dependency set that can compile under Android NDK/ARMv7.

### Findings and constraints

1. Upstream game's CMake includes `psxrecomp/runtime/runtime.cmake` and calls `psxrecomp_add_runtime_target`. It collects `generated/*_full*.c`, `generated/*_dispatch.c`, and OpenBIOS generated C files. These sources are absent from this Android scaffold and need to be generated from a user-provided matching game dump using the upstream tooling.
2. Upstream forces `PSX_LAUNCHER=ON` and `PSX_RECOMP_UI=ON`. Those defaults must not be carried over blindly; Android needs an intentional launcher/UI strategy.
3. The Android-focused fork has SDL3 compatibility wrappers and an extensive runtime, but its orchestration documentation reports testing on a 64-bit Android device. That is useful architectural evidence, not proof that its current branch builds or runs on `armeabi-v7a`.
4. The framework runtime CMake pulls in multiple dependency modules (including CHD, OpenXR, overlays, and netplay). Android integration should disable unsupported/unused features explicitly and avoid fetching host-only dependencies where possible.
5. CTR Native demonstrates useful Android activity, SDL loading, input, and packaging patterns, but its game-specific native compatibility layer is not a replacement for PSXRecomp's runtime.

## Milestone 2 — Runtime integration

- [ ] Replace the SDL shell with the PSXRecomp runtime entry point.
- [ ] Add upstream source as pinned dependencies without silently modifying upstream files.
- [ ] Keep desktop-only launcher/UI code out of the Android target or provide an Android implementation.
- [ ] Compile and link the generated game and OpenBIOS sources.
- [ ] Confirm compiler flags and generated C compile safely for 32-bit ARM (including 32-bit pointer/size assumptions).

## Milestone 3 — Android experience

- [ ] Add a file picker for the user's own legally obtained game data.
- [ ] Persist selected data in app-private storage and validate required files.
- [ ] Add configurable touch controls and SDL3 gamepad mapping.
- [ ] Verify audio initialization, lifecycle pause/resume, rendering, and frame pacing.

## Milestone 4 — Verification

- [x] CI build passes reproducibly for the SDL3 shell.
- [ ] CI verifies APK ABI and native libraries.
- [ ] APK installs and launches on a physical ARMv7 device.
- [ ] App loads user-provided data and reaches gameplay.
- [ ] Gameplay and performance tested; limitations documented.
- [ ] Publish a release only after actual runtime testing.

A successful build of the initial SDL shell is an infrastructure milestone only; it is not a playable game port. Do not report a success probability of 99% until a real ARMv7 device test confirms startup and gameplay.
