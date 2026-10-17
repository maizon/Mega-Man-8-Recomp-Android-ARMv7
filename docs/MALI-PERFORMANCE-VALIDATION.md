# Mali performance validation

This document separates build correctness from performance claims.

## Change under test

The Android preparation step batches the CPU-to-GPU VRAM upload flush into two texture passes:
1. Convert and upload each exact dirty rectangle to the RGBA staging texture, keeping the staging buffer's row length tightly packed.
2. Upload the same exact rectangles to the raw 16-bit mirror with the VRAM row stride.

Each texture is bound once per flush and unpack row length is set/reset once per pass. No rectangles are unioned, no draw is inserted between the passes, and the renderer still flushes pending geometry before changing VRAM. This is intended to reduce redundant GL state changes on mobile drivers; the actual FPS impact must be measured on device.

## Required A/B procedure

1. Build the baseline and optimized revisions with the same Android SDK/NDK, Release flags, game data, device, driver, display refresh rate, and thermal state.
2. Use the same game scene and repeat each run at least three times after a warm-up. Record frame-time median and 95th percentile, sustained FPS, CPU time, GPU time when available, upload rectangle count/area, upload conversion time, texture-upload time, and sync/readback counts.
3. Keep internal resolution at 1x, OpenGL ES, nearest filtering, and antialiasing off for the primary comparison. Test higher scales separately.
4. Confirm the title boots and test gameplay, VRAM transfers, transparency/mask behavior, audio, FMV, save/load, and at least 15 minutes of sustained play.
5. Reject the change if graphics differ, stability regresses, or repeated measurements show no benefit. Do not infer a performance gain from a successful compilation.

## Safety constraints

- Never remove readbacks or waits without proving the caller does not require current VRAM.
- Do not move GL calls to a worker thread unless the context and synchronization design explicitly supports it.
- Keep generated game code, disc images, and other proprietary game data out of commits and public artifacts.
- CI packaging checks prove APK integrity and ABI inclusion only; they do not replace physical-device tests.

The CI job also verifies that the preparation script applies this patch idempotently to the pinned framework before compiling either ABI.
