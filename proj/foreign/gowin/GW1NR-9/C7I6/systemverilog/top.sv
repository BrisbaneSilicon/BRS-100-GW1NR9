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
    parameter int                               CLK_FREQUENCY_MHZ,
    parameter int                               UART_BAUD,
    parameter int                               PUSHBUTTON0_AS_RESET
) (

    // ---------------- pads ----------------

    input                       clk_27Mhz,

    input                       user_pushbutton0_n,
    input                       user_pushbutton1_n,

    input                       uart_rx,
    output                      uart_tx,

    output  reg [5:0]           leds,

    output                      flash_clk,
    output                      flash_csb,
    inout                       flash_mosi,
    inout                       flash_miso,

    output  [CS_WIDTH-1:0]      psram_ck,
    output  [CS_WIDTH-1:0]      psram_ck_n,
    inout   [CS_WIDTH-1:0]      psram_rwds,
    inout   [DQ_WIDTH-1:0]      psram_dq,
    output  [CS_WIDTH-1:0]      psram_reset_n,
    output  [CS_WIDTH-1:0]      psram_cs_n,


    // -------------- fabric --------------

    output  reg                 sysclk,
    output  reg                 sysclk_resetn,

    output  reg                 microsecond_tick,
    output  reg                 millisecond_tick,
    output  reg                 second_tick,

    input                       uart_tx_valid,
    output  reg                 uart_tx_ready,
    input       [7:0]           uart_tx_data,
    output  reg                 uart_rx_valid,
    input                       uart_rx_ready,
    output  reg  [7:0]          uart_rx_data,

    // -------------- memory fabric --------------

    input       [31:0]          ram_addr,
    input       [31:0]          ram_wdata,
    input       [3:0]           ram_wstrb,
    output  reg [31:0]          ram_rdata,
    input                       ram_valid,
    output  reg                 ram_ready,

    input       [31:0]          flash_cfg_addr,
    input       [31:0]          flash_cfg_wdata,
    input       [3:0]           flash_cfg_wstrb,
    output  reg [31:0]          flash_cfg_rdata,
    input                       flash_cfg_valid,
    output  reg                 flash_cfg_ready,

    input       [31:0]          flash_xip_addr,
    input       [31:0]          flash_xip_wdata,
    input       [3:0]           flash_xip_wstrb,
    output  reg [31:0]          flash_xip_rdata,
    input                       flash_xip_valid,
    output  reg                 flash_xip_ready
);
localparam int DQ_WIDTH         = 16;
localparam int CS_WIDTH         = 2;
localparam int VERSION_CHARS    = 36;
localparam int MAX_IO_PER_CORE  = 16;
localparam int CLK_FREQUENCY_HZ = CLK_FREQUENCY_MHZ * 1000000;
localparam int UART_DIVIDER     = (CLK_FREQUENCY_HZ / UART_BAUD)-1;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    wire                    i_sysclk;
    wire                    i_sysclk_p;
    reg                     i_sysclk_pll_lock;
    reg                     i_sysclk_power_on_resetn;
    reg                     i_sysclk_resetn;
    reg                     i_sysclk_ce          = 1'b0;
    reg     [1:0]           i_sysclk_ce_counter  = 0;

    reg                     i_soft_rstn_p3;
    reg                     i_soft_rstn_p2;
    reg                     i_soft_rstn_p1;
    reg                     i_soft_rstn_p0;
    reg                     i_soft_reset_n;

    reg     [5:0]           i_leds;

    wire    [0:0] [31:0]    i_mbus_sram_addr;
    wire    [0:0] [31:0]    i_mbus_sram_wdata;
    wire    [0:0] [3:0]     i_mbus_sram_wstrb;
    reg     [0:0] [31:0]    i_mbus_sram_rdata;
    wire    [0:0]           i_mbus_sram_valid;
    reg     [0:0]           i_mbus_sram_ready;

    wire    [31:0]          i_mbus_spimemcfg_addr;
    wire    [31:0]          i_mbus_spimemcfg_wdata;
    wire    [3:0]           i_mbus_spimemcfg_wstrb;
    reg     [31:0]          i_mbus_spimemcfg_rdata;
    wire                    i_mbus_spimemcfg_valid;
    reg                     i_mbus_spimemcfg_ready;

    reg     [31:0]          i_mbus_saxisce_spimemcfg_addr;
    reg     [31:0]          i_mbus_saxisce_spimemcfg_wdata;
    reg     [3:0]           i_mbus_saxisce_spimemcfg_wstrb;
    reg     [31:0]          i_mbus_saxisce_spimemcfg_rdata;
    reg                     i_mbus_saxisce_spimemcfg_valid;
    reg                     i_mbus_saxisce_spimemcfg_ready;

    wire    [31:0]          i_mbus_spimemxip_addr;
    wire    [31:0]          i_mbus_spimemxip_wdata;
    wire    [3:0]           i_mbus_spimemxip_wstrb;
    reg     [31:0]          i_mbus_spimemxip_rdata;
    wire                    i_mbus_spimemxip_valid;
    reg                     i_mbus_spimemxip_ready;

    reg     [8:0]           i_microsecond_div_counter;
    reg     [19:0]          i_millisecond_div_counter;
    reg     [9:0]           i_millisecond_counter;


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

        .INC_RX_ESC_SEQUENCE_FILTER (0)
    ) user_comms_inst
    (
        .clk                        (i_sysclk),
        .resetn                     (i_soft_reset_n),

        .rx_esc_seq_filter_disable  (1'b0),

        .divider                    (UART_DIVIDER),

        .tx_valid                   (uart_tx_valid),
        .tx_ready                   (uart_tx_ready),
        .tx_data                    (uart_tx_data),

        .rx_valid                   (uart_rx_valid),
        .rx_ready                   (uart_rx_ready),
        .rx_data                    (uart_rx_data),

        .ser_rx                     (uart_rx),
        .ser_tx                     (uart_tx)
    );


    // NOTE: HyperRAM
    // ------------------

    ram_memory #(
        .IF                     (1),

        .CLK_FREQ_HZ            (CLK_FREQUENCY_HZ),
        .XIP_FIFO_DEPTH_WORDS   (8)
    ) ram_memory_Inst (
        .clk                    (i_sysclk),
        .clk_p                  (i_sysclk_p),

        .clk_resetn             (i_soft_reset_n),

        .saxis_mem_addr         (i_mbus_sram_addr),
        .saxis_mem_wdata        (i_mbus_sram_wdata),
        .saxis_mem_wstrb        (i_mbus_sram_wstrb),
        .saxis_mem_rdata        (i_mbus_sram_rdata),
        .saxis_mem_valid        (i_mbus_sram_valid),
        .saxis_mem_ready        (i_mbus_sram_ready),

        .O_psram_ck             (psram_ck),
        .O_psram_ck_n           (psram_ck_n),
        .IO_psram_rwds          (psram_rwds),
        .IO_psram_dq            (psram_dq),
        .O_psram_reset_n        (psram_reset_n),
        .O_psram_cs_n           (psram_cs_n)
    );


    // NOTE: Flash
    // ------------

    generate
        if (CLK_FREQUENCY_HZ == 51000000 || CLK_FREQUENCY_HZ == 66000000) begin
            always @(posedge i_sysclk) begin
                if(i_soft_reset_n == 1'b0) begin
                    i_sysclk_ce <= 0;
                end else begin
                    i_sysclk_ce <= ~i_sysclk_ce;
                end
            end
        end
        if (CLK_FREQUENCY_HZ == 75000000 || CLK_FREQUENCY_HZ == 81000000 || CLK_FREQUENCY_HZ == 87000000) begin
            always @(posedge i_sysclk) begin
                if(i_soft_reset_n == 1'b0) begin
                    i_sysclk_ce          <= 0;
                    i_sysclk_ce_counter  <= 0;
                end else begin
                    // defaults
                    i_sysclk_ce          <= 1'b0;
                    i_sysclk_ce_counter  <= i_sysclk_ce_counter + 1;

                    if (i_sysclk_ce_counter == 2'b10) begin
                        i_sysclk_ce          <= 1'b1;
                        i_sysclk_ce_counter  <= 0;
                    end
                end
            end
        end
    endgenerate

    axis_bus_to_axis_bus_ce saxisce_spimemcfg_inst (
        .clk                (i_sysclk),
        .clk_resetn         (i_soft_reset_n),

        .saxis_valid        (i_mbus_spimemcfg_valid),
        .saxis_addr         (i_mbus_spimemcfg_addr),
        .saxis_wdata        (i_mbus_spimemcfg_wdata),
        .saxis_wstrb        (i_mbus_spimemcfg_wstrb),
        .saxis_ready        (i_mbus_spimemcfg_ready),
        .saxis_rdata        (i_mbus_spimemcfg_rdata),

        .maxis_ce           (i_sysclk_ce),
        .maxis_valid        (i_mbus_saxisce_spimemcfg_valid),
        .maxis_addr         (i_mbus_saxisce_spimemcfg_addr),
        .maxis_wdata        (i_mbus_saxisce_spimemcfg_wdata),
        .maxis_wstrb        (i_mbus_saxisce_spimemcfg_wstrb),
        .maxis_ready        (i_mbus_saxisce_spimemcfg_ready),
        .maxis_rdata        (i_mbus_saxisce_spimemcfg_rdata)
    );

    flash_memory flash_memory_inst (
        .clk                (i_sysclk),
        .resetn             (i_soft_reset_n),

        .flash_mem_addr     (i_mbus_spimemxip_addr),
        .flash_mem_wdata    (i_mbus_spimemxip_wdata),
        .flash_mem_wstrb    (i_mbus_spimemxip_wstrb),
        .flash_mem_rdata    (i_mbus_spimemxip_rdata),
        .flash_mem_valid    (i_mbus_spimemxip_valid),
        .flash_mem_ready    (i_mbus_spimemxip_ready),

        .flash_cfg_ce       (i_sysclk_ce),
        .flash_cfg_addr     (i_mbus_saxisce_spimemcfg_addr),
        .flash_cfg_wdata    (i_mbus_saxisce_spimemcfg_wdata),
        .flash_cfg_wstrb    (i_mbus_saxisce_spimemcfg_wstrb),
        .flash_cfg_rdata    (i_mbus_saxisce_spimemcfg_rdata),
        .flash_cfg_valid    (i_mbus_saxisce_spimemcfg_valid),
        .flash_cfg_ready    (i_mbus_saxisce_spimemcfg_ready),

        .flash_csb          (flash_csb),
        .flash_clk          (flash_clk),
        .flash_mosi         (flash_mosi),
        .flash_miso         (flash_miso)
    );


    // NOTE: Leds
    // Related
    // ------------

    always @(posedge i_sysclk) begin
        if (second_tick == 1'b1) begin
            i_leds[0] <= ~i_leds[0];
        end
        if (uart_tx_valid == 1'b1 && uart_tx_ready == 1'b1) begin
            i_leds[1] <= 1'b1;
        end
        if (uart_rx_valid == 1'b1 && uart_rx_ready == 1'b1) begin
            i_leds[1] <= 1'b1;
        end

        if (|i_millisecond_counter[6:0] == 1'b1) begin
            i_leds[4:1] <= 0;
        end
        if (i_soft_reset_n == 1'b0) begin
            i_leds <= 0;
        end
    end
    assign leds = i_leds;
        // NOTE:
        //          led[4]: pin activity
        //          led[3]: flash activity
        //          led[2]: hyperram activity
        //          led[1]: uart activity
        //          led[0]: heartbeat


    // NOTE: Timer
    // Related
    // ------------

    always @(posedge i_sysclk) begin
        if (i_soft_reset_n == 1'b0) begin
            i_microsecond_div_counter   <= 0;
            i_millisecond_div_counter   <= 0;
            i_millisecond_counter       <= 0;

            second_tick                 <= 1'b0;
            millisecond_tick            <= 1'b0;
            microsecond_tick            <= 1'b0;
        end else begin
            // defaults
            second_tick         <= 1'b0;
            millisecond_tick    <= 1'b0;
            microsecond_tick    <= 1'b0;

            if (i_millisecond_div_counter == 0) begin
                i_millisecond_div_counter   <= (CLK_FREQUENCY_HZ/1000)-1;
                millisecond_tick            <= 1'b1;
            end else begin
                i_millisecond_div_counter <= i_millisecond_div_counter - 1;
            end

            if (i_microsecond_div_counter == 0) begin
                i_microsecond_div_counter   <= (CLK_FREQUENCY_HZ/1000000)-1;
                microsecond_tick            <= 1'b1;
            end else begin
                i_microsecond_div_counter <= i_microsecond_div_counter - 1;
            end

            if (millisecond_tick == 1'b1) begin
                if (i_millisecond_counter == 1000-1) begin
                    second_tick             <= 1'b1;

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
        .clk        (i_sysclk),
        .ext_resetn (i_sysclk_pll_lock),

        .resetn     (i_sysclk_power_on_resetn)
    );

    generate
        if (PUSHBUTTON0_AS_RESET) begin
            assign i_soft_rstn_p3 = i_sysclk_power_on_resetn & user_pushbutton0_n;
        end else begin
            assign i_soft_rstn_p3 = i_sysclk_power_on_resetn;
        end
    endgenerate

    always @(posedge i_sysclk) begin
        // NOTE: allow duplication
        // in PAR stage of high-
        // fanout net.
        // -----------------

        i_soft_rstn_p2 <= i_soft_rstn_p3;
        i_soft_rstn_p1 <= i_soft_rstn_p2;
        i_soft_rstn_p0 <= i_soft_rstn_p1;
        i_soft_reset_n <= i_soft_rstn_p0;
    end


    // NOTE: clocking
    // related
    // ------------------

    generate
        if (CLK_FREQUENCY_HZ == 51000000) begin
            clk51mhz clk51mhz_inst (
                .clkin_27Mhz    (clk_27Mhz),

                .lock           (i_sysclk_pll_lock),
                .clkout         (i_sysclk),
                .clkoutp        (i_sysclk_p)
            );
        end
        if (CLK_FREQUENCY_HZ == 66000000) begin
            clk66mhz clk66mhz_inst (
                .clkin_27Mhz    (clk_27Mhz),

                .lock           (i_sysclk_pll_lock),
                .clkout         (i_sysclk),
                .clkoutp        (i_sysclk_p)
            );
        end
        if (CLK_FREQUENCY_HZ == 75000000) begin
            clk75mhz clk75mhz_inst (
                .clkin_27Mhz    (clk_27Mhz),

                .lock           (i_sysclk_pll_lock),
                .clkout         (i_sysclk),
                .clkoutp        (i_sysclk_p)
            );
        end
        if (CLK_FREQUENCY_HZ == 81000000) begin
            clk81mhz clk81mhz_inst (
                .clkin_27Mhz    (clk_27Mhz),

                .lock           (i_sysclk_pll_lock),
                .clkout         (i_sysclk),
                .clkoutp        (i_sysclk_p)
            );
        end
        if (CLK_FREQUENCY_HZ == 87000000) begin
            clk87mhz clk87mhz_inst (
                .clkin_27Mhz    (clk_27Mhz),

                .lock           (i_sysclk_pll_lock),
                .clkout         (i_sysclk),
                .clkoutp        (i_sysclk_p)
            );
        end
    endgenerate

    assign sysclk        = i_sysclk;
    assign sysclk_resetn = i_soft_reset_n;

    // -------------- memory fabric assignments --------------

    // SRAM/HyperRAM — flatten [0:0][31:0] to [31:0]
    assign i_mbus_sram_addr[0]  = ram_addr;
    assign i_mbus_sram_wdata[0] = ram_wdata;
    assign i_mbus_sram_wstrb[0] = ram_wstrb;
    assign ram_rdata             = i_mbus_sram_rdata[0];
    assign i_mbus_sram_valid[0] = ram_valid;
    assign ram_ready             = i_mbus_sram_ready[0];

    // Flash config
    assign i_mbus_spimemcfg_addr  = flash_cfg_addr;
    assign i_mbus_spimemcfg_wdata = flash_cfg_wdata;
    assign i_mbus_spimemcfg_wstrb = flash_cfg_wstrb;
    assign flash_cfg_rdata         = i_mbus_spimemcfg_rdata;
    assign i_mbus_spimemcfg_valid = flash_cfg_valid;
    assign flash_cfg_ready         = i_mbus_spimemcfg_ready;

    // Flash XIP
    assign i_mbus_spimemxip_addr  = flash_xip_addr;
    assign i_mbus_spimemxip_wdata = flash_xip_wdata;
    assign i_mbus_spimemxip_wstrb = flash_xip_wstrb;
    assign flash_xip_rdata         = i_mbus_spimemxip_rdata;
    assign i_mbus_spimemxip_valid = flash_xip_valid;
    assign flash_xip_ready         = i_mbus_spimemxip_ready;

endmodule
