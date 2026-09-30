"""Draws the aquarium's pixel-art sprite sheet (aquarium-sheet.png) for aquarium.hlsl.

Layout (must match the constants in aquarium.hlsl):
  plants: PLANT_TYPES rows x PLANT_FRAMES columns of PW x PH cells, starting at x=0
  fish:   FISH_ROWS rows x 6 columns of FW x FH cells, starting at x = PW * PLANT_FRAMES
          columns 0-1 side view (tail frames), 2-3 head-on, 4-5 from behind (tail swinging)
Magenta (255, 0, 255) means "nothing here".
Everything faces right; the shader mirrors sprites for fish swimming left.
Run:  python aquarium-sprites.py
"""
import math
import os
import random
from PIL import Image

KEY = (255, 0, 255)
FW, FH = 32, 24            # fish cell
PW, PH = 40, 64            # plant cell
PLANT_FRAMES = 16          # sway frames per plant (one full sway)
PLANT_TYPES = 13           # 10 plants + 3 rocks
FISH_ROWS = 8              # 7 fish species + the crab
FISH_X = PW * PLANT_FRAMES

FISH_COLS = 6
SHEET_W = FISH_X + FW * FISH_COLS
SHEET_H = max(PH * PLANT_TYPES, FH * FISH_ROWS)


def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return tuple(clamp(v * k) for v in c)


