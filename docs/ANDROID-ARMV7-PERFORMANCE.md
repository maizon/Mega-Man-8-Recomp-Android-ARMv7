# Android ARMv7 performance profile

This profile intentionally keeps the shipping ABI at `armeabi-v7a`; it does not add or replace it with ARM64.

## Defaults applied during full-game generation

- PSXRecomp video renderer: `opengl` (the software renderer remains the fallback).
- Projection aspect: `16:9` (experimental per-title widescreen behavior; inspect gameplay, menus, backgrounds and FMVs for clipping or distortion).
- Internal supersampling: `1x` to prioritize frame-time headroom on the Helio G99. Output is still scaled to the Android display; higher internal scales should be selected only after measuring frame pacing.
- Vulkan is not offered to players. The pinned Android framework's Vulkan path is experimental and not sufficiently validated for this title/device. Do not force it as the default or expose it in the launcher merely because the native library compiles.
- ARMv7 NEON code generation is enabled via the Android NDK CMake option.
- The PSXRecomp runtime and generated game C are compiled with `-O3`, without `-ffast-math` or unsafe floating-point transformations.

The video configuration is applied to the ignored pinned upstream checkout by `scripts/generate-game.sh` after the disc identity check and before code generation. The edit is exact-match/idempotent and fails closed if the expected upstream `[video]` block changes.

## Why this does not promise locked 60 FPS

A successful build cannot prove frame pacing on a physical device. The game may be limited by generated CPU code, the PS1 GPU emulation, SDL presentation/vsync, driver behavior, thermal throttling, or title-specific widescreen coverage. A hard-coded 60 FPS cap does not create 60 FPS when the game misses its frame budget and can introduce pacing/audio problems.

## Required device acceptance tests

1. Confirm the startup log selects OpenGL and does not report software fallback.
2. Capture frame-time/FPS after a cold start and after 15 minutes; check throttling.
3. Test title screen, gameplay, bosses/effects, menus, transitions, and every FMV.
4. Compare 4:3 and 16:9 for clipping, missing sprites, UI stretching, and edge gaps.
5. Only then benchmark 2x internal supersampling; retain 1x as the performance-safe baseline if frame times worsen.
6. Keep Vulkan disabled/hidden until the pinned backend's rendering paths are complete and validated on Android. If OpenGL fails to initialize, retain the software fallback rather than crash.

A stable 60 FPS target is a test criterion, not a guarantee inferred from compilation.