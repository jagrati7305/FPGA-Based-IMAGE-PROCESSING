# gen_test.py  (run from the project root)
#   python3 scripts/gen_test.py [asparagus|dark|bright]
# Writes data/frame.hex (the "camera image") and data/lut.hex.
#   asparagus : back-lit scene, bright background, ONE dark spear lying along x, with taper, a gentle
#               bow, a rounded tip, dust specks on the background and a few pin-holes in the spear.
#   dark/bright : exposure-control tests (too dark / saturated).
# The LUT INVERTS the image: the dark spear becomes bright, so the rest of the chain finds a bright
# object on a dark background.
import sys, math, random
from config import W, H
mode = sys.argv[1] if len(sys.argv) > 1 else "asparagus"
random.seed(1)
img = [[0] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if mode == "dark":
            v = random.randint(10, 30)
        elif mode == "bright":
            v = random.randint(250, 255)
        else:
            v = 226 - abs(x - W / 2) * 20 / (W / 2) + random.randint(-4, 4)   # back-light with vignetting
        img[y][x] = int(v)

if mode == "asparagus":
    x0, x1 = 20, W - 20
    for x in range(x0, x1 + 1):
        t  = (x - x0) / (x1 - x0)
        yc = H / 2 + 7 * math.sin(math.pi * t)            # gentle bow
        d  = 24 - 12 * t                                  # diameter 24 px (butt) -> 12 px (tip)
        if x > x1 - 10:                                   # rounded tip
            d *= math.sqrt(max(0.0, 1 - ((x - (x1 - 10)) / 10) ** 2))
        for y in range(H):
            if abs(y - yc) <= d / 2:
                img[y][x] = 45 + random.randint(0, 10)    # dark spear
    for _ in range(30):                                   # dust specks on the bright background
        x, y = random.randrange(W), random.randrange(H)
        if img[y][x] > 150: img[y][x] = 60
    for _ in range(8):                                    # pin-holes inside the spear
        x = random.randrange(x0 + 15, x1 - 15)
        y = int(H / 2 + 7 * math.sin(math.pi * (x - x0) / (x1 - x0)))
        img[y][x] = 230

open("data/frame.hex", "w").write("\n".join(f"{p:02x}" for row in img for p in row) + "\n")
open("data/lut.hex", "w").write("\n".join(f"{255 - i:02x}" for i in range(256)) + "\n")   # invert
print(f"wrote data/frame.hex ({W}x{H}) and data/lut.hex (inverting), mode = {mode}")
