set_time_format -unit ns -decimal_places 3
create_clock -period 52 [get_ports clk_tf]

set_false_path -from [get_ports tf_reset_l] -to [get_pins rst_p*|aclr]
set_false_path -from [get_ports pps_raw_logic] -to [get_pins pps_raw_d1|data*]

# output should be valid at least 10ns before rising edge of clk_tf
set_output_delay -clock clk_tf -max 10 [get_ports pps_clean_next]
set_output_delay -clock clk_tf -max 10 [get_ports tdc_stop_next]
set_output_delay -clock clk_tf -max 10 [get_ports tos_mark_ddc]
set_output_delay -clock clk_tf -max 10 [get_ports uc_slow_clock]
set_output_delay -clock clk_tf -max 10 [get_ports uc_pps_next]
set_output_delay -clock clk_tf -max 10 [get_ports uc_stop_next]
set_output_delay -clock clk_tf -max 10 [get_ports uc_stop_done]

# output should be valid until at least 2ns after rising edge of clk_tf
set_output_delay -clock clk_tf -min -2 [get_ports pps_clean_next]
set_output_delay -clock clk_tf -min -2 [get_ports tdc_stop_next]
set_output_delay -clock clk_tf -min -2 [get_ports tos_mark_ddc]
set_output_delay -clock clk_tf -min -2 [get_ports uc_slow_clock]
set_output_delay -clock clk_tf -min -2 [get_ports uc_pps_next]
set_output_delay -clock clk_tf -min -2 [get_ports uc_stop_next]
set_output_delay -clock clk_tf -min -2 [get_ports uc_stop_done]
