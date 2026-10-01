"""The walking zombies for the Halloween sheet, used by halloween-sprites.py.

Each zombie is a little 3D figure (torso, head, two arms, two legs, shoes), posed for one moment of
its shambling walk, turned to face the way it walks, and drawn as pixels with depth sorting, so arms
and legs pass properly in front of and behind the body. Three views (walking towards you, at 45
degrees, and side on), two arm poses (held out in front, or hanging and swinging), two outfits, and
WALK_FRAMES frames for one full stride (two steps). The shader mirrors them for zombies going left.
"""
import math

ZW2, ZH2 = 32, 44                  # one frame
WALK_FRAMES = 8
VIEWS = [0.0, 45.0, 90.0]           # degrees turned from facing you
ARMS = ["out", "hang"]

SKIN = [(112, 142, 92), (128, 128, 98)]
SHIRT = [(64, 74, 96), (98, 64, 44)]
PANTS = [(46, 44, 52), (58, 66, 50)]
SHOE = (40, 34, 30)
HAIR = (52, 44, 36)
MOUTH = (40, 20, 22)
EYE = (28, 22, 24)

# the figure, in sprite pixels: y down from the top of the head, x to its left/right, z the way it faces
SHOULDER_Y, SHOULDER_X = 13.0, 6.0
HIP_Y, HIP_X = 26.0, 3.0
THIGH, SHIN = 8.5, 8.5
UPPER_ARM, FOREARM = 6.5, 6.5
TORSO_RX, TORSO_RZ = 5.5, 3.2      # the chest is wide but flat
LIMB_R = 1.6
HEAD_R = (3.6, 4.2, 3.6)
STEP_SWING = 0.42                  # how far the legs swing, in radians
LOOK_DOWN = 0.30                   # the camera is a little above: nearer things sit lower on screen
LIGHT = (0.45, -0.55, 0.70)        # the moon, upper right, in front


def _norm(v):
    n = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / n for a in v)


def _add(a, b, k=1.0):
    return tuple(a[i] + b[i] * k for i in range(3))


def _limb_dir(angle_fwd, spread=0.0):
    """A unit vector hanging straight down, swung `angle_fwd` forwards and `spread` outwards."""
    return _norm((math.sin(spread), math.cos(angle_fwd) * math.cos(spread), math.sin(angle_fwd)))


def _pose(arms, kind, frame):
    """Joint positions for one moment of the walk, plus how far the head lolls."""
    phi = frame / WALK_FRAMES * 2 * math.pi
    parts = []                                         # (start, end, radius, colour-name)
    feet = []
    for side in (-1, 1):
        ph = phi + (0 if side < 0 else math.pi)
        drag = 0.6 if (side > 0) == (kind == 0) else 1.0   # one leg drags a little
        a = STEP_SWING * drag * math.sin(ph)
        bend = max(0.0, math.sin(ph + math.pi / 2)) * 0.7 * drag
        hip = (side * HIP_X, HIP_Y, 0.0)
        knee = _add(hip, _limb_dir(a, side * 0.05), THIGH)
        ankle = _add(knee, _limb_dir(a - bend), SHIN)
        parts.append((hip, knee, LIMB_R + 0.4, "pants"))
        parts.append((knee, ankle, LIMB_R + 0.2, "pants"))
        parts.append((ankle, _add(ankle, (0, 0, 1), 3.0), LIMB_R, "shoe"))
        feet.append(ankle)
    for side in (-1, 1):
        sh = (side * SHOULDER_X, SHOULDER_Y, 0.0)
        ph = phi + (math.pi if side < 0 else 0.0)        # each arm swings with the opposite leg
        if arms == "out":
            lift = 1.25 + 0.10 * math.sin(ph) * (1 if side > 0 else 0.6)
            elbow = _add(sh, _limb_dir(lift, -side * 0.30), UPPER_ARM)
            hand = _add(elbow, _limb_dir(lift + 0.15, -side * 0.22), FOREARM)
            droop = _add(hand, _limb_dir(0.6), 2.0)      # limp wrists, fingers hanging
        else:
            swing = 0.38 * math.sin(ph) * (0.7 if side == kind * 2 - 1 else 1.0)
            elbow = _add(sh, _limb_dir(swing, side * 0.10), UPPER_ARM)
            hand = _add(elbow, _limb_dir(swing + 0.35, side * 0.05), FOREARM)
            droop = _add(hand, _limb_dir(swing + 0.2), 2.0)
        parts.append((sh, elbow, LIMB_R + 0.3, "shirt"))
        parts.append((elbow, hand, LIMB_R, "skin"))
        parts.append((hand, droop, LIMB_R - 0.3, "skin"))
    parts.append(((0.0, 9.5, 1.4), (0.0, SHOULDER_Y, 0.9), 1.3, "skin"))   # the neck
    loll = 0.25 * math.sin(phi) if kind == 0 else 0.25 * math.sin(2 * phi)
    return parts, feet, loll


