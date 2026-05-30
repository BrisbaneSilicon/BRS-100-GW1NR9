create_clock -name clk_27Mhz        -period 37.037  -waveform {0 18.518}    [get_ports  {pad_clk_27Mhz}]

create_clock -name clk_81Mhz        -period 12.346  -waveform {0 6.173}     [get_pins   {top_inst/clk81mhz_inst/rpll_inst/CLKOUT}]
create_clock -name clk_81Mhz_p      -period 12.346  -waveform {0 6.173}     [get_pins   {top_inst/clk81mhz_inst/rpll_inst/CLKOUTP}]

create_clock -name clk_tck          -period 400.000 -waveform {0 200.000}   [get_ports {tck_pad_i}]


# NOTE: all clocks, to/from everything else

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_81Mhz}]
set_false_path -from [get_clocks {clk_81Mhz}]       -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_81Mhz_p}]
set_false_path -from [get_clocks {clk_81Mhz_p}]     -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_81Mhz}]       -to [get_clocks {clk_81Mhz_p}]
set_false_path -from [get_clocks {clk_81Mhz_p}]     -to [get_clocks {clk_81Mhz}]


set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_81Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_81Mhz}]
