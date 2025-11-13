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
// DESCRIPTION : Register synchronization across clock domains, upon
// assertion of the 'clk_reg_updated' strobe.
//
// -------------------------------------------------------------------------
// SPECIFICATION : The module does not support 'clk_reg_updated' updating
// with a duty less than 'pSYNC_STAGES' of the 'syncclk' clock.
//
// -------------------------------------------------------------------------

module reg_sync
#(
    parameter int pREG_LEN,
    parameter int pSYNC_STAGES
        // NOTE: minimum 1
)
(
    // ------ 'clk' synchronous ------
    input  logic                clk,
    input  logic                clk_srst,
    input  logic [pREG_LEN-1:0] clk_reg,
    input  logic                clk_reg_updated,

    // ------ asynchronous ------
    input  logic                syncclk,
    input  logic                syncclk_srst,
    output logic [pREG_LEN-1:0] syncclk_reg,
    output logic                syncclk_reg_updated
);

    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    logic [pREG_LEN-1:0]    i_clk_reg;
    logic                   i_clk_reg_updated_sync;

    logic [pREG_LEN-1:0]    i_syncclk_clk_reg;
    logic                   i_syncclk_clk_reg_updated_sync;
    logic                   i_syncclk_clk_reg_updated_sync_d1;


    // ----------------------------------------------
    // Synchronization logic
    // ----------------------------------------------

    // ------------------------ 'clk' synchronous ------------------------

    always@(posedge clk) begin : CLKSync
        if (clk_srst == 1'b1) begin
            i_clk_reg_updated_sync <= 1'b0;
        end else begin
            if (clk_reg_updated == 1'b1) begin
                i_clk_reg_updated_sync  <= !i_clk_reg_updated_sync;
                i_clk_reg               <= clk_reg;
            end
        end
    end : CLKSync


    // ------------------------ 'syncclk' synchronous ------------------------

    genvar i;
    generate
        for (i = 0; i < pREG_LEN; i++) begin
            dff_sync
            #(
                .pSYNC_STAGES (pSYNC_STAGES)
            ) sync_i_clk_reg
            (
                .clk    (syncclk),
                .srst   (syncclk_srst),
                .sync   (i_syncclk_clk_reg[i]),

                .async  (i_clk_reg[i])
            );
        end
    endgenerate

    dff_sync
    #(
        .pSYNC_STAGES (pSYNC_STAGES)
    ) sync_i_clk_reg_updated_sync
    (
        .clk    (syncclk),
        .srst   (syncclk_srst),
        .sync   (i_syncclk_clk_reg_updated_sync),

        .async  (i_clk_reg_updated_sync)
    );

    always@(posedge syncclk) begin : SyncClk_Reg
        if (syncclk_srst == 1'b1) begin
            i_syncclk_clk_reg_updated_sync_d1   <= 1'b0;

            syncclk_reg_updated                 <= 1'b0;
            syncclk_reg                         <= 0;
        end else begin
            i_syncclk_clk_reg_updated_sync_d1 <= i_syncclk_clk_reg_updated_sync;

            if (i_syncclk_clk_reg_updated_sync_d1 != i_syncclk_clk_reg_updated_sync) begin
                syncclk_reg_updated <= 1'b1;
                syncclk_reg         <= i_syncclk_clk_reg;
            end else begin
                syncclk_reg_updated <= 1'b0;
            end
        end
    end : SyncClk_Reg

endmodule : reg_sync