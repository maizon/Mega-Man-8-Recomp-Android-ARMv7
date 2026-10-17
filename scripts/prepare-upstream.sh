#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${ROOT}/third_party/Mega-Man-8-Recomp"
GAME_URL="https://github.com/omegakatana92/Mega-Man-8-Recomp.git"
FRAMEWORK_URL="https://github.com/dguillot-gh/psxrecomp-android.git"
GAME_COMMIT="e9f808fa40c04592d1d95808c658c460c1c808d9"
FRAMEWORK_COMMIT="58e9fd9cffc582b5e3d4d2357d6a05bba7c1c69a"

if [[ ! -d "${UPSTREAM}/.git" && ! -f "${UPSTREAM}/.git" ]]; then
  if [[ -e "${UPSTREAM}" ]]; then
    echo "ERROR: ${UPSTREAM} exists but is not a Git checkout; refusing to overwrite it." >&2
    exit 1
  fi
  mkdir -p "${ROOT}/third_party"
  git clone --no-recurse-submodules "${GAME_URL}" "${UPSTREAM}"
fi

git -C "${UPSTREAM}" remote set-url origin "${GAME_URL}"
git -C "${UPSTREAM}" fetch origin "${GAME_COMMIT}"
git -C "${UPSTREAM}" checkout --detach "${GAME_COMMIT}"

# The original framework gitlink is not Android-ready. Pin the audited Android
# fork locally; no framework source or game data is copied into this repository.
if [[ -d "${UPSTREAM}/psxrecomp/.git" || -f "${UPSTREAM}/psxrecomp/.git" ]]; then
  git -C "${UPSTREAM}/psxrecomp" remote set-url origin "${FRAMEWORK_URL}"
  git -C "${UPSTREAM}/psxrecomp" fetch origin android
  git -C "${UPSTREAM}/psxrecomp" fetch origin "${FRAMEWORK_COMMIT}"
  git -C "${UPSTREAM}/psxrecomp" checkout --detach "${FRAMEWORK_COMMIT}"
