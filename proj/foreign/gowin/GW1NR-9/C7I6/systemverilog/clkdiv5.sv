module clkdiv5  (
        clkout, 
        hclkin, 
        resetn
    );

output clkout;
input hclkin;
input resetn;

wire gw_gnd;

assign gw_gnd = 1'b0;

CLKDIV clkdiv_inst (
    .CLKOUT     (clkout),
    .HCLKIN     (hclkin),
    .RESETN     (resetn),
    .CALIB      (gw_gnd)
);

defparam clkdiv_inst.DIV_MODE = "5";
defparam clkdiv_inst.GSREN = "false";

endmodule