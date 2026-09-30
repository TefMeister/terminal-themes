"""Adds four temporary "Preview: ..." profiles to Windows Terminal, one per style, for recording
the clips; removes them again afterwards.

    python add-profiles.py add       backs settings.json up, then adds the profiles
    python add-profiles.py remove    takes them out; the file must end up byte for byte as before

The edit is done on the text of settings.json, so its own layout and comments are left alone.
The aquarium profile points at a copy of aquarium.hlsl with LOOP_SECONDS set, written next to
this script, so the shader in styles/ is never changed.
"""
import os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__)).replace("\\", "/")
REPO = os.path.dirname(os.path.dirname(HERE))
STYLES = REPO + "/styles/"
SETTINGS = os.path.expandvars(
    r"%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
BACKUP = SETTINGS + ".bak-preview-clips"
LOOP_SHADER = HERE + "/aquarium-loop.hlsl"
LOOP_SECONDS = 32
TEXT = HERE + "/sample-text.py"
BEGIN = "            // BEGIN preview-clip profiles (temporary)\n"
END = "            // END preview-clip profiles (temporary)\n"


def profile(name, scheme, font, size, shader, image=None, cursor="bar", args="typing 18"):
    p = f'''            {{
                "name": "{name}",
                "commandline": "python \\"{TEXT}\\" {args}",
                "closeOnExit": "always",
                "colorScheme": "{scheme}",
                "cursorShape": "{cursor}",
                "padding": "16",
                "font": {{ "face": "{font}", "size": {size} }},
                "experimental.pixelShaderPath": "{shader}"'''
    if image:
        p += f',\n                "experimental.pixelShaderImagePath": "{image}"'
    return p + "\n            },\n"


BLOCK = BEGIN + "".join([
    profile("Preview: green-monitor-starburst", "RobCo", "Share Tech Mono", 14,
            STYLES + "green-monitor-starburst/starburst.hlsl",
            STYLES + "green-monitor-starburst/starburst.png", "filledBox"),
    profile("Preview: green-monitor", "RobCo", "Share Tech Mono", 14,
            STYLES + "green-monitor/robco.hlsl", None, "filledBox"),
    profile("Preview: sharp-scanlines", "Campbell", "Cascadia Code", 13,
            STYLES + "sharp-scanlines/sharp-scanlines.hlsl", None, "bar", "typing 12"),
    profile("Preview: aquarium", "Aquarium", "Cascadia Code", 13,
            LOOP_SHADER, STYLES + "aquarium/aquarium-sheet.png", "bar", "static"),
]) + END


def write_loop_shader():
    src = open(STYLES + "aquarium/aquarium.hlsl", encoding="utf-8").read()
    out, n = re.subn(r"(LOOP_SECONDS\s*=\s*)0\.0;", rf"\g<1>{LOOP_SECONDS}.0;", src, count=1)
    assert n == 1, "LOOP_SECONDS not found in aquarium.hlsl"
    open(LOOP_SHADER, "w", encoding="utf-8").write(out)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    raw = open(SETTINGS, "rb").read()
    if mode == "add":
        assert BEGIN.encode() not in raw, "already added"
        write_loop_shader()
        shutil.copyfile(SETTINGS, BACKUP)
        m = re.search(rb'"list":\s*\[\s*\n', raw)
        assert m, "profiles list not found in settings.json"
        open(SETTINGS, "wb").write(raw[:m.end()] + BLOCK.encode("utf-8") + raw[m.end():])
        print("added 4 preview profiles; backup at", BACKUP)
    elif mode == "remove":
        a, b = raw.find(BEGIN.encode()), raw.find(END.encode())
        assert a >= 0 and b > a, "preview block not found"
        out = raw[:a] + raw[b + len(END):]
        open(SETTINGS, "wb").write(out)
        same = out == open(BACKUP, "rb").read()
        print("removed; settings.json identical to the backup:", same)
        if same:
            os.remove(BACKUP)
        if os.path.exists(LOOP_SHADER):
            os.remove(LOOP_SHADER)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
