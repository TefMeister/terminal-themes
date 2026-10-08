"""Living fish for frequency-sheet.png: the fish the fish bones glitch into. Three kinds, two swim
frames each, 48 x 24 per cell, facing right like the bones. Used by frequency-sprites.py.
"""
import math
from PIL import ImageDraw

FISH_W, FISH_H = 48, 24
OUTLINE = (20, 16, 24, 255)
WHITE = (250, 250, 245, 255)
# kind -> (body, darker, fin, body length, body height)
KINDS = [
    ((255, 120, 20, 255), (200, 70, 10, 255), (255, 160, 60, 255), 30, 13),    # clownfish
    ((40, 110, 230, 255), (20, 60, 150, 255), (255, 210, 40, 255), 30, 15),    # blue tang
    ((250, 220, 40, 255), (200, 160, 20, 255), (60, 60, 60, 255), 24, 18),     # banded butterflyfish
]


def draw_live_fish(img, ox, oy, kind, frame):
    d = ImageDraw.Draw(img)
    body, dark, fin, length, height = KINDS[kind]
    cy = oy + FISH_H // 2
    nose = ox + 44
    tail = nose - length
    wag = 2 if frame else -2
    # tail fin, flicking between the two frames
    d.polygon([(tail + 2, cy), (tail - 7, cy - 7 + wag), (tail - 5, cy + wag // 2), (tail - 7, cy + 7 + wag)], fill=fin, outline=OUTLINE)
    # top and bottom fins
    d.polygon([(tail + 8, cy - height // 2 + 1), (tail + 14, cy - height // 2 - 4), (tail + 20, cy - height // 2 + 1)], fill=fin, outline=OUTLINE)
    d.polygon([(tail + 10, cy + height // 2 - 1), (tail + 15, cy + height // 2 + 3), (tail + 19, cy + height // 2 - 1)], fill=fin, outline=OUTLINE)
    # body
    d.ellipse((tail, cy - height // 2, nose, cy + height // 2), fill=body, outline=OUTLINE)
    for x in range(tail + 2, nose - 1):                              # shade the belly
        for y in range(cy + 2, cy + height // 2):
            if img.getpixel((x, y)) == body:
                img.putpixel((x, y), dark)
    if kind == 0:                                                     # white bands, edged black
        for bx in (nose - 13, tail + 11, tail + 3):
            for x in range(bx, bx + 3):
                for y in range(cy - height // 2, cy + height // 2 + 1):
                    if img.getpixel((x, y))[:3] in (body[:3], dark[:3]):
                        img.putpixel((x, y), WHITE if x != bx and x != bx + 2 else OUTLINE)
    if kind == 1:                                                     # the dark sweep
        for i in range(14):
            x = tail + 6 + i
            y = cy - 3 + round(math.sin(i / 13 * math.pi) * 3)
            for k in range(2):
                if img.getpixel((x, y + k))[:3] in (body[:3], dark[:3]):
                    img.putpixel((x, y + k), OUTLINE)
    if kind == 2:                                                     # thin dark stripes, slanted
        for x in range(tail + 3, nose - 5, 4):
            for y in range(cy - height // 2, cy + height // 2):
                px = x + (y - cy) // 3
                if img.getpixel((px, y))[:3] in (body[:3], dark[:3]):
                    img.putpixel((px, y), dark)
    # eye
    ex, ey = nose - 6, cy - 2
    d.ellipse((ex - 2, ey - 2, ex + 2, ey + 2), fill=WHITE)
    d.rectangle((ex, ey - 1, ex + 1, ey + 1), fill=OUTLINE)
