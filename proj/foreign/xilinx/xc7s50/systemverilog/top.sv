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
// DESCRIPTION :
//
// -------------------------------------------------------------------------
// SPECIFICATION :
//
// -------------------------------------------------------------------------

`timescale 1ns/1ps

module top #(
    parameter reg   [(8*VERSION_CHARS)-1:0]     VERSION,
    parameter int                               CLK_FREQUENCY_HZ,
    parameter int                               UART_BAUD,
    parameter int                               PUSHBUTTON_AS_HARD_RESET
) (
    input                                       clk_27Mhz,
    input                                       async_resetn,

    input                                       user_pushbutton0_n,
    input                                       user_pushbutton1_n,

    input                                       user_comms_individual_rx,
    output                                      user_comms_individual_tx,
    output                                      user_comms_individual_tx_interrupt,

    output  reg [5:0]                           leds,

    output  reg                                 clk_60Mhz,
    output  reg                                 clk_60Mhz_resetn,

    output                                      flash_clk,
    output                                      flash_csb,
    inout                                       flash_mosi,
    inout                                       flash_miso
);
localparam int VERSION_CHARS    = 36;
localparam int MAX_IO_PER_CORE  = 16;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    wire                    i_clk_60Mhz;
    wire                    i_clk_60Mhz_p;
    reg                     i_clk_60Mhz_pll_lock;
    reg                     i_clk_60Mhz_ce          = 1'b0;
    reg     [1:0]           i_clk_60Mhz_ce_counter  = 0;

    reg                     i_hard_reset_ext_n;
    reg                     i_hard_rstn_ext_p3;
    reg                     i_hard_rstn_ext_p2;
    reg                     i_hard_rstn_ext_p1;
    reg                     i_hard_rstn_ext_p0;

    reg     [11:0]          i_leds;

    reg     [0:0] [31:0]    i_mbus_sram_addr;
    reg     [0:0] [31:0]    i_mbus_sram_wdata;
    reg     [0:0] [3:0]     i_mbus_sram_wstrb;
    reg     [0:0] [31:0]    i_mbus_sram_rdata;
    reg     [0:0]           i_mbus_sram_valid;
    reg     [0:0]           i_mbus_sram_ready;

    reg     [31:0]          i_mbus_spimemcfg_addr;
    reg     [31:0]          i_mbus_spimemcfg_wdata;
    reg     [3:0]           i_mbus_spimemcfg_wstrb;
    reg     [31:0]          i_mbus_spimemcfg_rdata;
    reg                     i_mbus_spimemcfg_valid;
    reg                     i_mbus_spimemcfg_ready;

    reg     [31:0]          i_mbus_saxisce_spimemcfg_addr;
    reg     [31:0]          i_mbus_saxisce_spimemcfg_wdata;
    reg     [3:0]           i_mbus_saxisce_spimemcfg_wstrb;
    reg     [31:0]          i_mbus_saxisce_spimemcfg_rdata;
    reg                     i_mbus_saxisce_spimemcfg_valid;
    reg                     i_mbus_saxisce_spimemcfg_ready;

    reg     [31:0]          i_mbus_spimemxip_addr;
    reg     [31:0]          i_mbus_spimemxip_wdata;
    reg     [3:0]           i_mbus_spimemxip_wstrb;
    reg     [31:0]          i_mbus_spimemxip_rdata;
    reg                     i_mbus_spimemxip_valid;
    reg                     i_mbus_spimemxip_ready;

    reg     [8:0]           i_microsecond_div_counter;
    reg                     i_microsecond_tick;
    reg     [19:0]          i_millisecond_div_counter;
    reg                     i_millisecond_tick;
    reg     [9:0]           i_millisecond_counter;
    reg                     i_second_tick;


    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------


    // NOTE: User
    // Comms
    // ---------------

    uart
    #(
        .OUTPUT_BUFFER_ENABLE       (1),
        .INPUT_BUFFER_ENABLE        (1),

        .INC_RX_ESC_SEQUENCE_FILTER (0),

        .ASCII_CHAR_USER_INTERRUPT  ("q")
    ) user_comms_inst
    (
        .clk                        (i_clk_60Mhz),

        .hard_resetn                (i_hard_rstn_ext_p0),
        .soft_resetn                (i_soft_rstn_p0),

        .rx_esc_seq_filter_disable  (i_user_comms_rx_esc_seq_filter_disable),

        .mem_s_addr                 (i_mbus_user_comms_addr),
        .mem_s_wdata                (i_mbus_user_comms_wdata),
        .mem_s_wstrb                (i_mbus_user_comms_wstrb),
        .mem_s_rdata                (i_mbus_user_comms_rdata),
        .mem_s_valid                (i_mbus_user_comms_valid),
        .mem_s_ready                (i_mbus_user_comms_ready),

        .ser_rx                     (user_comms_individual_rx),
        .ser_rx_user_int            (i_user_comms_rx_interrupt),

        .ser_tx                     (user_comms_individual_tx),
        .ser_tx_int                 (user_comms_individual_tx_interrupt)
    );


    // NOTE: RAM
    // ------------------

    // TODO


    // NOTE: Flash
    // ------------

    // TODO


    // NOTE: Leds
    // Related
    // ------------

    always @(posedge i_clk_60Mhz) begin
        leds <= ~i_leds[5:0];
            // NOTE:
            //          led[3]: pin activity
            //          led[2]: flash activity
            //          led[1]: hyperram activity
            //          led[0]: heartbeat
            //
            // NOTE: invert as output is O.D

        if (i_second_tick == 1'b1) begin
            i_leds <= ~i_leds;
        end
    end


    // NOTE: Timer
    // Related
    // ------------

    always @(posedge i_clk_60Mhz) begin
        if (i_hard_rstn_ext_p0 == 1'b0) begin
            i_microsecond_div_counter   <= 0;
            i_millisecond_div_counter   <= 0;
            i_millisecond_counter       <= 0;

            i_second_tick               <= 1'b0;
            i_millisecond_tick          <= 1'b0;
            i_microsecond_tick          <= 1'b0;
        end else begin
            // defaults
            i_second_tick       <= 1'b0;
            i_millisecond_tick  <= 1'b0;
            i_microsecond_tick  <= 1'b0;

            if (i_millisecond_div_counter == 0) begin
                i_millisecond_div_counter   <= (CLK_FREQUENCY_HZ/1000)-1;
                i_millisecond_tick          <= 1'b1;
            end else begin
                i_millisecond_div_counter <= i_millisecond_div_counter - 1;
            end

            if (i_microsecond_div_counter == 0) begin
                i_microsecond_div_counter   <= (CLK_FREQUENCY_HZ/1000000)-1;
                i_microsecond_tick          <= 1'b1;
            end else begin
                i_microsecond_div_counter <= i_microsecond_div_counter - 1;
            end

            if (i_millisecond_tick == 1'b1) begin
                if (i_millisecond_counter == 1000-1) begin
                    i_second_tick           <= 1'b1;

                    i_millisecond_counter   <= 0;
                end else begin
                    i_millisecond_counter <= i_millisecond_counter + 1;
                end
            end
        end
    end


    // NOTE: Reset
    // Related
    // ------------

    rst_sync rst_sync_inst (
        .clk        (i_clk_60Mhz),
        .ext_resetn (i_clk_60Mhz_pll_lock & async_resetn),

        .resetn     (i_clk_60Mhz_resetn)
    );

    generate
        if (PUSHBUTTON_AS_HARD_RESET) begin
            assign i_hard_reset_ext_n = i_clk_60Mhz_resetn & user_pushbutton0_n;
        end else begin
            assign i_hard_reset_ext_n = i_clk_60Mhz_resetn;
        end
    endgenerate

    always @(posedge i_clk_60Mhz) begin
        // NOTE: allow duplication
        // in PAR stage of high-
        // fanout net.
        // -----------------

        i_hard_rstn_ext_p3 <= i_hard_reset_ext_n;
        i_hard_rstn_ext_p2 <= i_hard_rstn_ext_p3;
        i_hard_rstn_ext_p1 <= i_hard_rstn_ext_p2;
        i_hard_rstn_ext_p0 <= i_hard_rstn_ext_p1;
    end


    // NOTE: clocking
    // related
    // ------------------

    // TODO

    assign clk_60Mhz        = i_clk_60Mhz;
    assign clk_60Mhz_resetn = i_clk_60Mhz_resetn;

endmodule
