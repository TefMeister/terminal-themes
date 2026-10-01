"""Shows a few sample chat lines in the tab while a preview clip is recorded.

    python sample-text.py typing <loop seconds>   blank, then the lines type out, hold, and the
                                                   screen clears again exactly one loop later
    python sample-text.py static                   the lines appear at once and stay (for the
                                                   ocean, whose own loop mode sets the length)
    python sample-text.py static halloween         the same, with lines for the Halloween style

The cursor is hidden throughout: a blinking cursor would never be in step with the loop.
"""
import sys, time

PRE_SECONDS = 3.0      # blank screen before the typing starts
END_MARGIN = 1.0       # the screen is cleared this long before the loop ends, so both ends are blank
LINES = [
    ("> can you make the fish further away look dimmer, and the close ones a bit brighter?", 0.02),
    ("", 0),
    ("● Sure. The ocean is drawn by a small shader, so each fish can fade by how far away it is.", 0.015),
    ("", 0),
    ("● Read styles/ocean/ocean.hlsl", 0.01),
    ("", 0),
    ("● Edit ocean.hlsl: fish brightness and colour now follow their distance", 0.01),
    ("", 0),
    ("● Done. Far fish are dim and grey, close ones bright and vivid. Open a new tab to see it.", 0.015),
    ("", 0),
    ("> ", 0),
]
HALLOWEEN = [
    ("> make me a halloween theme: a big ghost, lightning, zombies, pumpkins and spiders", 0.02),
    ("", 0),
    ("● On it. Everything is pixel art, drawn behind your text by a small shader.", 0.015),
    ("", 0),
    ("● Write styles/halloween/halloween.hlsl", 0.01),
    ("", 0),
    ("● Done. Watch the middle of the screen when the lightning starts.", 0.015),
    ("", 0),
    ("> ", 0),
]
CLEAR = "\033[2J\033[H"
HIDE_CURSOR = "\033[?25l"


def out(s):
    print(s, end="", flush=True)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    global LINES
    mode = sys.argv[1] if len(sys.argv) > 1 else "typing"
    if "halloween" in sys.argv[2:]:
        LINES = HALLOWEEN
    out(CLEAR + HIDE_CURSOR)
    if mode == "static":
        out("\n".join(text for text, _ in LINES))
        time.sleep(90.0)
        return
    loop = float(sys.argv[2]) if len(sys.argv) > 2 else 18.0
    t0 = time.perf_counter()
    time.sleep(PRE_SECONDS)
    for text, delay in LINES:
        for ch in text:
            out(ch)
            if delay:
                time.sleep(delay)
        if text != "> ":
            out("\n")
        time.sleep(0.35)
    clear_at = t0 + PRE_SECONDS + loop - END_MARGIN
    time.sleep(max(0.0, clear_at - time.perf_counter()))
    out(CLEAR + HIDE_CURSOR)   # hide it again: clearing the screen can bring the cursor back
    time.sleep(6.0)


if __name__ == "__main__":
    main()
