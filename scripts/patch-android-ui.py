#!/usr/bin/env python3
"""Apply deterministic Android UI, renderer-default, and settings patches to pinned upstream."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
upstream = root / "third_party" / "Mega-Man-8-Recomp"
android = upstream / "psxrecomp" / "runtime" / "android" / "java" / "com" / "psxrecomp" / "android"
template = root / "android" / "app" / "src" / "main" / "assets" / "game.toml.in"


def read(path):
    if not path.is_file():
        raise SystemExit(f"ERROR: expected Android source file is missing: {path}")
    return path.read_text(encoding="utf-8")


def write(path, source):
    path.write_text(source, encoding="utf-8")


def replace_once(source, old, new, label):
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"ERROR: {label}: expected one source anchor, found {count}; refusing unsafe patch")
    return source.replace(old, new, 1)


# New installs use OpenGL ES and conservative settings chosen for Mali performance.
source = read(template)
source = replace_once(source, 'renderer = "software"', 'renderer = "opengl"', "OpenGL default")
if "supersampling = 1" not in source:
    source = replace_once(
        source,
        '[video]\nrenderer = "opengl"\n',
        '[video]\nrenderer = "opengl"\nsupersampling = 1\naspect_ratio = "16:9"\nantialiasing = false\ntexture_filtering = "nearest"\nperspective_texturing = false\n',
        "performance defaults",
    )
write(template, source)

# Never select the software renderer from Android. OpenGL is the default; Vulkan is optional.
activity_path = android / "PsxGameActivity.java"
activity = read(activity_path)
activity = activity.replace('wantsGpu(toml) ? "opengl" : "software"', 'renderer(toml)')
method_start = activity.find("private static String renderer(File toml) {")
if method_start < 0:
    method_start = activity.find("private static boolean wantsGpu(File toml) {")
if method_start < 0:
    raise SystemExit("ERROR: PsxGameActivity renderer method anchor not found")
method_end = activity.find("    @Override\n    protected void onCreate(Bundle state) {", method_start)
if method_end < 0:
    raise SystemExit("ERROR: PsxGameActivity renderer method end not found")
renderer_method = r'''private static String renderer(File toml) {
        try {
            String s = new String(java.nio.file.Files.readAllBytes(toml.toPath()),
                    java.nio.charset.StandardCharsets.UTF_8);
            java.util.regex.Matcher m = java.util.regex.Pattern
                    .compile("(?m)^\\s*renderer\\s*=\\s*\\\"(opengl|vulkan)\\\"")
                    .matcher(s);
            if (m.find()) return m.group(1);
        } catch (java.io.IOException e) {
            // OpenGL ES is the reliable default; software rendering is intentionally not selectable.
        }
        return "opengl";
    }

'''
activity = activity[:method_start] + renderer_method + activity[method_end:]
write(activity_path, activity)

# Remove the software choice from the in-game settings too.
menu_path = android / "PsxMenu.java"
menu = read(menu_path)
menu = menu.replace('video.getOrDefault("renderer", "\\"software\\"")', 'video.getOrDefault("renderer", "\\"opengl\\"")')
old_renderer_label = """list.addView(label("Renderer", "GPU draws on the phone's graphics chip: higher resolutions cost "
                + "much less. Experimental; switch back to Software if anything looks wrong."));"""
menu = replace_once(
    menu, old_renderer_label,
    'list.addView(label("Renderer", "OpenGL ES is the default for Mali GPUs. Vulkan is experimental and may not work on every device."));',
    "renderer help",
)
choice_pattern = re.compile(r'String\[\]\[\] rchoices = \{.*?\n        \};', re.S)
new_choices = '''String[][] rchoices = {
            { "OpenGL ES (recommended)", "\\"opengl\\"" },
            { "Vulkan (experimental)", "\\"vulkan\\"" }
        };'''
if new_choices not in menu:
    menu, count = choice_pattern.subn(new_choices, menu, count=1)
    if count != 1:
        raise SystemExit("ERROR: expected one renderer-choice array in PsxMenu.java")
if 'renderer.equals(value)' not in menu:
    menu = replace_once(menu, 'TextView b = chip(rchoices[i][0], (i == 1) == gpu);',
                        'TextView b = chip(rchoices[i][0], renderer.equals(value));',
                        "renderer selected state")
if '"Software"' in menu or '"software"' in menu:
    raise SystemExit("ERROR: software renderer option remains in PsxMenu.java")
write(menu_path, menu)

# Add a real settings dialog to the first screen, before Play, plus Maizon credits/profile.
launcher_path = android / "LauncherActivity.java"
launcher = read(launcher_path)
launcher = replace_once(
    launcher,
    '        resume = new Button(this);\n',
    '''        Button settings = new Button(this);
        settings.setText("Configurações");
        settings.setOnClickListener(v -> showSettings());
        root.addView(settings, button(dp));

        resume = new Button(this);
''',
    "first-screen settings button",
)
launcher = replace_once(
    launcher,
    '        root.addView(hint, wrap());\n\n        setContentView(root);',
    '''        root.addView(hint, wrap());

        TextView credits = new TextView(this);
        credits.setText("Créditos ao Maizon  •  Instagram @maicon_nasciment0");
        credits.setTextColor(0xFF79C7FF);
        credits.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        credits.setGravity(Gravity.CENTER);
        credits.setPadding(0, (int) (14 * dp), 0, (int) (4 * dp));
        credits.setOnClickListener(v -> {
            try {
                startActivity(new Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://www.instagram.com/maicon_nasciment0/")));
            } catch (Exception ignored) {
                // A browser may not be installed; the profile remains visible as text.
            }
        });
        root.addView(credits, wrap());

        setContentView(root);
        applySettingsToGameToml();''',
    "credits and profile link",
)

settings_methods = r'''
    private String settingDefault(String key) {
        switch (key) {
            case "renderer": return "opengl";
            case "supersampling": return "1";
            case "aspect_ratio": return "16:9";
            case "antialiasing": return "false";
            case "texture_filtering": return "nearest";
            case "perspective_texturing": return "false";
            default: return "";
        }
    }

    private void showSettings() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String renderer = prefs.getString("renderer", settingDefault("renderer"));
        String scale = prefs.getString("supersampling", settingDefault("supersampling"));
        String aspect = prefs.getString("aspect_ratio", settingDefault("aspect_ratio"));
        String aa = prefs.getString("antialiasing", settingDefault("antialiasing"));
        String filter = prefs.getString("texture_filtering", settingDefault("texture_filtering"));
        String perspective = prefs.getString("perspective_texturing", settingDefault("perspective_texturing"));
        String[] items = {
            "Renderizador: " + ("vulkan".equals(renderer) ? "Vulkan (experimental)" : "OpenGL ES"),
            "Resolução interna: " + scale + "×",
            "Proporção da tela: " + aspect,
            "Suavização de bordas: " + ("true".equals(aa) ? "Ativada" : "Desativada (mais FPS)"),
            "Filtro de textura: " + ("bilinear".equals(filter) ? "Bilinear" : "Nearest (mais rápido)"),
            "Texturas com perspectiva: " + ("true".equals(perspective) ? "Ativadas" : "Desativadas (mais FPS)")
        };
        new AlertDialog.Builder(this)
                .setTitle("Configurações antes de jogar")
                .setItems(items, (dialog, which) -> {
                    switch (which) {
                        case 0:
                            chooseSetting("Renderizador", new String[]{"OpenGL ES (recomendado)", "Vulkan (experimental)"},
                                    "renderer", new String[]{"opengl", "vulkan"});
                            break;
                        case 1:
                            chooseSetting("Resolução interna", new String[]{"1× — máximo desempenho", "2×", "3×", "4× — mais pesado"},
                                    "supersampling", new String[]{"1", "2", "3", "4"});
                            break;
                        case 2:
                            chooseSetting("Proporção da tela", new String[]{"16:9 — tela cheia", "4:3 — original"},
                                    "aspect_ratio", new String[]{"16:9", "4:3"});
                            break;
                        case 3:
                            chooseSetting("Suavização de bordas", new String[]{"Desativada — mais FPS", "Ativada — bordas suaves"},
                                    "antialiasing", new String[]{"false", "true"});
                            break;
                        case 4:
                            chooseSetting("Filtro de textura", new String[]{"Nearest — mais nítido e rápido", "Bilinear — mais suave"},
                                    "texture_filtering", new String[]{"nearest", "bilinear"});
                            break;
                        case 5:
                            chooseSetting("Texturas com perspectiva", new String[]{"Desativadas — mais desempenho", "Ativadas — perspectiva correta"},
                                    "perspective_texturing", new String[]{"false", "true"});
                            break;
                    }
                })
                .setPositiveButton("Concluído", null)
                .show();
    }

    private void chooseSetting(String title, String[] labels, String key, String[] values) {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String current = prefs.getString(key, settingDefault(key));
        int selected = 0;
        for (int i = 0; i < values.length; i++) {
            if (values[i].equals(current)) { selected = i; break; }
        }
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setSingleChoiceItems(labels, selected, (dialog, which) -> {
                    prefs.edit().putString(key, values[which]).apply();
                    dialog.dismiss();
                    applySettingsToGameToml();
                    showSettings();
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void applySettingsToGameToml() {
        File config = new File(getFilesDir(), "game.toml");
        if (!config.isFile()) return; // Settings can be chosen before importing a game file.
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String renderer = prefs.getString("renderer", "opengl");
        if (!"vulkan".equals(renderer)) renderer = "opengl";
        String scale = prefs.getString("supersampling", "1");
        if (!"1".equals(scale) && !"2".equals(scale) && !"3".equals(scale) && !"4".equals(scale)) scale = "1";
        String aspect = prefs.getString("aspect_ratio", "16:9");
        if (!"4:3".equals(aspect)) aspect = "16:9";
        String aa = "true".equals(prefs.getString("antialiasing", "false")) ? "true" : "false";
        String quote = String.valueOf((char) 34);
        String filter = "bilinear".equals(prefs.getString("texture_filtering", "nearest"))
                ? quote + "bilinear" + quote : quote + "nearest" + quote;
        String perspective = "true".equals(prefs.getString("perspective_texturing", "false")) ? "true" : "false";
        try {
            String source = new String(java.nio.file.Files.readAllBytes(config.toPath()),
                    java.nio.charset.StandardCharsets.UTF_8);
            source = setVideoValue(source, "renderer", quote + renderer + quote);
            source = setVideoValue(source, "supersampling", scale);
            source = setVideoValue(source, "aspect_ratio", quote + aspect + quote);
            source = setVideoValue(source, "antialiasing", aa);
            source = setVideoValue(source, "texture_filtering", filter);
            source = setVideoValue(source, "perspective_texturing", perspective);
            java.nio.file.Files.write(config.toPath(), source.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (IOException e) {
            // Keep the launcher usable; the next settings change can retry writing.
        }
    }

    private static String setVideoValue(String source, String key, String value) {
        Pattern section = Pattern.compile("(?ms)(^\\[video\\][ \\t]*\\R)(.*?)(?=^\\[[^\\r\\n]+\\][ \\t]*$|\\z)");
        Matcher sectionMatch = section.matcher(source);
        if (!sectionMatch.find()) {
            String separator = source.endsWith("\n") ? "" : "\n";
            return source + separator + "\n[video]\n" + key + " = " + value + "\n";
        }
        String body = sectionMatch.group(2);
        Pattern keyLine = Pattern.compile("(?m)^[ \\t]*" + Pattern.quote(key) + "[ \\t]*=.*$");
        Matcher keyMatch = keyLine.matcher(body);
        if (keyMatch.find()) {
            body = keyMatch.replaceFirst(Matcher.quoteReplacement(key + " = " + value));
        } else {
            if (!body.isEmpty() && !body.endsWith("\n")) body += "\n";
            body += key + " = " + value + "\n";
        }
        return source.substring(0, sectionMatch.start(2)) + body + source.substring(sectionMatch.end(2));
    }

'''
if "private void showSettings()" not in launcher:
    launcher = replace_once(
        launcher,
        "    private static LinearLayout.LayoutParams wrap() {",
        settings_methods + "    private static LinearLayout.LayoutParams wrap() {",
        "settings dialog methods",
    )

launcher = replace_once(
    launcher,
    '            PsxFiles.writeText(new File(files, "game.toml"),\n                    fillDiscs(PsxFiles.readAsset(this, "game.toml.in"), discs));\n',
    '            PsxFiles.writeText(new File(files, "game.toml"),\n                    fillDiscs(PsxFiles.readAsset(this, "game.toml.in"), discs));\n            applySettingsToGameToml();\n',
    "apply settings after game import",
)
if 'Créditos ao Maizon' not in launcher or 'showSettings()' not in launcher or 'https://www.instagram.com/maicon_nasciment0/' not in launcher:
    raise SystemExit("ERROR: launcher feature validation failed")
write(launcher_path, launcher)
print("Android UI patches applied: first-screen settings, OpenGL default, no software option, Maizon credits and Instagram.")
