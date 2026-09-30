"""Turns recorded frames into a GIF that loops without a seam.

    python make-loop.py <frames dir> <out.gif> --period 160 --fps 5 [--width 1152] [--native]

It looks for the start frame s where frame s+period matches frame s best (ideally exactly),
prints how many pixels still differ, and encodes frames s .. s+period-1 with ffmpeg. The window
frame and tab bar are cropped off (a maximised 3440x1440 window is assumed; change CROP for
another size). --native keeps the crop at full size instead of scaling it, for clips whose whole
point is fine detail, like scanlines. Needs Pillow, NumPy and ffmpeg on the PATH.
"""
import argparse, glob, os, subprocess, sys

import numpy as np
from PIL import Image

CROP = (8, 48, 3430, 1348)          # x, y, width, height of the text area; stops short of the scrollbar
NATIVE = (8, 48, 1152, 450)          # the top-left corner at full size


def load(path, crop):
    x, y, w, h = crop
    return np.asarray(Image.open(path).convert("RGB"))[y:y + h, x:x + w]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames")
    ap.add_argument("out")
    ap.add_argument("--period", type=int, required=True, help="frames in one loop")
    ap.add_argument("--fps", type=float, required=True)
    ap.add_argument("--width", type=int, default=1152)
    ap.add_argument("--native", action="store_true")
    ap.add_argument("--dither", default="bayer:bayer_scale=3")
    a = ap.parse_args()

    files = sorted(glob.glob(os.path.join(a.frames, "u*.png")))
    n = len(files)
    if n < a.period + 1:
        sys.exit(f"only {n} frames, need at least {a.period + 1}")
    crop = NATIVE if a.native else CROP
    # compare on a thumbnail first (fast), then confirm the winner at full size
    small = [np.asarray(Image.fromarray(load(f, crop)).resize((172, 68), Image.BILINEAR), dtype=np.int16)
             for f in files]
    best, best_d = 0, None
    for s in range(0, n - a.period):
        d = int(np.abs(small[s] - small[s + a.period]).sum())
        if best_d is None or d < best_d:
            best, best_d = s, d
    full = (load(files[best], crop) != load(files[best + a.period], crop)).any(axis=2).sum()
    print(f"loop starts at frame {best}: frame {best + a.period} differs from it in {full} pixels "
          f"of {crop[2] * crop[3]}" + ("  (exact)" if full == 0 else ""))

    x, y, w, h = crop
    vf = f"crop={w}:{h}:{x}:{y}"
    if not a.native:
        vf += f",scale={a.width}:-1:flags=lanczos"
    vf += f",split[p1][p2];[p1]palettegen=stats_mode=diff[pal];[p2][pal]paletteuse=dither={a.dither}:diff_mode=rectangle"
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(a.fps),
           "-start_number", str(best), "-i", os.path.join(a.frames, "u%04d.png"),
           "-frames:v", str(a.period), "-vf", vf, "-loop", "0", a.out]
    subprocess.run(cmd, check=True)
    print(f"wrote {a.out}: {a.period} frames, {os.path.getsize(a.out) // 1024} KB")


if __name__ == "__main__":
    main()
