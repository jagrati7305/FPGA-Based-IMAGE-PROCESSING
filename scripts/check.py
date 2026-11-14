# check.py (run from the project root): golden model of the whole chain + comparison with the RTL
import sys
from config import *
from grade_asparagus import parse_packet

def rd(name):  return [l.strip() for l in open(name) if l.strip()]
frame = [int(l, 16) for l in rd("data/frame.hex")]
lut   = [int(l, 16) for l in rd("data/lut.hex")]

# ---------- stage 1: LUT, 9x1 greyscale closing (min then max, along the rows) ----------
gold_lut = [lut[p] for p in frame]
def closing_row(row):
    n = len(row)
    M = [min(row[max(0, p-8):p+1]) for p in range(n)]
    return [max(M[max(0, p-8):p+1]) for p in range(n)]
gold_cl = []
for y in range(H): gold_cl += closing_row(gold_lut[y*W:(y+1)*W])

# ---------- stage 2: frame buffer (transpose), background + threshold, 1x9 binary closing ----------
lines   = [[gold_cl[r*W + c] for r in range(H)] for c in range(W)]     # W scan lines of H pixels
gold_fb = [p for ln in lines for p in ln]
def bg_line(x):
    L, out = len(x), []
    for j in range(L):
        t = j + N//2
        if t < N-1 or t > L-1: out.append(0); continue
        s = sum(x[t-N+1:t+1]); mean = ((s*RECIP) >> SHIFT) & 0xFF
        thr = mean + (mean >> 3) + (mean >> 5)
        out.append(1 if (x[j] > thr and x[j] >= MIN_LEVEL) else 0)
    return out
def bc_line(b):
    L = len(b); bp = lambda i: b[i] if 0 <= i < L else 0
    dc = [max(bp(k) for k in range(i-4, i+5)) for i in range(-4, L+4)]   # dc[i+4]
    return [min(dc[k+4] for k in range(j-4, j+5)) for j in range(L)]
bg_lines = [bg_line(ln) for ln in lines]
bc_lines = [bc_line(ln) for ln in bg_lines]
gold_bg  = [p for ln in bg_lines for p in ln]
gold_bc  = [p for ln in bc_lines for p in ln]

# ---------- stage 3: 5x1 vertical opening (+ closing), window clipped at the frame border ----------
def vstage(ls, dilate):
    OH, OW, op = len(ls), len(ls[0]), (max if dilate else min)
    return [[op(ls[k][x] for k in range(max(0, y-2), min(OH, y+3))) for x in range(OW)] for y in range(OH)]
oc = vstage(vstage(bc_lines, 0), 1)
if OC_MODE: oc = vstage(vstage(oc, 1), 0)
gold_oc = [p for ln in oc for p in ln]

# ---------- stage 4: edge detection ----------
def pick(line):
    runs, st = [], None
    for y, b in enumerate(line):
        if b and st is None: st = y
        if not b and st is not None: runs.append((st, y)); st = None
    if st is not None: runs.append((st, len(line)))
    if not runs: return (0, 0, 0)
    b = min(runs, key=lambda r: abs(r[0] + r[1] - 2*CENTER))
    return (b[0], b[1], 1)
edge_res = [pick(ln) for ln in oc]
gold_w   = sum((e - s)**2 for s, e, _ in edge_res)

# ---------- stage 5: the two histogram paths (counted only inside the previous line's run) ----------
def hist_median(fl):
    hist = [sum(col) for col in zip(*fl)]; T = sum(hist)
    if T == 0: return (0, 0)
    half, cum = (T+1)//2, 0
    for y, h in enumerate(hist):
        cum += h
        if cum >= half: return (y, T)
def flags(sel):
    out = []
    for k, (rl, cl) in enumerate(zip(bg_lines, oc)):
        s0, e0 = (0, 0) if k == 0 else edge_res[k-1][:2]
        out.append([((r ^ c) if sel == 0 else c) if s0 <= y < e0 else 0 for y, (r, c) in enumerate(zip(rl, cl))])
    return out
gold_sil = hist_median(flags(1))
gold_xor = hist_median(flags(0))

# ---------- compare (frame 2 of each stream; frame 1 may hold power-up values) ----------
fails = 0
def report(name, ok, extra=""):
    global fails
    fails += (not ok)
    print(f"{name}: {'PASS' if ok else 'FAIL'} {extra}")
def compare(name, f, gold):
    data = rd(f); got = data[W*H:2*W*H]
    if len(got) != W*H: report(name, False, f"only {len(data)} samples"); return
    bad = 0
    for i, (g, e) in enumerate(zip(got, gold)):
        try: ok = int(g, 16) == e
        except ValueError: ok = False
        if not ok:
            bad += 1
            if bad <= 3: print(f"   mismatch at sample {i}: rtl={g} expected={e:02x}")
    report(name, bad == 0, "" if bad == 0 else f"({bad} mismatches)")
compare("LUT           ", "out/rtl_lut.hex",     gold_lut)
compare("Closing 9x1   ", "out/rtl_closing.hex", gold_cl)
compare("Frame buffer  ", "out/rtl_fb.hex",      gold_fb)
compare("BG + threshold", "out/rtl_bg.hex",      gold_bg)
compare("Closing 1x9   ", "out/rtl_bc.hex",      gold_bc)
compare("Open/close 5x1", "out/rtl_oc.hex",      gold_oc)
compare("Delay bypass  ", "out/rtl_dly.hex",     gold_bg)

rd_edge = [tuple(map(int, l.split())) for l in rd("out/rtl_edge.txt")]
rd_w    = [int(l) for l in rd("out/rtl_weight.txt")]
rd_ms   = [tuple(map(int, l.split())) for l in rd("out/rtl_med_sil.txt")]
rd_mx   = [tuple(map(int, l.split())) for l in rd("out/rtl_med_xor.txt")]
report("Edge start/end ", rd_edge[W:2*W] == edge_res, f"({sum(1 for r in edge_res if r[2])} of {W} lines have a run)")
report("Weight         ", len(rd_w) >= 2 and rd_w[1] == gold_w, f"(weight = {gold_w})")
report("Histogram sil. ", len(rd_ms) >= 2 and rd_ms[1] == gold_sil, f"(median y = {gold_sil[0]}, {gold_sil[1]} px)")
report("Histogram xor  ", len(rd_mx) >= 2 and rd_mx[1] == gold_xor, f"({gold_xor[1]} px changed by cleaning)")

# ---------- the UART packet ----------
try:
    pk = parse_packet(bytes(int(l, 16) for l in rd("out/uart.txt")))
    ok = (pk["lines"] == [(s, e) for s, e, _ in edge_res] and pk["weight"] == gold_w and
          (pk["sil_y"], pk["sil_count"]) == gold_sil and pk["xor_count"] == gold_xor[1])
    report("UART packet    ", ok, f"(frame_id {pk['frame_id']}, {pk['nlines']} lines, checksum OK)")
except Exception as e:
    report("UART packet    ", False, f"({e})")
print("\nALL CHECKS PASSED" if fails == 0 else f"\n{fails} CHECK(S) FAILED")
sys.exit(1 if fails else 0)
