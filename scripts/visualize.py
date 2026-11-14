# visualize.py (run from the project root, after a simulation): builds out/compare.png
#   python3 scripts/visualize.py            # stages shifted back by 8 columns so they line up with the input
#   python3 scripts/visualize.py --raw      # exactly what the hardware streams (no shift correction)
# Panels: input | after LUT (inverted) | after 9x1 greyscale closing | threshold bits |
#         after 1x9 binary closing | FINAL cleaned silhouette | pixels changed by cleaning (XOR) |
#         input with the detected start / end / centre line drawn on it.
import sys, os
from PIL import Image, ImageDraw
from config import W, H
SHIFT = 0 if "--raw" in sys.argv else 8        # the causal 9x1 filter delays the picture by 8 columns
SCALE = 2

def rd(name, base=16):
    out = []
    for l in open(name):
        if l.strip():
            try: out.append(int(l, base))
            except ValueError: out.append(0)                  # 'xx' = power-up value in the 1st frame
    return out
def frame2(name, base=16):
    return rd(name, base)[W*H:2*W*H]                       # 2nd frame (the 1st can hold power-up values)

def grey_rows(flat):                                       # row-major flat list -> rows[y][x]
    return [flat[y*W:(y+1)*W] for y in range(H)]
def from_lines(flat, hi=255):                              # transposed stream (W lines of H) -> rows[y][x]
    return [[flat[x*H + y] * hi for x in range(W)] for y in range(H)]
def shift_left(rows, fill):
    return [r[SHIFT:] + [fill] * SHIFT for r in rows] if SHIFT else rows
def to_img(rows):
    im = Image.new("L", (W, H))
    im.putdata([min(255, max(0, v)) for r in rows for v in r])
    return im.convert("RGB")

inp = grey_rows(rd("data/frame.hex"))
lut = grey_rows(frame2("out/rtl_lut.hex"))
cl  = shift_left(grey_rows(frame2("out/rtl_closing.hex")), 0)
bg  = frame2("out/rtl_bg.hex");  oc = frame2("out/rtl_oc.hex");  bc = frame2("out/rtl_bc.hex")
bgi = shift_left(from_lines(bg), 0)
bci = shift_left(from_lines(bc), 0)
oci = shift_left(from_lines(oc), 0)
xor = shift_left(from_lines([a ^ b for a, b in zip(bg, oc)]), 0)

# input with detected edges drawn on it (red = start, blue = end, green = centre line)
edge = [tuple(map(int, l.split())) for l in open("out/rtl_edge.txt") if l.strip()][W:2*W]
over = to_img(inp)
px = over.load()
for xm, (s, e, found) in enumerate(edge):
    x = xm - SHIFT
    if found and 0 <= x < W:
        for y, col in ((s, (255, 0, 0)), (e - 1, (0, 90, 255)), ((s + e - 1) // 2, (0, 200, 0))):
            if 0 <= y < H: px[x, y] = col

title = "input with detected edges"
try:
    from scripts.grade_asparagus import parse_packet, grade
    pk = parse_packet(bytes(int(l, 16) for l in open("out/uart.txt") if l.strip()))
    r = grade(pk)
    title = "result: " + r["grade"] + (f"  L={r['length_mm']:.0f}mm D={r['median_diameter_mm']:.1f}mm bow={r['bow_mm']:.1f}mm" if r["found"] else "")
except Exception:
    pass

panels = [("1 input (camera)", to_img(inp)), ("2 after LUT (inverted)", to_img(lut)),
          ("3 after 9x1 greyscale closing", to_img(cl)), ("4 threshold bits", to_img(bgi)),
          ("5 after 1x9 binary closing", to_img(bci)), ("6 FINAL silhouette (after 5x1)", to_img(oci)),
          ("7 changed by cleaning (XOR)", to_img(xor)), ("8 " + title, over)]
pw, ph, pad, cols = W * SCALE, H * SCALE, 18, 2
rows_n = (len(panels) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (pw + 8), rows_n * (ph + pad + 6)), (255, 255, 255))
d = ImageDraw.Draw(sheet)
os.makedirs("out/stages", exist_ok=True)
for i, (name, im) in enumerate(panels):
    x, y = (i % cols) * (pw + 8), (i // cols) * (ph + pad + 6)
    d.text((x + 2, y + 3), name, fill=(0, 0, 0))
    big = im.resize((pw, ph), Image.NEAREST)
    sheet.paste(big, (x, y + pad))
    im.save(f"out/stages/{name.split()[0]}_{name.split(' ', 1)[1].split('(')[0].strip().replace(' ', '_')}.png")
sheet.save("out/compare.png")
print("wrote out/compare.png and out/stages/*.png", "(raw, not shifted)" if not SHIFT else "(shifted back 8 columns)")
