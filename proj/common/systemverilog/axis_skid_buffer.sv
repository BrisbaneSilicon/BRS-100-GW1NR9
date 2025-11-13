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
// DESCRIPTION : De-couples input/output AXI-S interface ports, i.e. there
// is no combinatorial path between input ready/valid and the output
// ready/valid.
//
// -------------------------------------------------------------------------
// USE CASE(S) : Splitting a critical path on the ready/valid strobes that
// may exist between two AXI-S interfaces.
//
// -------------------------------------------------------------------------

module axis_skid_buffer
#(
    parameter int pDATA_LEN     = 8,
    parameter int pID_LEN       = 8,
    parameter int pUSER_LEN     = 8
)
(
    input   logic                   clk,
    input   logic                   srst,

    input   logic                   s_tvalid,
    output  logic                   s_tready,
    input   logic [pDATA_LEN-1:0]   s_tdata,
    input   logic [pID_LEN-1:0]     s_tid,
    input   logic [pUSER_LEN-1:0]   s_tuser,

    output  logic                   m_tvalid,
    input   logic                   m_tready,
    output  logic [pDATA_LEN-1:0]   m_tdata,
    output  logic [pID_LEN-1:0]     m_tid,
    output  logic [pUSER_LEN-1:0]   m_tuser
);

    typedef enum {
        eIDLE,
        eBUFFER_EMPTY,
        eBUFFER_BUSY,
        eBUFFER_FULL
    } tSB_STATE;
        // NOTE: SB == skid buffer

    tSB_STATE i_skid_buffer_state;

    logic [pDATA_LEN-1:0]   i_tdata_buffer;
    logic [pID_LEN-1:0]     i_tid_buffer;
    logic [pUSER_LEN-1:0]   i_tuser_buffer;


    always_comb begin : FlowControl
        s_tready = (srst == 1'b0 && (i_skid_buffer_state == eBUFFER_EMPTY || i_skid_buffer_state == eBUFFER_BUSY)) ? 1'b1 : 1'b0;
        m_tvalid = (srst == 1'b0 && (i_skid_buffer_state == eBUFFER_BUSY || i_skid_buffer_state == eBUFFER_FULL)) ? 1'b1 : 1'b0;
    end

    always_ff @(posedge clk) begin : SkidBuffer

        case (i_skid_buffer_state)
            eIDLE: begin
                i_skid_buffer_state <= eBUFFER_EMPTY;
            end

            eBUFFER_EMPTY: begin
                if (s_tvalid == 1'b1) begin
                    m_tdata             <= s_tdata;
                    m_tid               <= s_tid;
                    m_tuser             <= s_tuser;

                    i_skid_buffer_state <= eBUFFER_BUSY;
                end
            end

            eBUFFER_BUSY: begin
                if (s_tvalid == 1'b1) begin
                    if (m_tready == 1'b0) begin
                        i_tdata_buffer      <= s_tdata;
                        i_tid_buffer        <= s_tid;
                        i_tuser_buffer      <= s_tuser;

                        i_skid_buffer_state <= eBUFFER_FULL;
                    end else begin
                        m_tdata <= s_tdata;
                        m_tid   <= s_tid;
                        m_tuser <= s_tuser;
                    end
                end else begin
                    if (m_tready == 1'b1) begin
                        i_skid_buffer_state <= eBUFFER_EMPTY;
                    end
                end
            end

            eBUFFER_FULL: begin
                if (m_tready == 1'b1) begin
                    m_tdata             <= i_tdata_buffer;
                    m_tid               <= i_tid_buffer;
                    m_tuser             <= i_tuser_buffer;

                    i_skid_buffer_state <= eBUFFER_BUSY;
                end
            end

            default: begin
                i_skid_buffer_state <= eIDLE;
            end
        endcase

        // NOTE: handle reset here in order to
        // reduce control sets by leaving
        // internal buffers and external data
        // ports unaffected by reset (only
        // ready/valid and skid-buffer state
        // is controlled by reset).
        if (srst == 1'b1) begin
            i_skid_buffer_state <= eIDLE;
        end
    end

endmodule: axis_skid_buffer