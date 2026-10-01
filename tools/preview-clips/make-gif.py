"""Cut window-only frames to one exact loop and save it as a GIF with one shared palette.
    python make-gif.py <frames dir> <out.gif> <period frames> <ms per frame> [width]"""
import glob, os, sys
import numpy as np
from PIL import Image

src, out, period, ms = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
W = int(sys.argv[5]) if len(sys.argv) > 5 else 700
fs = sorted(glob.glob(os.path.join(src, "u*.png")))
w0, h0 = Image.open(fs[0]).size
CROP = (8, 42, w0 - 8, h0 - 8)                      # inside the window frame, below the tab bar
small = [np.asarray(Image.open(f).convert("RGB").crop(CROP).resize((160, 116), Image.BILINEAR), dtype=np.int16) for f in fs]
best, bd = 0, None
for s in range(0, len(fs) - period):
    d = int(np.abs(small[s] - small[s + period]).sum())
    if bd is None or d < bd:
        best, bd = s, d
typical = int(np.mean([np.abs(small[i] - small[i + 1]).sum() for i in range(best, best + period)]))
full_a = np.asarray(Image.open(fs[best]).convert("RGB").crop(CROP))
full_b = np.asarray(Image.open(fs[best + period]).convert("RGB").crop(CROP))
print(f"loop start {best}: end frame differs in {(full_a != full_b).any(axis=2).sum()} px; "
      f"thumbnail diff {bd} vs typical frame-to-frame {typical}")
H = round((CROP[3] - CROP[1]) * W / (CROP[2] - CROP[0]))
frames = [Image.open(fs[i]).convert("RGB").crop(CROP).resize((W, H), Image.BOX) for i in range(best, best + period)]
sheet = Image.new("RGB", (W, H * 16))
for k in range(16):
    sheet.paste(frames[k * period // 16], (0, H * k))
pal = sheet.quantize(colors=220, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
q[0].save(out, save_all=True, append_images=q[1:], duration=ms, loop=0, optimize=True, disposal=1)
print(out, os.path.getsize(out) // 1024, "KB", W, H)
