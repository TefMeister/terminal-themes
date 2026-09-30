"""Turn an animated GIF into a frame sheet the starburst shader can play.

    python tools/gif-to-sheet.py my.gif my-sheet.png

Lays every frame out in a grid on one picture (left to right, top to bottom) and prints
the four numbers to put at the top of starburst.hlsl. Needs Pillow.
"""
import math
import sys

from PIL import Image

MAX_SIDE = 8192  # largest picture a graphics card is guaranteed to accept


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    gif = Image.open(src)
    count = getattr(gif, "n_frames", 1)
    w, h = gif.size
    cols = math.ceil(math.sqrt(count))
    rows = math.ceil(count / cols)

    # shrink the frames if the whole sheet would be too big for the graphics card
    scale = min(1.0, MAX_SIDE / (w * cols), MAX_SIDE / (h * rows))
    fw, fh = max(1, int(w * scale)), max(1, int(h * scale))

    sheet = Image.new("RGB", (fw * cols, fh * rows))
    durations = []
    for i in range(count):
        gif.seek(i)
        frame = gif.convert("RGB")
        if scale < 1.0:
            frame = frame.resize((fw, fh), Image.LANCZOS)
        sheet.paste(frame, ((i % cols) * fw, (i // cols) * fh))
        durations.append(gif.info.get("duration") or 100)
    sheet.save(dst)

    seconds = sum(durations) / len(durations) / 1000.0
    print(f"Saved {dst} ({sheet.width} x {sheet.height}, {count} frames).")
    print("Put these at the top of starburst.hlsl:")
    print(f"    SHEET_COLS    = {cols};")
    print(f"    SHEET_ROWS    = {rows};")
    print(f"    FRAME_COUNT   = {count};")
    print(f"    FRAME_SECONDS = {seconds:.3f};")


if __name__ == "__main__":
    main()
