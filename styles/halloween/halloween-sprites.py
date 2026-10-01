"""Draws the Halloween pixel-art sprite sheet (halloween-sheet.png) for halloween.hlsl.

Layout (must match the constants in halloween.hlsl; the script prints them):
  pumpkins      3 kinds x 4 frames,   PKW x PKH, one row per kind (the frames are the candle flame)
  hut           1,                    HUTW x HUTH, to the right of the pumpkins
  big pumpkins  3 x 4 frames,         BPW x BPH, at the bottom: turned to look left, drawn twice as fine
  zombies       12 rows x 8 frames,   ZW x ZH, row = (view * 2 + arms) * 2 + outfit; view 0 towards you,
                                      1 at 45 degrees, 2 side on (all walking right); arms 0 out, 1 hanging
  witch         4 frames,             WW x WH (a silhouette mask, facing right)
  spider        4 frames,             SW x SH (seen from underneath, crawling on the glass, facing up)
  hanging       2 frames,             HW x HH (seen from behind, head down, thread at the top)
  trees         2 kinds,              TW x TH (silhouette masks)
  tombstones    4 kinds,              GW x GH
Magenta (255, 0, 255) means "nothing here". Pure black is never used in the art.
Light codes, read by the shader (red is 255 or close to it, blue is the code):
  blue 7  candle light seen through a pumpkin's holes; green is the brightness. Flickers.
  blue 8  lit by the candle but keeps its own colour (wax, cut flesh). Flickers with it.
  blue 9  the hut's window light; green is the brightness.
Run:  python halloween-sprites.py
"""
import math
import os
import importlib.util
import random
from PIL import Image

_spec = importlib.util.spec_from_file_location(
    "halloween_zombies", os.path.join(os.path.dirname(os.path.abspath(__file__)), "halloween-zombies.py"))
ZOMBIE_ART = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ZOMBIE_ART)

KEY = (255, 0, 255)

PKW, PKH = 48, 40
ZW, ZH = ZOMBIE_ART.ZW2, ZOMBIE_ART.ZH2
Z_ROWS = len(ZOMBIE_ART.VIEWS) * len(ZOMBIE_ART.ARMS) * 2
WW, WH = 40, 24
SW, SH = 40, 40
HW, HH = 24, 24
TW, TH = 64, 80
GW, GH = 16, 22
HUTW, HUTH = 128, 120

PK_Y = 0
HUT_X = 4 * PKW
Z_Y = max(PK_Y + 3 * PKH, HUTH)
W_Y = Z_Y + Z_ROWS * ZH
S_Y = W_Y + WH
H_Y = S_Y + SH
T_Y = H_Y + HH
G_Y = T_Y + TH
BPW, BPH = PKW * 2, PKH * 2
BIG_Y = G_Y + GH
SHEET_W = max(HUT_X + HUTW, 4 * BPW)
SHEET_H = BIG_Y + 3 * BPH


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

ORANGE = (232, 110, 20)
ORANGE_DARK = (64, 20, 6)
ORANGE_LIGHT = (255, 178, 74)
SPILL = (255, 150, 40)
FLESH = (250, 204, 8)          # cut flesh: blue 8 = lit by the candle, keeps its own colour
WAX = (236, 222, 8)
STEM = (78, 86, 34)
FLAME_SWAY = [0.0, 0.8, 0.2, -0.7]


def glow(g):
    """Candle light seen through a hole: blue = 7 marks it, green carries the brightness."""
    return (255, clamp(g), 7)


