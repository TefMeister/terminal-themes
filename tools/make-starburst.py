"""Draws the starburst picture used as the terminal background.

Our own drawing, in the spirit of the Claude spark: uneven rays of different
lengths and widths, meeting in the middle. Shaded as a raised, rounded shape lit
from the upper left, with a fine grain on its surface, so it has depth and texture.
Grey on black; the shader turns it green, adds the stripes and the rolling light.

    python tools/make-starburst.py  ->  styles/green-monitor-starburst/starburst.png
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024            # finished picture, square, in pixels
SUPERSAMPLE = 4        # draw bigger, then shrink, for smooth edges
RAY_COUNT = 12
INNER_RADIUS = 0.05    # fraction of the picture; where each ray starts (near the middle)
# per ray: (length, width at the base, angle nudge in degrees); uneven on purpose
RAYS = [
    (0.40, 0.105, 0), (0.33, 0.095, 5), (0.38, 0.100, -4), (0.31, 0.090, 3),
    (0.39, 0.105, -3), (0.34, 0.095, 6), (0.41, 0.105, 1), (0.32, 0.090, -5),
    (0.37, 0.100, 4), (0.35, 0.095, -2), (0.40, 0.100, 3), (0.30, 0.090, -6),
]
TIP_WIDTH = 0.85       # tip width as a fraction of the base width (rounded tip)
SOFTEN = 1.2           # final blur radius in pixels, so the edges are not razor sharp

# depth and texture
CORE_RADIUS = 0.10     # the round middle, as a fraction of the picture
CORE_FLATTEN = 1.0     # how domed the middle is compared with the rays (1 = a full ball)
BLEND = 30             # pixels; how smoothly rays flow into each other (0 = hard joins)
LIGHT_DIR = (-0.6, -0.7, 0.45)   # light from the upper left, a little in front
AMBIENT = 0.18         # brightness of the side facing away from the light
SHINE = 0.55           # strength of the glossy highlight
SHINE_TIGHTNESS = 30   # higher = smaller, sharper highlight
GRAIN = 0.10           # fine surface grain (0 = smooth)
MOTTLE = 0.14          # larger soft blotches, like worn metal
MOTTLE_SIZE = 9        # pixels; size of the blotches
CREASE = 0.25          # darkening in the grooves where rays meet (0 = none)
CREASE_WIDTH = 10      # pixels; how wide those grooves are
SMOOTH = 4.0           # pixels; evens out the surface so the joins do not sparkle

OUT = os.path.join(os.path.dirname(__file__), "..", "styles",
                   "green-monitor-starburst", "starburst.png")


def ray_polygon(cx, cy, angle, r0, r1, w0, w1, steps=12):
    """A tapered ray from radius r0 to r1 with a round cap at the far end."""
    dx, dy = math.cos(angle), math.sin(angle)
    nx, ny = -dy, dx
    pts = [(cx + dx * r0 + nx * w0 / 2, cy + dy * r0 + ny * w0 / 2)]
    tipx, tipy = cx + dx * r1, cy + dy * r1
    for i in range(steps + 1):  # half circle round the tip
        a = math.pi / 2 - math.pi * i / steps
        pts.append((tipx + (nx * math.sin(a) + dx * math.cos(a)) * w1 / 2,
                    tipy + (ny * math.sin(a) + dy * math.cos(a)) * w1 / 2))
    pts.append((cx + dx * r0 - nx * w0 / 2, cy + dy * r0 - ny * w0 / 2))
    return pts


def blurred_noise(rng, shape, radius):
    n = rng.standard_normal(shape)
    img = Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8))
    n = np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float64) - 128
    return n / (np.abs(n).max() + 1e-9)


def soft_max(a, b, k):
    """Like max(a, b), but rounds off the join so two shapes flow into one."""
    h = np.clip(k - np.abs(a - b), 0, None) / k
    return np.maximum(a, b) + h * h * k / 4 * np.clip(np.minimum(a, b) / k, 0, 1)


def blur(a, radius):
    """Gaussian blur in full precision (an 8-bit blur leaves ripples in the lighting)."""
    r = int(radius * 3) + 1
    k = np.exp(-(np.arange(-r, r + 1) / radius) ** 2 / 2)
    k /= k.sum()
    a = np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 0, a)
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), 1, a)


def tube_height(size):
    """Height of the shape: each ray is a rounded tube, the middle a low dome.
    Where they overlap the taller one wins, which leaves a groove at the join."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5
    x -= size / 2
    y -= size / 2
    height = np.zeros((size, size))
    groove = np.full((size, size), np.inf)
    for i, (length, width, nudge) in enumerate(RAYS[:RAY_COUNT]):
        a = math.radians(i * 360 / RAY_COUNT + nudge - 90)
        dx, dy = math.cos(a), math.sin(a)
        r0, r1 = INNER_RADIUS * size, length * size
        t = np.clip((x * dx + y * dy - r0) / (r1 - r0), 0, 1)
        px, py = x - (r0 + t * (r1 - r0)) * dx, y - (r0 + t * (r1 - r0)) * dy
        half = width * size / 2 * (1 - t * (1 - TIP_WIDTH))
        h = np.sqrt(np.clip(half ** 2 - (px ** 2 + py ** 2), 0, None))
        groove = np.minimum(groove, np.abs(h - height) + (h <= 0) * 1e9 + (height <= 0) * 1e9)
        height = soft_max(height, h, BLEND)
    core = CORE_RADIUS * size
    h = np.sqrt(np.clip(core ** 2 - (x ** 2 + y ** 2), 0, None)) * CORE_FLATTEN
    groove = np.minimum(groove, np.abs(h - height) + (h <= 0) * 1e9 + (height <= 0) * 1e9)
    height = soft_max(height, h, BLEND)
    return height, groove


