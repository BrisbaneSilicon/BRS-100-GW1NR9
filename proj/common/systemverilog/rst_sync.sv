`timescale 1ns/1ps

module rst_sync (
    input   clk,
    input   ext_resetn,

    output  resetn
);

    reg [3:0]   i_reset_cnt = 4'h0;
    reg         i_resetn_p4;
    reg         i_resetn_p3 = 1'b0;
    reg         i_resetn_p2 = 1'b0;
    reg         i_resetn_p1 = 1'b0;
    reg         i_resetn    = 1'b0;


    // NOTE: outputs
    // ---------------

    assign resetn = i_resetn;


    // NOTE: i_resetn
    // derivation
    // ---------------

    assign i_resetn_p4 = &i_reset_cnt;

    always @(posedge clk) begin
        // defaults
        i_reset_cnt <= i_reset_cnt + !i_resetn_p4;

        i_resetn_p3 <= i_resetn_p4;
        i_resetn_p2 <= i_resetn_p3;
        i_resetn_p1 <= i_resetn_p2;
        i_resetn    <= i_resetn_p1;
            // NOTE: help with fanout

        if (ext_resetn == 1'b0) begin
            i_reset_cnt <= 4'b0;
        end
    end

endmodule
