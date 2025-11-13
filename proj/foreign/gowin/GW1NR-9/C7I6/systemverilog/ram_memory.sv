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

`timescale 1ns/1ps

import util::*;

module sram_8k (
    input           clk,
    input           reset,
    inout           ce,
    input           oce,
    input           wre,
    input [12:0]    ad,
    input [7:0]     din,
    output [7:0]    dout
);

    reg [7:0] mem [8191:0];
    reg [7:0] mem_out;

    always @(posedge clk) begin
        if (ce) begin
            if (wre) begin
                mem[ad] <= din;
            end
            mem_out <= mem[ad];
        end
    end

    assign dout = mem_out;

endmodule


module ram_memory #(
    //  Layout:
    //      - First 32 KB   : Internal FPGA SRAM
    //      - Next 8 MB     : HyperRAM

    parameter IF,

    parameter CLK_FREQ_HZ,
    parameter XIP_FIFO_DEPTH_WORDS,
        // NOTE: not much point having this > 8, as might as well
        // just do a fresh read at that point...

    parameter SIM_MODE = 0
) (
    input                           clk,
    input                           clk_p,

    input                           clk_resetn,

    input       [IF-1:0]            saxis_mem_valid,
    input       [IF-1:0] [31:0]     saxis_mem_addr,
    input       [IF-1:0] [31:0]     saxis_mem_wdata,
    input       [IF-1:0] [3:0]      saxis_mem_wstrb,
    output  reg [IF-1:0]            saxis_mem_ready,
    output  reg [IF-1:0] [31:0]     saxis_mem_rdata,

    output  reg [IF-1:0]            xip_fifo_almost_full,

    // NOTE: these ports are needed, or
    // the PSRAM IP will not compile...
    output  [CS_WIDTH-1:0]          O_psram_ck,
    output  [CS_WIDTH-1:0]          O_psram_ck_n,
    inout   [CS_WIDTH-1:0]          IO_psram_rwds,
    inout   [DQ_WIDTH-1:0]          IO_psram_dq,
    output  [CS_WIDTH-1:0]          O_psram_reset_n,
    output  [CS_WIDTH-1:0]          O_psram_cs_n
);
localparam DQ_WIDTH     = 16;
localparam CS_WIDTH     = 2;

localparam XIP_FIFO_MAX_ADDRESS_DISTANCE_SCROLL = XIP_FIFO_DEPTH_WORDS - 2;


    // ----------------------------------------------
    //  Constants / Types
    // ----------------------------------------------

    localparam int IF_BITS = log2ceil_min1(IF);


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    reg     [IF-1:0]    [IF_BITS-1:0]   i_if_pr;
                                            // NOTE: if == interface, pr == priority
    reg                 [IF_BITS-1:0]   i_if;

    reg     [IF-1:0]                    i_saxis_mem_ready;

    reg                                 i_release_saxis_for_if;
    reg                                 i_update_priority_for_if;

    reg                                 i_access_in_prog                    = 0;
    reg                                 i_access_in_prog_is_write           = 0;
    reg                                 i_access_in_prog_is_hyperram        = 0;

    reg                 [19:0]          i_if_hyperram_addr                  = 0;
    reg                 [19:0]          i_hyperram_addr                     = 0;
    reg                 [31:0]          i_hyperram_wdata                    = 0;
    reg                 [3:0]           i_hyperram_wstrb                    = 0;

    reg                 [12:0]          i_if_sram_addr                      = 0;
    reg                 [12:0]          i_sram_addr                         = 0;
    reg                 [31:0]          i_sram_wdata                        = 0;
    reg                 [3:0]           i_sram_wstrb                        = 0;
    reg                 [31:0]          i_sram_rdata                        = 0;
    wire                                i_sram_ce;

    reg                                 i_requesting_hyperram_write;
    reg     [IF-1:0]                    i_requesting_hyperram_read;

    reg                 [3:0]           i_hyperram_oper_wstrb;
    reg                                 i_hyperram_oper_lsw_byte_write;
    reg                                 i_hyperram_oper_msw_byte_write;
    reg                 [21:0]          i_hyperram_oper_lsw_addr;
    reg                 [21:0]          i_hyperram_oper_msw_addr;
    reg                 [20:0]          i_hyperram_oper_addr_msb;
    reg                                 i_hyperram_oper_lsw_lsb;
    reg                                 i_hyperram_oper_msw_lsb;
    reg                 [1:0]           i_hyperram_oper_en                  = 0;
    reg                                 i_hyperram_oper_in_progress         = 0;
    reg     [IF-1:0]                    i_hyperram_oper_is_write            = 0;
    reg     [IF-1:0]                    i_hyperram_oper_is_write_d1         = 0;
    reg                 [31:0]          i_hyperram_oper_wr_data             = 0;
    reg                 [31:0]          i_hyperram_oper_rd_data             = 0;
    reg                 [1:0]           i_hyperram_oper_busy                = 0;

    reg     [IF-1:0]    [19:0]          i_hyperram_rd_addr                  = 0;
    reg     [IF-1:0]    [19:0]          i_hyperram_rd_addr_d1               = 0;
    reg                 [31:0]          i_hyperram_rd_data                  = 0;
    reg     [IF-1:0]                    i_hyperram_rd_data_valid            = 0;
    reg     [IF-1:0]                    i_hyperram_rd_rst_ack               = 0;

    reg                 [IF_BITS-1:0]   i_hyperram_rd_if;
    reg                 [IF_BITS-1:0]   i_if_rds;
                                            // NOTE: if rds == interface read scan

    reg     [IF-1:0]                    i_of_reset                          = 0;
    reg     [IF-1:0]                    i_of_wr_almost_full                 = 0;
    reg     [IF-1:0]                    i_of_wr_valid_p                     = 0;
    reg     [IF-1:0]                    i_of_wr_valid;
    reg     [IF-1:0]                    i_of_wr_ready                       = 0;
    reg     [IF-1:0]    [51:0]          i_of_wr_data;
    reg     [IF-1:0]                    i_of_rd_valid                       = 0;
    reg     [IF-1:0]                    i_of_rd_valid_d1                    = 0;
    reg     [IF-1:0]    [51:0]          i_of_rd_data;
    reg     [IF-1:0]    [19:0]          i_of_rd_addr;
    reg     [IF-1:0]    [19:0]          i_of_rd_addr_diff                   = 0;
    reg     [IF-1:0]                    i_of_rd_addr_match                  = 0;
    reg     [IF-1:0]                    i_of_rd_ready;
    reg     [IF-1:0]                    i_of_process                        = 0;
    reg     [IF-1:0]                    i_of_processing_match               = 0;
    reg     [IF-1:0]                    i_of_inspect_hyperram_write_stg0    = 0;
    reg     [IF-1:0]                    i_of_inspect_hyperram_write_stg1    = 0;
        // NOTE: of == output FIFO

    reg     [IF-1:0]                    i_skb_out_wren;
    reg     [IF-1:0]                    i_hyperram_skb_valid;
    reg     [IF-1:0]                    i_hyperram_skb_ready;
    reg     [IF-1:0]    [31:0]          i_hyperram_skb_read_data            = 0;

    reg     [IF-1:0]                    i_hyperram_write_complete;
    reg     [IF-1:0]                    i_hyperram_read_complete;


    // ----------------------------------------------
    //  Assertions
    // ----------------------------------------------

    initial begin : Assertions
        assert(IF <= 2)
            else $error("Module 'ram_memory' does not currently support 'IF > 2'");
    end : Assertions



    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------

    // NOTE: Outputs
    // --------------

    always_comb begin
        saxis_mem_ready <= i_saxis_mem_ready | i_hyperram_read_complete;

        for (int i = 0; i < IF; i++) begin
            if (i_access_in_prog_is_hyperram == 1'b1) begin
                saxis_mem_rdata[i] <= i_hyperram_skb_read_data[i];
            end else begin
                saxis_mem_rdata[i] <= i_sram_rdata;
            end
        end
    end




    // NOTE: Prelim
    // Stage
    // --------------

    always @(posedge clk) begin
        // defaults
        i_saxis_mem_ready           <= 0;

        i_update_priority_for_if    <= 1'b0;
        i_release_saxis_for_if      <= 1'b0;


        if (i_access_in_prog == 1'b0) begin
            if (|i_saxis_mem_ready == 1'b0) begin
                for (int i = 0; i < IF; i++) begin
                    if (saxis_mem_valid[i_if_pr[i]] == 1'b1) begin
                        i_if                <= i_if_pr[i];

                        i_sram_wdata        <= saxis_mem_wdata[i_if_pr[i]];
                        i_sram_wstrb        <= saxis_mem_wstrb[i_if_pr[i]];
                        i_sram_addr         <= saxis_mem_addr[i_if_pr[i]][14:2];

                        i_hyperram_wdata    <= saxis_mem_wdata[i_if_pr[i]];
                        i_hyperram_wstrb    <= saxis_mem_wstrb[i_if_pr[i]];
                        i_hyperram_addr     <= saxis_mem_addr[i_if_pr[i]][21:2];

                        if (IF == 1) begin
                            i_access_in_prog_is_hyperram <= |saxis_mem_addr[i_if_pr[i]][21:15];
                                // NOTE: one 32 kB SRAM
                        end
                        if (IF == 2) begin
                            i_access_in_prog_is_hyperram <= |saxis_mem_addr[i_if_pr[i]][21:14];
                                // NOTE: two 16 kB SRAM
                        end

                        i_access_in_prog_is_write   <= |saxis_mem_wstrb[i_if_pr[i]];
                        i_release_saxis_for_if      <= |saxis_mem_wstrb[i_if_pr[i]];
                            // NOTE: if write operation, we can release
                            // the upstream straight away...

                        i_access_in_prog            <= 1'b1;
                        i_update_priority_for_if    <= saxis_mem_valid[i_if_pr[IF-1]];
                    end
                end
            end
        end else begin
            if (i_access_in_prog_is_hyperram == 1'b1) begin
                if (i_access_in_prog_is_write == 1'b1) begin
                    if (i_hyperram_write_complete[i_if] == 1'b1) begin
                        i_access_in_prog <= 1'b0;
                    end
                end else begin
                    if (i_hyperram_read_complete[i_if] == 1'b1) begin
                        i_access_in_prog <= 1'b0;
                    end
                end
            end else begin
                // NOTE: SRAM access always completes in
                // a single cycle.
                i_access_in_prog        <= 1'b0;

                i_saxis_mem_ready[i_if] <= ~i_access_in_prog_is_write;
            end

            if (i_release_saxis_for_if == 1'b1) begin
                i_saxis_mem_ready[i_if] <= 1'b1;
            end

            if (i_update_priority_for_if == 1'b1) begin
                i_if_pr[0] <= i_if_pr[IF-1];
                for (int i = 1; i < IF; i++) begin
                    i_if_pr[i] <= i_if_pr[i-1];
                end
            end
        end

        if (clk_resetn == 1'b0) begin
            for (int i = 0; i < IF; i++) begin
                i_if_pr[i] <= i;
            end

            i_saxis_mem_ready   <= 0;
            i_access_in_prog    <= 1'b0;
        end
    end


    assign i_requesting_hyperram_write = i_access_in_prog & i_access_in_prog_is_hyperram &
                                            i_access_in_prog_is_write;

    always_comb begin
        // defaults
        i_requesting_hyperram_read          <= 0;

        i_requesting_hyperram_read[i_if]    <= i_access_in_prog & i_access_in_prog_is_hyperram &
                                                    ~i_access_in_prog_is_write;
    end


    // NOTE: HyperRAM
    // Access Manager
    // -------------

    assign i_hyperram_oper_lsw_byte_write   = i_hyperram_oper_wstrb[1] ^ i_hyperram_oper_wstrb[0];
    assign i_hyperram_oper_msw_byte_write   = i_hyperram_oper_wstrb[3] ^ i_hyperram_oper_wstrb[2];

    assign i_hyperram_oper_lsw_lsb          = i_hyperram_oper_lsw_byte_write & i_hyperram_oper_wstrb[1];
    assign i_hyperram_oper_msw_lsb          = i_hyperram_oper_msw_byte_write & i_hyperram_oper_wstrb[3];

    assign i_hyperram_oper_lsw_addr         = { i_hyperram_oper_addr_msb, i_hyperram_oper_lsw_lsb };
    assign i_hyperram_oper_msw_addr         = { i_hyperram_oper_addr_msb, i_hyperram_oper_msw_lsb };
        // NOTE: lowest bit isn't used as part of the address,
        // but to distinguish if upper / lower is used as part
        // of a byte-only write...

    always_comb begin
        if (IF == 1) begin
            i_if_hyperram_addr <= i_hyperram_addr;
        end else if (IF == 2) begin
            i_if_hyperram_addr <= { i_if[0], i_hyperram_addr[18:0] };
        end
    end

    always @(posedge clk) begin
        // defaults
        i_hyperram_oper_en          <= 2'b00;

        i_hyperram_rd_data_valid    <= 0;
        i_hyperram_rd_rst_ack       <= 0;

        for (int i = 0; i < IF; i++) begin
            i_hyperram_rd_addr_d1[i] <= i_hyperram_rd_addr[i];
        end


        if (i_hyperram_oper_in_progress == 1'b0) begin
            i_hyperram_oper_is_write    <= 0;

            i_hyperram_oper_addr_msb    <= i_if_hyperram_addr;
                // REVISIT: could use the full 20:0 now...
            i_hyperram_oper_wstrb       <= i_hyperram_wstrb;
            i_hyperram_oper_wr_data     <= i_hyperram_wdata;

            if (i_hyperram_oper_busy == 2'b00) begin
                if (i_requesting_hyperram_write == 1'b1) begin
                    // NOTE: priortise request for write, as it resets
                    // the read...

                    i_hyperram_oper_in_progress     <= 1'b1;
                    i_hyperram_oper_is_write[i_if]  <= 1'b1;
                    i_hyperram_oper_en              <= { i_hyperram_wstrb[3] | i_hyperram_wstrb[2],
                                                            i_hyperram_wstrb[1] | i_hyperram_wstrb[0] };
                end else begin
                    // REVISIT: proper priority for 'i_if_rds' ?
                    if (i_if_rds < (IF-1)) begin
                        i_if_rds <= i_if_rds + 1;
                    end else begin
                        i_if_rds <= 0;
                    end

                    i_hyperram_rd_if <= i_if_rds;

                    if (i_of_wr_almost_full[i_if_rds] == 1'b0) begin
                        if (i_of_reset[i_if_rds] == 1'b1) begin
                            if (i_requesting_hyperram_read[i_if_rds] == 1'b1) begin
                                i_hyperram_rd_rst_ack[i_if_rds] <= 1'b1;
                                i_hyperram_rd_addr[i_if_rds]    <= i_if_hyperram_addr;

                                i_hyperram_oper_in_progress     <= 1'b1;
                                i_hyperram_oper_en              <= { 1'b1, 1'b1 };
                            end
                        end else begin
                            i_hyperram_oper_addr_msb    <= i_hyperram_rd_addr[i_if_rds];

                            i_hyperram_oper_in_progress <= 1'b1;
                            i_hyperram_oper_en          <= { 1'b1, 1'b1 };
                        end
                    end
                end
            end
        end else begin
            if (i_hyperram_oper_en == 2'b00) begin
                if (i_hyperram_oper_busy == 2'b00) begin
                    i_hyperram_rd_data <= i_hyperram_oper_rd_data;

                    if (|i_hyperram_oper_is_write == 1'b0) begin
                        i_hyperram_rd_addr[i_hyperram_rd_if]        <= i_hyperram_rd_addr[i_hyperram_rd_if] + 1;
                        i_hyperram_rd_data_valid[i_hyperram_rd_if]  <= 1'b1;
                    end

                    i_hyperram_oper_is_write    <= 0;
                    i_hyperram_oper_in_progress <= 1'b0;
                end
            end
        end

        if (clk_resetn == 1'b0) begin
            i_if_rds                    <= 0;

            i_hyperram_oper_in_progress <= 1'b0;
        end
    end


    genvar i;
    generate
        for (i = 0; i < IF; i++) begin

            assign i_hyperram_write_complete[i] = i_hyperram_oper_is_write[i] & ~i_hyperram_oper_en[0] & ~i_hyperram_oper_en[1] &
                                                    ~i_hyperram_oper_busy[0] & ~i_hyperram_oper_busy[1];


            // NOTE: HyperRAM
            // Output FIFO
            // -------------

            assign i_of_wr_data[i]  = { i_hyperram_rd_addr_d1[i], i_hyperram_rd_data };
            assign i_of_wr_valid[i] = i_hyperram_rd_data_valid[i];

            axis_fifo_sync #(
                .g_data_bits        ($size(i_of_wr_data[i])),
                .g_depth            (XIP_FIFO_DEPTH_WORDS)
            ) hyperram_of_inst
            (
                .clk                (clk),
                .srst               (i_of_reset[i]),

                .s_tdata            (i_of_wr_data[i]),
                .s_talmost_full     (i_of_wr_almost_full[i]),
                .s_tvalid           (i_of_wr_valid[i]),
                .s_tready           (i_of_wr_ready[i]),
                    // NOTE: could catch overflow ...?

                .m_tdata            (i_of_rd_data[i]),
                .m_tvalid           (i_of_rd_valid[i]),
                .m_tready           (i_of_rd_ready[i])
            );

            assign i_of_rd_addr[i]  = i_of_rd_data[i][51:32];
            assign i_of_rd_ready[i] = i_of_process[i];

            always @(posedge clk) begin
                // defaults
                i_of_process[i]                     <= i_requesting_hyperram_read[i] & ~i_of_processing_match[i] &
                                                            ~i_of_process[i] & i_of_rd_valid[i];

                i_of_rd_addr_diff[i]                <= i_if_hyperram_addr - i_of_rd_addr[i];
                i_of_rd_addr_match[i]               <= (i_if_hyperram_addr == i_of_rd_addr[i]) ? 1'b1 : 1'b0;

                i_hyperram_oper_is_write_d1[i]      <= i_hyperram_oper_is_write[i];
                i_of_inspect_hyperram_write_stg0[i] <= i_hyperram_oper_is_write[i] & ~i_hyperram_oper_is_write_d1[i];
                i_of_inspect_hyperram_write_stg1[i] <= 1'b0;

                if (i_of_reset[i] == 1'b0) begin
                    if (i_of_process[i] == 1'b1) begin
                        if (i_of_rd_addr_diff[i] >= XIP_FIFO_MAX_ADDRESS_DISTANCE_SCROLL) begin
                            i_of_reset[i] <= 1'b1;
                        end
                        if (i_if_hyperram_addr < i_of_rd_addr[i]) begin
                            i_of_reset[i] <= 1'b1;
                        end
                    end
                end else begin
                    if (i_hyperram_rd_rst_ack[i] == 1'b1) begin
                        i_of_process[i] <= 1'b0;
                        i_of_reset[i]   <= 1'b0;
                    end
                end

                if (i_of_processing_match[i] == 1'b0) begin
                    if (i_of_reset[i] == 1'b0) begin
                        if (i_of_process[i] == 1'b1) begin
                            i_of_processing_match[i] <= i_of_rd_addr_match[i];
                        end
                    end
                end else begin
                    if (i_hyperram_skb_valid[i] == 1'b1) begin
                        i_of_processing_match[i] <= 1'b0;
                    end
                end

                if (i_of_reset[i] == 1'b0) begin
                    if (i_of_rd_valid[i] == 1'b1) begin
                        if (i_of_inspect_hyperram_write_stg0[i] == 1'b1) begin
                            if (i_if_hyperram_addr >= i_of_rd_addr[i]) begin
                                i_of_inspect_hyperram_write_stg1[i] <= 1'b1;
                            end
                        end
                        if (i_of_inspect_hyperram_write_stg1[i] == 1'b1) begin
                            if (i_of_rd_addr_diff[i]    <= XIP_FIFO_DEPTH_WORDS) begin
                                i_of_reset[i]           <= 1'b1;
                            end
                        end
                    end
                end

                if (clk_resetn == 1'b0) begin
                    i_of_process[i]             <= 1'b0;
                    i_of_processing_match[i]    <= 1'b0;

                    i_of_reset[i]               <= 1'b1;
                end
            end

            assign i_skb_out_wren[i] = i_of_process[i] & i_of_rd_addr_match[i];

            axis_skid_buffer_fp_opt #(
                .pDATA_LEN      ($size(i_hyperram_skb_read_data[i])),
                .pID_LEN        (1),
                .pUSER_LEN      (1)
            ) hyperram_skb_inst
            (
                .clk            (clk),
                .srst           (~clk_resetn),

                .s_data         (i_of_rd_data[i][31:0]),
                .s_valid        (i_skb_out_wren[i]),
                .s_ready        (),

                .m_data         (i_hyperram_skb_read_data[i]),
                .m_valid        (i_hyperram_skb_valid[i]),
                .m_ready        (i_hyperram_skb_ready[i])
                    // NOTE: deliberate switcheroo...
            );

            assign i_hyperram_skb_ready[i]      = i_requesting_hyperram_read[i];

            assign i_hyperram_read_complete[i]  = i_hyperram_skb_valid[i];

        end
    endgenerate


    // HyperRAM
    // Instances
    // ---------------

    psram_controller #(
        .FREQ               (CLK_FREQ_HZ),
        .LATENCY            (3)
    ) psram_controller_inst_0
    (
        .clk                (clk),
        .clk_p              (clk_p),

        .resetn             (clk_resetn),

        .read               (~i_hyperram_oper_is_write[i_if] & i_hyperram_oper_en[0]),
        .write              (i_hyperram_oper_is_write[i_if] & i_hyperram_oper_en[0]),
        .addr               (i_hyperram_oper_lsw_addr),
            // NOTE: lsw == least significant word
        .din                (i_hyperram_oper_wr_data[15:0]),
        .byte_write         (i_hyperram_oper_lsw_byte_write),
            // NOTE: when writing, only write one byte
            // instead of the whole word.
            //
            // If addr[0] == 1 means we write the upper
            // half of din - lower half otherwise.

        .dout               (i_hyperram_oper_rd_data[15:0]),
        .busy               (i_hyperram_oper_busy[0]),

        // HyperRAM physical interface. Gowin interface is for 2 dies.
        // This is the first die (4MB).
        .psram_clk          (O_psram_ck[0]),
        .psram_clk_n        (O_psram_ck_n[0]),
        .psram_rd_wr        (IO_psram_rwds[0]),
        .psram_data_q       (IO_psram_dq[7:0]),
        .psram_chip_sel_n   (O_psram_cs_n[0])
    );

    assign O_psram_reset_n[0] = clk_resetn;


    psram_controller #(
        .FREQ               (CLK_FREQ_HZ),
        .LATENCY            (3)
    ) psram_controller_inst_1
    (
        .clk                (clk),
        .clk_p              (clk_p),

        .resetn             (clk_resetn),

        .read               (~i_hyperram_oper_is_write[i_if] & i_hyperram_oper_en[1]),
        .write              (i_hyperram_oper_is_write[i_if] & i_hyperram_oper_en[1]),
        .addr               (i_hyperram_oper_msw_addr),
            // NOTE: msw == least significant word
        .din                (i_hyperram_oper_wr_data[31:16]),
        .byte_write         (i_hyperram_oper_msw_byte_write),
            // NOTE: when writing, only write one byte
            // instead of the whole word.
            //
            // If addr[0] == 1 means we write the upper
            // half of din - lower half otherwise.

        .dout               (i_hyperram_oper_rd_data[31:16]),
        .busy               (i_hyperram_oper_busy[1]),

        .psram_clk          (O_psram_ck[1]),
        .psram_clk_n        (O_psram_ck_n[1]),
        .psram_rd_wr        (IO_psram_rwds[1]),
        .psram_data_q       (IO_psram_dq[15:8]),
        .psram_chip_sel_n   (O_psram_cs_n[1])
    );

    assign O_psram_reset_n[1] = clk_resetn;


    // NOTE: SRAM
    // Access Manager
    // -------------

    assign i_sram_ce = i_access_in_prog & ~i_access_in_prog_is_hyperram;

    always_comb begin
        if (IF == 1) begin
            i_if_sram_addr <= i_sram_addr;
        end else if (IF == 2) begin
            i_if_sram_addr <= { i_if[0], i_sram_addr[11:0] };
        end
    end

    // NOTE: SRAM
    // Instances
    // ---------------

    sram_8k sram_8k_inst_0 (
        .clk    (clk),
        .reset  (~clk_resetn),

        .ce     (i_sram_ce),
        .oce    (1'b1),
        .wre    (i_sram_wstrb[0]),
        .ad     (i_if_sram_addr),
        .din    (i_sram_wdata[7:0]),
        .dout   (i_sram_rdata[7:0])
    );

    sram_8k sram_8k_inst_1 (
        .clk    (clk),
        .reset  (~clk_resetn),

        .ce     (i_sram_ce),
        .oce    (1'b1),
        .wre    (i_sram_wstrb[1]),
        .ad     (i_if_sram_addr),
        .din    (i_sram_wdata[15:8]),
        .dout   (i_sram_rdata[15:8])
    );

    sram_8k sram_8k_inst_2 (
        .clk    (clk),
        .reset  (~clk_resetn),

        .ce     (i_sram_ce),
        .oce    (1'b1),
        .wre    (i_sram_wstrb[2]),
        .ad     (i_if_sram_addr),
        .din    (i_sram_wdata[23:16]),
        .dout   (i_sram_rdata[23:16])
    );

    sram_8k sram_8k_inst_3 (
        .clk    (clk),
        .reset  (~clk_resetn),

        .ce     (i_sram_ce),
        .oce    (1'b1),
        .wre    (i_sram_wstrb[3]),
        .ad     (i_if_sram_addr),
        .din    (i_sram_wdata[31:24]),
        .dout   (i_sram_rdata[31:24])
    );

    // NOTE: Debug
    // Outputs
    // --------------

    always @(posedge clk) begin
        xip_fifo_almost_full <= i_of_wr_almost_full;
    end

endmodule
