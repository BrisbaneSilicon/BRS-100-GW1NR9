create_clock -name clk_27Mhz        -period 37.037  -waveform {0 18.518}    [get_ports {pad_clk_27Mhz}]

create_clock -name clk_51Mhz        -period 19.608  -waveform {0 9.804}     [get_pins {top_inst/clk51mhz_inst/rpll_inst/CLKOUT}]
create_clock -name clk_51Mhz_p      -period 19.608  -waveform {0 9.804}     [get_pins {top_inst/clk51mhz_inst/rpll_inst/CLKOUTP}]

create_clock -name clk_tck          -period 400.000 -waveform {0 200.000}   [get_ports {tck_pad_i}]


# NOTE: all clocks, to/from everything else

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_51Mhz}]
set_false_path -from [get_clocks {clk_51Mhz}]       -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_51Mhz_p}]
set_false_path -from [get_clocks {clk_51Mhz_p}]     -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_51Mhz}]       -to [get_clocks {clk_51Mhz_p}]
set_false_path -from [get_clocks {clk_51Mhz_p}]     -to [get_clocks {clk_51Mhz}]


set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_51Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_51Mhz}]
