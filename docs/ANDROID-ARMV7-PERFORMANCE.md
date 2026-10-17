# Android ARMv7 performance profile

This profile intentionally keeps the shipping ABI at `armeabi-v7a`; it does not add or replace it with ARM64.

## Defaults applied during full-game generation

- PSXRecomp video renderer: `opengl` (the software renderer remains the fallback).
- Projection aspect: `16:9` (experimental per-title widescreen behavior; inspect gameplay, menus, backgrounds and FMVs for clipping or distortion).
- Internal supersampling: `1x` and antialiasing off by default to prioritize frame-time headroom on Mali GPUs. The in-game settings retain `1x`–`4x`, antialiasing, texture filtering and perspective-texturing controls; increase quality one step at a time and re-measure.
- OpenGL ES is the default GPU path. Vulkan is now an explicitly selectable experimental renderer in the in-game menu, compiled with SDL Vulkan support when `glslc` and Vulkan headers are available. Compare both on the target Mali GPU; Vulkan may be faster or slower and is not promoted to default until device tests pass. Software remains available as a compatibility fallback.
- ARMv7 NEON code generation is enabled via the Android NDK CMake option.
- The PSXRecomp runtime and generated game C are compiled with `-O3`, without `-ffast-math` or unsafe floating-point transformations.

The video configuration is applied to the ignored pinned upstream checkout by `scripts/generate-game.sh` after the disc identity check and before code generation. The edit is exact-match/idempotent and fails closed if the expected upstream `[video]` block changes. The Android framework menu patch is applied by `scripts/prepare-upstream.sh` to the ignored pinned checkout; no upstream game/framework sources or game data are committed.

## Why this does not promise locked 60 FPS

A successful build cannot prove frame pacing on a physical device. The game may be limited by generated CPU code, the PS1 GPU emulation, SDL presentation/vsync, driver behavior, thermal throttling, or title-specific widescreen coverage. A hard-coded 60 FPS cap does not create 60 FPS when the game misses its frame budget and can introduce pacing/audio problems.

## Required device acceptance tests

1. Confirm the startup log selects OpenGL and does not report software fallback.
2. Capture frame-time/FPS after a cold start and after 15 minutes; check throttling.
3. Test title screen, gameplay, bosses/effects, menus, transitions, and every FMV.
4. Compare 4:3 and 16:9 for clipping, missing sprites, UI stretching, and edge gaps.
5. Only then benchmark 2x internal supersampling; retain 1x as the performance-safe baseline if frame times worsen.
6. Compare OpenGL ES and Vulkan separately on the same scene, resolution, device temperature and refresh rate. Check startup logs for the actual selected backend; a requested Vulkan mode that was not compiled or cannot initialize must not be counted as a Vulkan test. If a hardware backend fails, retain a working fallback rather than crash.

A stable 60 FPS target is a test criterion, not a guarantee inferred from compilation.