def blurred_noise(rng, shape, radius):
    n = rng.standard_normal(shape)
    img = Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8))
    n = np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float64) - 128
    return n / (np.abs(n).max() + 1e-9)


def shade(mask):
    """Turns the flat white shape into a lit, rounded, textured one."""
    rng = np.random.default_rng(7)  # fixed seed: same picture every run
    height, groove = tube_height(mask.shape[0])
    smooth = blur(height, SMOOTH)

    gy, gx = np.gradient(smooth)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    light = np.array(LIGHT_DIR) / np.linalg.norm(LIGHT_DIR)
    diffuse = np.clip(n @ light, 0, 1)
    half = light + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    shine = np.clip(n @ half, 0, 1) ** SHINE_TIGHTNESS
    crease = np.exp(-(groove / CREASE_WIDTH) ** 2)

    tone = AMBIENT + (1 - AMBIENT) * diffuse
    tone *= 1 + GRAIN * blurred_noise(rng, mask.shape, 0.8) + MOTTLE * blurred_noise(rng, mask.shape, MOTTLE_SIZE)
    tone *= 1 - CREASE * crease
    tone += SHINE * shine
    return np.clip(tone, 0, 1) * mask


def main():
    big = SIZE * SUPERSAMPLE
    img = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(img)
    c = big / 2
    for i, (length, width, nudge) in enumerate(RAYS[:RAY_COUNT]):
        angle = math.radians(i * 360 / RAY_COUNT + nudge - 90)
        w0 = width * big
        draw.polygon(ray_polygon(c, c, angle, INNER_RADIUS * big, length * big,
                                 w0, w0 * TIP_WIDTH), fill=255)
    draw.ellipse([c - 0.11 * big, c - 0.11 * big, c + 0.11 * big, c + 0.11 * big], fill=255)
    img = img.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(SOFTEN))
    shaded = shade(np.asarray(img, dtype=np.float64) / 255)
    Image.fromarray((shaded * 255).astype(np.uint8)).convert("RGB").save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
