# run_images.py (run from the project root): push test images through the whole simulated pipeline
#   python3 scripts/run_images.py                 # all images
#   python3 scripts/run_images.py 01 04           # only names starting with these prefixes
import sys, glob, shutil, subprocess, os, csv
import grading_config as g
from grade_asparagus import parse_packet, grade
truth = {r["name"]: r for r in csv.DictReader(open("test_images/manifest.csv"))}
pick = sys.argv[1:]
names = sorted(os.path.basename(f)[:-4] for f in glob.glob("test_images/*.hex"))
names = [n for n in names if not pick or any(n.startswith(p) for p in pick)]
subprocess.run(["python3", "scripts/gen_params.py"], stdout=subprocess.DEVNULL, check=True)
subprocess.run(["iverilog", "-g2005", "-I", "rtl", "-o", "out/sim.out", "tb/tb_pipeline.v"] +
               sorted(glob.glob("rtl/*.v")), check=True)
print(f"{'image':24s} {'RTL=model':9s} {'grade':9s} {'len mm (true)':14s} {'diam mm (true)':15s} {'bow mm':7s} {'grams':6s}  exposure")
for n in names:
    shutil.copy(f"test_images/{n}.hex", "data/frame.hex")
    out = subprocess.run(["vvp", "out/sim.out"], capture_output=True, text=True).stdout
    chk = subprocess.run(["python3", "scripts/check.py"], capture_output=True, text=True)
    same = "yes" if chk.returncode == 0 else "NO"
    exp = [l for l in out.splitlines() if "exposure flags" in l]
    exp = "up" if "inc=1" in exp[0] else ("down" if "dec=1" in exp[0] else "ok") if exp else "?"
    try:
        p = parse_packet(bytes(int(l, 16) for l in open("out/uart.txt") if l.strip()))
        r = grade(p); t = truth[n]; mm = g.MM_PER_PX
        if r["found"]:
            print(f"{n:24s} {same:9s} {r['grade']:9s} {r['length_mm']:5.0f} ({float(t['true_length_px'])*mm:4.0f})   "
                  f"{r['median_diameter_mm']:5.1f} ({float(t['true_median_width_px'])*mm:4.1f})    {r['bow_mm']:5.1f}   {r['grams']:5.0f}  {exp}")
        else:
            print(f"{n:24s} {same:9s} {r['grade']:9s} {'-':14s} {'-':15s} {'-':7s} {'-':6s}  {exp}")
    except Exception as e:
        print(f"{n:24s} {same:9s} no packet ({e})  {exp}")
