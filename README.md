# Terminal styles

A collection of looks for **Windows Terminal**, mostly made for running Claude Code in. Each style is a
small shader (a file that repaints the terminal window) plus a colour scheme.

![The green monitor starburst style](preview/green-monitor-starburst.png)

## The styles

| Style | What it looks like |
| --- | --- |
| [`green-monitor-starburst`](styles/green-monitor-starburst/) | **The default.** An old green monitor: sharp letters with a soft glow, green glass, dark corners, and a faint striped starburst behind the text, drawn as a flower with the rays as petals, with a light that slowly runs down the screen over it. |
| [`green-monitor`](styles/green-monitor/) | The same monitor without a picture: fine scanlines over the whole screen, a lighter band and the rolling light. |
| [`sharp-scanlines`](styles/sharp-scanlines/) | The simplest one: dark scanlines only, letters stay crisp. Pair it with any colour scheme. |

**Swap the picture:** the starburst style will take any picture. Point
`experimental.pixelShaderImagePath` at your own image and the shader turns it green and striped. The
size and position are set at the top of `starburst.hlsl` (`PIC_SIZE`, `PIC_X`, `PIC_Y`).

## Install (green-monitor-starburst)

1. Download or clone this repo somewhere that will stay put.
2. Install the free font [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono)
   (or change the font in step 4 to one you have).
3. Open Windows Terminal → Settings → **Open JSON file**. Make a backup copy of it first.
4. From [`profile-snippet.json`](styles/green-monitor-starburst/profile-snippet.json), paste the
   `profile` into `profiles` → `list` and the `scheme` into `schemes`. Replace `<FOLDER>` with where
   you put this repo, **written with forward slashes** (`C:/Users/you/terminal-styles`).
5. Open a new tab with the **Green Monitor Claude** profile.

**Optional, for Claude Code:** save `claude-theme-robco.json` as `%USERPROFILE%\.claude\themes\robco.json`
and pick the RobCo theme with `/theme`. It draws your own messages on a hidden marker colour, which the
shader finds and turns a yellow-green, so you can tell your lines from Claude's at a glance.

## Tuning

Every number worth changing sits at the top of each `.hlsl` file with a comment saying what it does:
glow strength, how faint the picture is, how fast the light runs down, how dark the corners get.
Save the file and Windows Terminal reloads it straight away.

## Remaking the pictures

- `python tools/make-starburst.py` redraws `starburst.png` (needs Pillow).
- `python tools/make-preview.py` redraws the preview at the top of this page (needs Pillow and NumPy).

## Disclaimer

This is a fan-made set of terminal themes. The starburst and the icons are our own drawings, made in
the spirit of the Claude logo; this project is **not** made by, endorsed by or connected to Anthropic.
Shaders use Windows Terminal's experimental pixel-shader feature, which may change or break in future
updates. If anything here should be credited or removed, the rights holder can open an issue and it
will be fixed quickly.

## Credits

- **Windows Terminal** (Microsoft) for the pixel-shader feature these styles are built on.
- **Share Tech Mono** by Carrois Apostrophe, under the SIL Open Font License.
- Styles designed by Tefa, written by Claude.
