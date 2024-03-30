`timescale 1us/100ns
module timing_fpga_tb();

initial begin
  $dumpfile("timing_fpga.vcd");
  $dumpvars(0, timing_fpga_tb);
end

logic clk, rst_l, pps_raw;

initial begin
  clk = 1'b0;
  forever begin
    #50 clk = ~clk;
  end
end

initial begin
  rst_l = 1'b0;
  pps_raw = 1'b0;
  #1000 rst_l = 1'b1;
end

initial begin
  #2000;
  // happens during first slow clk pulse
  #1000 pps_raw = 1'b1;
  #200 pps_raw = 1'b0;
  #999800;
  // happens during second slow clk pulse
  #11000 pps_raw = 1'b1;
  #200 pps_raw = 1'b0;
  #979800;
  // happens prior to first slow clk pulse (i.e. in last slow clock pulse of prior second)
  #1000 pps_raw = 1'b1;
  #200 pps_raw = 1'b0;
  #999800;
  // happens prior to first slow clk pulse (i.e. in last slow clock pulse of prior second)
  #1000 pps_raw = 1'b1;
  #200 pps_raw = 1'b0;
  
  #10000;
  $finish(2);
end

timing_fpga #(
  .ClocksPerSecond(10000),    // 10kHz
  .PpsPulseWidth(10),       // 10ms
  .SlowClockPeriod(100)      // 100Hz
) timing_fpga_dut (
  .clk_tf(clk),
  .tf_reset_l(rst_l),
  .pps_raw_logic(pps_raw),
  //
  .tos_mark_ddc(),
  .tdc_stop_next(),
  .pps_clean_next(),
  //
  .uc_slow_clock(),
  .uc_pps_next(),
  .uc_stop_next(),
  .uc_stop_done()
);

endmodule
