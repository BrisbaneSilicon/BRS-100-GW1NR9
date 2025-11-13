// -------------------------------------------------------------------------
// COPYRIGHT © 2025, BRISBANE SILICON, PTY LTD.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROVIDED ON AN "AS IS" BASIS.
// BRISBANE SILICON, PTY LTD. DISCLAIMS ANY AND ALL WARRANTIES,
// WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING ANY IMPLIED
// WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE.
// IN NO EVENT SHALL BRISBANE SILICON, PTY LTD. BE LIABLE FOR ANY
// INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY KIND WHATSOEVER
// ARISING FROM THE USE OF THIS SOURCE CODE.
//
// THIS DISCLAIMER OF WARRANTY EXTENDS TO THE USER OF THIS SOURCE CODE
// AND USER'S CUSTOMERS, EMPLOYEES, AGENTS, TRANSFEREES, SUCCESSORS,
// AND ASSIGNS.
//
// THIS IS NOT A GRANT OF PATENT RIGHTS
//
// -------------------------------------------------------------------------
// DESCRIPTION : TODO
//
// -------------------------------------------------------------------------
// SPECIFICATION : TODO
//
// -------------------------------------------------------------------------

module axis_bus_to_axis_bus_ce (
    input               clk,
    input               clk_resetn,

    input               saxis_valid,
    input       [31:0]  saxis_addr,
    input       [31:0]  saxis_wdata,
    input       [3:0]   saxis_wstrb,
    output  reg         saxis_ready,
    output  reg [31:0]  saxis_rdata,


    input               maxis_ce,
    output  reg         maxis_valid,
    output  reg [31:0]  maxis_addr,
    output  reg [31:0]  maxis_wdata,
    output  reg [3:0]   maxis_wstrb,
    input               maxis_ready,
    input       [31:0]  maxis_rdata
);

    reg i_saxis_trnsactn_in_progress;

    reg i_maxis_handshake;
    reg i_maxis_trnsactn_last_cycle;
    reg i_maxis_trnsactn_in_progress;
        // NOTE: above register is technically
        // redundant (same as 'maxis_valid') but
        // for the perusal of the HDL it is easier.


    assign i_maxis_handshake            = maxis_valid & maxis_ready & maxis_ce;
    assign i_maxis_trnsactn_last_cycle  = i_maxis_handshake;

    always @(posedge clk) begin
        if (clk_resetn == 1'b0) begin
            i_saxis_trnsactn_in_progress    <= 1'b0;
            i_maxis_trnsactn_in_progress    <= 1'b0;

            saxis_ready                     <= 1'b0;
            maxis_valid                     <= 1'b0;
        end else begin
            // defaults
            saxis_ready <= 1'b0;


            // NOTE: important to bias starting a
            // new transaction (if possible) over
            // ending a current transaction...

            if (i_saxis_trnsactn_in_progress == 1'b1) begin
                // NOTE: specific conditions for ending
                // a slave transaction.

                if (saxis_ready == 1'b0) begin
                    saxis_rdata <= maxis_rdata;
                    saxis_ready <= maxis_ready;
                end else begin
                    i_saxis_trnsactn_in_progress <= 1'b0;
                end
            end

            if (i_maxis_trnsactn_in_progress == 1'b1) begin
                // NOTE: specific conditions for ending
                // a master transaction.

                if (i_maxis_handshake == 1'b1) begin
                    i_maxis_trnsactn_in_progress    <= 1'b0;

                    maxis_valid                     <= 1'b0;
                end
            end

            if ((i_saxis_trnsactn_in_progress == 1'b0) &&
                    ((i_maxis_trnsactn_in_progress == 1'b0) || (i_maxis_trnsactn_last_cycle == 1'b1))) begin

                // NOTE: conditions to begin both a new
                // slave and new master transaction...
                // of which are common for beginning a
                // new transaction, but independent for
                // ending transactions.

                // NOTE: This is setup to optimise the transaction
                // rate, irrespective of the behaviour of 'CE'...

                if (saxis_valid == 1'b1) begin
                    i_saxis_trnsactn_in_progress    <= 1'b1;
                    i_maxis_trnsactn_in_progress    <= 1'b1;

                    maxis_valid                     <= 1'b1;
                    maxis_addr                      <= saxis_addr;
                    maxis_wdata                     <= saxis_wdata;
                    maxis_wstrb                     <= saxis_wstrb;
                end
            end
        end
    end
    
endmodule
