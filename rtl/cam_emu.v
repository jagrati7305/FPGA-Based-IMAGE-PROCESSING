// cam_emu.v : camera emulator. Plays a stored image (hex file) with camera-style timing.
// Replace this module by your real camera interface: it only has to deliver
//   pix[7:0], valid (1 = active pixel), vs (1-clock pulse with the first pixel of a frame).
module cam_emu #(parameter W=640, H=480, HB=160, VB=45,
                 parameter FILE="data/frame.hex")(
  input clk, rst,
  output reg [7:0] pix, output reg valid, vs, hs,
  output reg [10:0] x, output reg [9:0] y);
  reg [7:0] rom [0:W*H-1];
  initial $readmemh(FILE, rom);
  reg [10:0] hc; reg [9:0] vc;
  reg [31:0] addr;                                   // running read address (no multiplier)
  wire act = (hc<W) && (vc<H);
  always @(posedge clk) begin
    if (rst) begin hc<=0; vc<=0; addr<=0; end
    else begin
      if (hc==W+HB-1) begin hc<=0; vc <= (vc==H+VB-1)?0:vc+1; end
      else hc<=hc+1;
      if (act) addr <= (addr==W*H-1) ? 32'd0 : addr + 1;
    end
    valid <= act & ~rst;
    hs <= (hc==0) & ~rst;
    vs <= (vc==0 && hc==0) & ~rst;
    x<=hc; y<=vc;
    pix <= act ? rom[addr] : 8'd0;
  end
endmodule
