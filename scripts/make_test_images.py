# make_test_images.py  (run from the project root)  ->  test_images/<name>.png, <name>.hex, manifest.csv
# Synthetic back-lit asparagus scenes, W x H from config.py.  The .hex files have the same format as
# data/frame.hex (one byte per line, row by row), the .png files are the same pictures for viewing.
import math, random, csv, statistics
from PIL import Image
from config import W, H

def scene(spears=(), bg=226, vign=20, noise=4, dust=30, holes=8, seed=1, spear_val=45):
    rnd = random.Random(seed)
    img = [[int(bg - abs(x - W/2) * vign / (W/2) + rnd.randint(-noise, noise)) for x in range(W)] for _ in range(H)]
    mask = [[False] * W for _ in range(H)]
    centres = []
    for sp in spears:
        x0, x1 = sp["x0"], sp["x1"]
        yc0, d0, d1 = sp.get("yc", H/2), sp["d0"], sp["d1"]
        bow, shape, tip = sp.get("bow", 0), sp.get("shape", "bow"), sp.get("tip", 10)
        for x in range(x0, x1 + 1):
            t = (x - x0) / (x1 - x0)
            off = bow * (math.sin(math.pi * t) if shape == "bow" else math.sin(2 * math.pi * t))
            yc, d = yc0 + off, d0 + (d1 - d0) * t
            if x > x1 - tip:
                d *= math.sqrt(max(0.0, 1 - ((x - (x1 - tip)) / tip) ** 2))
            for y in range(H):
                if abs(y - yc) <= d / 2:
                    img[y][x] = spear_val + rnd.randint(0, 10); mask[y][x] = True
        centres.append(sp)
    for _ in range(dust):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if not mask[y][x]: img[y][x] = 60
    if spears:
        sp = spears[0]
        for _ in range(holes):
            x = rnd.randrange(sp["x0"] + 15, sp["x1"] - 15)
            col = [y for y in range(H) if mask[y][x]]
            if col: img[col[len(col)//2]][x] = 230
    return img, mask

def truth(mask):
    cols = [(x, sum(mask[y][x] for y in range(H))) for x in range(W)]
    cols = [(x, w) for x, w in cols if w > 0]
    if not cols: return 0, 0, 0
    ws = [w for _, w in cols]
    return cols[-1][0] - cols[0][0] + 1, statistics.median(ws), max(ws)

S = lambda **k: dict(dict(x0=20, x1=W-20, d0=24, d1=12), **k)
CASES = {
 # name: (description, scene kwargs)
 "01_medium_straight":  ("straight medium spear",                       dict(spears=[S(d0=18, d1=14, bow=0)])),
 "02_thin":             ("thin spear (small diameter class)",           dict(spears=[S(d0=11, d1=8, bow=2)])),
 "03_jumbo":            ("very thick spear",                            dict(spears=[S(d0=30, d1=20, bow=3)])),
 "04_bowed_reject":     ("strongly bowed spear -> should be rejected",  dict(spears=[S(d0=20, d1=14, bow=20)])),
 "05_short_reject":     ("short spear -> should be rejected",           dict(spears=[S(x0=70, x1=190, d0=18, d1=12, bow=2)])),
 "06_s_shape":          ("S-shaped spear",                              dict(spears=[S(d0=20, d1=14, bow=9, shape="s")])),
 "07_dusty_noisy":      ("lots of dust, pin-holes and sensor noise",    dict(spears=[S(d0=20, d1=14, bow=4)], dust=300, holes=30, noise=10)),
 "08_off_centre":       ("spear lying 28 px off the centre line",       dict(spears=[S(d0=18, d1=14, bow=3, yc=H/2-28)])),
 "09_dim_backlight":    ("weak back-light, low contrast",               dict(spears=[S(d0=18, d1=14, bow=3)], bg=150, vign=10, spear_val=95)),
 "10_empty":            ("nothing on the belt",                         dict(spears=[])),
 "11_two_spears":       ("LIMIT: two spears, only the one nearest the centre is measured",
                         dict(spears=[S(d0=18, d1=14, bow=2, yc=H/2-5), S(x0=40, x1=200, d0=14, d1=10, yc=H/2+38)])),
 "12_tip_at_right_edge":("LIMIT: tip touches the right edge (last 8 columns are lost)",
                         dict(spears=[S(x0=40, x1=W-3, d0=20, d1=14, bow=3, tip=8)])),
 "13_underexposed":     ("exposure test: whole frame too dark",         dict(spears=[S(d0=18, d1=14)], bg=70, vign=5, spear_val=20, dust=0, holes=0)),
 "14_overexposed":      ("exposure test: back-light saturated",         dict(spears=[S(d0=18, d1=14)], bg=252, vign=0, spear_val=200, dust=0, holes=0, noise=2)),
}
rows = [("name", "description", "true_length_px", "true_median_width_px", "true_max_width_px")]
for name, (desc, kw) in CASES.items():
    img, mask = scene(**kw)
    flat = bytes(min(255, max(0, p)) for row in img for p in row)
    Image.frombytes("L", (W, H), flat).save(f"test_images/{name}.png")
    open(f"test_images/{name}.hex", "w").write("\n".join(f"{p:02x}" for p in flat) + "\n")
    rows.append((name, desc) + truth(mask))
csv.writer(open("test_images/manifest.csv", "w", newline="")).writerows(rows)
print(f"wrote {len(CASES)} test images ({W}x{H}) to test_images/")
