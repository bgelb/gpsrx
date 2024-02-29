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
localparam SlowClockPeriod = 1920; // 10kHz

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
logic [$clog2(SlowClockPeriod)-1:0] slow_clock_count;
assign slow_clock_rise_next = (slow_clock_count == SlowClockPeriod-1);
assign slow_clock_fall_next = (slow_clock_count == (SlowClockPeriod/2)-1);

always_ff @(posedge clk_tf) begin
  if(rst) begin
    slow_clock_count <= '0;
  end
  else if (slow_clock_rise_next) begin
    slow_clock_count <= '0;
  end
  else
    slow_clock_count <= slow_clock_count + 1'b1;
  end
end

// "clean" pps
logic [$clog2(ClocksPerSecond)-1:0] pps_count;
logic pps_rise_next;

assign pps_rise_next = (pps_count == ClocksPerSecond-1);
assign pps_fall_next = (pps_count == PpsPulseWidth-1);
assign pps_pulse_next = (pps_count < PpsPulseWidth || pps_count == ClocksPerSecond-1);

always_ff @(posedge clk_tf) begin
  if(rst) begin
    pps_count <= '0;
  end
  else if (pps_rise_next) begin
    pps_count <= '0;
  end
  else begin
    pps_count <= pps_count + 1'b1;
  end
end

// these are meant to indicate the next rising edge of clk_tf is the top of second
assign tos_mark_ddc = pps_rise_next; // 1 cycle pulse
assign pps_clean_next = pps_pulse_next; // many cycle pulse

// we flop this internally, so the rising edge of pps_clean_uc is
// really at the top of second and doesn't need conditioning on a clock edge
always_ff @(posedge clk_tf) begin
  if(rst) begin
    pps_clean_uc <= 1'b1;
  end
	else begin
		pps_clean_uc <= pps_pulse_next;
	end
end

// stop logic
// TODO: output the first pulse of slow_clock that is safely after the arrival of pps_raw_logic
logic pps_raw_d1, pps_raw_d2, pps_raw_d3;
logic pps_arrived;
logic stop_pending;

always @(posedge clk_tf) begin
	// sync the pps signal, and add 1-2 cycles of clk_tf delay in the process
  pps_raw_d1 <= pps_raw_logic;
  pps_raw_d2 <= pps_raw_d1;
  pps_raw_d3 <= pps_raw_d2;
end

assign pps_raw_rise_next = (pps_raw_d2 && !pps_raw_d3);

// compute enables for passing slow_clock pulses
always @(posedge clk_tf) begin
	if (pps_raw_rise_next) begin
		// next slow clock will pick up pps_pending and emit stop
		pps_arrived <= 1'b1;
		stop_pending <= 1'b1;
	end
	else if (slow_clock_fall_next) begin
		stop_pending <= 1'b0;
	end
	else if (pps_rise_next) begin
		pps_arrived <= 1'b0;
		stop_pending <= 1'b0;
	end
end


// TODO: output the pulses of slow_clock between TOS and the stop pulse
// (so the UC can figure out how far into the second the stop pulse is)
endmodule