else
  if [[ -L "${UPSTREAM}/psxrecomp" || -e "${UPSTREAM}/psxrecomp" ]]; then
    if [[ ! -d "${UPSTREAM}/psxrecomp" ]] ||
       [[ -n "$(find "${UPSTREAM}/psxrecomp" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      echo "ERROR: ${UPSTREAM}/psxrecomp exists without Git metadata and is not empty; refusing to delete it." >&2
      exit 1
    fi
    rmdir "${UPSTREAM}/psxrecomp"
  fi
  git clone --branch android --single-branch "${FRAMEWORK_URL}" "${UPSTREAM}/psxrecomp"
  git -C "${UPSTREAM}/psxrecomp" checkout --detach "${FRAMEWORK_COMMIT}"
fi

git -C "${UPSTREAM}/psxrecomp" submodule sync --recursive
git -C "${UPSTREAM}/psxrecomp" submodule update --init --recursive
git -C "${UPSTREAM}" submodule update --init recomp-ui

# All source patches are local to this ignored checkout. Each patch requires
# one exact upstream match (or one exact already-patched match); ambiguity fails.
python3 - "${UPSTREAM}/CMakeLists.txt" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = 'set(PSX_LAUNCHER ON CACHE BOOL "" FORCE)\nset(PSX_RECOMP_UI ON CACHE BOOL "" FORCE)'
new = '''set(PSX_LAUNCHER ON CACHE BOOL "" FORCE)
if(ANDROID)
    set(PSX_RECOMP_UI OFF CACHE BOOL "" FORCE)
    set(PSX_ENABLE_VULKAN ON CACHE BOOL "" FORCE)
    set(PSX_REWIND OFF CACHE BOOL "" FORCE)
else()
    set(PSX_RECOMP_UI ON CACHE BOOL "" FORCE)
endif()'''

if source.count(new) == 1:
    print("Android CMake options already patched exactly once.")
elif source.count(old) == 1:
    patched = source.replace(old, new, 1)
    if patched.count(new) != 1 or patched.count(old) != 0:
        raise SystemExit("ERROR: Android CMake option patch did not validate.")
    path.write_text(patched, encoding="utf-8")
    print("Patched Android CMake options in the local upstream checkout.")
else:
    raise SystemExit(
        f"ERROR: expected exactly one known CMake block; old={source.count(old)}, patched={source.count(new)}. Refusing an unsafe patch."
    )
PY

# vaddvq_s32 is AArch64-only; ARMv7 NEON sums the same four lanes explicitly.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/mdec.c" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = "    return vaddvq_s32(vaddq_s32(lo, hi));"
new = '''    int32x4_t sum = vaddq_s32(lo, hi);
#if defined(__aarch64__)
    return vaddvq_s32(sum);
#else
    return vgetq_lane_s32(sum, 0) + vgetq_lane_s32(sum, 1) +
           vgetq_lane_s32(sum, 2) + vgetq_lane_s32(sum, 3);
#endif'''

if source.count(new) == 1:
    print("ARMv7 MDEC NEON reduction already patched exactly once.")
elif source.count(old) == 1:
    patched = source.replace(old, new, 1)
    if patched.count(new) != 1 or patched.count(old) != 0:
        raise SystemExit("ERROR: ARMv7 NEON patch did not validate.")
    path.write_text(patched, encoding="utf-8")
    print("Patched AArch64-only MDEC NEON reduction for ARMv7.")
else:
    raise SystemExit(
        f"ERROR: expected exactly one known MDEC reduction; old={source.count(old)}, patched={source.count(new)}. Refusing an unsafe patch."
    )
PY

# Android GLESv2 lacks desktop glReadBuffer. OpenXR is disabled for this target.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
start_signature = "static int openxr_copy_native("
end_signature = "\nstatic void openxr_present_native(void) {"
if source.count(start_signature) != 1 or source.count(end_signature) != 1:
    raise SystemExit(
        "ERROR: expected exactly one OpenXR native-copy function and following present function; refusing an unsafe patch."
    )
start = source.find(start_signature)
end = source.find(end_signature, start)
block = source[start:end]

if "#if defined(__ANDROID__)" in block:
    if block.count("#if defined(__ANDROID__)") != 1 or "glReadBuffer" not in block:
        raise SystemExit("ERROR: existing Android OpenXR guard is ambiguous or incomplete.")
    print("Android OpenXR GLES guard already present exactly once.")
else:
    if "glReadBuffer" not in block:
        raise SystemExit("ERROR: expected desktop glReadBuffer call not found in native-copy function.")
    brace = block.find("{")
    close = block.rfind("}")
    if brace < 0 or close < brace:
        raise SystemExit("ERROR: could not parse OpenXR native-copy function.")
    signature = block[:brace + 1]
    body = block[brace + 1:close]
    replacement = signature + '''
#if defined(__ANDROID__)
    (void)eye;
    (void)texture;
    (void)w;
    (void)h;
    return 0;
#else
''' + body + '''
#endif
}
'''
    patched = source[:start] + replacement + source[end:]
    patched_start = patched.find(start_signature)
    patched_end = patched.find(end_signature, patched_start)
    patched_block = patched[patched_start:patched_end]
    if patched_block.count("#if defined(__ANDROID__)") != 1 or "glReadBuffer" not in patched_block:
        raise SystemExit("ERROR: OpenXR Android guard failed post-patch validation.")
    path.write_text(patched, encoding="utf-8")
    print("Disabled the desktop OpenXR native-copy path on Android GLES.")

PY

# Mali-focused renderer controls: expose both hardware backends while preserving software fallback.
python3 - "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxMenu.java" "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxGameActivity.java" <<'PY'
from pathlib import Path
import re
import sys

menu_path, activity_path = map(Path, sys.argv[1:])
menu = menu_path.read_text(encoding="utf-8")
new_menu = r'''String renderer = video.getOrDefault("renderer", "\"opengl\"");'''
if new_menu not in menu:
    menu, count = re.subn(
        r'(?m)^[ \t]*(?:boolean gpu[ \t]*=.*?;|String renderer[ \t]*=.*?;)[ \t]*$',
        new_menu, menu, count=1)
    if count != 1:
        raise SystemExit("ERROR: expected one renderer selection declaration")

new_choices = r'''String[][] rchoices = {
            { "OpenGL ES (recommended)", "\"opengl\"" },
            { "Vulkan (experimental)", "\"vulkan\"" }
        };'''
if new_choices not in menu:
    menu, count = re.subn(r'String\s*\[\s*\]\s*\[\s*\]\s*rchoices\s*=\s*(?:new\s+String\s*\[\s*\]\s*\[\s*\]\s*)?\{.*?\};',
                          lambda _: new_choices, menu, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("ERROR: expected one renderer choice list")

new_selected = 'TextView b = chip(rchoices[i][0], renderer.equals(value));'
if new_selected not in menu:
    menu, count = re.subn(
        r'TextView b = chip\(rchoices\[i\]\[0\],[^;]*\);',
        lambda _: new_selected, menu, count=1)
    if count != 1:
        raise SystemExit("ERROR: expected one renderer selected-state expression")
if "Vulkan (experimental)" not in menu or "vulkan" not in menu or 'renderer.equals(value)' not in menu:
    raise SystemExit("ERROR: renderer menu failed post-patch validation")
menu_path.write_text(menu, encoding="utf-8")

activity = activity_path.read_text(encoding="utf-8")
old_call = 'wantsGpu(toml) ? "opengl" : "software"'
if old_call in activity:
    activity = activity.replace(old_call, 'renderer(toml)')
elif 'renderer(toml)' not in activity:
    raise SystemExit("ERROR: expected renderer argument selection in PsxGameActivity")
new_method = r'''private static String renderer(File toml) {
        try {
            String s = new String(java.nio.file.Files.readAllBytes(toml.toPath()),
                    java.nio.charset.StandardCharsets.UTF_8);
            java.util.regex.Matcher m = java.util.regex.Pattern
                    .compile("(?m)^\\s*renderer\\s*=\\s*\\\"(software|opengl|vulkan)\\\"")
                    .matcher(s);
            if (m.find()) return m.group(1);
        } catch (java.io.IOException e) {
            // Keep the known-safe software fallback if settings cannot be read.
        }
        return "software";
    }'''
if 'private static String renderer(File toml)' not in activity:
    start_sig = "private static boolean wantsGpu(File toml) {"
    end_sig = "\n    @Override\n    protected void onCreate(Bundle state) {"
    if activity.count(start_sig) != 1 or activity.count(end_sig) != 1:
        raise SystemExit("ERROR: expected unique renderer method boundaries")
    start = activity.find(start_sig)
    end = activity.find(end_sig, start)
    if end <= start:
        raise SystemExit("ERROR: renderer method boundaries are out of order")
    activity = activity[:start] + new_method + "\n\n" + activity[end:]
if 'wantsGpu(' in activity or activity.count('renderer(toml)') < 2:
    raise SystemExit("ERROR: PsxGameActivity renderer parsing failed post-patch validation")
activity_path.write_text(activity, encoding="utf-8")
print("Enabled selectable Software/OpenGL ES/Vulkan renderer modes in the local Android framework.")
PY


# Vulkan diagnostics + conservative Android transform selection.  Identity is
# preferred only when explicitly supported; otherwise use the surface's required
# transform. Log real window/pixel/surface dimensions to diagnose portrait-sized
# swapchains without spamming per-frame logs.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_vk_renderer.c" <<'PYVK'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old_transform = "    ci.preTransform = caps.currentTransform;"
new_transform = """    /* Prefer identity when the surface supports it: this keeps the rendered
     * landscape viewport in native swapchain coordinates and avoids applying
     * an implicit 90-degree transform on Android. If unsupported, honor the
     * transform required by the surface. */
    VkSurfaceTransformFlagBitsKHR selected_transform = caps.currentTransform;
    if (caps.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR)
        selected_transform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    ci.preTransform = selected_transform;
    int logical_w = 0, logical_h = 0, pixel_w = 0, pixel_h = 0;
    SDL_GetWindowSize(s_win, &logical_w, &logical_h);
#if defined(PSX_SDL3)
    SDL_GetWindowSizeInPixels(s_win, &pixel_w, &pixel_h);
#else
    SDL_Vulkan_GetDrawableSize(s_win, &pixel_w, &pixel_h);
#endif
    fprintf(stdout,
            "psxrecomp: Vulkan surface diag logical=%dx%d pixels=%dx%d "
            "capsExtent=%ux%u swapExtent=%ux%u currentTransform=0x%x "
            "supportedTransforms=0x%x selectedPreTransform=0x%x minExtent=%ux%u maxExtent=%ux%u\\n",
            logical_w, logical_h, pixel_w, pixel_h,
            caps.currentExtent.width, caps.currentExtent.height,
            ext.width, ext.height, (unsigned)caps.currentTransform,
            (unsigned)caps.supportedTransforms, (unsigned)selected_transform,
            caps.minImageExtent.width, caps.minImageExtent.height,
            caps.maxImageExtent.width, caps.maxImageExtent.height);"""
if source.count(new_transform) == 1:
    print("Vulkan transform diagnostics already patched.")
elif source.count(old_transform) == 1:
    source = source.replace(old_transform, new_transform, 1)
    path.write_text(source, encoding="utf-8")
    print("Patched Vulkan transform selection and swapchain diagnostics.")
else:
    raise SystemExit(f"Expected one preTransform assignment, found {source.count(old_transform)}")
PYVK



# Log the actual present viewport/scissor once (not every frame) so a small
# Vulkan image can be distinguished from a surface/swapchain extent problem.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_vk_renderer.c" <<'PYVP'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
start_sig = "static int pp_draw("
end_sig = "\nint vk_renderer_present_vram("
if source.count(start_sig) != 1 or source.count(end_sig) != 1:
    raise SystemExit("ERROR: could not uniquely locate Vulkan present pass for viewport diagnostics")
start = source.find(start_sig)
end = source.find(end_sig, start)
if end <= start:
    raise SystemExit("ERROR: Vulkan present pass boundaries are out of order")
block = source[start:end]
old = "    p_vkCmdSetViewport(cb, 0, 1, &view);\n    p_vkCmdSetScissor(cb, 0, 1, &sci);"
new = old + """
    static int s_present_diag_logged;
    if (!s_present_diag_logged) {
        s_present_diag_logged = 1;
        fprintf(stdout,
                "psxrecomp: Vulkan present diag swapExtent=%ux%u viewport=(%.0f,%.0f %.0fx%.0f) "
                "scissor=(%d,%d %ux%u) dst=(%d,%d)-(%d,%d)\\n",
                s_sc_extent.width, s_sc_extent.height,
                view.x, view.y, view.width, view.height,
                sci.offset.x, sci.offset.y, sci.extent.width, sci.extent.height,
                dst[0].x, dst[0].y, dst[1].x, dst[1].y);
    }"""
if block.count(new) == 1:
    print("Vulkan viewport/scissor diagnostics already patched.")
elif block.count(old) == 1:
    block = block.replace(old, new, 1)
    source = source[:start] + block + source[end:]
    path.write_text(source, encoding="utf-8")
    print("Added one-time Vulkan viewport/scissor diagnostics.")
else:
    raise SystemExit(f"ERROR: expected one viewport/scissor pair in pp_draw; found {block.count(old)}")
PYVP

# Presets only touch keys that the pinned runtime already consumes. These are
# not live performance switches: the menu already explains that video settings
# apply after a game restart.
python3 - "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxMenu.java" <<'PYPRESET'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
anchor = '''        toggle(list, "Smooth textures", "Bilinear filtering instead of blocky pixels.",
                "\\\"bilinear\\\"".equals(video.get("texture_filtering")),
                on -> setVideo("texture_filtering", on ? "\\\"bilinear\\\"" : "\\\"nearest\\\""));'''
insert = anchor + '''
        section(list, "Performance presets");
        list.addView(label("Presets", "Choose a real combination of supported video settings. Restart the game to apply."));
        LinearLayout presets = new LinearLayout(activity);
        String[][] presetChoices = {
            { "Max FPS", "max" }, { "Performance", "performance" },
            { "Balanced", "balanced" }, { "Quality", "quality" }
        };
        for (int i = 0; i < presetChoices.length; i++) {
            final String preset = presetChoices[i][1];
            TextView b = chip(presetChoices[i][0], false);
            b.setOnClickListener(v -> applyPreset(preset));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, px(44), 1);
            lp.setMargins(i == 0 ? 0 : px(5), px(6), 0, px(4));
            presets.addView(b, lp);
        }
        list.addView(presets);'''
if "Performance presets" not in source:
    if source.count(anchor) != 1:
        raise SystemExit(f"Expected one texture-filter toggle anchor; found {source.count(anchor)}")
    source = source.replace(anchor, insert, 1)

method_anchor = '''    /** Set one [video] key (raw TOML value), keeping every other line as it was. */
    private void setVideo(String key, String value) {'''
method = '''    /** Apply a preset using only settings understood by the pinned runtime. */
    private void applyPreset(String preset) {
        switch (preset) {
            case "max":
                setVideo("renderer", "\\\"opengl\\\"");
                setVideo("supersampling", "1");
                setVideo("antialiasing", "false");
                setVideo("texture_filtering", "\\\"nearest\\\"");
                setVideo("perspective_texturing", "false");
                setVideo("aspect_ratio", "\\\"16:9\\\"");
                break;
            case "performance":
                setVideo("renderer", "\\\"opengl\\\"");
                setVideo("supersampling", "1");
                setVideo("antialiasing", "false");
                setVideo("texture_filtering", "\\\"nearest\\\"");
                setVideo("perspective_texturing", "false");
                setVideo("aspect_ratio", "\\\"4:3\\\"");
                break;
            case "balanced":
                setVideo("renderer", "\\\"opengl\\\"");
                setVideo("supersampling", "1");
                setVideo("antialiasing", "false");
                setVideo("texture_filtering", "\\\"bilinear\\\"");
                setVideo("perspective_texturing", "true");
                setVideo("aspect_ratio", "\\\"16:9\\\"");
                break;
            case "quality":
                setVideo("renderer", "\\\"opengl\\\"");
                setVideo("supersampling", "2");
                setVideo("antialiasing", "true");
                setVideo("texture_filtering", "\\\"bilinear\\\"");
                setVideo("perspective_texturing", "true");
                setVideo("aspect_ratio", "\\\"4:3\\\"");
                break;
            default:
                return;
        }
        android.widget.Toast.makeText(activity, "Preset saved. Restart the game to apply.",
                android.widget.Toast.LENGTH_SHORT).show();
    }

''' + method_anchor
if "private void applyPreset(String preset)" not in source:
    if source.count(method_anchor) != 1:
        raise SystemExit(f"Expected one setVideo method anchor; found {source.count(method_anchor)}")
    source = source.replace(method_anchor, method, 1)

if "Performance presets" not in source or "private void applyPreset(String preset)" not in source:
    raise SystemExit("Preset menu post-validation failed")
path.write_text(source, encoding="utf-8")
print("Added four presets built only from existing [video] runtime keys.")
PYPRESET


# Reduce redundant GL texture binds and pixel-store changes in CPU->GPU VRAM
# synchronization. Converted RGBA rects and raw R16UI rects are independent
# textures; upload them in two passes before any draw, preserving dirty rects,
# command ordering, and exact VRAM contents.
python3 - "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c" <<'PYUPLOAD'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
start_anchor = "    /* Stage every rect's CPU data first (texture uploads outside the FBO"
end_anchor = "    /* Quads into the hr FBO; two passes split by bit15"
if source.count(start_anchor) != 1 or source.count(end_anchor) != 1:
    raise SystemExit("ERROR: expected one CPU-upload staging block; refusing unsafe optimization.")
start = source.index(start_anchor)
end = source.index(end_anchor, start)
old = source[start:end]
if "GPU texture upload batching: upload converted rects first" in old:
    print("GPU texture upload batching already patched exactly once.")
else:
    new = """    /* GPU texture upload batching: upload converted rects first.
     * The RGBA staging buffer is reused per rect, so those uploads remain in
     * this loop. The independent raw mirror can be uploaded in a second pass:
     * no draw or CPU VRAM mutation occurs between the passes. Binding each
     * texture once and setting unpack row length once removes redundant driver
     * state changes without merging dirty rects or changing PS1 command order. */
    glBindTexture(GL_TEXTURE_2D, s_up_tex);
    glPixelStorei(PSXGL_UNPACK_ROW_LENGTH, 0);
    for (int i = 0; i < nrects; i++) {
        int x = rects[i].x0, y = rects[i].y0;
        int w = rects[i].x1 - rects[i].x0 + 1;
        int h = rects[i].y1 - rects[i].y0 + 1;
        if (diag) s_rt_up_diag[2] += (uint64_t)w * (uint64_t)h;
        coh_record(GL_COH_FLUSH, x, y, x + w - 1, y + h - 1);

        /* RGBA8 staging for the hr quad draw. */
        uint64_t t0 = diag ? SDL_GetPerformanceCounter() : 0;
        for (int row = 0; row < h; row++) {
            const uint16_t *src = s_vram + (size_t)(y + row) * VRAM_W + x;
            uint32_t *dst = s_conv + (size_t)row * w;
            for (int col = 0; col < w; col++) dst[col] = conv_1555_to_rgba8(src[col]);
        }
        if (diag) s_rt_up_diag[3] += SDL_GetPerformanceCounter() - t0;
        t0 = diag ? SDL_GetPerformanceCounter() : 0;
        glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, s_conv);
        if (diag) s_rt_up_diag[4] += SDL_GetPerformanceCounter() - t0;
    }

    /* Raw mirror takes CPU data directly. All rects use the VRAM row stride. */
    glBindTexture(GL_TEXTURE_2D, s_raw_tex);
    glPixelStorei(PSXGL_UNPACK_ROW_LENGTH, VRAM_W);
    for (int i = 0; i < nrects; i++) {
        int x = rects[i].x0, y = rects[i].y0;
        int w = rects[i].x1 - rects[i].x0 + 1;
        int h = rects[i].y1 - rects[i].y0 + 1;
        uint64_t t0 = diag ? SDL_GetPerformanceCounter() : 0;
        glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h,
                        PSXGL_RED_INTEGER, GL_UNSIGNED_SHORT,
                        s_vram + (size_t)y * VRAM_W + x);
        if (diag) s_rt_up_diag[4] += SDL_GetPerformanceCounter() - t0;
    }
    glPixelStorei(PSXGL_UNPACK_ROW_LENGTH, 0);

"""
    source = source[:start] + new + source[end:]
    if source.count("GPU texture upload batching: upload converted rects first") != 1:
        raise SystemExit("ERROR: optimized upload block post-validation failed.")
    path.write_text(source, encoding="utf-8")
    print("Optimized CPU->GPU VRAM uploads: batched texture binds and pixel-store state.")
PYUPLOAD

python3 "${ROOT}/scripts/patch-android-ui.py"

test -s "${UPSTREAM}/psxrecomp/runtime/runtime.cmake"
test -s "${UPSTREAM}/psxrecomp/runtime/android/java/com/psxrecomp/android/PsxGameActivity.java"
test -s "${UPSTREAM}/psxrecomp/bios/openbios.bin"
test -s "${UPSTREAM}/psxrecomp/bios/OpenBIOS.LICENSE"
grep -Fq 'vgetq_lane_s32(sum, 3)' "${UPSTREAM}/psxrecomp/runtime/src/mdec.c"
grep -Fq '#if defined(__ANDROID__)' "${UPSTREAM}/psxrecomp/runtime/src/gpu_gl_renderer.c"

actual_game="$(git -C "${UPSTREAM}" rev-parse HEAD)"
actual_framework="$(git -C "${UPSTREAM}/psxrecomp" rev-parse HEAD)"
if [[ "${actual_game}" != "${GAME_COMMIT}" || "${actual_framework}" != "${FRAMEWORK_COMMIT}" ]]; then
  echo "ERROR: upstream pin verification failed." >&2
  echo "Game: ${actual_game}" >&2
  echo "Framework: ${actual_framework}" >&2
  exit 1
fi

echo
echo "Pinned game:      ${actual_game}"
echo "Pinned framework: ${actual_framework}"
echo "Android Java layer, OpenBIOS assets and ARMv7/GLES compatibility patches: present"
echo "No disc image, retail BIOS dump, or generated game C was downloaded."
echo "Next, generate from your own matching disc with:"
echo "  bash scripts/generate-game.sh /path/to/your/Mega-Man-8.cue"
