# check_edge.py : golden model for edge_detect (standalone test)
OW, OH, NF, CENTER = 48, 6, 8, 24

def pick(line):
    """runs of 1s -> (start, end, found) of the run whose midpoint is closest to CENTER"""
    runs, s = [], None
    for y, b in enumerate(line):
        if b and s is None: s = y
        if not b and s is not None: runs.append((s, y)); s = None
    if s is not None: runs.append((s, len(line)))
    if not runs: return (0, 0, 0)
    best = min(runs, key=lambda r: abs(r[0] + r[1] - 2 * CENTER))   # min() keeps the first on a tie
    return (best[0], best[1], 1)

bits  = [int(l) for l in open("out/e_in.txt") if l.strip()]
ces   = [int(l) for l in open("out/e_ce.txt") if l.strip()]
lines = [bits[i*OW:(i+1)*OW] for i in range(len(bits)//OW)]
res   = [pick(l) for l in lines]
gold_w = [sum((e - s) ** 2 for s, e, _ in res[f*OH:(f+1)*OH]) for f in range(NF)]
gold_ce = []
for k in range(len(lines)):
    s, e = (0, 0) if k % OH == 0 else res[k-1][:2]          # previous line of the same frame
    gold_ce += [1 if s <= y < e else 0 for y in range(OW)]

got_l = [tuple(map(int, l.split())) for l in open("out/e_line.txt") if l.strip()]
got_w = [int(l) for l in open("out/e_w.txt") if l.strip()]
def rep(name, ok, extra=""): print(f"{name}: {'PASS' if ok else 'FAIL'} {extra}")
rep("start/end per line", got_l == res, f"({len(got_l)} lines, {sum(1 for r in res if r[2]==0)} empty)")
rep("weight per frame  ", got_w == gold_w, f"({len(got_w)} frames, e.g. {gold_w[:3]})")
rep("ce (prev. line)   ", ces == gold_ce, f"({sum(gold_ce)} pixels enabled)")
