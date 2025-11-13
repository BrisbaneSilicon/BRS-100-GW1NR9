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
// DESCRIPTION : Simple DFF synchronizer of a single strobe.
//
// -------------------------------------------------------------------------
// SPECIFICATION : Configurable number of synchronization stages.
//
// -------------------------------------------------------------------------

module dff_sync
#(
    parameter int   pSYNC_STAGES,
        // NOTE: minimum 1
    parameter logic pSYNC_DEFAULT = 1'b0
)
(
    // ------ 'clk' synchronous ------
    input  logic clk,
    input  logic srst,
    output logic sync = pSYNC_DEFAULT,

    // ------ asynchronous ------
    input  logic async
);

    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    logic [pSYNC_STAGES-1:0] i_sync_stages = {(pSYNC_STAGES){pSYNC_DEFAULT}};


    // ----------------------------------------------
    //  Synchronization
    // ----------------------------------------------

    always@(posedge clk) begin : SyncStage
        if (srst == 1'b1) begin
            i_sync_stages   <= {(pSYNC_STAGES){pSYNC_DEFAULT}};
            sync            <= pSYNC_DEFAULT;

        end else begin
            i_sync_stages       <= i_sync_stages << 1;
            i_sync_stages[0]    <= async;

            sync                <= i_sync_stages[$bits(i_sync_stages)-1];
        end
    end : SyncStage

endmodule : dff_sync