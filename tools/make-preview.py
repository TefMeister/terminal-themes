"""Makes preview/green-monitor-starburst.png: a still of what the starburst style looks like.

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
STYLE = os.path.join(HERE, "..", "styles", "green-monitor-starburst")
OUT = os.path.join(HERE, "..", "preview", "green-monitor-starburst.png")

# same numbers as starburst.hlsl
GLASS_TINT = np.array([0.020, 0.070, 0.035])
PIC_GREEN = np.array([0.30, 1.00, 0.50])
PIC_STRENGTH, PIC_CONTRAST, PIC_SIZE = 0.30, 1.4, 0.80
STRIPE_PERIOD, STRIPE_DARKEN = 4.0, 0.55
ROLL_HEIGHT, ROLL_STRENGTH = 0.10, 0.55
VIGNETTE = 1.35

TEXT = [
    "> make the terminal green, please",
    "",
    "* Drawing the starburst picture now.",
    "  Bash(python tools/make-starburst.py)",
    "    wrote styles/green-monitor-starburst/starburst.png",
    "",
    "* Done. Open a new tab to see it.",
]


def main():
    pic = Image.open(os.path.join(STYLE, "starburst.png")).convert("L")
    ph = int(H * PIC_SIZE)
    pic = np.asarray(pic.resize((ph, ph), Image.LANCZOS), dtype=np.float64) / 255
    lum = np.zeros((H, W))
    top, left = (H - ph) // 2, (W - ph) // 2
    lum[top:top + ph, left:left + ph] = np.clip(pic ** PIC_CONTRAST * 1.25, 0, 1)

    y = np.arange(H)[:, None]
    stripe = np.where((y % STRIPE_PERIOD) < STRIPE_PERIOD / 2, 1 - STRIPE_DARKEN, 1.0)
    roll = np.exp(-(((y / H) - ROLL_AT) / ROLL_HEIGHT) ** 2)
    bright = lum * stripe * (PIC_STRENGTH + roll * ROLL_STRENGTH)
    back = GLASS_TINT + PIC_GREEN * bright[..., None]

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
