"""Draws the starburst picture used as the terminal background.

Our own drawing, in the spirit of the Claude spark: uneven rays of different
lengths and widths, meeting in the middle. White on black; the shader turns it
green, adds the stripes and the rolling light.

    python tools/make-starburst.py  ->  styles/green-monitor-starburst/starburst.png
"""
import math
import os

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
    img.convert("RGB").save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