class Cell:
    """A small sprite canvas; pixels outside it are ignored."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    def outline(self, colour_fn):
        """Darken every filled pixel that touches an empty one."""
        edge = [(x, y) for (x, y) in self.px
                if any((x + dx, y + dy) not in self.px
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in edge:
            self.px[(x, y)] = colour_fn(self.px[(x, y)])

    def blit(self, img, ox, oy):
        for (x, y), c in self.px.items():
            img.putpixel((ox + x, oy + y), c)


# ---------------------------------------------------------------- fish

def draw_fish(sp, frame):
    """sp: species dict. frame 0/1 = tail position."""
    c = Cell(FW, FH)
    y0 = FH / 2
    nose = 29.5
    L, hh = sp["len"], sp["half_h"]
    tail_x = nose - L

    def half(u):
        h = hh * math.sqrt(max(0.0, 1 - ((u - 0.55) / 0.55) ** 2))
        if u < 0.22:
            h = max(h, hh * sp.get("peduncle", 0.3))
        snout = sp.get("snout", 0.0)       # tapers the head into a longer, rounder nose
        if snout and u > 0.7:
            h *= 1 - snout * ((u - 0.7) / 0.3) ** 1.5
        return h

    wag = (1.6 if frame else -0.4) * sp.get("wag", 1.0)
    for y in range(FH):
        for x in range(FW):
            px, py = x + 0.5, y + 0.5
            u = (px - tail_x) / L
            part, f = None, 0.0
            if 0 <= u <= 1:
                h = half(u)
                v = (py - y0) / max(h, 0.01)
                if abs(v) <= 1:
                    part, f = "body", 0.0
                else:
                    # fins sweep back as they get further from the body
                    k = abs(py - y0) - h
                    for name, sign in (("dorsal", -1), ("ventral", 1)):
                        fin = sp.get(name)
                        if not fin or (py - y0) * sign <= 0:
                            continue
                        d0, d1, fh, sweep = fin
                        us = u + sweep * k / L
                        if d0 <= us <= d1:
                            span = (us - d0) / (d1 - d0)
                            top = fh * math.sin(math.pi * span) ** 0.6
                            if sweep > 0.3:
                                top = fh * (1 - span) ** 0.5 * min(1, span * 5)
                            if k <= top:
                                part, f = name, k / max(top, 0.01)
            if part is None and u < 0.06:
                t = (tail_x + 0.06 * L - px) / sp["tail_len"]
                if 0 <= t <= 1:
                    dy = wag * t * t + sp.get("droop", 0) * t * t
                    th = 1 + (sp["tail_h"] - 1) * t
                    if sp["tail"] == "round":
                        th = sp["tail_h"] * math.sqrt(max(0, t * (2.2 - t))) / 1.1 + 0.8
                    off = abs(py - y0 - dy)
                    inside = off <= th
                    if sp["tail"] == "fork" and t > 0.55 and off < (t - 0.55) * sp["tail_h"] * 1.6:
                        inside = False
                    if inside:
                        part, f, u = "tail", t, -t
            if part:
                v = (py - y0) / max(half(max(0, min(1, u))), 0.01)
                col = sp["colour"](part, u, v, f, x, y)
                if part == "body":
                    col = shade(col, 1.12 - 0.14 * (v + 1))        # lit from above, darker belly
                else:
                    col = mix(col, mix(col, (255, 255, 255), 0.5), f * 0.5)  # fins paler at the tips
                c.put(x, y, col)
    # soft two-step rim: a darker edge, then a slightly darker ring just inside it
    body_px = set(c.px)
    c.outline(sp.get("edge", lambda col: shade(col, 0.62)))
    rim = [(x, y) for (x, y) in body_px
           if all((x + dx, y + dy) in body_px for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
           and any((x + dx, y + dy) not in body_px or
                   any((x + dx + ex, y + dy + ey) not in body_px for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in rim:
        c.px[(x, y)] = shade(c.px[(x, y)], 0.86)
    # eye
    ex, ey = int(tail_x + L * sp.get("eye_u", 0.84)), int(y0 - hh * 0.3)
    if sp.get("eye_big", True):
        c.put(ex, ey, (15, 15, 20))
        c.put(ex + 1, ey, (15, 15, 20))
        c.put(ex, ey - 1, (235, 240, 240))
        c.put(ex + 1, ey - 1, (15, 15, 20))
    else:
        c.put(ex, ey, (15, 15, 20))
    return c


def clown_colour(part, u, v, f, x, y):
    orange, white, black = (255, 118, 20), (250, 250, 245), (20, 18, 18)
    if part == "body":
        for cu, w in ((0.76, 0.07), (0.47, 0.07), (0.12, 0.05)):
            if abs(u - cu) < w:
                return white
            if abs(u - cu) < w + 0.045:
                return black
        return mix(orange, (255, 160, 60), -v * 0.5)
    if part == "tail" and f > 0.75:
        return black
    return orange


def tang_colour(part, u, v, f, x, y):
    blue, black, yellow = (35, 90, 235), (15, 15, 30), (255, 210, 40)
    if part == "tail":
        return yellow if f > 0.15 else black
    if part in ("dorsal", "ventral"):
        return black if f > 0.7 else blue
    ring = ((u - 0.52) / 0.2) ** 2 + ((v + 0.3) / 0.22) ** 2 < 1
    if 0.22 < u < 0.82 and -0.75 < v < -0.05 and not ring:
        return black
    if u < 0.25 and -0.3 < v < 0.3:
        return black
    return mix(blue, (90, 150, 255), (v + 1) * 0.3)


def gold_colour(part, u, v, f, x, y):
    body, belly = (255, 140, 25), (255, 205, 120)
    if part == "body":
        return mix(shade(body, 0.9), belly, (v + 0.2) * 0.9)
    return mix((255, 160, 60), (255, 235, 200), f)


def neon_colour(part, u, v, f, x, y):
    silver, blue, red = (185, 195, 205), (40, 215, 255), (235, 35, 50)
    if part != "body":
        return (150, 160, 170)
    if 0.12 < u < 0.92 and -0.55 < v < 0.02:
        return blue
    if u < 0.55 and 0.08 < v < 0.85:
        return red
    return silver if v < 0 else (225, 230, 235)


def jewel_colour(part, u, v, f, x, y):
    red, dark, spot = (238, 62, 30), (185, 30, 20), (125, 205, 255)
    if y % 2 == 0 and (x + (y // 2) * 2) % 4 == 0:
        return spot
    if part == "body" and abs(u - 0.5) < 0.05 and abs(v) < 0.25:
        return (20, 15, 15)
    return dark if v < -0.5 or part != "body" else red


def angel_colour(part, u, v, f, x, y):
    silver, black = (220, 222, 205), (18, 18, 22)
    for cu, w in ((0.8, 0.035), (0.5, 0.05), (0.2, 0.04)):
        if abs(u - cu) < w:
            return black
    if part == "body" and v < -0.4 and u > 0.65:
        return (235, 205, 140)
    if part in ("dorsal", "ventral", "tail"):
        return mix(silver, (160, 170, 175), f)
    return silver


def betta_colour(part, u, v, f, x, y):
    red, violet = (205, 25, 50), (95, 55, 210)
    if part == "body":
        return mix(red, (150, 15, 40), max(0, v))
    col = mix((215, 35, 60), violet, f ** 1.3)
    return shade(col, 0.75) if y % 2 else col  # fin rays


SPECIES = [
    dict(name="clownfish", len=21, half_h=5.5, snout=0.45, eye_u=0.8, tail="round", tail_len=5, tail_h=4.5,
         dorsal=(0.3, 0.8, 3, 0.0), ventral=(0.35, 0.6, 2.5, 0.0),
         colour=clown_colour, edge=lambda col: shade(col, 0.55)),
    dict(name="blue tang", len=23, half_h=7, snout=0.5, eye_u=0.8, tail="fork", tail_len=7, tail_h=6,
         dorsal=(0.12, 0.85, 2, 0.0), ventral=(0.15, 0.65, 2, 0.0),
         colour=tang_colour, edge=lambda col: shade(col, 0.6)),
    dict(name="goldfish", len=18, half_h=6.5, snout=0.6, eye_u=0.8, tail="fork", tail_len=11, tail_h=7, droop=2.0,
         dorsal=(0.3, 0.72, 4.5, 0.0), ventral=(0.42, 0.66, 3, 0.0),
         colour=gold_colour, edge=lambda col: shade(col, 0.7), peduncle=0.35),
    dict(name="neon tetra", len=13, half_h=3, tail="fork", tail_len=3.5, tail_h=2.8,
         dorsal=(0.48, 0.62, 1.8, 0.0), ventral=(0.3, 0.5, 1.5, 0.0),
         colour=neon_colour, eye_big=False, wag=0.6),
    dict(name="jewel cichlid", len=20, half_h=6, tail="round", tail_len=5, tail_h=4.5,
         dorsal=(0.12, 0.88, 3, 0.0), ventral=(0.15, 0.55, 3, 0.0),
         colour=jewel_colour, edge=lambda col: shade(col, 0.5)),
    dict(name="angelfish", len=14, half_h=6, tail="fork", tail_len=5, tail_h=4,
         dorsal=(0.3, 0.75, 6, 0.9), ventral=(0.3, 0.75, 6, 0.9),
         colour=angel_colour, edge=lambda col: shade(col, 0.55), eye_u=0.82),
    dict(name="betta", len=13, half_h=3.5, tail="round", tail_len=10, tail_h=6.5, droop=1.5,
         dorsal=(0.2, 0.62, 5, 1.2), ventral=(0.05, 0.72, 6, 1.0),
         colour=betta_colour, edge=lambda col: shade(col, 0.6), wag=1.4),
]


def draw_crab(frame):
    c = Cell(FW, FH)
    shell, dark, claw = (220, 80, 40), (140, 40, 20), (240, 110, 60)
    cx, cy = 16, 17
    # legs, three each side, alternating with the frame
    for i in range(3):
        lift = (i + frame) % 2
        for side in (-1, 1):
            bx = cx + side * (3 + i * 2)
            c.put(bx + side, cy + 2, dark)
            c.put(bx + side * 2, cy + 3 - lift, dark)
            c.put(bx + side * 3, cy + 4 - lift, dark)
            c.put(bx + side * 3, cy + 5 - lift, dark)
    # shell
    for y in range(-3, 3):
        for x in range(-7, 8):
            if (x / 7.5) ** 2 + (y / 3.4) ** 2 <= 1:
                c.put(cx + x, cy + y, mix(shell, (255, 150, 100), -y * 0.15))
    # arms and claws
    for side in (-1, 1):
        c.put(cx + side * 7, cy - 2, dark)
        c.put(cx + side * 8, cy - 3, dark)
        open_ = frame if side > 0 else 1 - frame
        for dx, dy in ((9, -4), (10, -4), (9, -5), (10, -5), (11, -5)):
            c.put(cx + side * dx, cy + dy, claw)
        c.put(cx + side * 11, cy - 6 - open_, claw)
        c.put(cx + side * 10, cy - 6, claw)
    # eyes on stalks
    for side in (-1, 1):
        c.put(cx + side * 2, cy - 4, dark)
        c.put(cx + side * 2, cy - 5, (15, 15, 15))
    c.outline(lambda col: shade(col, 0.7))
    return c


# ---------------------------------------------------------------- plants
# y = PH - 1 is the ground. hf = height fraction (0 root, 1 tip).

def sway(phi, hf, amp, seed=0.0):
    return amp * hf * hf * math.sin(phi + seed)


def plant_seagrass(phi, rnd):
    c = Cell(PW, PH)
    for b in range(9):
        base = 5 + b * 3.6 + rnd.uniform(-1, 1)
        h = rnd.uniform(28, 58)
        lean = rnd.uniform(-5, 5)
        hue = rnd.uniform(0, 1)
        for i in range(int(h)):
            hf = i / h
            x = base + lean * hf * hf + sway(phi, hf, 4, b * 0.6)
            col = mix(mix((25, 95, 40), (40, 120, 35), hue), mix((110, 205, 85), (160, 215, 90), hue), hf)
            c.put(x, PH - 1 - i, col)
            if hf < 0.55:
                c.put(x + 1, PH - 1 - i, shade(col, 0.8))
    return c


def plant_kelp(phi, rnd):
    c = Cell(PW, PH)
    for s, (base, h) in enumerate(((15, 62), (25, 50))):
        for i in range(h):
            hf = i / h
            x = base + sway(phi, hf, 6, s)
            y = PH - 1 - i
            c.put(x, y, (120, 95, 25))
            if i % 5 == 2 and i > 4:
                side = 1 if (i // 5) % 2 else -1
                ln = 5 + (i % 3)
                for k in range(1, ln):
                    lx = x + side * k + sway(phi, hf, 1.5, 1 + k * 0.3)
                    ly = y - k * 0.6
                    col = mix((150, 130, 35), (215, 185, 70), k / ln)
                    c.put(lx, ly, col)
                    c.put(lx, ly + 1, shade(col, 0.85))
    return c


def plant_anemone(phi, rnd):
    c = Cell(PW, PH)
    for y in range(PH - 12, PH):
        for x in range(15, 26):
            c.put(x, y, (170, 70, 120) if x % 3 else (200, 95, 145))
    n = 15
    for i in range(n):
        a0 = -1.3 + 2.6 * i / (n - 1)
        bx = 15 + 10 * i / (n - 1)
        ln = rnd.uniform(9, 14)
        x, y, a = bx, PH - 12.0, a0
        for k in range(int(ln)):
            t = k / ln
            a = a0 * (0.6 + 0.6 * t) + 0.35 * t * math.sin(phi + i * 0.45)
            x += math.sin(a)
            y -= math.cos(a)
            c.put(x, y, mix((235, 120, 180), (255, 225, 240), t))
    return c


def branch(c, x, y, ang, ln, depth, phi, rnd, cols, thick=1):
    for k in range(int(ln)):
        a = ang + 0.05 * math.sin(phi) * (5 - depth)
        x += math.sin(a)
        y -= math.cos(a)
        col = mix(cols[0], cols[1], (5 - depth) / 5 + k / ln * 0.2)
        c.put(x, y, col)
        if thick > 1:
            c.put(x + 1, y, shade(col, 0.85))
    if depth > 0:
        for d in (-1, 1):
            branch(c, x, y, ang + d * rnd.uniform(0.3, 0.6), ln * rnd.uniform(0.62, 0.8),
                   depth - 1, phi, rnd, cols, thick)


def plant_seafan(phi, rnd):
    c = Cell(PW, PH)
    branch(c, 20, PH - 1, 0.0, 13, 5, phi, rnd, ((140, 25, 35), (235, 70, 80)))
    return c


def plant_staghorn(phi, rnd):
    c = Cell(PW, PH)
    for ang in (-0.6, 0.0, 0.55):
        branch(c, 20 + ang * 6, PH - 1, ang, 10, 3, phi * 0.3, rnd,
               ((200, 100, 35), (255, 205, 140)), thick=2)
    return c


def plant_brain(phi, rnd):
    c = Cell(PW, PH)
    for y in range(PH - 14, PH):
        for x in range(4, 36):
            dx, dy = (x - 20) / 15.0, (y - (PH - 1)) / 13.0
            if dx * dx + dy * dy <= 1:
                groove = math.sin(x * 1.1 + math.sin(y * 0.8) * 2.2) * math.cos(y * 1.2 + math.sin(x * 0.6) * 2)
                col = (175, 165, 105) if groove < 0.45 else (120, 115, 70)
                c.put(x, y, mix(col, (205, 195, 140), -dy * 0.4))
    c.outline(lambda col: shade(col, 0.7))
    return c


def plant_tubes(phi, rnd):
    c = Cell(PW, PH)
    for i, (x0, h) in enumerate(((8, 14), (12, 24), (17, 30), (22, 20), (27, 26), (31, 12))):
        for k in range(h):
            hf = k / h
            x = x0 + sway(phi, hf, 1.0, i)
            col = mix((110, 45, 160), (165, 80, 215), hf)
            for w in range(3):
                c.put(x + w, PH - 1 - k, shade(col, 0.8 if w == 2 else 1.0))
        top = PH - 1 - h
        x = x0 + sway(phi, 1, 1.0, i)
        c.put(x, top, (225, 170, 255))
        c.put(x + 1, top, (60, 20, 80))
        c.put(x + 2, top, (225, 170, 255))
    return c


def plant_bubble_anemone(phi, rnd):
    c = Cell(PW, PH)
    for i in range(46):
        bx = rnd.uniform(7, 33)
        mound = 6 * math.sqrt(max(0, 1 - ((bx - 20) / 14) ** 2))
        by = PH - 1 - rnd.uniform(0, mound)
        a0 = (bx - 20) / 14 * 0.9 + rnd.uniform(-0.3, 0.3)
        ln = rnd.uniform(3, 7)
        x, y = bx, by
        for k in range(int(ln)):
            a = a0 + 0.25 * math.sin(phi + i * 0.7) * k / ln
            x += math.sin(a)
            y -= math.cos(a)
            c.put(x, y, (55, 160, 85))
        c.put(x, y - 1, (165, 250, 150))
        c.put(x + 1, y - 1, (120, 225, 120))
    return c


def plant_fern(phi, rnd):
    """Broad-leaved green plant (like a java fern): long pointed leaves with a dark middle vein."""
    c = Cell(PW, PH)
    for i in range(7):
        a0 = -1.0 + 2.0 * i / 6 + rnd.uniform(-0.15, 0.15)
        ln = rnd.uniform(28, 46) * (1 - 0.3 * abs(a0))
        x, y = 20.0 + rnd.uniform(-2, 2), PH - 1.0
        tone = rnd.uniform(0, 1)
        for k in range(int(ln)):
            t = k / ln
            a = a0 * (0.4 + 0.8 * t) + 0.2 * t * math.sin(phi + i * 0.8)
            x += math.sin(a)
            y -= math.cos(a)
            width = 2.6 * math.sin(math.pi * min(1, t * 1.15)) + 0.3
            leaf = mix((40, 130, 50), (95, 190, 75), tone * 0.5 + t * 0.5)
            nx, ny = math.cos(a), math.sin(a)       # sideways across the leaf
            for w in range(-int(width), int(width) + 1):
                c.put(x + nx * w, y + ny * w, leaf if w else shade(leaf, 0.6))
    return c


def plant_cabomba(phi, rnd):
    """Feathery green stems with little whorls of needle leaves."""
    c = Cell(PW, PH)
    for s in range(4):
        base = 9 + s * 7 + rnd.uniform(-1, 1)
        h = rnd.uniform(35, 60)
        for i in range(int(h)):
            hf = i / h
            x = base + sway(phi, hf, 5, s * 0.9)
            y = PH - 1 - i
            c.put(x, y, (50, 120, 45))
            if i % 4 == 1 and i > 3:
                ln = 3 + (1 - hf) * 2
                col = mix((70, 170, 70), (150, 230, 110), hf)
                for k in range(1, int(ln) + 1):
                    c.put(x - k, y - k * 0.4, col)
                    c.put(x + k, y - k * 0.4, col)
    return c


def rock_blob(c, cx, rw, rh, base, rnd, moss=0.0):
    """One stone sitting on the ground, lit from the top left, with an optional mossy top."""
    seed = rnd.uniform(0, 6.3)
    for y in range(PH - 1 - int(rh * 1.3), PH):
        for x in range(PW):
            dx, dy = (x + 0.5 - cx) / rw, (y + 0.5 - (PH - 1)) / rh
            ang = math.atan2(dy, dx)
            r = 1 + 0.12 * math.sin(ang * 3 + seed) + 0.07 * math.sin(ang * 5 + seed * 2)
            if dx * dx + dy * dy > r * r or dy > 0.05:
                continue
            light = 0.75 + 0.45 * (-dx * 0.4 - dy * 0.8)
            col = shade(base, light)
            if rnd.random() < 0.08:
                col = shade(col, 0.8)                      # speckle / cracks
            if moss and dy < -0.55 and rnd.random() < moss:
                col = mix((50, 110, 45), (90, 150, 60), rnd.random())
            c.put(x, y, col)


def rock_boulder(phi, rnd):
    c = Cell(PW, PH)
    rock_blob(c, 20, 15, 17, (120, 118, 112), rnd, moss=0.5)
    c.outline(lambda col: shade(col, 0.6))
    return c


def rock_slate(phi, rnd):
    c = Cell(PW, PH)
    rock_blob(c, 20, 18, 8, (95, 100, 110), rnd, moss=0.7)
    c.outline(lambda col: shade(col, 0.6))
    return c


def rock_pile(phi, rnd):
    c = Cell(PW, PH)
    rock_blob(c, 12, 8, 7, (140, 125, 105), rnd)
    rock_blob(c, 27, 9, 9, (110, 105, 100), rnd, moss=0.3)
    rock_blob(c, 19, 6, 5, (160, 150, 130), rnd)
    c.outline(lambda col: shade(col, 0.6))
    return c


# half-width of each fish seen head-on or from behind (fish are flat, so this is small)
THICK = {"clownfish": 3.0, "blue tang": 2.4, "goldfish": 4.0, "neon tetra": 1.6,
         "jewel cichlid": 3.0, "angelfish": 1.6, "betta": 2.2}


def draw_fish_end(sp, frame, back):
    """The fish seen head-on (back=False) or from behind (back=True).
    The body is drawn as rings: seen from the front the centre is the nose and the outer ring is
    the widest part of the body; from behind the centre is the tail root. Sampling the side-view
    colours along those rings keeps each species' markings (bands, stripes, spots)."""
    c = Cell(FW, FH)
    cx, cy = FW / 2, FH / 2
    hh, tw = sp["half_h"], THICK[sp["name"]]
    for y in range(FH):
        for x in range(FW):
            dx, dy = (x + 0.5 - cx) / tw, (y + 0.5 - cy) / hh
            r = math.sqrt(dx * dx + dy * dy)
            if r > 1:
                continue
            u = 0.1 + 0.45 * r if back else 1.0 - 0.45 * r
            col = sp["colour"]("body", u, dy, 0.0, x, y)
            col = shade(col, (1.12 - 0.14 * (dy + 1)) * (1 - 0.25 * abs(dx)))
            c.put(x, y, col)

    def fin(part, x, y, f):
        col = sp["colour"](part, 0.5, -1.5 if part == "dorsal" else 1.5, f, x, y)
        c.put(x, y, mix(col, mix(col, (255, 255, 255), 0.5), f * 0.5))

    # dorsal fin on top, ventral fin underneath: thin blades seen edge-on
    for part, sign in (("dorsal", -1), ("ventral", 1)):
        spec = sp.get(part)
        if not spec:
            continue
        fh = spec[2]
        for k in range(int(round(fh))):
            fin(part, int(cx) - (1 if k < fh * 0.5 and tw > 2 else 0), int(cy + sign * (hh + k)), k / max(fh, 1))
            fin(part, int(cx), int(cy + sign * (hh + k)), k / max(fh, 1))
    # pectoral fins sticking out at the sides, flapping between frames
    for side in (-1, 1):
        for i in range(1, 4):
            lift = -0.6 * i if frame == 0 else 0.5 * i
            fin("ventral", int(cx + side * (tw + i - 1)), int(cy + hh * 0.15 + lift), i / 3)
    if back:
        # tail fin, closest to us, swinging side to side
        th = sp["tail_h"]
        swing = 3.0 if frame else -3.0
        wide = 2 if sp["tail_len"] > 8 else 1
        for k in range(-int(th), int(th) + 1):
            t = abs(k) / max(th, 1)
            tx = cx - 0.5 + swing * t
            for w in range(wide):
                col = sp["colour"]("tail", -0.5, k / max(hh, 1), t, int(tx) + w, int(cy + k))
                c.put(tx + w, cy + k, mix(col, mix(col, (255, 255, 255), 0.5), t * 0.5))
    c.outline(sp.get("edge", lambda col: shade(col, 0.62)))
    if not back:
        ey = int(cy - hh * 0.35)
        for side in (-1, 1):
            ex = int(cx + side * (tw - 0.2)) - (1 if side < 0 else 0)
            c.put(ex, ey, (15, 15, 20))
            if sp.get("eye_big", True):
                c.put(ex, ey - 1, (235, 240, 240))
        c.put(int(cx) - 1, int(cy + hh * 0.2), shade(c.get(int(cx) - 1, int(cy + hh * 0.2)) or (60, 30, 30), 0.45))
    return c


# rows 0..9 are plants, rows 10..12 are rocks (the shader picks them separately)
PLANTS = [plant_seagrass, plant_kelp, plant_anemone, plant_seafan,
          plant_brain, plant_tubes, plant_bubble_anemone, plant_staghorn,
          plant_fern, plant_cabomba,
          rock_boulder, rock_slate, rock_pile]


def main():
    img = Image.new("RGB", (SHEET_W, SHEET_H), KEY)
    for row, fn in enumerate(PLANTS):
        for f in range(PLANT_FRAMES):
            phi = 2 * math.pi * f / PLANT_FRAMES
            fn(phi, random.Random(row * 101 + 7)).blit(img, f * PW, row * PH)
    for row, sp in enumerate(SPECIES):
        for f in range(2):
            draw_fish(sp, f).blit(img, FISH_X + f * FW, row * FH)
            draw_fish_end(sp, f, False).blit(img, FISH_X + (2 + f) * FW, row * FH)
            draw_fish_end(sp, f, True).blit(img, FISH_X + (4 + f) * FW, row * FH)
    for f in range(2):
        draw_crab(f).blit(img, FISH_X + f * FW, len(SPECIES) * FH)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aquarium-sheet.png")
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
