"""Draws frequency-sheet.png: the pixel sprites the frequency shader flips through.

    python frequency-sprites.py

Layout (must match the SHEET constants at the top of frequency.hlsl):
    y   0..23   fish bones, 48 x 24 each: 3 kinds x 2 swim frames, kind-major (6 columns)
    y  24..47   skulls, 24 x 24 each: 4 kinds
    y  48..111  the cartoon dog jogging, 64 x 64 each: 8 frames
Everything faces right. Transparent pixels have alpha 0; the shader tints and scales the rest.
"""
import math, os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SHEET_W, SHEET_H = 512, 128
FISH_W, FISH_H, FISH_KINDS, FISH_FRAMES = 48, 24, 3, 2
SKULL_Y, SKULL_S, SKULL_KINDS = 24, 24, 4
DOG_Y, DOG_S, DOG_FRAMES = 48, 64, 8

# --- palettes ---
BONE, BONE_SHADE, BONE_DARK = (236, 230, 206, 255), (168, 158, 132, 255), (92, 84, 70, 255)
# the cartoon is black and white film: five greys only
INK, DARK, MID, LIGHT, PAPER = (16, 16, 16, 255), (70, 70, 70, 255), (138, 138, 138, 255), (200, 200, 200, 255), (246, 246, 240, 255)


def blob(d, x, y, r, col):
    """A filled disc with no smoothing, r in pixels (0 = one pixel)."""
    if r <= 0:
        d.point((round(x), round(y)), fill=col)
    else:
        d.ellipse((round(x - r), round(y - r), round(x + r), round(y + r)), fill=col)


def curve(d, pts, r, col, steps=24):
    """A thick quadratic Bezier through three points: the rubber-hose limb."""
    (x0, y0), (x1, y1), (x2, y2) = pts
    for i in range(steps + 1):
        t = i / steps
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        blob(d, a * x0 + b * x1 + c * x2, a * y0 + b * y1 + c * y2, r, col)


# ---------------------------------------------------------------- fish bones
FISH_KIND = [  # (spine length, rib count, rib height, head size)
    (26, 7, 7, 8),
    (22, 5, 9, 9),
    (30, 9, 5, 7),
]


