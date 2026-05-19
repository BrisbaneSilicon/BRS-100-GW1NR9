create_clock -name clk_27Mhz        -period 37.037  -waveform {0 18.518}    [get_ports  {pad_clk_27Mhz}]

create_clock -name clk_87Mhz        -period 11.494  -waveform {0 6.666}     [get_pins   {top_inst/clk87mhz_inst/rpll_inst/CLKOUT}]
create_clock -name clk_87Mhz_p      -period 11.494  -waveform {0 6.666}     [get_pins   {top_inst/clk87mhz_inst/rpll_inst/CLKOUTP}]

create_clock -name clk_tck          -period 400.000 -waveform {0 200.000}   [get_ports {tck_pad_i}]


# NOTE: all clocks, to/from everything else

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_87Mhz}]
set_false_path -from [get_clocks {clk_87Mhz}]       -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_87Mhz_p}]
set_false_path -from [get_clocks {clk_87Mhz_p}]     -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_87Mhz}]       -to [get_clocks {clk_87Mhz_p}]
set_false_path -from [get_clocks {clk_87Mhz_p}]     -to [get_clocks {clk_87Mhz}]


set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_81Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_81Mhz}]