def pumpkin_face(kind, cx, cy, ry):
    face = []
    ey = cy - ry * 0.25
    if kind == 0:
        # slanted, angry triangle eyes and a wide jagged grin
        face.append([(cx - 15, ey - 5), (cx - 3, ey + 1), (cx - 13, ey + 4)])
        face.append([(cx + 15, ey - 5), (cx + 3, ey + 1), (cx + 13, ey + 4)])
        face.append([(cx - 2, ey + 4), (cx + 2, ey + 4), (cx, ey + 8)])
        my = cy + ry * 0.35
        face.append([(cx - 16, my - 4), (cx - 11, my), (cx - 8, my - 2), (cx - 5, my + 1), (cx - 2, my - 1),
                     (cx + 2, my + 1), (cx + 5, my - 1), (cx + 8, my + 1), (cx + 11, my - 1), (cx + 16, my - 4),
                     (cx + 12, my + 5), (cx + 6, my + 3), (cx + 2, my + 6), (cx - 3, my + 3), (cx - 7, my + 6),
                     (cx - 12, my + 4)])
    elif kind == 1:
        # narrow, sharply slanted slits for eyes; a grin with two fangs
        face.append([(cx - 13, ey - 6), (cx - 2, ey + 1), (cx - 4, ey + 3), (cx - 13, ey - 1)])
        face.append([(cx + 13, ey - 6), (cx + 2, ey + 1), (cx + 4, ey + 3), (cx + 13, ey - 1)])
        face.append([(cx - 2, ey + 4), (cx + 2, ey + 4), (cx, ey + 7)])
        my = cy + ry * 0.30
        face.append([(cx - 13, my - 3), (cx - 7, my), (cx + 7, my), (cx + 13, my - 3), (cx + 9, my + 4),
                     (cx + 5, my + 6), (cx + 3, my + 2), (cx - 3, my + 2), (cx - 5, my + 6), (cx - 9, my + 4)])
    else:
        # crescent-cut evil eyes, small triangle nose, a grin with teeth left standing
        face.append([(cx - 16, ey - 3), (cx - 10, ey - 6), (cx - 3, ey - 1), (cx - 6, ey + 4), (cx - 13, ey + 3)])
        face.append([(cx + 16, ey - 3), (cx + 10, ey - 6), (cx + 3, ey - 1), (cx + 6, ey + 4), (cx + 13, ey + 3)])
        face.append([(cx - 2, ey + 5), (cx + 2, ey + 5), (cx, ey + 8)])
        my = cy + ry * 0.38
        face.append([(cx - 18, my - 5), (cx - 9, my - 1), (cx + 9, my - 1), (cx + 18, my - 5), (cx + 13, my + 3),
                     (cx + 4, my + 6), (cx - 4, my + 6), (cx - 13, my + 3)])
    return face, ey


