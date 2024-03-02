module timing_fpga #(
  parameter ClocksPerSecond = 19200000;
  parameter PpsPulseWidth = 1920; // 100us
  parameter SlowClockPeriod = 1920; // 10kHz
)
(
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


// sync reset
logic rst;
logic rst_p1, rst_p0;
always_ff @(posedge clk_tf) begin
  if(!tf_reset_l) begin
    rst_p1 <= 1'b1;
    rst_p0 <= 1'b1;
  end
  else begin
    rst_p1 <= 1'b1;
    rst_p0 <= rst_p1;
  end
end

assign rst = rst_p0;

// forward clk to uC
assign clk_uc = clk_tf;

// slow clk
logic [$clog2(SlowClockPeriod)-1:0] slow_clock_count;
assign slow_clock_rise_next = (slow_clock_count == SlowClockPeriod-1);
assign slow_clock_fall_next = (slow_clock_count == (SlowClockPeriod/2)-1);
assign slow_clock_next = (slow_clock_count < (SlowClockPeriod/2) || slow_clock_count == (SlowClockPeriod-1));

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
logic pps_raw_d1, pps_raw_d2, pps_raw_d3;
logic pps_raw_rise;

// sync the pps signal, find the rising edge
// this adds delay greater than the minimum TDC start->stop time
assign pps_raw_rise = (pps_raw_d2 && !pps_raw_d3);
always @(posedge clk_tf) begin
  if(rst) begin
    pps_raw_d1 <= 1'b0;
    pps_raw_d2 <= 1'b0;
    pps_raw_d3 <= 1'b0;
  end
  else begin
    pps_raw_d1 <= pps_raw_logic;
    pps_raw_d2 <= pps_raw_d1;
    pps_raw_d3 <= pps_raw_d2;
  end
end

enum logic [1:0] {
  S_idle,
  S_arm,
  S_stop,
  S_wait
} stop_state, stop_state_next;

always_comb begin
  stop_state_next = stop_state;
  case (stop_state)
    S_idle: begin
      if(pps_raw_rise) begin
        stop_state_next = S_arm;
      end
    end
    S_arm: begin
      if(slow_clock_rise_next) begin
        stop_state_next = S_stop;
      end
    end
    S_stop: begin
      if(slow_clock_fall_next) begin
        stop_state_next = S_wait;
      end
    end
    S_wait: begin
      if(pps_rise_next) begin
        stop_state_next = S_idle;
      end
    end
  endcase
end

always_ff @(posedge clk_tf) begin
  if(rst) begin
    stop_state <= S_idle;
  end
  else begin
    stop_state <= stop_state_next;
  end
end

// stop output (to be flopped on clk_tf externally)
assign tdc_stop_next = (stop_state_next == S_stop);

// tos count output (flopped internally, here)
always_ff @(posedge clk_tf) begin
  if(rst) begin
    stop_tos_count <= 1'b1;
  end
  else if(stop_state_next == S_idle) begin
    stop_tos_count <= stop_clock_next;
  end
  else begin
    stop_tos_count <= 1'b0;
  end
end

endmodule
