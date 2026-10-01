"""Draws the Halloween pixel-art sprite sheet (halloween-sheet.png) for halloween.hlsl.

Layout (must match the constants in halloween.hlsl; the script prints them):
  pumpkins      3 kinds,              PKW x PKH, one row
  zombies       2 kinds x 4 frames,   ZW x ZH, one row per kind (front view, walking towards you)
  witch         4 frames,             WW x WH (a silhouette mask, facing right)
  spider        4 frames,             SW x SH (seen from underneath, crawling on the glass, facing up)
  hanging       2 frames,             HW x HH (seen from behind, head down, thread at the top)
  trees         2 kinds,              TW x TH (silhouette masks)
  tombstones    4 kinds,              GW x GH
Magenta (255, 0, 255) means "nothing here". Pure black is never used in the art.
Pumpkin face holes are written with blue = 7 exactly: the shader treats those pixels as candle
light (their green value is the brightness) and makes them flicker.
Run:  python halloween-sprites.py
"""
import math
import os
import random
from PIL import Image

KEY = (255, 0, 255)

PKW, PKH = 48, 40
ZW, ZH = 24, 44
WW, WH = 40, 24
SW, SH = 40, 40
HW, HH = 24, 24
TW, TH = 64, 80
GW, GH = 16, 22

