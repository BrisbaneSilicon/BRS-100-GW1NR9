module clk66mhz (
    input       clkin_27Mhz,

    output reg  lock,
    output      clkout,
    output      clkoutp
);

wire clkoutd_o;
wire clkoutd3_o;
wire gw_vcc;
wire gw_gnd;

assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

rPLL rpll_inst (
    .CLKOUT     (clkout),
    .LOCK       (lock),
    .CLKOUTP    (clkoutp),
    .CLKOUTD    (clkoutd_o),
    .CLKOUTD3   (clkoutd3_o),

    .RESET      (gw_gnd),
    .RESET_P    (gw_gnd),

    .CLKIN      (clkin_27Mhz),

    .CLKFB      (gw_gnd),

    .FBDSEL     ({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .IDSEL      ({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .ODSEL      ({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .PSDA       ({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .DUTYDA     ({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .FDLY       ({gw_vcc,gw_vcc,gw_vcc,gw_vcc})
);

    defparam rpll_inst.FCLKIN           = "27";
    defparam rpll_inst.DYN_IDIV_SEL     = "false";

    defparam rpll_inst.FBDIV_SEL        = 21;
    defparam rpll_inst.IDIV_SEL         = 8;
    defparam rpll_inst.ODIV_SEL         = 16;
        // NOTE: 87 MHz

    defparam rpll_inst.DYN_FBDIV_SEL    = "false";
    defparam rpll_inst.DYN_ODIV_SEL     = "false";
    defparam rpll_inst.PSDA_SEL         = "0100";
    defparam rpll_inst.DYN_DA_EN        = "false";
    defparam rpll_inst.DUTYDA_SEL       = "1000";
    defparam rpll_inst.CLKOUT_FT_DIR    = 1'b1;
    defparam rpll_inst.CLKOUTP_FT_DIR   = 1'b1;
    defparam rpll_inst.CLKOUT_DLY_STEP  = 0;
    defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
    defparam rpll_inst.CLKFB_SEL        = "internal";
    defparam rpll_inst.CLKOUT_BYPASS    = "false";
    defparam rpll_inst.CLKOUTP_BYPASS   = "false";
    defparam rpll_inst.CLKOUTD_BYPASS   = "false";
    defparam rpll_inst.DYN_SDIV_SEL     = 2;
    defparam rpll_inst.CLKOUTD_SRC      = "CLKOUT";
    defparam rpll_inst.CLKOUTD3_SRC     = "CLKOUT";
    defparam rpll_inst.DEVICE           = "GW1NR-9C";

endmodule