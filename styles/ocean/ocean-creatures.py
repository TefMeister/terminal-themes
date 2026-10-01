"""The ocean's big and small swimmers, for ocean-sprites.py: a humpback whale and a little silver
schooling fish. Both face right; the shader mirrors them to swim left.

Each draw function returns a {(x, y): colour} dict for one frame.
"""
import math

WHALE_W, WHALE_H = 128, 40
WHALE_FRAMES = 4                    # one beat of the tail, up and back down
SCHOOL_W, SCHOOL_H = 16, 8
SCHOOL_FRAMES = 2

WHALE_BACK = (52, 70, 92)           # dark slate blue on top
WHALE_BELLY = (176, 186, 192)       # pale underneath
WHALE_GROOVE = (128, 138, 148)      # the throat grooves
WHALE_EYE = (20, 26, 34)
SILVER_BACK = (70, 96, 120)
SILVER_SIDE = (196, 212, 222)
SILVER_STRIPE = (120, 170, 200)


def _mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def draw_whale(frame):
    """A humpback seen side on: long body, pale grooved throat, a long flipper, a small hump of a
    dorsal fin, and flukes that beat up and down (the back half of the body bends with them)."""
    px = {}
    phase = frame / WHALE_FRAMES * 2 * math.pi
    nose, tail = 124.0, 14.0
    mid_y = WHALE_H * 0.48

    def bend(x):
        """How far the body's centre line is lifted at x: nothing at the head, most at the tail."""
        t = max(0.0, (nose - x) / (nose - tail) - 0.35) / 0.65
        return math.sin(phase) * 4.0 * t * t

    def half(x):
        u = (x - tail) / (nose - tail)                   # 0 at the tail stock, 1 at the nose
        if u < 0 or u > 1:
            return 0.0
        # thickest just ahead of the middle, a blunt rounded head, thinning to the tail stock
        h = 10.0 * math.sqrt(max(0.0, 1 - ((u - 0.58) / 0.58) ** 2))
        if u > 0.9:
            h *= 0.45 + 0.55 * math.sqrt(max(0.0, 1 - ((u - 0.9) / 0.1) ** 2))   # a rounded snout
        return max(h, 1.8)

    for x in range(WHALE_W):
        cx = x + 0.5
        h = half(cx)
        if h <= 0:
            continue
        c = mid_y - bend(cx)
        for y in range(WHALE_H):
            v = (y + 0.5 - c) / h                         # -1 top edge .. 1 belly edge
            if abs(v) > 1:
                continue
            u = (cx - tail) / (nose - tail)
            col = _mix(WHALE_BACK, WHALE_BELLY, (v + 0.15) * 1.4) if v > -0.15 else WHALE_BACK
            if v < -0.5:
                col = _mix(col, (80, 100, 124), 0.4)     # sunlight on the back
            if u > 0.62 and v > 0.25 and int(cx) % 3 == 0:
                col = WHALE_GROOVE                        # throat grooves
            if u > 0.9 and abs(v - 0.12) < 0.1:
                col = (30, 38, 50)                        # the line of the mouth
            if u > 0.93 and v < -0.3 and (int(cx) + y) % 4 == 0:
                col = (110, 120, 130)                     # knobbly bumps on the head
            px[(x, y)] = col
    # the eye, just above the end of the mouth
    ex, ey = int(nose - 16), int(mid_y + 1)
    px[(ex, ey)] = WHALE_EYE
    # small dorsal hump two thirds of the way back
    dx = tail + (nose - tail) * 0.35
    for i in range(6):
        for j in range(3 - i // 2):
            x, y = int(dx + i), int(mid_y - bend(dx) - half(dx) - j)
            px[(x, y)] = WHALE_BACK
    # the long flipper, sweeping down and back from behind the head, gently rowing
    fx, fy = nose - 30, mid_y + 4
    row = math.sin(phase + 1.0) * 0.25
    for i in range(30):
        t = i / 29
        ang = 2.45 + row                                  # pointing down and back
        x = fx + math.cos(ang) * 30 * t
        y = fy + math.sin(ang) * 12 * t + 3 * t
        w = 2.6 * (1 - t) + 0.7
        for k in range(-6, 7):
            dy = k * 0.5
            if abs(dy) <= w:
                px[(int(x), int(y + dy))] = _mix(WHALE_BELLY, WHALE_BACK, 0.45 if dy < 0 else 0.1)
    # the flukes: a wide tail seen edge on, tipping up and down with the beat
    tilt = math.cos(phase) * 0.9
    ty = mid_y - bend(tail)
    spread = 0.35 + 0.65 * abs(math.sin(phase + 1.6))   # edge on it looks thin, tipped it looks wide
    for i in range(14):
        t = i / 13
        x = tail - 1 - t * 11
        centre = ty - tilt * t * 6
        reach = (1.5 + 7.0 * t * spread) * (1.0 - 0.5 * max(0.0, t - 0.8) / 0.2)
        notch = 1.0 if t > 0.75 else 0.0                  # the notch between the two flukes
        for k in range(-16, 17):
            dy = k * 0.5
            if notch and abs(dy) < 1.0:
                continue
            if abs(dy) <= reach:
                X, Y = int(x), int(centre + dy)
                if 0 <= X < WHALE_W and 0 <= Y < WHALE_H:
                    px[(X, Y)] = WHALE_BACK
    # darken the outline so it reads against the water
    edge = [(x, y) for (x, y) in px if any((x + a, y + b) not in px for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        px[p] = tuple(max(12, int(c * 0.6)) for c in px[p])
    return {p: c for p, c in px.items() if 0 <= p[0] < WHALE_W and 0 <= p[1] < WHALE_H}


def draw_school_fish(frame):
    """A small silver fish for the school: dark back, bright flank with a blue line, forked tail."""
    px = {}
    for x in range(SCHOOL_W):
        for y in range(SCHOOL_H):
            cx, cy = x + 0.5, y + 0.5
            u = (cx - 3.0) / 12.0                         # 0 tail stock .. 1 nose
            if 0 <= u <= 1:
                h = 2.9 * math.sin(math.pi * min(1.0, u * 1.1) ** 0.7)
                v = (cy - 4.0) / max(h, 0.6)
                if abs(v) <= 1:
                    col = SILVER_BACK if v < -0.35 else (SILVER_STRIPE if v < 0.0 else SILVER_SIDE)
                    if u > 0.85 and abs(v + 0.1) < 0.35:
                        col = (24, 30, 40)                # the eye
                    px[(x, y)] = col
    wag = 1 if frame else -1
    for i in range(3):
        px[(2 - i, 4 - 1 - i + (wag if i == 2 else 0))] = SILVER_BACK
        px[(2 - i, 4 + i + (wag if i == 2 else 0))] = SILVER_BACK
    return {p: c for p, c in px.items() if 0 <= p[0] < SCHOOL_W and 0 <= p[1] < SCHOOL_H}
