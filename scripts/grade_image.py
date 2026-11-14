# grade_image.py : grade ANY picture.   Run from the project root.
#   python3 scripts/grade_image.py my_spear.jpg
#   python3 scripts/grade_image.py my_spear.jpg --bright-spear --rotate 90 --fit crop --autolevel
# It converts the picture to the camera format (W x H grey, from config.py), writes data/frame.hex and the
# inverting data/lut.hex, runs the simulated hardware, checks it against the golden model, grades the spear
# and writes out/compare.png (every stage side by side).
#
# The spear must end up DARK on a BRIGHT background and LYING ALONG THE X AXIS (left-right). Options:
#   --bright-spear   your spear is brighter than the background -> invert the picture first
#   --rotate DEG     rotate counter-clockwise (try 90 or 270 if the spear is vertical)
#   --fit MODE       pad (default, keep aspect, bright borders) | crop (centre crop) | stretch
#   --autolevel      stretch contrast so the background becomes about 225 (poorly exposed photos)
#   --no-sim         only convert, do not simulate
import argparse, subprocess, sys, shutil, glob, os
from PIL import Image, ImageOps
from config import W, H

ap = argparse.ArgumentParser()
ap.add_argument("image"); ap.add_argument("--bright-spear", action="store_true")
ap.add_argument("--rotate", type=float, default=0); ap.add_argument("--fit", default="pad", choices=["pad", "crop", "stretch"])
ap.add_argument("--autolevel", action="store_true"); ap.add_argument("--no-sim", action="store_true")
a = ap.parse_args()
py = sys.executable
os.makedirs("out", exist_ok=True); os.makedirs("data", exist_ok=True)

if a.image.lower().endswith(".hex"):
    shutil.copy(a.image, "data/frame.hex")
else:
    im = Image.open(a.image).convert("L")
    if a.rotate: im = im.rotate(a.rotate, expand=True, fillcolor=255)
    if a.bright_spear: im = ImageOps.invert(im)
    if a.autolevel:
        px = sorted(im.getdata()); bgv = px[int(len(px) * 0.9)] or 1
        im = im.point(lambda v: min(255, int(v * 225 / bgv)))
    if a.fit == "stretch":
        im = im.resize((W, H), Image.LANCZOS)
    elif a.fit == "crop":
        im = ImageOps.fit(im, (W, H), Image.LANCZOS)
    else:
        im.thumbnail((W, H), Image.LANCZOS)
        canvas = Image.new("L", (W, H), 235)
        canvas.paste(im, ((W - im.width) // 2, (H - im.height) // 2)); im = canvas
    open("data/frame.hex", "w").write("\n".join(f"{p:02x}" for p in im.tobytes()) + "\n")
    im.save("out/input_converted.png")
    print(f"converted {a.image} -> data/frame.hex ({W}x{H}); preview: out/input_converted.png")
open("data/lut.hex", "w").write("\n".join(f"{255 - i:02x}" for i in range(256)) + "\n")
if a.no_sim: sys.exit(0)

def run(cmd, **kw): return subprocess.run(cmd, capture_output=True, text=True, **kw)
run([py, "scripts/gen_params.py"])
r = run(["iverilog", "-g2005", "-I", "rtl", "-o", "out/sim.out", "tb/tb_pipeline.v"] + sorted(glob.glob("rtl/*.v")))
if r.returncode: sys.exit("compile failed:\n" + r.stderr)
print("simulating the hardware (about a minute) ...")
sim = run(["vvp", "out/sim.out"])
print("\n".join(l for l in sim.stdout.splitlines() if "exposure" in l or "TIMEOUT" in l))
chk = run([py, "scripts/check.py"])
print("hardware vs golden model:", "ALL CHECKS PASSED" if chk.returncode == 0 else "MISMATCH\n" + chk.stdout)
print(run([py, "scripts/grade_asparagus.py", "--file", "out/uart.txt"]).stdout)
print(run([py, "scripts/visualize.py"]).stdout.strip())
