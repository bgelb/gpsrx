module timing_fpga #(
  parameter ClocksPerSecond = 19200000,
  parameter PpsPulseWidth =   1920, // 100us
  parameter SlowClockPeriod = 1920  // 10kHz
)
(
  input logic clk_tf,
  input logic tf_reset_l,
  input logic pps_raw_logic,
  // uC interface
  output logic uc_slow_clock,
  output logic uc_pps_next,
  output logic uc_stop_next,
  output logic uc_stop_done,
  // DDC interface
  output logic tos_mark_ddc,
  // TDC interface
  output logic tdc_stop_next,
  // Ref output interface
  output logic pps_clean_next
);


localparam SlowClocksPerSecond = ClocksPerSecond/SlowClockPeriod;

// sync reset
logic rst_l;
logic rst_p1, rst_p0;
always_ff @(posedge clk_tf or negedge tf_reset_l) begin
  if(!tf_reset_l) begin
    rst_p1 <= 1'b0;
    rst_p0 <= 1'b0;
  end
  else begin
    rst_p1 <= 1'b1;
    rst_p0 <= rst_p1;
  end
end

assign rst_l = rst_p0;

// slow clk
logic [$clog2(SlowClockPeriod)-1:0] slow_clock_count;
logic slow_clock_rise_next, slow_clock_fall_next, slow_clock_next;

// make the below (commented) assignments, but flopped for timing
// assign slow_clock_rise_next = (slow_clock_count == SlowClockPeriod-1);
// assign slow_clock_fall_next = (slow_clock_count == (SlowClockPeriod/2)-1);
// assign slow_clock_next = (slow_clock_count < (SlowClockPeriod/2)-1 || slow_clock_count == SlowClockPeriod-1);

always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
    slow_clock_rise_next <= 1'b0;
    slow_clock_fall_next <= 1'b0;
    slow_clock_next <= 1'b1;
  end
  else begin
    slow_clock_rise_next <= (slow_clock_count == SlowClockPeriod-2);
    slow_clock_fall_next <= (slow_clock_count == (SlowClockPeriod/2)-2);
    slow_clock_next <= (slow_clock_count < (SlowClockPeriod/2)-2 || slow_clock_count == SlowClockPeriod-2 || slow_clock_count == SlowClockPeriod-1);
  end
end


always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
    slow_clock_count <= '0;
  end
  else if (slow_clock_rise_next || pps_rise_next) begin
    slow_clock_count <= '0;
  end
  else begin
    slow_clock_count <= slow_clock_count + 1'b1;
  end
end

// "clean" pps
logic [$clog2(ClocksPerSecond)-1:0] pps_count;
logic pps_rise_next, pps_pulse_next;

// make the below (commented) assignments, but flopped for timing
// assign pps_rise_next = (pps_count == ClocksPerSecond-1);
// assign pps_fall_next = (pps_count == PpsPulseWidth-1);
// assign pps_pulse_next = (pps_count < PpsPulseWidth-1 || pps_count == ClocksPerSecond-1);

always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
    pps_rise_next <= 1'b0;
    pps_pulse_next <= 1'b1;
  end
  else begin
    pps_rise_next <= (pps_count == ClocksPerSecond-2);
    pps_pulse_next <= (pps_count < PpsPulseWidth-2 || pps_count == ClocksPerSecond-2 || pps_count == ClocksPerSecond-1);
  end
end


always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
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

// stop logic
logic pps_raw_d1, pps_raw_d2, pps_raw_d3;
logic pps_raw_rise;

// sync the pps signal, find the rising edge
// this adds delay greater than the minimum TDC start->stop time
assign pps_raw_rise = (pps_raw_d2 && !pps_raw_d3);
always @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
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
  S_idle = 2'h0,
  S_arm = 2'h1,
  S_stop = 2'h2
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
        stop_state_next = S_idle;
      end
    end
  endcase
end

always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
    stop_state <= S_idle;
  end
  else begin
    stop_state <= stop_state_next;
  end
end

// stop output (to be flopped on clk_tf externally)
assign tdc_stop_next = (stop_state_next == S_stop);

// uC interface
logic int_uc_slow_clock_pre;

// add 1 clk_tf cycle delay in uc_slow_clock, so that pps_next and stop_next can have 1 cycle setup
always_ff @(posedge clk_tf or negedge rst_l) begin
  if(!rst_l) begin
    int_uc_slow_clock_pre <= 1'b1;
    uc_slow_clock <= 1'b0;
  end
  else begin
    int_uc_slow_clock_pre <= slow_clock_next;
    uc_slow_clock <= int_uc_slow_clock_pre;
  end
end

// these must be valid 1 clk_tf cycle prior to uc_slow_clk edge as seen by uC
// and held until falling edge of uc_slow_clk
//
// uC will sample them upon seeing rising edge of uc_slow_clk
always @(posedge clk_tf) begin
  if(!rst_l) begin
    uc_pps_next <= 1'b1;
    uc_stop_next <= 1'b0;
    uc_stop_done <= 1'b0;
  end
  else if(slow_clock_rise_next) begin
    uc_pps_next <= pps_rise_next;
    uc_stop_next <= (stop_state_next == S_stop);
    uc_stop_done <= uc_stop_next; // uc_stop_next shifted out by 1 uc_slow_clk
  end
end

endmodule
