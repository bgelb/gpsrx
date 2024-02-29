module timing_fpga (
  input logic clk_tf,
  input logic tf_reset_l,
  input logic pps_raw_logic,
  // uC interface
  output logic clk_uc,
  output logic pps_clean_uc,
  output logic stop_tos_count,
  // DDC interface
  output logic tos_mark_ddc,
  // TDC interface
  output logic tdc_stop_next,
  // Ref output interface
  output logic pps_clean_next
);

localparam ClocksPerSecond = 19200000;
localparam PpsPulseWidth = 1920; // 100us
localparam SlowClockHalfPeriod = 960; // 10kHz

// reset sync
logic rst;
logic rst_p1, rst_p0;
always_ff @(posedge clk_tf or negedge tf_reset_l) begin
  if(!tf_reset_l) begin
    rst_p1 <= 1'b1;
    rst_p0 <= 1'b1;
  end
  else begin
    rst_p1 <= 1'b1;
    rst_p0 <= rst_p1;
  end
end

assign rst = rst_p1;

// forward clk to uC
assign clk_uc = clk_tf;

// slow clk
logic [$clog2(SlowClockHalfPeriod)-1:0] slow_clock_count;
logic slow_clock;

always_ff @(posedge clk_tf) begin
  if(rst) begin
    slow_clock_count <= '0;
    slow_clock <= 1'b1;
  end
  else if (slow_clock_count == SlowClockHalfPeriod-1) begin
    slow_clock_count <= '0;
    slow_clock <= ~slow_clock;
  end
  else
    slow_clock_count <= slow_clock_count + 1'b1;
  end
end

// "clean" pps
logic [$clog2(ClocksPerSecond)-1:0] pps_count;

always_ff @(posedge clk_tf) begin
  if(rst) begin
    pps_count <= '0;
  end
  else if (pps_count == ClocksPerSecond-1) begin
    pps_count <= '0;
  end
  else begin
    pps_count <= pps_count + 1'b1;
  end
end

// these are meant to indicate the next rising edge is the top of second
assign tos_mark_ddc = (pps_count == ClocksPerSecond-1);
assign pps_clean_next = (pps_count == ClocksPerSecond-1);

// this PPS is async. the edge itself indicates PPS.
always_ff @(posedge clk_tf) begin
  if(rst) begin
    pps_clean_uc <= 1'b0;
  end
  else if (pps_count == ClocksPerSecond-1) begin
    pps_clean_uc <= 1'b1;
  end
  else if(pps_count == PpsPulseWidth-1) begin
    pps_clean_uc <= 1'b0;
  end
end

// stop logic
// TODO: output the first pulse of slow_clock that is more than 156.25ns after the arrival of pps_raw_logic
always @(posedge clk_tf) begin
  pps_raw_d1 <= pps_raw_logic;
  pps_raw_d2 <= pps_raw_d1;
  pps_raw_d3 <= pps_raw_d2;
end


// TODO: output the pulses of slow_clock between TOS and the stop pulse
// (so the UC can figure out how far into the second the stop pulse is)
endmodule
