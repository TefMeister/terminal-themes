"""python tools/make-preview-lanes.py makes preview/green-monitor-lanes.png: a still of what the lanes banner style looks like.

It copies the shader's maths in Python (picture, stripes, rolling light, glass tint,
dark corners) and draws a few lines of sample text on top. Not pixel-exact; close enough
to show the look.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 720
ROLL_AT = 0.42         # where the rolling light is in this still (0 = top, 1 = bottom)
HERE = os.path.dirname(__file__)
STYLE = os.path.join(HERE, "..", "styles", "green-monitor-lanes")
OUT = os.path.join(HERE, "..", "preview", "green-monitor-lanes.png")

# same numbers as lanes.hlsl
GLASS_TINT = np.array([0.020, 0.070, 0.035])
PIC_GREEN = np.array([0.30, 1.00, 0.50])
PIC_STRENGTH, PIC_CONTRAST, EDGE_FADE, SIDE_FADE = 0.20, 1.4, 0.06, 0.04
STRIPE_PERIOD, STRIPE_DARKEN = 4.0, 0.55
ROLL_HEIGHT, ROLL_STRENGTH = 0.10, 0.25
VIGNETTE = 1.35

TEXT = [
    "> make the terminal green, please",
    "",
    "* Putting the Lanes banner behind the text.",
    "  Bash(python tools/make-preview-lanes.py)",
    "    wrote preview/green-monitor-lanes.png",
    "",
    "* Done. Open a new tab to see it.",
]


def main():
    pic = Image.open(os.path.join(STYLE, "lanes.png")).convert("L")   # one dim green, no white
    fit = min(W / pic.width, H / pic.height)          # the whole banner fits inside the window
    pw, ph = int(pic.width * fit), int(pic.height * fit)
    pic = np.asarray(pic.resize((pw, ph), Image.LANCZOS), dtype=np.float64) / 255
    u, v = np.linspace(0, 1, pw), np.linspace(0, 1, ph)
    sm = lambda t: np.clip(t / EDGE_FADE, 0, 1) ** 2 * (3 - 2 * np.clip(t / EDGE_FADE, 0, 1))
    fade = (sm(u) * sm(1 - u))[None, :] * (sm(v) * sm(1 - v))[:, None]
    lum = np.zeros((H, W))
    top, left = (H - ph) // 2, (W - pw) // 2
    lum[top:top + ph, left:left + pw] = np.clip(pic ** PIC_CONTRAST * 1.25, 0, 1) * fade

    y = np.arange(H)[:, None]
    stripe = np.where((y % STRIPE_PERIOD) < STRIPE_PERIOD / 2, 1 - STRIPE_DARKEN, 1.0)
    roll = np.exp(-(((y / H) - ROLL_AT) / ROLL_HEIGHT) ** 2)
    bright = (stripe * (PIC_STRENGTH + roll * ROLL_STRENGTH))[..., None]
    x = np.arange(W)[None, :] / W
    side = np.clip(np.minimum(x, 1 - x) / SIDE_FADE, 0, 1)
    side = (side * side * (3 - 2 * side))[..., None]
    back = (GLASS_TINT + PIC_GREEN * lum[..., None] * bright) * side

    txt = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(txt)
    try:
        font = ImageFont.truetype("consola.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, line in enumerate(TEXT):
        colour = (204, 255, 115) if line.startswith(">") else (140, 242, 168)
        d.text((40, 40 + i * 32), line, fill=colour, font=font)
    text = np.asarray(txt, dtype=np.float64) / 255
    ink = text.max(axis=2, keepdims=True)

    color = text + back * (1 - ink)
    yy, xx = np.mgrid[0:H, 0:W]
    dist = (xx / W - 0.5) ** 2 + (yy / H - 0.5) ** 2
    color *= np.clip(1 - dist * VIGNETTE, 0, 1)[..., None]

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
