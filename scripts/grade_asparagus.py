# grade_asparagus.py : decode a result packet from the FPGA and grade the spear.
#   python3 scripts/grade_asparagus.py --file out/uart.txt        (simulation output, one hex byte per line)
#   python3 scripts/grade_asparagus.py --port COM5 [--baud 921600] (live, needs: pip install pyserial)
import argparse, statistics, sys
import grading_config as g

def parse_packet(data):
    """data: bytes of one packet starting at A5 5A.  Returns a dict, raises ValueError when invalid."""
    if len(data) < 18 or data[0] != 0xA5 or data[1] != 0x5A:
        raise ValueError("bad header")
    nl = data[15] | (data[16] << 8)
    if len(data) < 18 + 2 * nl:
        raise ValueError("packet too short")
    chk = 0
    for b in data[2:17 + 2 * nl]:
        chk ^= b
    if chk != data[17 + 2 * nl]:
        raise ValueError("checksum error")
    le = lambda i, n: int.from_bytes(data[i:i + n], "little")
    lines = [(data[17 + 2 * k], data[18 + 2 * k]) for k in range(nl)]
    return dict(frame_id=data[2], weight=le(3, 4), sil_y=data[7], sil_count=le(8, 3),
                xor_count=le(11, 3), exp_up=data[14] & 1, exp_down=(data[14] >> 1) & 1,
                nlines=nl, lines=lines)

def grade(p):
    cols = [(i, s, e) for i, (s, e) in enumerate(p["lines"]) if e > s]
    r = dict(found=len(cols) > 0, reasons=[])
    if not cols:
        r.update(grade="NO SPEAR", reasons=["no spear found in the frame"]); return r
    first, last = cols[0][0], cols[-1][0]
    widths = [e - s for _, s, e in cols]
    cx = [(i, (s + e) / 2) for i, s, e in cols]
    # least-squares straight line through the centre points; bow = largest distance from it
    n = len(cx); mx = sum(i for i, _ in cx) / n; my = sum(c for _, c in cx) / n
    sxx = sum((i - mx) ** 2 for i, _ in cx) or 1
    slope = sum((i - mx) * (c - my) for i, c in cx) / sxx
    bow_px = max(abs(c - (my + slope * (i - mx))) for i, c in cx)
    mm = g.MM_PER_PX
    length_mm = (last - first + 1) * mm
    diam_mm = statistics.median(widths) * mm
    # hardware weight = sum of width^2 (px^2) -> volume of a solid of revolution
    volume_cm3 = (3.14159265 / 4) * p["weight"] * mm ** 3 / 1000.0
    grams = volume_cm3 * g.GRAMS_PER_CM3
    r.update(length_mm=length_mm, diameter_mm=diameter_of(widths, mm), median_diameter_mm=diam_mm,
             bow_mm=bow_px * mm, grams=grams, columns=len(cols), first=first, last=last)
    size = next(name for name, lim in g.DIAMETER_CLASSES if diam_mm < lim)
    if length_mm < g.MIN_LENGTH_MM: r["reasons"].append(f"too short ({length_mm:.0f} mm)")
    if bow_px * mm > g.MAX_BOW_MM:  r["reasons"].append(f"too bent ({bow_px * mm:.1f} mm)")
    r["grade"] = "REJECT" if r["reasons"] else size.upper()
    return r

def diameter_of(widths, mm):
    return max(widths) * mm

def report(p, r):
    print(f"frame {p['frame_id']}: {p['nlines']} scan lines, hardware weight = {p['weight']} px^2")
    print(f"  silhouette: {p['sil_count']} px counted, median position y = {p['sil_y']}")
    print(f"  cleaning changed {p['xor_count']} px inside the spear range, exposure up/down = {p['exp_up']}/{p['exp_down']}")
    if r["found"]:
        print(f"  spear spans columns {r['first']}..{r['last']} ({r['columns']} columns)")
        print(f"  length   {r['length_mm']:.0f} mm | diameter median {r['median_diameter_mm']:.1f} mm, max {r['diameter_mm']:.1f} mm")
        print(f"  bow      {r['bow_mm']:.1f} mm | weight ~ {r['grams']:.0f} g")
    print(f"  GRADE: {r['grade']}" + ("  (" + "; ".join(r["reasons"]) + ")" if r["reasons"] else ""))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file"); ap.add_argument("--port"); ap.add_argument("--baud", type=int, default=921600)
    a = ap.parse_args()
    if a.file:
        data = bytes(int(l, 16) for l in open(a.file) if l.strip())
        i = data.find(b"\xa5\x5a")
        if i < 0: sys.exit("no packet header found")
        p = parse_packet(data[i:]); report(p, grade(p)); return
    if a.port:
        import serial
        ser = serial.Serial(a.port, a.baud, timeout=2)
        sync = b""
        while True:
            sync = (sync + ser.read(1))[-2:]
            if sync != b"\xa5\x5a": continue
            head = sync + ser.read(15)
            nl = (head[15] | (head[16] << 8)) if len(head) >= 17 else 0
            body = ser.read(2 * nl + 1)
            try:
                p = parse_packet(head + body)
            except ValueError as e:
                print("skipped:", e); continue
            report(p, grade(p)); print()
    ap.print_help()

if __name__ == "__main__":
    main()