def _turn(p, yaw):
    """Turn a point by `yaw` (degrees) and look at it: returns screen x, screen y, depth (bigger = nearer)."""
    r = math.radians(yaw)
    x = p[0] * math.cos(r) + p[2] * math.sin(r)
    z = -p[0] * math.sin(r) + p[2] * math.cos(r)
    return x, p[1] + z * LOOK_DOWN, z


def _turn_dir(n, yaw):
    r = math.radians(yaw)
    return (n[0] * math.cos(r) + n[2] * math.sin(r), n[1], -n[0] * math.sin(r) + n[2] * math.cos(r))


def _shade(col, k):
    return tuple(max(1, min(255, int(round(v * k)))) for v in col)


def draw_zombie(view, arms, kind, frame):
    """One frame, as a {(x, y): colour} dict on a ZW2 x ZH2 canvas, feet on the bottom row."""
    yaw = VIEWS[view]
    colours = {"skin": SKIN[kind], "shirt": SHIRT[kind], "pants": PANTS[kind], "shoe": SHOE}
    parts, feet, loll = _pose(ARMS[arms], kind, frame)
    # the body stands on whichever foot is lowest
    lift = (ZH2 - 1.5) - max(_turn(f, yaw)[1] for f in feet)
    # side-on figures stand a little back so arms held out still fit
    ox = ZW2 / 2 - (3.0 * math.sin(math.radians(yaw)) if ARMS[arms] == "out" else 0.0)
    zbuf, px = {}, {}

    def splat(p, n, col):
        sx, sy, z = _turn(p, yaw)
        key = (int(math.floor(sx + ox)), int(math.floor(sy + lift)))
        if not (0 <= key[0] < ZW2 and 0 <= key[1] < ZH2):
            return
        if key in zbuf and zbuf[key] >= z:
            return
        lit = max(0.0, sum(a * b for a, b in zip(_turn_dir(n, yaw), _norm(LIGHT))))
        zbuf[key] = z
        px[key] = _shade(col, 0.55 + 0.6 * lit)

    # limbs: tubes between the joints
    for a, b, r, name in parts:
        d = tuple(b[i] - a[i] for i in range(3))
        length = math.sqrt(sum(v * v for v in d)) or 1.0
        u = _norm(d)
        side = _norm((u[1], -u[0], 0.0) if abs(u[2]) < 0.9 else (1.0, 0.0, 0.0))
        up = _norm((u[1] * side[2] - u[2] * side[1], u[2] * side[0] - u[0] * side[2], u[0] * side[1] - u[1] * side[0]))
        steps = int(length * 3) + 1
        for i in range(steps + 1):
            c = _add(a, d, i / steps)
            for k in range(16):
                ang = k / 16 * 2 * math.pi
                n = _add(_add((0, 0, 0), side, math.cos(ang)), up, math.sin(ang))
                for rr in (r, r * 0.5):
                    col = colours[name]
                    if name == "pants" and i > steps * 0.8 and parts.index((a, b, r, name)) % 3 == 1:
                        col = SKIN[kind]                 # torn trouser ends, bare ankles
                    splat(_add(c, n, rr), n, col)
    # the torso: a flattened tube from the shoulders down to the hips, leaning forward a little
    for i in range(41):
        t = i / 40
        y = SHOULDER_Y - 1 + (HIP_Y + 1 - SHOULDER_Y) * t
        zc = 1.2 * (1 - t)                               # hunched
        for k in range(48):
            ang = k / 48 * 2 * math.pi
            for rr in (1.0, 0.6, 0.25):
                n = (math.sin(ang), 0.0, math.cos(ang))
                p = (n[0] * TORSO_RX * rr, y, zc + n[2] * TORSO_RZ * rr)
                col = colours["shirt"]
                if (int(p[0] * 1.3) * 7 + int(y) * 3 + kind) % 11 == 0:
                    col = _shade(col, 0.65)              # stains and tears
                if 15 <= y <= 20 and 1.0 < p[0] < 3.0 and n[2] > 0.3 and int(y) % 2:
                    col = SKIN[kind]                     # ribs showing through a tear
                splat(p, n, col)
    # the head, lolling forward and to the side
    hc = (math.sin(loll) * 1.5, 6.0, 1.5)
    for i in range(24):
        th = i / 23 * math.pi
        for k in range(36):
            ph = k / 36 * 2 * math.pi
            n = (math.sin(th) * math.sin(ph), -math.cos(th), math.sin(th) * math.cos(ph))
            col = colours["skin"]
            if n[1] < -0.55 or (n[2] < -0.2 and n[1] < 0.2):
                if (k + i + kind) % 3:
                    col = HAIR                            # patchy hair, top and back
            for sx in (-1, 1):
                e = (sx * 0.42, -0.10, 0.90)
                if sum(a * b for a, b in zip(n, _norm(e))) > 0.965:
                    col = EYE
            if sum(a * b for a, b in zip(n, _norm((0.0, 0.42, 0.90)))) > 0.955:
                col = MOUTH                               # the open jaw
            for rr in (1.0, 0.6):
                splat((hc[0] + n[0] * HEAD_R[0] * rr, hc[1] + n[1] * HEAD_R[1] * rr, hc[2] + n[2] * HEAD_R[2] * rr), n, col)
    return px
