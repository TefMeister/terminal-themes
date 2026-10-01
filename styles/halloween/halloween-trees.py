"""The big gnarled trees that stand in the field, for the Halloween sheet (used by halloween-sprites.py).

Each tree is a trunk with root flare and branches that fork and twist as they thin out, drawn with real
bark (grooves, knots, a little moss) that the shader only shows when lightning strikes; in the dark the
tree is a black shape with a moonlit edge. A few leaves cling on: dark green, yellow and red, mostly at
the tips, mostly bare. Leaves carry blue 5 so the shader can tell them from bark.
The script also picks branch points that spiders can hang from (ANCHORS, printed for the shader).
"""
import math
import random

BTW, BTH = 160, 200                 # one tree drawing
KINDS = 2
LEAF_CODE = 5                       # blue value that marks a leaf
LEAF_COLOURS = [(34, 62, 5), (46, 78, 5), (196, 160, 5), (150, 40, 5)]   # dark greens, yellow, red
LEAF_WEIGHTS = [3, 2, 2, 2]
LEAF_SHARE = 0.30                   # share of branch tips that keep a few leaves
BARK = (78, 66, 56)
BARK_DARK = (34, 28, 26)
MOSS = (58, 70, 44)
ANCHORS_PER_TREE = 4


def _mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _bark(x, y, along, rnd_seed):
    """Bark colour at a pixel: grooves running `along` the limb (an angle), knots and moss."""
    u = x * math.cos(along) + y * math.sin(along)        # across the grain
    v = -x * math.sin(along) + y * math.cos(along)       # along the grain
    groove = math.sin(u * 1.7 + math.sin(v * 0.21 + rnd_seed) * 2.2)
    col = _mix(BARK_DARK, BARK, 0.55 + 0.45 * groove)
    n = math.sin(x * 0.37 + y * 0.11 + rnd_seed) * math.sin(y * 0.29 - x * 0.07)
    if n > 0.82:
        col = _mix(col, MOSS, 0.6)
    if math.sin(u * 0.31 + v * 0.13 + rnd_seed * 3.0) > 0.985:
        col = _mix(col, BARK_DARK, 0.8)                 # a knot
    return tuple(max(12, c) for c in col)              # never black: black means empty


def draw_tree(kind):
    """Returns ({(x, y): colour}, anchors) for one big tree; the trunk stands on the bottom row.
    The tree is grown smaller and smaller until no branch runs off the edge of its drawing."""
    size = 1.0
    while True:
        px, anchors, fits = _grow(kind, size)
        if fits:
            return px, anchors
        size *= 0.93
        if size < 0.2:
            raise RuntimeError("tree %d never fits its drawing" % kind)


def _grow(kind, size):
    rnd = random.Random(707 + kind * 97)
    fits = True
    px = {}
    segs = []                                          # (x0, y0, x1, y1, width, level)

    def stamp(x, y, r, along):
        for dy in range(-int(r) - 1, int(r) + 2):
            for dx in range(-int(r) - 1, int(r) + 2):
                if dx * dx + dy * dy <= r * r + 0.3:
                    X, Y = int(math.floor(x + dx)), int(math.floor(y + dy))
                    if Y >= BTH:
                        continue                       # roots going into the ground
                    if not (1 <= X < BTW - 1 and 1 <= Y):
                        nonlocal fits
                        fits = False
                    else:
                        col = _bark(X, Y, along, kind * 1.7)
                        if dx > r * 0.45:
                            col = _mix(col, (120, 116, 132), 0.25)   # moonlit side
                        px[(X, Y)] = col

    def limb(x, y, ang, length, width, level):
        """Grow a limb from (x, y) heading `ang` (0 = straight up), then fork."""
        steps = max(2, int(length / 2))
        for i in range(steps):
            ang += rnd.uniform(-0.18, 0.18)            # gnarled
            nx = x + math.sin(ang) * length / steps
            ny = y - math.cos(ang) * length / steps
            w = width * (1.0 - 0.35 * i / steps)
            segs.append((x, y, nx, ny, w, level))
            for k in range(3):
                t = k / 3
                stamp(x + (nx - x) * t, y + (ny - y) * t, w / 2, ang)
            x, y = nx, ny
        if width < 1.6 or level > 5:
            return [(x, y)]
        tips = []
        forks = 2 if rnd.random() < 0.7 else 3
        for f in range(forks):
            spread = (f - (forks - 1) / 2) * rnd.uniform(0.5, 0.8)
            tips += limb(x, y, ang + spread + rnd.uniform(-0.2, 0.2), length * rnd.uniform(0.62, 0.8),
                         width * rnd.uniform(0.55, 0.7), level + 1)
        return tips

    cx = BTW * (0.47 if kind == 0 else 0.53)
    # root flare: the trunk widens into the ground
    for y in range(BTH - 8, BTH):
        f = (y - (BTH - 8)) / 8.0
        stamp(cx, y, 8 + f * f * 9, 0.0)
    trunk_h = BTH * (0.42 if kind == 0 else 0.36) * size
    lean = 0.10 if kind == 0 else -0.14
    tips = limb(cx, BTH - 6, lean, trunk_h, 16, 0)
    # a couple of low limbs straight off the trunk, the big ones spiders hang from
    for side, at in ((-1, 0.55), (1, 0.72 if kind == 0 else 0.62)):
        y0 = BTH - 6 - trunk_h * at
        x0 = cx + math.sin(lean) * trunk_h * at
        tips += limb(x0, y0, side * rnd.uniform(1.05, 1.35), BTH * 0.22 * size, 8, 2)
    # leaves: a few clusters near some of the tips
    for (x, y) in tips:
        if rnd.random() > LEAF_SHARE:
            continue
        col = rnd.choices(LEAF_COLOURS, LEAF_WEIGHTS)[0]
        for _ in range(rnd.randint(2, 5)):
            lx, ly = int(x + rnd.uniform(-3, 3)), int(y + rnd.uniform(-2, 3))
            if 0 <= lx < BTW and 0 <= ly < BTH:
                px[(lx, ly)] = col
                if rnd.random() < 0.5 and 0 <= lx + 1 < BTW:
                    px[(lx + 1, ly)] = (min(255, col[0] + 20), min(255, col[1] + 16), LEAF_CODE)
    # anchors: the middle underside of the thick, fairly level limbs
    cands = [s for s in segs if 1 <= s[5] <= 3 and s[4] >= 3.0 and abs(s[3] - s[1]) < 0.7 * abs(s[2] - s[0])]
    rnd.shuffle(cands)
    anchors = []
    for s in cands:
        ax, ay = (s[0] + s[2]) / 2, (s[1] + s[3]) / 2 + s[4] / 2
        if all(abs(ax - bx) > 18 for bx, _ in anchors) and 10 < ax < BTW - 10:
            anchors.append((round(ax, 1), round(ay, 1)))
        if len(anchors) == ANCHORS_PER_TREE:
            break
    while len(anchors) < ANCHORS_PER_TREE:            # never short: fall back to the trunk's top
        anchors.append((round(cx, 1), round(BTH - 6 - trunk_h, 1)))
    return px, anchors, fits