def draw_fish(img, ox, oy, kind, frame):
    d = ImageDraw.Draw(img)
    spine, ribs, rib_h, head = FISH_KIND[kind]
    cy = oy + FISH_H // 2
    wig = 1 if frame else -1                       # the whole skeleton flexes between the two frames
    x_head = ox + 46 - head
    x_tail = x_head - spine
    # spine with a slight S-bend
    for x in range(x_tail, x_head + 1):
        t = (x - x_tail) / max(spine, 1)
        y = cy + round(wig * math.sin(t * math.pi) * 1.2 * (1 - t))
        d.point((x, y), fill=BONE)
        if x % 3 == 0:
            d.point((x, y + 1), fill=BONE_SHADE)   # vertebra notches
    # ribs, tallest near the head, curving back towards the tail
    for i in range(ribs):
        t = (i + 1) / (ribs + 1)
        x = x_tail + round(spine * (0.25 + 0.72 * t))
        h = max(2, round(rib_h * (0.45 + 0.55 * t)))
        lean = -1 - wig * 0.5
        for s in (-1, 1):
            for k in range(1, h + 1):
                px = x + round(lean * k / h * 2 + (k / h) ** 2 * -1.5)
                py = cy + s * k
                d.point((px, py), fill=BONE if k < h else BONE_SHADE)
    # tail fin: forked rays
    for s in (-1, 1):
        for k in range(1, 7):
            d.point((x_tail - k, cy + s * round(k * 0.9) + wig * (k // 3)), fill=BONE)
            if k > 2:
                d.point((x_tail - k + 1, cy + s * round(k * 0.5)), fill=BONE_SHADE)
    # head: a hollow wedge with an eye socket and a jaw
    for x in range(head + 1):
        half = round(head * 0.62 * (1 - (x / head) ** 1.6)) + 1
        for y in range(-half, half + 1):
            edge = abs(y) == half or x == 0
            d.point((x_head + x, cy + y), fill=BONE if edge else BONE_DARK)
    blob(d, x_head + head * 0.45, cy - head * 0.22, 1, (10, 10, 10, 255))
    d.point((round(x_head + head * 0.45), round(cy - head * 0.22)), fill=(255, 70, 60, 255))  # an ember in the eye
    d.line((x_head + 2, cy + 2, x_head + head, cy + 1 + frame), fill=BONE_SHADE)          # jaw line


# ---------------------------------------------------------------- skulls
SKULL = [
    "....kkkkkkkkkkk.....",
    "..kkWWWWWWWWWWWkk...",
    ".kWWWWWWWWWWWWWWWk..",
    "kWWWWWWWWWWWWWWWWgk.",
    "kWWWWWWWWWWWWWWWWgk.",
    "kWWWWWWWWWWWWWWWggk.",
    "kWWkkkkWWWWWkkkkWgk.",
    "kWkddddkWWWkddddkgk.",
    "kWkddddkWWWkddddkgk.",
    "kWkddddkWWWkddddkgk.",
    "kWWkkkkWWkWWkkkkWgk.",
    ".kWWWWWWkdkWWWWWgk..",
    "..kgWWWWkdkWWWWggk..",
    "...kkWWWWWWWWWgkk...",
    "....kWkWkWkWkWgk....",
    "....kWkWkWkWkWgk....",
    "....kkkkkkkkkkkk....",
]
SKULL_COLS = {"k": (20, 14, 26, 255), "W": (248, 244, 232, 255), "g": (170, 160, 176, 255), "d": (6, 4, 10, 255)}


def paste_map(img, ox, oy, rows, cols):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in cols:
                img.putpixel((ox + x, oy + y), cols[ch])


def draw_skull(img, ox, oy, kind):
    d = ImageDraw.Draw(img)
    if kind == 1:                                   # crossbones behind
        for a, b in (((ox + 2, oy + 4), (ox + 21, oy + 22)), ((ox + 21, oy + 4), (ox + 2, oy + 22))):
            d.line(a + b, fill=BONE_SHADE, width=2)
            for p in (a, b):
                blob(d, p[0] - 1, p[1], 1, BONE)
                blob(d, p[0] + 1, p[1] + (1 if p[1] < oy + 12 else -1), 1, BONE)
    paste_map(img, ox + 2, oy + 3, SKULL, SKULL_COLS)
    if kind == 2:                                   # a crack across the dome
        for i, (x, y) in enumerate([(10, 3), (11, 4), (11, 5), (12, 6), (13, 6), (13, 7)]):
            img.putpixel((ox + 2 + x, oy + 3 + y), SKULL_COLS["k"])
    if kind == 3:                                   # glowing eyes
        for ex in (4, 13):
            for y in range(7, 10):
                for x in range(ex - 1, ex + 2):
                    img.putpixel((ox + 2 + x, oy + 3 + y), (120, 255, 120, 255) if (x, y) == (ex, 8) else (30, 140, 40, 255))


# ---------------------------------------------------------------- the jogging dog
def draw_dog(img, ox, oy, frame):
    """A 1930s rubber-hose cartoon dog in baggy trousers, jogging to the right."""
    d = ImageDraw.Draw(img)
    p = frame / DOG_FRAMES * math.tau
    bob = -round(abs(math.sin(p)) * 3)              # up at mid-stride
    hip = (ox + 28, oy + 40 + bob)
    shoulder = (ox + 33, oy + 27 + bob)

    def leg(side, col):
        a = p + (0 if side > 0 else math.pi)
        fx = hip[0] + 13 * math.sin(a)
        lift = max(0.0, -math.cos(a))              # the back-swinging foot comes up
        fy = oy + 59 - 7 * lift + bob * 0.3
        knee = ((hip[0] + fx) / 2 + 5 + 3 * lift, (hip[1] + fy) / 2 + 2 - 4 * lift)
        curve(d, (hip, knee, (fx, fy)), 1, col)
        # big round shoe, toe forward
        d.ellipse((round(fx - 4), round(fy - 3), round(fx + 6), round(fy + 2)), fill=INK)
        d.point((round(fx + 3), round(fy - 2)), fill=LIGHT)

    def arm(side, col):
        a = p + (math.pi if side > 0 else 0)
        hx = shoulder[0] + 12 * math.sin(a)
        hy = shoulder[1] + 9 - 4 * math.cos(a)
        elbow = ((shoulder[0] + hx) / 2 - 3, (shoulder[1] + hy) / 2 + 4)
        curve(d, (shoulder, elbow, (hx, hy)), 1, col)
        blob(d, hx, hy, 3, PAPER)                  # white glove
        d.arc((round(hx - 3), round(hy - 3), round(hx + 3), round(hy + 3)), 200, 340, fill=INK)
        d.line((round(hx - 2), round(hy - 3), round(hx + 2), round(hy - 3)), fill=LIGHT)  # glove cuff

    arm(-1, DARK)                                   # far limbs a shade lighter, so they read behind
    leg(-1, DARK)
    # tail, wagging with the stride
    tw = math.sin(p * 2) * 3
    curve(d, ((hip[0] - 6, hip[1] - 6), (hip[0] - 12, hip[1] - 12 + tw), (hip[0] - 15, hip[1] - 18 + tw)), 0, INK)
    # body: a black bean leaning into the run
    d.ellipse((ox + 23, oy + 22 + bob, ox + 39, oy + 40 + bob), fill=INK)
    # baggy trousers with two big buttons and braces
    d.rounded_rectangle((ox + 20, oy + 33 + bob, ox + 37, oy + 47 + bob), radius=4, fill=MID)
    for y in range(oy + 35 + bob, oy + 47 + bob, 3):
        d.line((ox + 21, y, ox + 36, y), fill=(122, 122, 122, 255))     # a woven stripe
    d.line((ox + 28, oy + 41 + bob, ox + 28, oy + 47 + bob), fill=DARK)  # the leg split
    d.line((ox + 24, oy + 26 + bob, ox + 25, oy + 34 + bob), fill=LIGHT)
    d.line((ox + 34, oy + 25 + bob, ox + 33, oy + 34 + bob), fill=LIGHT)
    blob(d, ox + 24, oy + 36 + bob, 1, PAPER)
    blob(d, ox + 33, oy + 36 + bob, 1, PAPER)
    leg(1, INK)
    # head: round black skull, a white muzzle, pie-cut eyes and a big shiny nose
    hx, hy = ox + 40, oy + 15 + bob
    ear = math.sin(p + 1.2) * 3
    curve(d, ((hx - 4, hy - 6), (hx - 13, hy - 4 - ear), (hx - 16, hy + 4 - ear)), 2, INK)   # far ear, flapping
    d.ellipse((hx - 9, hy - 10, hx + 7, hy + 6), fill=INK)
    d.ellipse((hx - 1, hy - 3, hx + 14, hy + 8), fill=PAPER)            # muzzle
    d.ellipse((hx - 3, hy - 9, hx + 7, hy - 1), fill=PAPER)            # face mask round the eyes
    for ex in (hx, hx + 4):
        d.ellipse((ex - 1, hy - 8, ex + 2, hy - 2), fill=PAPER)
        d.rectangle((ex, hy - 6, ex + 1, hy - 3), fill=INK)            # pupil
        d.point((ex + 1, hy - 6), fill=PAPER)                          # the pie-cut wedge
    d.ellipse((hx + 10, hy - 3, hx + 17, hy + 2), fill=INK)            # nose
    d.point((hx + 12, hy - 2), fill=PAPER)
    d.arc((hx + 1, hy - 1, hx + 13, hy + 7), 20, 160, fill=INK)        # grin
    d.point((hx + 9, hy + 6), fill=MID)                                # tongue tip, in film grey
    curve(d, ((hx - 2, hy - 8), (hx - 9, hy - 3 + ear), (hx - 10, hy + 6 + ear)), 2, INK)    # near ear
    arm(1, INK)


def main():
    img = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for kind in range(FISH_KINDS):
        for frame in range(FISH_FRAMES):
            draw_fish(img, (kind * FISH_FRAMES + frame) * FISH_W, 0, kind, frame)
    for kind in range(SKULL_KINDS):
        draw_skull(img, kind * SKULL_S, SKULL_Y, kind)
    for frame in range(DOG_FRAMES):
        draw_dog(img, frame * DOG_S, DOG_Y, frame)
    out = os.path.join(HERE, "frequency-sheet.png")
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
