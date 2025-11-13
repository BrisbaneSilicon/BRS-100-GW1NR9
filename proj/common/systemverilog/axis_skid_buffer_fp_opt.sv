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
// USE CASE(S) : TODO
//
// -------------------------------------------------------------------------

module axis_skid_buffer_fp_opt
    // NOTE: fp_opt == footprint optimised
#(
    parameter int pDATA_LEN,
    parameter int pID_LEN,
    parameter int pUSER_LEN
)
(
    input   logic                   clk,
    input   logic                   srst,

    input   logic                   s_valid,
    output  logic                   s_ready,
    input   logic [pDATA_LEN-1:0]   s_data,
    input   logic [pID_LEN-1:0]     s_id,
    input   logic [pUSER_LEN-1:0]   s_user,

    output  logic                   m_valid,
    input   logic                   m_ready,
    output  logic [pDATA_LEN-1:0]   m_data,
    output  logic [pID_LEN-1:0]     m_id,
    output  logic [pUSER_LEN-1:0]   m_user
);

    typedef enum {
        eBUFFER_WAIT_FOR_SLAVE,
        eBUFFER_APPLY_TO_MASTER
    } tSB_STATE;
        // NOTE: SB == skid buffer

    tSB_STATE i_skid_buffer_state;


    always_comb begin : FlowControl
        s_ready = ((srst == 1'b0) && (i_skid_buffer_state == eBUFFER_WAIT_FOR_SLAVE)) ? 1'b1 : 1'b0;
        m_valid = ((srst == 1'b0) && (i_skid_buffer_state == eBUFFER_APPLY_TO_MASTER)) ? 1'b1 : 1'b0;
    end

    always @(posedge clk) begin : ReadbackSkidBuffer

        case (i_skid_buffer_state)
            eBUFFER_WAIT_FOR_SLAVE: begin
                if (s_valid == 1'b1) begin
                    m_data              <= s_data;
                    m_id                <= s_id;
                    m_user              <= s_user;

                    i_skid_buffer_state <= eBUFFER_APPLY_TO_MASTER;
                end
            end

            eBUFFER_APPLY_TO_MASTER: begin
                if (m_ready == 1'b1) begin
                    i_skid_buffer_state <= eBUFFER_WAIT_FOR_SLAVE;
                end
            end
        endcase

        // NOTE: handle reset here in order to
        // reduce control sets...
        if (srst == 1'b1) begin
            i_skid_buffer_state <= eBUFFER_WAIT_FOR_SLAVE;
        end
    end

endmodule