set_time_format -unit ns -decimal_places 3
create_clock -period 52 [get_ports clk_tf]
#create_generated_clock -name clk_uc -divide_by 1 -source [get_ports clk_tf] [get_ports clk_uc]

set_false_path -from [get_ports tf_reset_l] -to [get_pins rst_p*|aclr]
set_false_path -from [get_ports pps_raw_logic] -to [get_pins pps_raw_d1|datad]

# constain some reasonable prop delay on forwarded copy of clk
# this is just used to enable uc to count cycles, precise delay of edge not critical
# just want to make sure it is something reasonable
set_max_delay -from [get_ports clk_tf] -to [get_ports clk_uc] 10

# output should be valid at least 20ns before rising edge of clk_tf
set_output_delay -clock clk_tf -max 20 [get_ports pps_clean_next]
set_output_delay -clock clk_tf -max 20 [get_ports tdc_stop_next]
set_output_delay -clock clk_tf -max 20 [get_ports tos_mark_ddc]

# output should be valid until at least 10ns after rising edge of clk
set_output_delay -clock clk_tf -min -10 [get_ports pps_clean_next]
set_output_delay -clock clk_tf -min -10 [get_ports tdc_stop_next]
set_output_delay -clock clk_tf -min -10 [get_ports tos_mark_ddc]

# these are not sampled on clk_tf externally, but constrain them to be within 5ns of clk_uc output
set_output_delay -clock clk_tf -reference_pin [get_ports clk_uc] -max 47 [get_ports pps_clean_uc]
set_output_delay -clock clk_tf -reference_pin [get_ports clk_uc] -min -1 [get_ports pps_clean_uc]
set_output_delay -clock clk_tf -reference_pin [get_ports clk_uc] -max 47 [get_ports stop_tos_count]
set_output_delay -clock clk_tf -reference_pin [get_ports clk_uc] -min -1 [get_ports stop_tos_count]
