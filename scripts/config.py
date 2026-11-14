# config.py : THE ONE PLACE for every design parameter.  After editing, run:  python3 scripts/gen_params.py
# (it writes rtl/produce_params.vh, which the Verilog top level and testbench read).

# ---- image geometry ------------------------------------------------------------------
W   = 256          # camera width  = number of scan lines after the transpose (spear runs ALONG x)
H   = 160          # camera height = samples per scan line (spear is measured ACROSS y). Must be <= 255
HB  = 48           # horizontal blanking of the (emulated) camera, clocks
VB  = 16           # vertical blanking, lines
OB  = 16           # blanking clocks the frame buffer inserts after each scan line (>= 8)

# ---- background subtraction ----------------------------------------------------------
N      = 64                       # sliding-mean window (even). Must be > 2 x widest spear in pixels, < H
SHIFT  = 15
RECIP  = round(2**SHIFT / N)      # mean = sum * RECIP >> SHIFT    (N=160 -> 205)

MIN_LEVEL = 64                    # a spear pixel (after the LUT inverts the image) must be at least this bright

# ---- other stages ----------------------------------------------------------------------
CNT_W   = 15       # exposure counters: MSB set at 2**(CNT_W-1) pixels (~40 % of a 256x160 frame)
OC_MODE = 1        # 5x1 stage: 0 = opening only, 1 = opening then closing
CENTER  = H // 2   # preferred spear position along a scan line (80 for H = 160)

# ---- UART / capture --------------------------------------------------------------------
CLK_HZ       = 100_000_000
BAUD         = 921_600
CPB_HW       = round(CLK_HZ / BAUD)   # clocks per UART bit on the board
CPB_SIM      = 8                      # fast UART for simulation
SKIP_FRAMES  = 1                      # frames ignored after reset before the first capture

assert H <= 255 and N % 2 == 0 and N < H and OB >= 8
