# check_hist.py : golden model for hist_median / hist_path (standalone test)
OW, G, NG = 48, 5, 12
def med(hist):
    T = sum(hist)
    if T == 0: return (0, 0)
    half, cum = (T + 1) // 2, 0
    for y, h in enumerate(hist):
        cum += h
        if cum >= half: return (y, T)
bits  = [int(l) for l in open("out/h_in.txt") if l.strip()]
lines = [bits[i*OW:(i+1)*OW] for i in range(len(bits)//OW)]
gold_line = [med(l) for l in lines]
gold_grp  = [med([sum(col) for col in zip(*lines[g*G:(g+1)*G])]) for g in range(NG)]
def rd(n): return [tuple(map(int, l.split())) for l in open(n) if l.strip()]
for name, f, gold in (("per-line histogram ", "out/h_line.txt", gold_line),
                      ("per-group histogram", "out/h_grp.txt",  gold_grp)):
    got = rd(f)
    bad = sum(1 for a, b in zip(got, gold) if a != b) + abs(len(got) - len(gold))
    print(f"{name}: {len(got)} results, {'PASS' if bad == 0 else 'FAIL, %d wrong' % bad}")
print("empty lines in test:", sum(1 for t in gold_line if t[1] == 0), "| max total in a group:", max(t[1] for t in gold_grp))