def draw_pumpkin(kind, frame, yaw_deg=0.0, res=1):
    """A round, ribbed jack-o'-lantern lit by a candle inside. frame = the flame's shape.
    yaw_deg turns the face to the left (the shader mirrors it for pumpkins that look right).
    res draws it at that many pixels per pixel, for the big pumpkins near the screen."""
    W, H = PKW * res, PKH * res
    c = Cell(W, H)
    yaw = math.radians(yaw_deg)
    cx = PKW / 2
    ry = [15.5, 17.5, 15.0][kind]
    rx = [22.0, 19.0, 23.0][kind]
    cy = PKH - ry - 1.5
    ribs = [6, 5, 7][kind]
    lx, ly, lz = 0.45, -0.55, 0.70                       # moonlight from the upper right, towards us
    face, ey = pumpkin_face(kind, cx, cy, ry)
    my = cy + ry * 0.38

    def face_x(px, py):
        """Where on the flat face design this point of the round, turned pumpkin lies (None = round the back)."""
        u = (px - cx) / rx
        v = (py - cy) / ry
        rr = math.sqrt(max(1e-4, 1.0 - v * v))
        lon = math.asin(max(-1.0, min(1.0, u / rr))) + yaw
        if math.cos(lon) < 0.12:
            return None
        return cx + rr * math.sin(lon) * rx

    holes = set()
    for y in range(H):
        for x in range(W):
            px, py = (x + 0.5) / res, (y + 0.5) / res
            u = (px - cx) / rx
            v = (py - cy) / ry
            d = u * u + v * v * (1.0 + 0.25 * max(0.0, -v) * (1.0 - abs(u)))
            if d > 1.0:
                continue
            nz = math.sqrt(max(0.0, 1.0 - d))
            # each rib is its own bulge: tilt the surface across it (the ribs turn with the pumpkin)
            a = math.atan2(u, max(nz, 0.05)) + yaw
            rib_phase = a * ribs
            bulge = math.cos(rib_phase)
            tilt = -math.sin(rib_phase) * 0.45
            nx, ny = u + tilt, v
            n = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
            diff = max(0.0, (nx * lx + ny * ly + nz * lz) / n)
            k = 0.18 + 0.82 * diff
            k *= 0.55 + 0.45 * (bulge * 0.5 + 0.5)
            k *= 0.45 + 0.55 * math.sqrt(nz)             # dark towards the outline: it reads as round
            if v > 0.55:
                k *= 1.0 - (v - 0.55) * 0.9              # its own shadow underneath
            col = mix(ORANGE_DARK, ORANGE, k * 1.15)
            if bulge < -0.75:
                col = shade(col, 0.6)                     # the grooves between ribs
            if diff > 0.82 and bulge > 0.6 and v < 0.1:
                col = mix(col, ORANGE_LIGHT, (diff - 0.82) * 4.0)   # shine on the rib tops
            c.put(x, y, col)
            fx = face_x(px, py)
            if fx is None:
                continue
            if kind == 2 and my + 1 <= py < my + 3 and any(abs(fx - (cx + tx) - 0.5) < 0.5 for tx in (-8, -3, 3, 8)):
                continue                                  # teeth left standing in the grin
            if any(inside(pts, fx, py) for pts in face):
                holes.add((x, y))
    c.outline(lambda col: shade(col, 0.6))
    # stem, lit on its right
    sx = cx - 1 + kind
    top = cy - ry
    for i in range(7):
        bend = (i / 6.0) ** 2 * (3 if kind != 1 else -3)
        for w in range(3 if i < 4 else 2):
            for qy in range(res):
                for qx in range(res):
                    c.put((sx + bend + w) * res + qx, (top + 1 - i) * res + qy, mix((44, 48, 18), STEM, w / 2))

    # the candle stands on the bottom inside; we see it, and its flame, only through the holes
    wick_y = cy + ry * 0.28
    base_y = cy + ry * 0.80
    flx = cx + FLAME_SWAY[frame]
    flame_h = [6.5, 7.5, 6.0, 7.0][frame]
    for (x, y) in holes:
        px, py = (x + 0.5) / res, (y + 0.5) / res
        # the inside of the shell, lit brightest close to the flame
        dist = math.hypot((px - flx) / 1.6, py - (wick_y - 2))
        g = 205 - min(dist, 20) * 6.5
        near_edge = sum((x + dx, y + dy) not in holes for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        g -= near_edge * 6 / res
        col = glow(g)
        if abs(px - cx) <= 2.2 and wick_y <= py <= base_y:
            col = WAX if px - cx < 1.0 else (210, 190, 8)           # wax, shaded on one side
        t = (wick_y - py) / flame_h                                   # 0 at the wick, 1 at the tip
        if 0.0 <= t <= 1.0:
            w = (1.6 if t < 0.45 else 1.6 * (1.0 - (t - 0.45) / 0.55)) + 0.3
            if abs(px - (flx + t * FLAME_SWAY[frame] * 0.8)) <= w:
                col = glow(255) if t > 0.15 else glow(205)
        c.put(x, y, col)
    # the cut flesh: a pale rim on the hole edges facing away from the middle, and along the bottom
    for (x, y) in holes:
        side = 1 if (x + 0.5) / res > cx else -1
        for dx, dy in ((side, 0), (0, 1)):
            if (x + dx * res, y + dy * res) not in holes:
                col = c.get(x, y)
                if col and col[2] == 7:
                    c.put(x, y, FLESH)
                break
    # light leaking through the thin skin round the cuts
    reach = 2 * res
    for (x, y), col in list(c.px.items()):
        if (x, y) in holes or col[2] in (7, 8):
            continue
        near = min((abs(x - hx) + abs(y - hy) for hx, hy in holes
                    if abs(x - hx) <= reach and abs(y - hy) <= reach), default=99)
        if near <= reach:
            c.px[(x, y)] = mix(col, SPILL, (reach + 1 - near) / res * 0.12)
    # no plain skin pixel may look like one of the shader's light codes
    for p, col in list(c.px.items()):
        if col[2] not in (7, 8) and col[0] > 229 and 6 <= col[2] <= 10:
            c.px[p] = (col[0], col[1], 12)
    return c


# the turned pumpkins at the bottom of the screen, drawn twice as fine: (kind, how far the face turns)
BIG_PUMPKINS = [(0, 50.0), (1, 45.0), (2, 55.0)]


# ---------------------------------------------------------------- the witch's hut

WOOD = (74, 54, 40)
WOOD_DARK = (40, 28, 24)
SHINGLE = (66, 48, 62)
STONE_H = (96, 92, 100)


def window_glow(g):
    """Light in the hut's windows: blue = 9 marks it, green carries the brightness."""
    return (255, clamp(g), 9)


def draw_hut():
    c = Cell(HUTW, HUTH)
    rnd = random.Random(1313)
    floor_y = 100
    # stilts under the porch, then the porch deck with steps down in the middle
    for x in (16, 40, 88, 112):
        for y in range(floor_y + 4, HUTH):
            c.put(x, y, WOOD_DARK)
            c.put(x + 1, y, WOOD_DARK)
    for y in range(floor_y, floor_y + 5):
        for x in range(10, 118):
            plank = (x // 9) % 2
            col = mix(WOOD, (96, 72, 52), 0.3 * plank) if y < floor_y + 3 else WOOD_DARK
            if x % 9 == 0:
                col = WOOD_DARK
            c.put(x, y, col)
    for step in range(3):
        y0 = floor_y + 5 + step * 5
        for y in range(y0, y0 + 5):
            for x in range(54 - step * 2, 76 + step * 2):
                c.put(x, y, WOOD if y < y0 + 2 else WOOD_DARK)
    # porch railing posts and rail
    for x in (12, 116):
        for y in range(floor_y - 16, floor_y):
            c.put(x, y, WOOD_DARK)
            c.put(x + 1, y, WOOD)
    for x in range(12, 50):
        c.put(x, floor_y - 12 + (x % 7 == 0), WOOD)
    for x in range(84, 118):
        c.put(x, floor_y - 12 + (x % 9 == 0), WOOD)
    # the walls lean: wider at the bottom, crooked to the left
    for y in range(48, floor_y):
        left = 24 + (floor_y - y) * 0.10
        right = 104 - (floor_y - y) * 0.03 + math.sin(y * 0.15) * 0.6
        for x in range(int(left), int(right) + 1):
            plank = int((x - left) // 5)
            shade_k = 0.75 + 0.35 * random.Random(plank * 7 + 3).random()
            col = shade(WOOD, shade_k)
            if (x - left) % 5 < 1:
                col = WOOD_DARK                                  # gaps between the planks
            if x > right - 4:
                col = mix(col, (130, 120, 140), 0.25)            # moonlit right edge
            if rnd.random() < 0.03:
                col = shade(col, 0.6)                            # knots and rot
            c.put(x, y, col)
    # a crooked patch board nailed across
    c.line(30, 88, 50, 85, (112, 86, 60), 2)
    # the door: arched, dark, light leaking round it, a little round window
    for y in range(62, floor_y):
        for x in range(66, 85):
            dx, dy = x + 0.5 - 75.5, y + 0.5 - 70
            if dy > 0 or dx * dx + dy * dy <= 90:
                col = (34, 22, 18) if (x - 66) % 5 else (24, 16, 14)
                c.put(x, y, col)
    for y in range(64, floor_y):
        c.put(85, y, window_glow(55))
    c.put(73, 82, (150, 140, 60))                                # door knob
    for y in range(66, 72):
        for x in range(72, 79):
            if (x + 0.5 - 75.5) ** 2 + (y + 0.5 - 69) ** 2 <= 9:
                c.put(x, y, window_glow(170))
    # the big crooked window, glowing, with a cross frame
    for y in range(60, 82):
        for x in range(34, 56):
            dx, dy = (x + 0.5 - 45) / 10.0, (y + 0.5 - 71) / 11.0
            r = dx * dx + dy * dy
            if r <= 1.0:
                if r > 0.72:
                    c.put(x, y, (52, 36, 28))                    # frame
                elif abs(x + 0.5 - 45 - (y - 71) * 0.1) < 1.0 or abs(y + 0.5 - 71) < 1.0:
                    c.put(x, y, (52, 36, 28))                    # cross
                else:
                    c.put(x, y, window_glow(255 - int(r * 90) - (20 if y > 72 else 0)))
    # roof: steep, overhanging, shingled, with a bent tip curling over to the left
    apex = (60, 10)
    for y in range(4, 58):
        for x in range(4, 124):
            # left slope from (8, 56) to the apex, right slope from the apex to (122, 54)
            yl = 56 + (apex[1] - 56) * (x - 8) / (apex[0] - 8) if x <= apex[0] else None
            yr = apex[1] + (54 - apex[1]) * (x - apex[0]) / (122 - apex[0]) if x >= apex[0] else None
            edge = yl if yl is not None else yr
            sag = math.sin((x - 8) / 114.0 * math.pi) * 3.0         # the ridge line sags
            if y < edge + sag * 0.3 or y > 56 - (0 if x < 64 else (x - 64) * 0.03):
                continue
            row = int((y - edge) // 4)
            col = shade(SHINGLE, 0.8 + 0.3 * ((row + (x + row * 3) // 6) % 2))
            if (y - edge) % 4 < 1:
                col = shade(SHINGLE, 0.55)
            if x > 100:
                col = mix(col, (120, 112, 132), 0.15)
            c.put(x, y, col)
    c.line(apex[0], apex[1], 54, 4, SHINGLE, 3)
    c.line(54, 4, 47, 6, SHINGLE, 2)
    c.line(47, 6, 45, 10, SHINGLE, 1)
    # a small round attic window in the roof
    for y in range(30, 40):
        for x in range(56, 66):
            r = (x + 0.5 - 61) ** 2 + (y + 0.5 - 35) ** 2
            if r <= 20:
                c.put(x, y, (52, 36, 28) if r > 12 else window_glow(200))
    # crooked stone chimney on the right of the roof
    for y in range(16, 46):
        lean = (46 - y) * 0.12
        for x in range(int(88 + lean), int(99 + lean)):
            row = (y - 16) // 3
            col = shade(STONE_H, 0.7 + 0.3 * ((x // 4 + row) % 2))
            if (y - 16) % 3 == 0 or (x + row * 2) % 4 == 0:
                col = shade(STONE_H, 0.5)
            c.put(x, y, col)
    for x in range(int(87 + 3.6), int(101 + 3.6)):
        c.put(x, 15, shade(STONE_H, 0.85))
        c.put(x, 16, shade(STONE_H, 0.6))
    c.outline(lambda col: shade(col, 0.6) if col[2] != 9 else col)
    return c


# ---------------------------------------------------------------- zombies (drawn in halloween-zombies.py)

def zombie_cell(view, arms, kind, frame):
    c = Cell(ZW, ZH)
    c.px = ZOMBIE_ART.draw_zombie(view, arms, kind, frame)
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
        for f in range(4):
            draw_pumpkin(k, f).blit(img, f * PKW, PK_Y + k * PKH)
    draw_hut().blit(img, HUT_X, 0)
    for row, (kind, yaw) in enumerate(BIG_PUMPKINS):
        for f in range(4):
            draw_pumpkin(kind, f, yaw, 2).blit(img, f * BPW, BIG_Y + row * BPH)
    for view in range(len(ZOMBIE_ART.VIEWS)):
        for arms in range(len(ZOMBIE_ART.ARMS)):
            for kind in range(2):
                row = (view * 2 + arms) * 2 + kind
                for f in range(ZOMBIE_ART.WALK_FRAMES):
                    zombie_cell(view, arms, kind, f).blit(img, f * ZW, Z_Y + row * ZH)
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
    print(f"BIG_Y={BIG_Y} SHEET={SHEET_W}x{SHEET_H} PK_Y={PK_Y} HUT_X={HUT_X} Z_Y={Z_Y} W_Y={W_Y} S_Y={S_Y} H_Y={H_Y} T_Y={T_Y} G_Y={G_Y}")


if __name__ == "__main__":
    main()
