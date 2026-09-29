"""Draws the picture used as the terminal background: the starburst as a flower.

Our own drawing, in the spirit of the Claude spark: the same uneven rays, but each ray
is a petal (narrow at the middle, wide and rounded at the end, a vein down the centre)
around a seeded flower heart. Flat 2D, like a drawing, not lit like an object.
Grey on black; the shader turns it green, adds the stripes and the rolling light.

    python tools/make-starburst.py  ->  styles/green-monitor-starburst/starburst.png
"""
import math
import os

import numpy as np
from PIL import Image

SIZE = 1024            # finished picture, square, in pixels
SUPERSAMPLE = 2        # draw bigger, then shrink, for smooth edges
RAY_COUNT = 12
# per petal: (length, widest width, angle nudge in degrees); uneven on purpose, like the spark
RAYS = [
    (0.46, 0.16, 0), (0.39, 0.14, 5), (0.44, 0.15, -4), (0.37, 0.13, 3),
    (0.45, 0.16, -3), (0.40, 0.14, 6), (0.47, 0.16, 1), (0.38, 0.13, -5),
    (0.43, 0.15, 4), (0.41, 0.14, -2), (0.46, 0.15, 3), (0.36, 0.13, -6),
]
PETAL_START = 0.04     # where petals begin, from the middle (fraction of the picture)
WIDEST_AT = 0.62       # how far along the petal it is widest (0 = base, 1 = tip)
TIP_ROUND = 0.55       # lower = rounder, fuller tip; higher = more pointed

PETAL_BASE_TONE = 0.45 # brightness of a petal where it meets the heart
PETAL_TIP_TONE = 0.95  # brightness at the petal's outer end
OUTLINE = 3.0          # pixels; dark line round each petal so overlapping petals read apart
VEIN_WIDTH = 2.2       # pixels; the centre vein
VEIN_DARKEN = 0.30
SIDE_VEINS = 5         # faint veins branching off the centre one, per side
SIDE_VEIN_DARKEN = 0.07

HEART_RADIUS = 0.085   # the flower's middle (fraction of the picture)
HEART_TONE = 0.85
SEEDS = 60             # dots in the middle, laid out in a sunflower spiral
SEED_SIZE = 0.0070     # dot radius (fraction of the picture)
SEED_DARKEN = 0.45

OUT = os.path.join(os.path.dirname(__file__), "..", "styles",
                   "green-monitor-starburst", "starburst.png")


def petal(x, y, angle, length, width, size):
    """Returns (coverage 0..1, tone) for one petal over the whole picture."""
    dx, dy = math.cos(angle), math.sin(angle)
    r0, r1 = PETAL_START * size, length * size
    u = (x * dx + y * dy - r0) / (r1 - r0)         # 0 at the base, 1 at the tip
    v = -x * dy + y * dx                           # pixels sideways from the centre line
    t = np.clip(u, 0, 1)
    # one smooth teardrop curve: grows from nothing, widest at WIDEST_AT, closes at the tip
    b = TIP_ROUND
    a = b * WIDEST_AT / (1 - WIDEST_AT)
    peak = WIDEST_AT ** a * (1 - WIDEST_AT) ** b
    half = width * size / 2 * t ** a * (1 - t) ** b / peak
    edge = half - np.abs(v)                        # pixels inside the edge
    inside = (u > 0) & (u < 1)
    cover = np.clip(edge + 0.5, 0, 1) * inside

    tone = PETAL_BASE_TONE + (PETAL_TIP_TONE - PETAL_BASE_TONE) * t
    tone = tone * (1 - VEIN_DARKEN * np.exp(-(v / VEIN_WIDTH) ** 2) * (1 - t * 0.7))
    along = u * (r1 - r0) - np.abs(v) * 1.3        # side veins slope out towards the tip
    side = np.exp(-((np.mod(along, (r1 - r0) / SIDE_VEINS) - 4) / 1.6) ** 2)
    tone = tone * (1 - SIDE_VEIN_DARKEN * side * (np.abs(v) < half * 0.85))
    tone = tone * np.clip(edge / OUTLINE, 0.15, 1)  # dark rim
    return cover, tone


def main():
    size = SIZE * SUPERSAMPLE
    y, x = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5 - size / 2
    img = np.zeros((size, size))

    # longest petals last so they sit on top, like a real flower's front row
    order = sorted(range(RAY_COUNT), key=lambda i: RAYS[i][0])
    for i in order:
        length, width, nudge = RAYS[i]
        angle = math.radians(i * 360 / RAY_COUNT + nudge - 90)
        cover, tone = petal(x, y, angle, length, width, size)
        img = img * (1 - cover) + tone * cover

    r = np.hypot(x, y)
    heart_r = HEART_RADIUS * size
    cover = np.clip(heart_r - r + 0.5, 0, 1)
    tone = HEART_TONE * np.clip((heart_r - r) / (OUTLINE * SUPERSAMPLE), 0.15, 1)
    golden = math.pi * (3 - math.sqrt(5))
    seed_r = SEED_SIZE * size
    for k in range(SEEDS):
        rr = heart_r * 0.86 * math.sqrt((k + 0.5) / SEEDS)
        sx, sy = rr * math.cos(k * golden), rr * math.sin(k * golden)
        d = np.hypot(x - sx, y - sy)
        tone = tone * (1 - SEED_DARKEN * np.clip(seed_r - d + 0.5, 0, 1))
    img = img * (1 - cover) + tone * cover

    small = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    small = small.resize((SIZE, SIZE), Image.LANCZOS)
    small.convert("RGB").save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
