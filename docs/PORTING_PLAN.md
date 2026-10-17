# Android ARMv7 port plan

## Milestone 0 — Build infrastructure
- [x] Create Android Gradle module.
- [x] Restrict native ABI to `armeabi-v7a`.
- [x] Integrate SDL3 Android Java activity and native CMake build shell.
- [x] Add GitHub Actions workflow and APK artifact upload.
- [ ] Confirm the first CI run is green and download/install the shell APK.

## Milestone 1 — Runtime audit
- [ ] Pin upstream game and submodule revisions.
- [ ] Map PSXRecomp target creation, SDL3 setup, CHD/disc dependencies, UI/launcher dependencies, and generated sources.
- [ ] Identify platform-specific calls and compiler flags.
- [ ] Document any dependency that cannot currently build for Android ARMv7.

## Milestone 2 — Runtime integration
- [ ] Replace the SDL shell with the PSXRecomp runtime entry point.
- [ ] Add upstream source as pinned dependencies without silently modifying upstream files.
- [ ] Keep desktop-only launcher/UI code out of the Android target or provide an Android implementation.
- [ ] Compile and link the generated game and OpenBIOS sources.

## Milestone 3 — Android experience
- [ ] Add a file picker for the user's own legally obtained game data.
- [ ] Persist selected data in app-private storage and validate required files.
- [ ] Add configurable touch controls and SDL3 gamepad mapping.
- [ ] Verify audio initialization, lifecycle pause/resume, rendering, and frame pacing.

## Milestone 4 — Verification
- [ ] CI build passes reproducibly.
- [ ] APK ABI and native libraries verified.
- [ ] App launches and loads user-provided data on a physical ARMv7 device.
- [ ] Gameplay and performance tested; limitations documented.
- [ ] Publish a release only after actual runtime testing.

A successful build of the initial SDL shell is an infrastructure milestone only; it is not a playable game port.
