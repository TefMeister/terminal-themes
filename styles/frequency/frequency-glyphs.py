"""The pixel letters for frequency-sheet.png: 32 real ones (digits and capitals, 5 x 7) and 32
made-up ones in the same size, drawn from strokes between points on a small lattice so they look like
a script that almost makes sense. Used by frequency-sprites.py; each glyph sits in a 6 x 8 cell,
white on transparent, and the shader colours them.
"""
import random

GLYPH_W, GLYPH_H = 6, 8
REAL = [
    "01110 10001 10011 10101 11001 10001 01110", "00100 01100 00100 00100 00100 00100 01110",
    "01110 10001 00001 00010 00100 01000 11111", "11111 00010 00100 00010 00001 10001 01110",
    "00010 00110 01010 10010 11111 00010 00010", "11111 10000 11110 00001 00001 10001 01110",
    "00110 01000 10000 11110 10001 10001 01110", "11111 00001 00010 00100 01000 01000 01000",
    "01110 10001 10001 01110 10001 10001 01110", "01110 10001 10001 01111 00001 00010 01100",
    "01110 10001 10001 11111 10001 10001 10001", "11110 10001 10001 11110 10001 10001 11110",
    "01110 10001 10000 10000 10000 10001 01110", "11100 10010 10001 10001 10001 10010 11100",
    "11111 10000 10000 11110 10000 10000 11111", "11111 10000 10000 11110 10000 10000 10000",
    "01110 10001 10000 10111 10001 10001 01111", "10001 10001 10001 11111 10001 10001 10001",
    "10001 10010 10100 11000 10100 10010 10001", "10001 11011 10101 10101 10001 10001 10001",
    "10001 10001 11001 10101 10011 10001 10001", "11110 10001 10001 11110 10000 10000 10000",
    "11110 10001 10001 11110 10100 10010 10001", "01111 10000 10000 01110 00001 00001 11110",
    "11111 00100 00100 00100 00100 00100 00100", "10001 10001 01010 00100 01010 10001 10001",
    "11111 00001 00010 00100 01000 10000 11111", "10001 10001 01010 00100 00100 00100 00100",
    "10001 10001 10001 10101 10101 10101 01010", "10001 10001 10001 10001 10001 01010 00100",
    "10001 10001 10001 10001 10001 10001 01110", "10000 10000 10000 10000 10000 10000 11111",
]
MADE_UP = 32
LATTICE = [(x, y) for y in (0, 3, 6) for x in (0, 2, 4)]   # 3 x 3 points inside the 5 x 7 box


def _line(px, a, b):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        px.add((round(x0 + (x1 - x0) * i / max(n, 1)), round(y0 + (y1 - y0) * i / max(n, 1))))


def made_up(seed):
    """Three or four strokes between neighbouring lattice points, sometimes mirrored."""
    rnd = random.Random(seed)
    px = set()
    for _ in range(rnd.randint(3, 4)):
        a = rnd.choice(LATTICE)
        near = [p for p in LATTICE if p != a and abs(p[0] - a[0]) <= 2 and abs(p[1] - a[1]) <= 3]
        _line(px, a, rnd.choice(near))
    if rnd.random() < 0.4:
        px |= {(4 - x, y) for x, y in px}
    if rnd.random() < 0.3:
        px.add((rnd.choice((1, 3)), rnd.choice((1, 5))))   # a loose dot
    return px


def draw_glyphs(img, oy):
    white = (255, 255, 255, 255)
    for i, rows in enumerate(REAL):
        for y, row in enumerate(rows.split()):
            for x, ch in enumerate(row):
                if ch == "1":
                    img.putpixel((i * GLYPH_W + x, oy + y), white)
    for k in range(MADE_UP):
        for x, y in made_up(1000 + k):
            img.putpixel(((len(REAL) + k) * GLYPH_W + x, oy + y), white)