PK_Y = 0
Z_Y = PK_Y + PKH
W_Y = Z_Y + 2 * ZH
S_Y = W_Y + WH
H_Y = S_Y + SH
T_Y = H_Y + HH
G_Y = T_Y + TH
SHEET_W = 256
SHEET_H = G_Y + GH


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
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    def erase(self, x, y):
        self.px.pop((int(x), int(y)), None)

    def outline(self, colour_fn, skip=None):
        edge = [(x, y) for (x, y) in self.px
                if any((x + dx, y + dy) not in self.px
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in edge:
            if skip and skip(self.px[(x, y)]):
                continue
            self.px[(x, y)] = colour_fn(self.px[(x, y)])

    def line(self, x0, y0, x1, y1, c, width=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for wx in range(width):
                for wy in range(width):
                    self.put(x + wx - width // 2, y + wy - width // 2, c(t) if callable(c) else c)

    def poly(self, pts, c):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                if inside(pts, x + 0.5, y + 0.5):
                    self.put(x, y, c(x, y) if callable(c) else c)

    def blit(self, img, ox, oy):
        for (x, y), c in self.px.items():
            img.putpixel((ox + x, oy + y), c)


def inside(pts, x, y):
    res = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            res = not res
        j = i
    return res


# ---------------------------------------------------------------- pumpkins

ORANGE = (226, 104, 18)
ORANGE_DARK = (120, 42, 8)
ORANGE_LIGHT = (255, 158, 52)
STEM = (78, 86, 34)


def glow(g):
    """A candle-lit hole pixel: blue = 7 marks it, green carries the brightness."""
    return (255, clamp(g), 7)


def draw_pumpkin(kind):
    c = Cell(PKW, PKH)
    cx = PKW / 2
    ry = [15.5, 17.5, 15.0][kind]
    rx = [22.0, 19.0, 23.0][kind]
    cy = PKH - ry - 1.5
    ribs = [6, 5, 7][kind]
    for y in range(PKH):
        for x in range(PKW):
            u = (x + 0.5 - cx) / rx
            v = (y + 0.5 - cy) / ry
            # flattened top and bottom, a slight dip where the stem goes in
            d = u * u + v * v * (1.0 + 0.25 * max(0.0, -v) * (1.0 - abs(u)))
            if d > 1.0:
                continue
            a = math.asin(max(-1.0, min(1.0, u / max(math.sqrt(max(1e-6, 1 - v * v * 0.9)), 1e-3))))
            rib = math.cos(a * ribs) * 0.5 + 0.5          # 1 on a rib's bulge, 0 in a groove
            light = 0.55 + 0.45 * (1.0 - abs(u)) - 0.25 * max(0.0, v)
            col = mix(ORANGE_DARK, ORANGE, light * (0.45 + 0.55 * rib))
            if rib > 0.85 and v < -0.2 and abs(u) < 0.6:
                col = mix(col, ORANGE_LIGHT, 0.6)
            c.put(x, y, col)
    c.outline(lambda col: shade(col, 0.55))
    # stem
    sx = cx - 1 + kind
    top = cy - ry
    for i in range(7):
        bend = (i / 6.0) ** 2 * (3 if kind != 1 else -3)
        for w in range(3 if i < 4 else 2):
            c.put(sx + bend + w, top + 1 - i, mix(STEM, (40, 44, 18), w / 2))

    face = []
    ey = cy - ry * 0.25
    if kind == 0:
        # slanted, angry triangle eyes and a wide jagged grin
        face.append([(cx - 15, ey - 5), (cx - 3, ey + 1), (cx - 13, ey + 4)])
        face.append([(cx + 15, ey - 5), (cx + 3, ey + 1), (cx + 13, ey + 4)])
        face.append([(cx - 1.5, ey + 4), (cx + 1.5, ey + 4), (cx, ey + 7)])
        my = cy + ry * 0.35
        face.append([(cx - 16, my - 4), (cx - 11, my), (cx - 8, my - 2), (cx - 5, my + 1), (cx - 2, my - 1),
                     (cx + 2, my + 1), (cx + 5, my - 1), (cx + 8, my + 1), (cx + 11, my - 1), (cx + 16, my - 4),
                     (cx + 12, my + 5), (cx + 6, my + 3), (cx + 2, my + 6), (cx - 3, my + 3), (cx - 7, my + 6),
                     (cx - 12, my + 4)])
    elif kind == 1:
        # narrow, sharply slanted slits for eyes; a grin with two fangs
        face.append([(cx - 13, ey - 6), (cx - 2, ey + 1), (cx - 4, ey + 3), (cx - 13, ey - 1)])
        face.append([(cx + 13, ey - 6), (cx + 2, ey + 1), (cx + 4, ey + 3), (cx + 13, ey - 1)])
        my = cy + ry * 0.30
        face.append([(cx - 13, my - 3), (cx - 7, my), (cx + 7, my), (cx + 13, my - 3), (cx + 9, my + 4),
                     (cx + 5, my + 6), (cx + 3, my + 2), (cx - 3, my + 2), (cx - 5, my + 6), (cx - 9, my + 4)])
    else:
        # crescent-cut evil eyes with a little pupil left in, small triangle nose, stitched grin
        face.append([(cx - 16, ey - 3), (cx - 10, ey - 6), (cx - 3, ey - 1), (cx - 6, ey + 4), (cx - 13, ey + 3)])
        face.append([(cx + 16, ey - 3), (cx + 10, ey - 6), (cx + 3, ey - 1), (cx + 6, ey + 4), (cx + 13, ey + 3)])
        face.append([(cx - 2, ey + 5), (cx + 2, ey + 5), (cx, ey + 8)])
        my = cy + ry * 0.38
        face.append([(cx - 18, my - 5), (cx - 9, my - 1), (cx + 9, my - 1), (cx + 18, my - 5), (cx + 13, my + 3),
                     (cx + 4, my + 6), (cx - 4, my + 6), (cx - 13, my + 3)])

    holes = {}
    for pts in face:
        for y in range(PKH):
            for x in range(PKW):
                if c.get(x, y) is not None and inside(pts, x + 0.5, y + 0.5):
                    holes[(x, y)] = True
    for (x, y) in holes:
        # brightest in the middle of each hole, dimmer near its cut edge; the cut flesh below and on
        # the side away from us shows as a thin pale-yellow rim
        near = sum((x + dx, y + dy) not in holes for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        c.put(x, y, glow(255 - near * 14))
    for (x, y) in list(holes):
        for dx, dy in ((0, 1), (1, 0), (-1, 0)):
            p = (x + dx, y + dy)
            if p not in holes and c.get(*p) is not None and dy == 1:
                c.put(p[0], p[1], (250, 196, 96))
    if kind == 2:
        # the stitches: teeth left standing in the grin
        my = cy + ry * 0.38
        for tx in (-8, -3, 3, 8):
            for ty in range(2):
                c.put(cx + tx, my + 1 + ty, mix(ORANGE, ORANGE_DARK, 0.3))
        # pupils
        c.put(cx - 9, ey, mix(ORANGE, ORANGE_DARK, 0.5))
        c.put(cx + 8, ey, mix(ORANGE, ORANGE_DARK, 0.5))
    return c


# ---------------------------------------------------------------- zombies (front view)

SKIN = [(112, 142, 92), (128, 128, 98)]
SHIRT = [(64, 74, 96), (98, 64, 44)]
PANTS = [(46, 44, 52), (58, 66, 50)]


def draw_zombie(kind, frame):
    c = Cell(ZW, ZH)
    rnd = random.Random(kind * 31 + 5)
    skin, shirt, pants = SKIN[kind], SHIRT[kind], PANTS[kind]
    sway = [-1, 0, 1, 0][frame]
    cx = ZW / 2 + sway * 0.5
    # legs: the leg stepping towards us reaches lower and is a little wider
    hip = 26
    for side in (-1, 1):
        fwd = (frame == 0 and side < 0) or (frame == 2 and side > 0)
        back = (frame == 0 and side > 0) or (frame == 2 and side < 0)
        foot = ZH - 1 if fwd else (ZH - 4 if back else ZH - 2)
        lx = cx + side * 3 - (1 if side < 0 else 0)
        for y in range(hip, foot + 1):
            w = 3 if not fwd else 4
            for i in range(w):
                col = pants if (y + i + kind) % 7 else shade(pants, 0.7)
                c.put(lx - w // 2 + i + (0 if y < foot - 1 else side), y, col)
        # torn trouser end with a bare ankle, then a shoe
        c.put(lx, foot - 2, skin)
        for i in range(-2, 2):
            c.put(lx + i, foot, (40, 34, 30))
    # torso, ragged shirt
    for y in range(12, hip + 1):
        hw = 6 if y < 22 else 5
        for x in range(-hw, hw + 1):
            col = shirt
            if (x * 7 + y * 3 + kind) % 11 == 0:
                col = shade(shirt, 0.65)            # stains and tears
            if y > hip - 2 and rnd.random() < 0.35:
                continue                          # ragged hem
            c.put(cx + x - 0.5, y, col)
    # a tear showing ribs on one side
    for y in range(16, 21):
        c.put(cx + 2, y, skin if y % 2 else shade(skin, 0.6))
    # arms reaching forward: seen from the front they are short and point at us, hands up
    reach = [0, 1, 0, -1][frame]
    for side in (-1, 1):
        sx = cx + side * 7 - (1 if side < 0 else 0)
        lift = reach * side
        for y in range(13, 19):
            c.put(sx, y + lift, shirt)
            c.put(sx + side, y + lift, shade(shirt, 0.8))
        # forearm and hand coming out towards us, drawn bigger and lower (closer)
        hx = sx + side * 1
        for y in range(18, 22):
            for i in range(3):
                c.put(hx - 1 + i, y + lift, skin)
        for f in range(4):
            c.put(hx - 2 + f + (1 if side > 0 else 0), 22 + lift, shade(skin, 0.75))
    # neck and lolling head
    tilt = [1, 0, -1, 0][frame] if kind == 0 else [0, 1, 0, 1][frame]
    for y in range(10, 12):
        c.put(cx - 1, y, shade(skin, 0.8))
        c.put(cx, y, shade(skin, 0.8))
    hx0 = cx - 4 + tilt * 0.5
    for y in range(1, 11):
        hw = 3.5 if 2 < y < 9 else 2.5
        for x in range(int(-hw), int(hw) + 1):
            col = skin
            if x <= -2:
                col = shade(skin, 0.8)
            c.put(hx0 + 4 + x, y, col)
    # hair (patchy), sunken eyes, open jaw
    for x in range(-3, 4):
        if (x + kind) % 3:
            c.put(hx0 + 4 + x, 1, (52, 44, 36))
    for side in (-1, 1):
        ex = hx0 + 4 + side * 2 - (1 if side < 0 else 0)
        c.put(ex, 5, (28, 22, 24))
        c.put(ex + (1 if side < 0 else 0), 5, (28, 22, 24))
        c.put(ex, 4, shade(skin, 0.55))
        c.put(ex + 1 if side < 0 else ex, 6, (190, 40, 30) if frame % 2 == kind else (28, 22, 24))
    for x in range(-1, 2):
        c.put(hx0 + 4 + x, 8, (40, 20, 22))
    c.put(hx0 + 4, 9, (40, 20, 22))
    c.outline(lambda col: shade(col, 0.55))
    return c


# ---------------------------------------------------------------- witch silhouette (facing right)

MASK = (200, 200, 200)


def draw_witch(frame):
    c = Cell(WW, WH)
    phi = frame * math.pi / 2
    by = 16
    # broom handle, slightly tilted up at the front
    c.line(9, by + 1, 39, by - 2, MASK)
    # bristles fanning out at the back, fluttering
    for i in range(9):
        spread = (i - 4) * 0.8
        flut = math.sin(phi + i) * 0.8
        c.line(10, by + 1, 1 + flut, by + 1 + spread, MASK)
    c.line(9, by - 1, 9, by + 3, MASK)
    # body: sitting on the broom, leaning forward
    c.poly([(17, by + 1), (27, by + 1), (25, by - 6), (22, by - 9), (18, by - 7)], MASK)
    # legs and pointed boots below the broom
    c.line(22, by + 1, 24, by + 4, MASK, 2)
    c.line(24, by + 5, 28, by + 4, MASK)
    # arm reaching to the handle
    c.line(23, by - 6, 29, by - 1, MASK, 2)
    # head with long nose and chin
    c.poly([(22, by - 9), (25, by - 12), (26, by - 9), (27.5, by - 9.5), (26, by - 8), (24, by - 7)], MASK)
    # hat: wide brim, tall cone bent backwards at the tip
    c.line(19, by - 11, 28, by - 13, MASK)
    tip = math.sin(phi) * 1.0
    c.poly([(21, by - 11), (26, by - 12.5), (21, by - 19), (16 + tip, by - 21)], MASK)
    # cape streaming back, flapping
    pts = [(21, by - 9)]
    for i in range(1, 7):
        x = 21 - i * 2.2
        y = by - 9 + i * 1.2 + math.sin(phi + i * 0.9) * 1.6
        pts.append((x, y))
    for i in range(6, -1, -1):
        x = 21 - i * 1.6
        y = by - 4 + i * 0.6 + math.sin(phi + i * 0.9 + 0.6) * 1.2
        pts.append((x, y))
    c.poly(pts, MASK)
    # hair streaming back under the hat
    for i in range(3):
        c.line(21, by - 10 + i, 17 - i, by - 9 + i + math.sin(phi + i) * 0.7, MASK)
    return c


# ---------------------------------------------------------------- spider, seen from underneath

SP_BODY = (66, 50, 40)
SP_STERNUM = (128, 104, 78)
SP_LEG_A = (82, 62, 48)
SP_LEG_B = (40, 30, 26)
SP_FANG = (24, 20, 20)


def draw_spider(frame):
    c = Cell(SW, SH)
    cx, cy = SW / 2, 15.5
    phase = frame * math.pi / 2
    # legs first, so the body covers their roots. Alternating gait: L1 R2 L3 R4 swing together.
    base = [-60, -25, 15, 50]                        # degrees from straight out sideways (minus = forwards)
    for side in (-1, 1):
        for i in range(4):
            group = (i + (0 if side < 0 else 1)) % 2
            a = math.radians(base[i] + math.sin(phase + group * math.pi) * 12)
            ax = cx + side * 3.5
            ay = cy - 2.5 + i * 1.7
            # femur goes out and slightly forward/back, then the knee bends, the tip presses the glass
            kx = ax + side * math.cos(a) * 9
            ky = ay + math.sin(a) * 9
            reach = 9 + (1.5 if i in (0, 3) else 0)
            tx = kx + side * math.cos(a * 1.25) * reach
            ty = ky + math.sin(a * 1.25) * reach + (2 if i >= 2 else -1)
            c.line(ax, ay, kx, ky, lambda t: SP_LEG_A if t < 0.6 else SP_LEG_B, 2)
            c.line(kx, ky, tx, ty, lambda t: SP_LEG_A if 0.3 < t < 0.6 else SP_LEG_B, 1)
            c.put(kx, ky, (150, 120, 92))          # pale knee joint
            c.put(tx, ty, (24, 18, 18))
            # little hairs on the leg
            mx, my = (kx + tx) / 2, (ky + ty) / 2
            c.put(mx, my + 1, SP_LEG_B)
    # pedipalps and fangs at the front
    for side in (-1, 1):
        c.line(cx + side * 1.5, cy - 4.5, cx + side * 3.5, cy - 8, SP_LEG_A)
        c.put(cx + side * 1 - (1 if side < 0 else 0), cy - 6, SP_FANG)
        c.put(cx + side * 1 - (1 if side < 0 else 0), cy - 7, (140, 30, 24))
    # cephalothorax (underside): leg-base ring round a pale heart-shaped sternum
    for y in range(SH):
        for x in range(SW):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx / 22 + dy * dy / 30 <= 1:
                inner = dx * dx / 9 + (dy + 0.5) * (dy + 0.5) / 16
                c.put(x, y, SP_STERNUM if inner <= 1 else SP_BODY)
    # waist, then the abdomen with a pale belly stripe, book-lung patches and spinnerets
    ay0 = cy + 12.5
    for y in range(SH):
        for x in range(SW):
            dx, dy = x + 0.5 - cx, y + 0.5 - ay0
            if dx * dx / 56 + dy * dy / 90 <= 1:
                col = SP_BODY
                if abs(dx) < 1.6 and -6 < dy < 7:
                    col = mix(SP_STERNUM, SP_BODY, 0.35)
                if 2.5 < abs(dx) < 5 and -6 < dy < -3:
                    col = (150, 128, 96)
                if (int(x) * 5 + int(y) * 3) % 9 == 0:
                    col = shade(col, 0.75)        # bristly texture
                c.put(x, y, col)
    c.put(cx - 1, ay0 + 9, (30, 24, 22))
    c.put(cx, ay0 + 9, (30, 24, 22))
    c.put(cx, cy + 3.5, SP_BODY)
    c.outline(lambda col: shade(col, 0.6))
    return c


# ---------------------------------------------------------------- hanging spider (head down)

def draw_hanging(frame):
    c = Cell(HW, HH)
    cx = HW / 2
    wig = (1 if frame else -1)
    # legs: four a side, bent like a crouched hand, twitching
    for side in (-1, 1):
        for i in range(4):
            ay = 12 + i * 1.3
            kx = cx + side * (5 + i * 0.6)
            ky = ay - 3 + i * 1.5 + (wig * side if i % 2 else -wig * side) * 0.8
            tx = cx + side * (9 + (i % 2))
            ty = ay + 3 + i * 1.6
            c.line(cx + side * 1.5, ay, kx, ky, (34, 30, 34))
            c.line(kx, ky, tx, ty, (34, 30, 34))
    # abdomen at the top (where the thread is), black and glossy, red hourglass
    for y in range(HH):
        for x in range(HW):
            dx, dy = x + 0.5 - cx, y + 0.5 - 7.5
            if dx * dx / 22 + dy * dy / 30 <= 1:
                col = (30, 26, 32)
                if dx < -1.5 and dy < -2:
                    col = (82, 78, 96)             # a glint
                c.put(x, y, col)
            dx2, dy2 = x + 0.5 - cx, y + 0.5 - 14.5
            if dx2 * dx2 / 7 + dy2 * dy2 / 6 <= 1:
                c.put(x, y, (40, 34, 40))
    for y, w in ((4, 1), (5, 0), (6, 1)):
        for x in range(-w, w + 1):
            c.put(cx + x - 0.5, y + 2, (200, 30, 26))
    # eyes catching the light
    c.put(cx - 1.5, 16, (210, 60, 50))
    c.put(cx + 0.5, 16, (210, 60, 50))
    return c


# ---------------------------------------------------------------- dead trees and tombstones

def draw_tree(kind):
    c = Cell(TW, TH)
    rnd = random.Random(77 + kind * 13)

    def branch(x, y, ang, length, width, depth):
        if depth == 0 or length < 2:
            return
        x2 = x + math.cos(ang) * length
        y2 = y + math.sin(ang) * length
        c.line(x, y, x2, y2, MASK, max(1, int(width)))
        n = 2 if depth > 1 else 1
        for i in range(n + (1 if rnd.random() < 0.4 else 0)):
            na = ang + rnd.uniform(-0.75, 0.75) + (i - n / 2) * 0.35
            na = max(-math.pi + 0.25, min(-0.25, na))
            branch(x2, y2, na, length * rnd.uniform(0.6, 0.8), width * 0.65, depth - 1)

    base = TW / 2 + (kind * 6 - 3)
    # gnarled trunk with roots
    branch(base, TH - 1, -math.pi / 2 + (0.15 if kind else -0.1), 26 if kind == 0 else 22, 5, 6)
    for r in (-1, 1):
        c.line(base, TH - 2, base + r * 7, TH - 1, MASK, 2)
    return c


STONE = (112, 110, 118)


def draw_tomb(kind):
    c = Cell(GW, GH)
    cx = GW / 2
    if kind == 0:                       # rounded headstone
        for y in range(5, GH):
            for x in range(2, GW - 2):
                dx, dy = x + 0.5 - cx, y + 0.5 - 9
                if dy > 0 or dx * dx + dy * dy <= 36:
                    c.put(x, y, STONE)
        for x in range(5, 11):
            c.put(x, 12, shade(STONE, 0.6))
        c.put(7, 10, shade(STONE, 0.6)); c.put(8, 10, shade(STONE, 0.6))
    elif kind == 1:                     # cross
        c.poly([(6.5, 2), (9.5, 2), (9.5, GH), (6.5, GH)], STONE)
        c.poly([(2.5, 6), (13.5, 6), (13.5, 9), (2.5, 9)], STONE)
    elif kind == 2:                     # tall pointed obelisk
        c.poly([(5, GH), (5, 5), (8, 0), (11, 5), (11, GH)], STONE)
    else:                               # leaning, broken slab
        c.poly([(3, GH), (2, 9), (7, 7), (9, 9), (13, 8), (13, GH)], STONE)
        c.line(6, 12, 9, 17, shade(STONE, 0.55))
    for (x, y), col in list(c.px.items()):
        k = 1.15 if x < cx - 1 else (0.8 if x > cx + 2 else 1.0)
        if (x * 3 + y * 7) % 13 == 0:
            k *= 0.8                         # moss and wear
        c.px[(x, y)] = shade(col, k)
    c.outline(lambda col: shade(col, 0.55))
    return c


def main():
    img = Image.new("RGB", (SHEET_W, SHEET_H), KEY)
    for k in range(3):
        draw_pumpkin(k).blit(img, k * PKW, PK_Y)
    for k in range(2):
        for f in range(4):
            draw_zombie(k, f).blit(img, f * ZW, Z_Y + k * ZH)
    for f in range(4):
        draw_witch(f).blit(img, f * WW, W_Y)
        draw_spider(f).blit(img, f * SW, S_Y)
    for f in range(2):
        draw_hanging(f).blit(img, f * HW, H_Y)
        draw_tree(f).blit(img, f * TW, T_Y)
    for k in range(4):
        draw_tomb(k).blit(img, k * GW, G_Y)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "halloween-sheet.png")
    img.save(out)
    print("wrote", out, img.size)
    print(f"PK_Y={PK_Y} Z_Y={Z_Y} W_Y={W_Y} S_Y={S_Y} H_Y={H_Y} T_Y={T_Y} G_Y={G_Y}")


if __name__ == "__main__":
    main()
