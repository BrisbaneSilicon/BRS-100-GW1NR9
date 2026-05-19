create_clock -name clk_27Mhz        -period 37.037  -waveform {0 18.518}    [get_ports {pad_clk_27Mhz}]

create_clock -name clk_66Mhz        -period 15.151  -waveform {0 7.575}     [get_pins {top_inst/clk66mhz_inst/rpll_inst/CLKOUT}]
create_clock -name clk_66Mhz_p      -period 15.151  -waveform {0 7.575}     [get_pins {top_inst/clk66mhz_inst/rpll_inst/CLKOUTP}]

create_clock -name clk_tck          -period 400.000 -waveform {0 200.000}   [get_ports {tck_pad_i}]



# NOTE: all clocks, to/from everything else

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_66Mhz}]
set_false_path -from [get_clocks {clk_66Mhz}]       -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_66Mhz_p}]
set_false_path -from [get_clocks {clk_66Mhz_p}]     -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_66Mhz}]       -to [get_clocks {clk_66Mhz_p}]
set_false_path -from [get_clocks {clk_66Mhz_p}]     -to [get_clocks {clk_66Mhz}]


set_false_path -from [get_clocks {clk_27Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_27Mhz}]

set_false_path -from [get_clocks {clk_66Mhz}]       -to [get_clocks {clk_tck}]
set_false_path -from [get_clocks {clk_tck}]         -to [get_clocks {clk_66Mhz}]