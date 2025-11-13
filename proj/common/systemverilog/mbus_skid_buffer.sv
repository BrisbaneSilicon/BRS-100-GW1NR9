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

module mbus_skid_buffer
#(
    parameter int pWR_DATA_LEN  = 8,
    parameter int pRD_DATA_LEN  = 8,
    parameter int pID_LEN       = 8,
    parameter int pUSER_LEN     = 8
        // REVISIT: rename to addr + wstrb
)
(
    input   logic                       clk,
    input   logic                       srst,

    input   logic                       s_valid,
    output  logic                       s_ready,
    input   logic [pWR_DATA_LEN-1:0]    s_wrdata,
    output  logic [pRD_DATA_LEN-1:0]    s_rddata,
    input   logic [pID_LEN-1:0]         s_id,
    input   logic [pUSER_LEN-1:0]       s_user,

    output  logic                       m_valid,
    input   logic                       m_ready,
    output  logic [pWR_DATA_LEN-1:0]    m_wrdata,
    input   logic [pRD_DATA_LEN-1:0]    m_rddata,
    output  logic [pID_LEN-1:0]         m_id,
    output  logic [pUSER_LEN-1:0]       m_user
);

    typedef enum {
        eIDLE,
        eBUFFER_WAIT_FOR_SLAVE,
        eBUFFER_APPLY_TO_MASTER,
        eBUFFER_RESPOND_TO_SLAVE
    } tSB_STATE;
        // NOTE: SB == skid buffer

    tSB_STATE i_skid_buffer_state;


    always_comb begin : FlowControl
        m_valid = (i_skid_buffer_state == eBUFFER_APPLY_TO_MASTER)  ? 1'b1 : 1'b0;
        s_ready = (i_skid_buffer_state == eBUFFER_RESPOND_TO_SLAVE) ? 1'b1 : 1'b0;
    end

    always @(posedge clk) begin

        case (i_skid_buffer_state)
            eIDLE: begin
                i_skid_buffer_state <= eBUFFER_WAIT_FOR_SLAVE;
            end

            eBUFFER_WAIT_FOR_SLAVE: begin
                m_wrdata <= s_wrdata;
                m_id     <= s_id;
                m_user   <= s_user;

                if (s_valid == 1'b1) begin
                    i_skid_buffer_state <= eBUFFER_APPLY_TO_MASTER;
                end
            end

            eBUFFER_APPLY_TO_MASTER: begin
                s_rddata <= m_rddata;

                if (m_ready == 1'b1) begin
                    i_skid_buffer_state <= eBUFFER_RESPOND_TO_SLAVE;
                end
            end

            eBUFFER_RESPOND_TO_SLAVE: begin
                i_skid_buffer_state <= eBUFFER_WAIT_FOR_SLAVE;
            end

            default: begin
                i_skid_buffer_state <= eIDLE;
            end
        endcase

        // NOTE: handle reset here in order to
        // reduce control sets...
        if (srst == 1'b1) begin
            i_skid_buffer_state <= eIDLE;
        end
    end

endmodule