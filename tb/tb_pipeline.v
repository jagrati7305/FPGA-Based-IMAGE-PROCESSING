`timescale 1ns/1ps
`include "produce_params.vh"
// System testbench: runs the complete design (produce_top) and dumps every stage to out/*.
// Run from the project root.  Add +vcd to the vvp command line to get out/dump.vcd.
module tb_pipeline;
    parameter NFRAMES = 3;
    localparam W = `CFG_W, H = `CFG_H, HB = `CFG_HB, VB = `CFG_VB;
    localparam TOTAL_BYTES = 18 + 2*W;

    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    wire uart_tx, exp_inc, exp_dec, busy;
    produce_top #(.CLKS_PER_BIT(`CFG_CPB_SIM)) dut (
        .clk(clk), .rst(rst), .uart_tx(uart_tx), .exp_inc(exp_inc), .exp_dec(exp_dec), .busy(busy));

    // ---- UART receiver model ----
    integer f_uart, rx_cnt = 0, i;
    reg [7:0] rx_byte;
    initial begin
        f_uart = $fopen("out/uart.txt","w");
        forever begin
            @(negedge uart_tx);
            if (!rst) begin
                repeat (`CFG_CPB_SIM/2) @(posedge clk);
                for (i = 0; i < 8; i = i + 1) begin
                    repeat (`CFG_CPB_SIM) @(posedge clk);
                    rx_byte[i] = uart_tx;
                end
                repeat (`CFG_CPB_SIM) @(posedge clk);          // stop bit
                $fwrite(f_uart, "%02x\n", rx_byte);
                rx_cnt = rx_cnt + 1;
            end
        end
    end

    // ---- stage dumps ----
    integer f_lut, f_cl, f_fb, f_bg, f_bc, f_oc, f_dly, f_ed, f_wt, f_ms, f_mx;
    integer oc_cnt = 0;
    reg done = 0;
    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("out/dump.vcd"); $dumpvars(0, tb_pipeline); end
        f_lut = $fopen("out/rtl_lut.hex","w");   f_cl  = $fopen("out/rtl_closing.hex","w");
        f_fb  = $fopen("out/rtl_fb.hex","w");    f_bg  = $fopen("out/rtl_bg.hex","w");
        f_bc  = $fopen("out/rtl_bc.hex","w");    f_oc  = $fopen("out/rtl_oc.hex","w");
        f_dly = $fopen("out/rtl_dly.hex","w");   f_ed  = $fopen("out/rtl_edge.txt","w");
        f_wt  = $fopen("out/rtl_weight.txt","w");
        f_ms  = $fopen("out/rtl_med_sil.txt","w"); f_mx = $fopen("out/rtl_med_xor.txt","w");
        #50 rst = 0;
        wait (oc_cnt >= NFRAMES*W*H && rx_cnt >= TOTAL_BYTES);
        repeat (20) @(posedge clk);
        done = 1;
        $fclose(f_lut); $fclose(f_cl); $fclose(f_fb); $fclose(f_bg); $fclose(f_bc); $fclose(f_oc);
        $fclose(f_dly); $fclose(f_ed); $fclose(f_wt); $fclose(f_ms); $fclose(f_mx); $fclose(f_uart);
        $display("simulation finished: %0d pixels out, %0d UART bytes", oc_cnt, rx_cnt);
        $display("exposure flags at end: inc=%b dec=%b | histogram overrun: %b %b",
                 exp_inc, exp_dec, dut.hs_ovr, dut.hx_ovr);
        $finish;
    end
    initial begin
        #(10*(NFRAMES+6)*(W+HB)*(H+VB));
        $display("TIMEOUT: %0d pixels out, %0d UART bytes (expected %0d)", oc_cnt, rx_cnt, TOTAL_BYTES);
        $finish;
    end

    always @(posedge clk) if (!done) begin
        if (dut.lut_valid) $fwrite(f_lut,"%02x\n",dut.lut_pix);
        if (dut.cl_valid)  $fwrite(f_cl ,"%02x\n",dut.cl_pix);
        if (dut.fb_valid)  $fwrite(f_fb ,"%02x\n",dut.fb_pix);
        if (dut.bg_valid)  $fwrite(f_bg ,"%x\n",dut.bg_bin);
        if (dut.bc_valid)  $fwrite(f_bc ,"%x\n",dut.bc_bin);
        if (dut.oc_valid)  begin $fwrite(f_oc ,"%x\n",dut.oc_bin); oc_cnt = oc_cnt + 1; end
        if (dut.dly_o[1])  $fwrite(f_dly,"%x\n",dut.dly_o[0]);
        if (dut.ed_lv)     $fwrite(f_ed ,"%0d %0d %0d\n",dut.ed_ls,dut.ed_le,dut.ed_lf);
        if (dut.ed_wv)     $fwrite(f_wt ,"%0d\n",dut.ed_w);
        if (dut.hs_valid)  $fwrite(f_ms ,"%0d %0d\n",dut.hs_y,dut.hs_tot);
        if (dut.hx_valid)  $fwrite(f_mx ,"%0d %0d\n",dut.hx_y,dut.hx_tot);
    end
endmodule
