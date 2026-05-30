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

module board_demonstration #(
    parameter int VERSION_CHARS = 63,
    parameter reg [(8*VERSION_CHARS)-1:0] VERSION,
    parameter int VERSION_LEN = 0
) (
    input               sysclk,
    input               sysclk_resetn,

    input               microsecond_tick,
    input               millisecond_tick,
    input               second_tick,

    inout       [31:0]  io,

    output  reg         uart_tx_valid,
    input               uart_tx_ready,
    output  reg [7:0]   uart_tx_data,
    input               uart_rx_valid,
    output  reg         uart_rx_ready,
    input       [7:0]   uart_rx_data,

    // -------------- memory fabric --------------

    output  reg [31:0]  ram_addr,
    output  reg [31:0]  ram_wdata,
    output  reg [3:0]   ram_wstrb,
    input       [31:0]  ram_rdata,
    output  reg         ram_valid,
    input               ram_ready,

    output  reg [31:0]  flash_cfg_addr,
    output  reg [31:0]  flash_cfg_wdata,
    output  reg [3:0]   flash_cfg_wstrb,
    input       [31:0]  flash_cfg_rdata,
    output  reg         flash_cfg_valid,
    input               flash_cfg_ready,

    output  reg [31:0]  flash_xip_addr,
    output  reg [31:0]  flash_xip_wdata,
    output  reg [3:0]   flash_xip_wstrb,
    input       [31:0]  flash_xip_rdata,
    output  reg         flash_xip_valid,
    input               flash_xip_ready
);
localparam                              UART_TX_BUF_CHARS   = 96;
localparam                              UART_TX_BUF_BITS    = UART_TX_BUF_CHARS * 8;
localparam                              RST_SCRN_CHARS      = 14;
localparam                              BEGIN_MSG_CHARS     = 21;
localparam reg  [UART_TX_BUF_BITS-1:0]  RST_SCRN            = {"\033[2J\033[3J\033[0;0H",
                                                               {(UART_TX_BUF_CHARS-RST_SCRN_CHARS){8'h00}}};
localparam reg  [UART_TX_BUF_BITS-1:0]  BEGIN_MSG           = {"BOARD: BRS-100-GW1NR9",
                                                               {(UART_TX_BUF_CHARS-BEGIN_MSG_CHARS){8'h00}}};

`define UART_TX_BUF_BYTE(_idx) i_uart_tx_buf[UART_TX_BUF_BITS-1 - ((_idx) * 8) -: 8]


    // ----------------------------------------------
    //  Definitions
    // ----------------------------------------------

    typedef enum {
        eRESET,
        eSTARTUP_DELAY,
        ePREP_NEXT_UART_STARTUP_MSG,
        eOUTPUT_UART_STARTUP_MSG,
        eSRAM_WRITE,
        eSRAM_READ,
        eSRAM_COMPARE,
        eSRAM_DEMO_WRITE_PREP,
        eSRAM_DEMO_WRITE,
        eSRAM_DEMO_WRITE_GAP,
        eSRAM_DEMO_PRINT_WRITE,
        eSRAM_DEMO_READ_PREP,
        eSRAM_DEMO_READ,
        eSRAM_DEMO_READ_GAP,
        eSRAM_DEMO_PRINT_READ,
        eSRAM_DEMO_PRINT_RESULT,
        eHRAM_DEMO_WRITE_PREP,
        eHRAM_DEMO_WRITE,
        eHRAM_DEMO_WRITE_GAP,
        eHRAM_DEMO_PRINT_WRITE,
        eHRAM_DEMO_READ_PREP,
        eHRAM_DEMO_READ,
        eHRAM_DEMO_READ_GAP,
        eHRAM_DEMO_PRINT_READ,
        eHRAM_DEMO_PRINT_RESULT,
        eHRAM_WAIT,
        eHRAM_WRITE,
        eHRAM_READ,
        eHRAM_COMPARE,
        eJEDEC_INIT_EN,
        eJEDEC_INIT_OE,
        eJEDEC_INIT_CSB_HI,
        eJEDEC_INIT_CSB_LO,
        eJEDEC_BIT_LO,
        eJEDEC_BIT_HI,
        eJEDEC_BIT_CAP,
        eJEDEC_END,
        eJEDEC_RESTORE,
        eJEDEC_COMPARE,
        eFW_INIT_EN,
        eFW_INIT_OE,
        eFW_INIT_CSB_HI,
        eFW_SETUP_WREN_ERASE,
        eFW_SETUP_ERASE,
        eFW_SETUP_POLL_ERASE,
        eFW_CHECK_POLL_ERASE,
        eFW_SETUP_WREN_PROGRAM,
        eFW_SETUP_PROGRAM,
        eFW_SETUP_POLL_PROGRAM,
        eFW_CHECK_POLL_PROGRAM,
        eFW_SPI_CSB_LO,
        eFW_SPI_BIT_LO,
        eFW_SPI_BIT_HI,
        eFW_SPI_BIT_CAP,
        eFW_SPI_END,
        eFW_RESTORE,
        eFW_XIP_READ,
        eFW_COMPARE,
        ePRINT_BUF,
        eIDLE
    } tDEMONSTRATE_SYSTEM_STATE;

    typedef enum {
        eRESET_SCREEN,
        eOUTPUT_BEGIN_MSG,
        eOUTPUT_NLCR_1,
        eOUTPUT_VERSION_MSG,
        eOUTPUT_NLCR_2,
        eTEST_SRAM,
        eDEMO_SRAM,
        eTEST_HRAM,
        eDEMO_HRAM,
        eTEST_FLASH_ID,
        eTEST_FLASH_WRV,
        eNONE
    } tSTARTUP_TASKS;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    tSTARTUP_TASKS                                      i_next_startup_task;
    tDEMONSTRATE_SYSTEM_STATE                           i_demo_system_state;
    reg                         [UART_TX_BUF_BITS-1:0]  i_uart_tx_buf;
    reg                         [6:0]                   i_uart_tx_buf_counter;
    reg                         [6:0]                   i_uart_tx_buf_count;

    reg                         [31:0]                  i_io;

    reg                         [31:0]                  readback;
    tDEMONSTRATE_SYSTEM_STATE                           print_next_state;
    reg                         [7:0]                   hram_init_us;

    reg                         [5:0]                   jedec_bit_idx;
    reg                         [23:0]                  jedec_id_in;

    localparam [7:0]  JEDEC_CMD         = 8'h9F;
    localparam [23:0] EXPECTED_JEDEC_ID = 24'h85_6016;
    localparam [31:0] SRAM_DEMO_ADDR    = 32'h0000_0010;
    localparam [31:0] HRAM_DEMO_ADDR    = 32'h0000_8010;
    localparam [23:0] FLASH_TEST_ADDR   = 24'h01_0000;
    localparam [31:0] FLASH_TEST_DATA   = 32'hABCD_ABCD;
    localparam [7:0]  FLASH_CMD_WREN    = 8'h06;
    localparam [7:0]  FLASH_CMD_RDSR    = 8'h05;
    localparam [7:0]  FLASH_CMD_ERASE   = 8'h20;
    localparam [7:0]  FLASH_CMD_PROGRAM = 8'h02;
    localparam [9:0]  FLASH_POLL_LIMIT  = 10'd1000;

    wire [2:0] jedec_tx_idx   = 3'd7 - jedec_bit_idx[2:0];
    wire       jedec_mosi_bit = (jedec_bit_idx < 6'd8) ? JEDEC_CMD[jedec_tx_idx] : 1'b0;

    reg                         [63:0]                  fw_shift;
    reg                         [6:0]                   fw_bit_idx;
    reg                         [6:0]                   fw_bit_count;
    reg                         [7:0]                   fw_status;
    reg                         [9:0]                   fw_poll_ms;
    reg                                                 fw_capture_status;
    tDEMONSTRATE_SYSTEM_STATE                           fw_next_state;

    localparam int DEMO_MAX_LEN       = VERSION_CHARS;
    localparam int DEMO_LEN           = (VERSION_LEN > DEMO_MAX_LEN) ? DEMO_MAX_LEN : VERSION_LEN;
    localparam int DEMO_WORDS         = (DEMO_LEN + 3) / 4;
    localparam int SRAM_DEMO_LINE_LEN = 20 + DEMO_LEN + 2;

    reg                         [4:0]                   demo_word_idx;
    reg                                                 demo_pass;

    wire [6:0] demo_word_base = {demo_word_idx, 2'b00};

    function automatic [7:0] hex_nibble;
        input [3:0] n;
        hex_nibble = (n < 4'd10) ? (8'h30 + {4'h0, n}) : (8'h37 + {4'h0, n});
    endfunction

    function automatic [7:0] version_byte;
        input [6:0] idx;
        begin
            if (idx < DEMO_LEN) begin
                version_byte = (VERSION >> ((VERSION_LEN - idx - 1) * 8)) & 8'hFF;
            end else begin
                version_byte = 8'h00;
            end
        end
    endfunction

    function automatic [31:0] version_word;
        input [4:0] word_idx;
        reg [6:0] base;
        begin
            base = {word_idx, 2'b00};
            version_word = {
                version_byte(base),
                version_byte(base + 7'd1),
                version_byte(base + 7'd2),
                version_byte(base + 7'd3)
            };
        end
    endfunction

    integer demo_i;


    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------

    always @(posedge sysclk) begin
        // defaults
        uart_tx_valid   <= 1'b0;
        uart_rx_ready   <= 1'b0;
        ram_valid       <= 1'b0;
        ram_addr        <= 32'd0;
        ram_wdata       <= 32'd0;
        ram_wstrb       <= 4'd0;
        flash_cfg_valid <= 1'b0;
        flash_cfg_addr  <= 32'd0;
        flash_cfg_wdata <= 32'd0;
        flash_cfg_wstrb <= 4'd0;
        flash_xip_valid <= 1'b0;
        flash_xip_addr  <= 32'd0;
        flash_xip_wdata <= 32'd0;
        flash_xip_wstrb <= 4'd0;

        case (i_demo_system_state)
            eRESET:                                                             begin
                i_next_startup_task <= eRESET_SCREEN;

                i_demo_system_state <= eSTARTUP_DELAY;
            end

            eSTARTUP_DELAY:                                                     begin
                if (second_tick == 1'b1) begin
                    i_demo_system_state <= ePREP_NEXT_UART_STARTUP_MSG;
                end
            end

            ePREP_NEXT_UART_STARTUP_MSG:                                        begin
                // REVISIT: this could be done more cleanly...

                // defaults
                i_demo_system_state     <= eOUTPUT_UART_STARTUP_MSG;
                i_uart_tx_buf           <= 0;
                i_uart_tx_buf_counter   <= 0;
                i_uart_tx_buf_count     <= 0;
                i_next_startup_task     <= eOUTPUT_BEGIN_MSG;

                if (i_next_startup_task == eRESET_SCREEN) begin
                    i_uart_tx_buf       <= RST_SCRN;
                    i_uart_tx_buf_count <= RST_SCRN_CHARS;
                    i_next_startup_task <= eOUTPUT_BEGIN_MSG;
                end
                if (i_next_startup_task == eOUTPUT_BEGIN_MSG) begin
                    i_uart_tx_buf       <= BEGIN_MSG;
                    i_uart_tx_buf_count <= BEGIN_MSG_CHARS;
                    i_next_startup_task <= eOUTPUT_NLCR_1;
                end
                if (i_next_startup_task == eOUTPUT_NLCR_1) begin
                    i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                    UART_TX_BUF_BITS-16]    <= 16'h0A0D;
                    i_uart_tx_buf_count                     <= 7'd2;
                    i_next_startup_task                     <= eOUTPUT_VERSION_MSG;
                end
                if (i_next_startup_task == eOUTPUT_VERSION_MSG) begin
                    i_uart_tx_buf       <= 0;
                    for (demo_i = 0; demo_i < VERSION_LEN; demo_i = demo_i + 1) begin
                        `UART_TX_BUF_BYTE(demo_i) <= version_byte(demo_i[6:0]);
                    end
                    i_uart_tx_buf_count <= VERSION_LEN[6:0];
                    i_next_startup_task <= eOUTPUT_NLCR_2;
                end
                if (i_next_startup_task == eOUTPUT_NLCR_2) begin
                    i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                    UART_TX_BUF_BITS-16]    <= 16'h0A0D;
                    i_uart_tx_buf_count                     <= 7'd2;
                    i_next_startup_task                     <= eTEST_SRAM;
                end

                if (i_next_startup_task == eTEST_SRAM) begin
                    i_next_startup_task <= eDEMO_SRAM;
                    i_demo_system_state <= eSRAM_WRITE;
                end

                if (i_next_startup_task == eDEMO_SRAM) begin
                    i_next_startup_task <= eTEST_HRAM;
                    i_demo_system_state <= eSRAM_DEMO_WRITE_PREP;
                end

                if (i_next_startup_task == eTEST_HRAM) begin
                    i_next_startup_task <= eDEMO_HRAM;
                    hram_init_us        <= 8'd0;
                    i_demo_system_state <= eHRAM_WAIT;
                end

                if (i_next_startup_task == eDEMO_HRAM) begin
                    i_next_startup_task <= eTEST_FLASH_ID;
                    i_demo_system_state <= eHRAM_DEMO_WRITE_PREP;
                end

                if (i_next_startup_task == eTEST_FLASH_ID) begin
                    i_next_startup_task <= eTEST_FLASH_WRV;
                    jedec_bit_idx       <= 6'd0;
                    jedec_id_in         <= 24'h0;
                    i_demo_system_state <= eJEDEC_INIT_EN;
                end

                if (i_next_startup_task == eTEST_FLASH_WRV) begin
                    i_next_startup_task <= eNONE;
                    fw_poll_ms          <= 10'd0;
                    i_demo_system_state <= eFW_INIT_EN;
                end

                if (i_next_startup_task == eNONE) begin
                    // NOTE: done - abort!
                    i_demo_system_state <= eIDLE;
                end
            end

            eOUTPUT_UART_STARTUP_MSG:                                           begin
                if (i_uart_tx_buf_count == 7'd0) begin
                    i_demo_system_state <= ePREP_NEXT_UART_STARTUP_MSG;
                end else begin
                    uart_tx_valid   <= 1'b1;
                    uart_tx_data    <= i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                                        UART_TX_BUF_BITS-8];

                    if (uart_tx_valid == 1'b1 && uart_tx_ready == 1'b1) begin
                        if (i_uart_tx_buf_counter + 7'd1 == i_uart_tx_buf_count) begin
                            uart_tx_valid       <= 1'b0;
                            i_demo_system_state <= ePREP_NEXT_UART_STARTUP_MSG;
                        end else begin
                            i_uart_tx_buf_counter   <= i_uart_tx_buf_counter + 7'd1;
                            i_uart_tx_buf           <= i_uart_tx_buf << 8;
                            uart_tx_data            <= i_uart_tx_buf[UART_TX_BUF_BITS-9 -: 8];
                        end
                    end
                end
            end

            eSRAM_WRITE:                                                        begin
                ram_valid <= 1'b1;
                ram_addr  <= 32'h0000_0000;
                ram_wdata <= 32'hABCD_ABCD;
                ram_wstrb <= 4'hF;
                if (ram_ready) begin
                    i_demo_system_state <= eSRAM_READ;
                end
            end

            eSRAM_READ:                                                         begin
                ram_valid <= 1'b1;
                ram_addr  <= 32'h0000_0000;
                ram_wstrb <= 4'h0;
                if (ram_ready) begin
                    readback            <= ram_rdata;
                    i_demo_system_state <= eSRAM_COMPARE;
                end
            end

            eSRAM_COMPARE:                                                      begin
                // "Testing SRAM... "
                `UART_TX_BUF_BYTE(0) <= "T"; `UART_TX_BUF_BYTE(1) <= "e"; `UART_TX_BUF_BYTE(2) <= "s";
                `UART_TX_BUF_BYTE(3) <= "t"; `UART_TX_BUF_BYTE(4) <= "i"; `UART_TX_BUF_BYTE(5) <= "n";
                `UART_TX_BUF_BYTE(6) <= "g"; `UART_TX_BUF_BYTE(7) <= " "; `UART_TX_BUF_BYTE(8) <= "S";
                `UART_TX_BUF_BYTE(9) <= "R"; `UART_TX_BUF_BYTE(10) <= "A"; `UART_TX_BUF_BYTE(11) <= "M";
                `UART_TX_BUF_BYTE(12) <= "."; `UART_TX_BUF_BYTE(13) <= "."; `UART_TX_BUF_BYTE(14) <= ".";
                `UART_TX_BUF_BYTE(15) <= " ";
                if (readback == 32'hABCD_ABCD) begin
                    `UART_TX_BUF_BYTE(16) <= "p"; `UART_TX_BUF_BYTE(17) <= "a";
                    `UART_TX_BUF_BYTE(18) <= "s"; `UART_TX_BUF_BYTE(19) <= "s";
                    `UART_TX_BUF_BYTE(20) <= 8'h0D; `UART_TX_BUF_BYTE(21) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd22;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    `UART_TX_BUF_BYTE(16) <= "F"; `UART_TX_BUF_BYTE(17) <= "A";
                    `UART_TX_BUF_BYTE(18) <= "I"; `UART_TX_BUF_BYTE(19) <= "L";
                    `UART_TX_BUF_BYTE(20) <= " "; `UART_TX_BUF_BYTE(21) <= "(";
                    `UART_TX_BUF_BYTE(22) <= "w"; `UART_TX_BUF_BYTE(23) <= "r";
                    `UART_TX_BUF_BYTE(24) <= "o"; `UART_TX_BUF_BYTE(25) <= "t";
                    `UART_TX_BUF_BYTE(26) <= "e"; `UART_TX_BUF_BYTE(27) <= " ";
                    `UART_TX_BUF_BYTE(28) <= "0"; `UART_TX_BUF_BYTE(29) <= "x";
                    `UART_TX_BUF_BYTE(30) <= "A"; `UART_TX_BUF_BYTE(31) <= "B";
                    `UART_TX_BUF_BYTE(32) <= "C"; `UART_TX_BUF_BYTE(33) <= "D";
                    `UART_TX_BUF_BYTE(34) <= "A"; `UART_TX_BUF_BYTE(35) <= "B";
                    `UART_TX_BUF_BYTE(36) <= "C"; `UART_TX_BUF_BYTE(37) <= "D";
                    `UART_TX_BUF_BYTE(38) <= " "; `UART_TX_BUF_BYTE(39) <= "r";
                    `UART_TX_BUF_BYTE(40) <= "e"; `UART_TX_BUF_BYTE(41) <= "a";
                    `UART_TX_BUF_BYTE(42) <= "d"; `UART_TX_BUF_BYTE(43) <= " ";
                    `UART_TX_BUF_BYTE(44) <= "0"; `UART_TX_BUF_BYTE(45) <= "x";
                    `UART_TX_BUF_BYTE(46) <= hex_nibble(readback[31:28]);
                    `UART_TX_BUF_BYTE(47) <= hex_nibble(readback[27:24]);
                    `UART_TX_BUF_BYTE(48) <= hex_nibble(readback[23:20]);
                    `UART_TX_BUF_BYTE(49) <= hex_nibble(readback[19:16]);
                    `UART_TX_BUF_BYTE(50) <= hex_nibble(readback[15:12]);
                    `UART_TX_BUF_BYTE(51) <= hex_nibble(readback[11:8]);
                    `UART_TX_BUF_BYTE(52) <= hex_nibble(readback[7:4]);
                    `UART_TX_BUF_BYTE(53) <= hex_nibble(readback[3:0]);
                    `UART_TX_BUF_BYTE(54) <= ")";
                    `UART_TX_BUF_BYTE(55) <= 8'h0D; `UART_TX_BUF_BYTE(56) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd57;
                end
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            eSRAM_DEMO_WRITE_PREP:                                             begin
                demo_word_idx       <= 5'd0;
                demo_pass           <= 1'b1;
                i_demo_system_state <= eSRAM_DEMO_WRITE;
            end

            eSRAM_DEMO_WRITE:                                                  begin
                ram_valid <= 1'b1;
                ram_addr  <= SRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wdata <= version_word(demo_word_idx);
                ram_wstrb <= 4'hF;
                if (ram_valid && ram_ready) begin
                    if (demo_word_idx + 5'd1 == DEMO_WORDS) begin
                        i_demo_system_state <= eSRAM_DEMO_PRINT_WRITE;
                    end else begin
                        demo_word_idx       <= demo_word_idx + 5'd1;
                        i_demo_system_state <= eSRAM_DEMO_WRITE_GAP;
                    end
                end
            end

            eSRAM_DEMO_WRITE_GAP:                                              begin
                i_demo_system_state <= eSRAM_DEMO_WRITE;
            end

            eSRAM_DEMO_PRINT_WRITE:                                            begin
                `UART_TX_BUF_BYTE(0) <= "S"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "W";
                `UART_TX_BUF_BYTE(6) <= " "; `UART_TX_BUF_BYTE(7) <= "@"; `UART_TX_BUF_BYTE(8) <= "0";
                `UART_TX_BUF_BYTE(9) <= "x"; `UART_TX_BUF_BYTE(10) <= "0"; `UART_TX_BUF_BYTE(11) <= "0";
                `UART_TX_BUF_BYTE(12) <= "0"; `UART_TX_BUF_BYTE(13) <= "0"; `UART_TX_BUF_BYTE(14) <= "0";
                `UART_TX_BUF_BYTE(15) <= "0"; `UART_TX_BUF_BYTE(16) <= "1"; `UART_TX_BUF_BYTE(17) <= "0";
                `UART_TX_BUF_BYTE(18) <= ":"; `UART_TX_BUF_BYTE(19) <= " ";
                for (demo_i = 0; demo_i < DEMO_LEN; demo_i = demo_i + 1) begin
                    `UART_TX_BUF_BYTE(20 + demo_i) <= version_byte(demo_i[6:0]);
                end
                `UART_TX_BUF_BYTE(20 + DEMO_LEN) <= 8'h0D;
                `UART_TX_BUF_BYTE(21 + DEMO_LEN) <= 8'h0A;
                i_uart_tx_buf_count <= SRAM_DEMO_LINE_LEN;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= eSRAM_DEMO_READ_PREP;
                i_demo_system_state <= ePRINT_BUF;
            end

            eSRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                `UART_TX_BUF_BYTE(0) <= "S"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "R";
                `UART_TX_BUF_BYTE(6) <= " "; `UART_TX_BUF_BYTE(7) <= "@"; `UART_TX_BUF_BYTE(8) <= "0";
                `UART_TX_BUF_BYTE(9) <= "x"; `UART_TX_BUF_BYTE(10) <= "0"; `UART_TX_BUF_BYTE(11) <= "0";
                `UART_TX_BUF_BYTE(12) <= "0"; `UART_TX_BUF_BYTE(13) <= "0"; `UART_TX_BUF_BYTE(14) <= "0";
                `UART_TX_BUF_BYTE(15) <= "0"; `UART_TX_BUF_BYTE(16) <= "1"; `UART_TX_BUF_BYTE(17) <= "0";
                `UART_TX_BUF_BYTE(18) <= ":"; `UART_TX_BUF_BYTE(19) <= " ";
                i_demo_system_state <= eSRAM_DEMO_READ;
            end

            eSRAM_DEMO_READ:                                                   begin
                if (~(ram_valid && ram_ready)) begin
                    ram_valid <= 1'b1;
                end
                ram_addr  <= SRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wstrb <= 4'h0;
                if (ram_valid && ram_ready) begin
                    if (demo_word_base < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base) <= ram_rdata[31:24];
                        if (ram_rdata[31:24] != version_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd1) <= ram_rdata[23:16];
                        if (ram_rdata[23:16] != version_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd2) <= ram_rdata[15:8];
                        if (ram_rdata[15:8] != version_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd3) <= ram_rdata[7:0];
                        if (ram_rdata[7:0] != version_byte(demo_word_base + 7'd3)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_idx + 5'd1 == DEMO_WORDS) begin
                        i_demo_system_state <= eSRAM_DEMO_PRINT_READ;
                    end else begin
                        demo_word_idx       <= demo_word_idx + 5'd1;
                        i_demo_system_state <= eSRAM_DEMO_READ_GAP;
                    end
                end
            end

            eSRAM_DEMO_READ_GAP:                                               begin
                i_demo_system_state <= eSRAM_DEMO_READ;
            end

            eSRAM_DEMO_PRINT_READ:                                             begin
                `UART_TX_BUF_BYTE(20 + DEMO_LEN) <= 8'h0D;
                `UART_TX_BUF_BYTE(21 + DEMO_LEN) <= 8'h0A;
                i_uart_tx_buf_count <= SRAM_DEMO_LINE_LEN;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= eSRAM_DEMO_PRINT_RESULT;
                i_demo_system_state <= ePRINT_BUF;
            end

            eSRAM_DEMO_PRINT_RESULT:                                           begin
                `UART_TX_BUF_BYTE(0) <= "S"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "d";
                `UART_TX_BUF_BYTE(6) <= "e"; `UART_TX_BUF_BYTE(7) <= "m"; `UART_TX_BUF_BYTE(8) <= "o";
                `UART_TX_BUF_BYTE(9) <= "."; `UART_TX_BUF_BYTE(10) <= "."; `UART_TX_BUF_BYTE(11) <= ".";
                `UART_TX_BUF_BYTE(12) <= " ";
                if (demo_pass) begin
                    `UART_TX_BUF_BYTE(13) <= "p"; `UART_TX_BUF_BYTE(14) <= "a";
                    `UART_TX_BUF_BYTE(15) <= "s"; `UART_TX_BUF_BYTE(16) <= "s";
                end else begin
                    `UART_TX_BUF_BYTE(13) <= "F"; `UART_TX_BUF_BYTE(14) <= "A";
                    `UART_TX_BUF_BYTE(15) <= "I"; `UART_TX_BUF_BYTE(16) <= "L";
                end
                `UART_TX_BUF_BYTE(17) <= 8'h0D;
                `UART_TX_BUF_BYTE(18) <= 8'h0A;
                i_uart_tx_buf_count <= 7'd19;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_DEMO_WRITE_PREP:                                             begin
                demo_word_idx       <= 5'd0;
                demo_pass           <= 1'b1;
                i_demo_system_state <= eHRAM_DEMO_WRITE;
            end

            eHRAM_DEMO_WRITE:                                                  begin
                ram_valid <= 1'b1;
                ram_addr  <= HRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wdata <= version_word(demo_word_idx);
                ram_wstrb <= 4'hF;
                if (ram_valid && ram_ready) begin
                    if (demo_word_idx + 5'd1 == DEMO_WORDS) begin
                        i_demo_system_state <= eHRAM_DEMO_PRINT_WRITE;
                    end else begin
                        demo_word_idx       <= demo_word_idx + 5'd1;
                        i_demo_system_state <= eHRAM_DEMO_WRITE_GAP;
                    end
                end
            end

            eHRAM_DEMO_WRITE_GAP:                                              begin
                i_demo_system_state <= eHRAM_DEMO_WRITE;
            end

            eHRAM_DEMO_PRINT_WRITE:                                            begin
                `UART_TX_BUF_BYTE(0) <= "H"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "W";
                `UART_TX_BUF_BYTE(6) <= " "; `UART_TX_BUF_BYTE(7) <= "@"; `UART_TX_BUF_BYTE(8) <= "0";
                `UART_TX_BUF_BYTE(9) <= "x"; `UART_TX_BUF_BYTE(10) <= "0"; `UART_TX_BUF_BYTE(11) <= "0";
                `UART_TX_BUF_BYTE(12) <= "0"; `UART_TX_BUF_BYTE(13) <= "0"; `UART_TX_BUF_BYTE(14) <= "8";
                `UART_TX_BUF_BYTE(15) <= "0"; `UART_TX_BUF_BYTE(16) <= "1"; `UART_TX_BUF_BYTE(17) <= "0";
                `UART_TX_BUF_BYTE(18) <= ":"; `UART_TX_BUF_BYTE(19) <= " ";
                for (demo_i = 0; demo_i < DEMO_LEN; demo_i = demo_i + 1) begin
                    `UART_TX_BUF_BYTE(20 + demo_i) <= version_byte(demo_i[6:0]);
                end
                `UART_TX_BUF_BYTE(20 + DEMO_LEN) <= 8'h0D;
                `UART_TX_BUF_BYTE(21 + DEMO_LEN) <= 8'h0A;
                i_uart_tx_buf_count <= SRAM_DEMO_LINE_LEN;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= eHRAM_DEMO_READ_PREP;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                `UART_TX_BUF_BYTE(0) <= "H"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "R";
                `UART_TX_BUF_BYTE(6) <= " "; `UART_TX_BUF_BYTE(7) <= "@"; `UART_TX_BUF_BYTE(8) <= "0";
                `UART_TX_BUF_BYTE(9) <= "x"; `UART_TX_BUF_BYTE(10) <= "0"; `UART_TX_BUF_BYTE(11) <= "0";
                `UART_TX_BUF_BYTE(12) <= "0"; `UART_TX_BUF_BYTE(13) <= "0"; `UART_TX_BUF_BYTE(14) <= "8";
                `UART_TX_BUF_BYTE(15) <= "0"; `UART_TX_BUF_BYTE(16) <= "1"; `UART_TX_BUF_BYTE(17) <= "0";
                `UART_TX_BUF_BYTE(18) <= ":"; `UART_TX_BUF_BYTE(19) <= " ";
                i_demo_system_state <= eHRAM_DEMO_READ;
            end

            eHRAM_DEMO_READ:                                                   begin
                if (~(ram_valid && ram_ready)) begin
                    ram_valid <= 1'b1;
                end
                ram_addr  <= HRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wstrb <= 4'h0;
                if (ram_valid && ram_ready) begin
                    if (demo_word_base < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base) <= ram_rdata[31:24];
                        if (ram_rdata[31:24] != version_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd1) <= ram_rdata[23:16];
                        if (ram_rdata[23:16] != version_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd2) <= ram_rdata[15:8];
                        if (ram_rdata[15:8] != version_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < DEMO_LEN) begin
                        `UART_TX_BUF_BYTE(20 + demo_word_base + 7'd3) <= ram_rdata[7:0];
                        if (ram_rdata[7:0] != version_byte(demo_word_base + 7'd3)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_idx + 5'd1 == DEMO_WORDS) begin
                        i_demo_system_state <= eHRAM_DEMO_PRINT_READ;
                    end else begin
                        demo_word_idx       <= demo_word_idx + 5'd1;
                        i_demo_system_state <= eHRAM_DEMO_READ_GAP;
                    end
                end
            end

            eHRAM_DEMO_READ_GAP:                                               begin
                i_demo_system_state <= eHRAM_DEMO_READ;
            end

            eHRAM_DEMO_PRINT_READ:                                             begin
                `UART_TX_BUF_BYTE(20 + DEMO_LEN) <= 8'h0D;
                `UART_TX_BUF_BYTE(21 + DEMO_LEN) <= 8'h0A;
                i_uart_tx_buf_count <= SRAM_DEMO_LINE_LEN;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= eHRAM_DEMO_PRINT_RESULT;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_DEMO_PRINT_RESULT:                                           begin
                `UART_TX_BUF_BYTE(0) <= "H"; `UART_TX_BUF_BYTE(1) <= "R"; `UART_TX_BUF_BYTE(2) <= "A";
                `UART_TX_BUF_BYTE(3) <= "M"; `UART_TX_BUF_BYTE(4) <= " "; `UART_TX_BUF_BYTE(5) <= "d";
                `UART_TX_BUF_BYTE(6) <= "e"; `UART_TX_BUF_BYTE(7) <= "m"; `UART_TX_BUF_BYTE(8) <= "o";
                `UART_TX_BUF_BYTE(9) <= "."; `UART_TX_BUF_BYTE(10) <= "."; `UART_TX_BUF_BYTE(11) <= ".";
                `UART_TX_BUF_BYTE(12) <= " ";
                if (demo_pass) begin
                    `UART_TX_BUF_BYTE(13) <= "p"; `UART_TX_BUF_BYTE(14) <= "a";
                    `UART_TX_BUF_BYTE(15) <= "s"; `UART_TX_BUF_BYTE(16) <= "s";
                end else begin
                    `UART_TX_BUF_BYTE(13) <= "F"; `UART_TX_BUF_BYTE(14) <= "A";
                    `UART_TX_BUF_BYTE(15) <= "I"; `UART_TX_BUF_BYTE(16) <= "L";
                end
                `UART_TX_BUF_BYTE(17) <= 8'h0D;
                `UART_TX_BUF_BYTE(18) <= 8'h0A;
                i_uart_tx_buf_count <= 7'd19;
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state  <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_WAIT:                                                         begin
                // HyperRAM controller needs ~160us after reset; 250us is safe margin.
                // The 1s startup delay already covers this, but keep the wait for
                // correctness if the board is reset without full power cycle.
                if (microsecond_tick) begin
                    hram_init_us <= hram_init_us + 8'd1;
                    if (hram_init_us == 8'd249) begin
                        i_demo_system_state <= eHRAM_WRITE;
                    end
                end
            end

            eHRAM_WRITE:                                                        begin
                ram_valid <= 1'b1;
                ram_addr  <= 32'h0000_8000;
                ram_wdata <= 32'hABCD_ABCD;
                ram_wstrb <= 4'hF;
                if (ram_ready) begin
                    i_demo_system_state <= eHRAM_READ;
                end
            end

            eHRAM_READ:                                                         begin
                ram_valid <= 1'b1;
                ram_addr  <= 32'h0000_8000;
                ram_wstrb <= 4'h0;
                if (ram_ready) begin
                    readback            <= ram_rdata;
                    i_demo_system_state <= eHRAM_COMPARE;
                end
            end

            eHRAM_COMPARE:                                                      begin
                // "Testing HyperRAM... "
                `UART_TX_BUF_BYTE(0) <= "T"; `UART_TX_BUF_BYTE(1) <= "e"; `UART_TX_BUF_BYTE(2) <= "s";
                `UART_TX_BUF_BYTE(3) <= "t"; `UART_TX_BUF_BYTE(4) <= "i"; `UART_TX_BUF_BYTE(5) <= "n";
                `UART_TX_BUF_BYTE(6) <= "g"; `UART_TX_BUF_BYTE(7) <= " "; `UART_TX_BUF_BYTE(8) <= "H";
                `UART_TX_BUF_BYTE(9) <= "y"; `UART_TX_BUF_BYTE(10) <= "p"; `UART_TX_BUF_BYTE(11) <= "e";
                `UART_TX_BUF_BYTE(12) <= "r"; `UART_TX_BUF_BYTE(13) <= "R"; `UART_TX_BUF_BYTE(14) <= "A";
                `UART_TX_BUF_BYTE(15) <= "M"; `UART_TX_BUF_BYTE(16) <= "."; `UART_TX_BUF_BYTE(17) <= ".";
                `UART_TX_BUF_BYTE(18) <= "."; `UART_TX_BUF_BYTE(19) <= " ";
                if (readback == 32'hABCD_ABCD) begin
                    `UART_TX_BUF_BYTE(20) <= "p"; `UART_TX_BUF_BYTE(21) <= "a";
                    `UART_TX_BUF_BYTE(22) <= "s"; `UART_TX_BUF_BYTE(23) <= "s";
                    `UART_TX_BUF_BYTE(24) <= 8'h0D; `UART_TX_BUF_BYTE(25) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd26;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    `UART_TX_BUF_BYTE(20) <= "F"; `UART_TX_BUF_BYTE(21) <= "A";
                    `UART_TX_BUF_BYTE(22) <= "I"; `UART_TX_BUF_BYTE(23) <= "L";
                    `UART_TX_BUF_BYTE(24) <= " "; `UART_TX_BUF_BYTE(25) <= "(";
                    `UART_TX_BUF_BYTE(26) <= "w"; `UART_TX_BUF_BYTE(27) <= "r";
                    `UART_TX_BUF_BYTE(28) <= "o"; `UART_TX_BUF_BYTE(29) <= "t";
                    `UART_TX_BUF_BYTE(30) <= "e"; `UART_TX_BUF_BYTE(31) <= " ";
                    `UART_TX_BUF_BYTE(32) <= "0"; `UART_TX_BUF_BYTE(33) <= "x";
                    `UART_TX_BUF_BYTE(34) <= "A"; `UART_TX_BUF_BYTE(35) <= "B";
                    `UART_TX_BUF_BYTE(36) <= "C"; `UART_TX_BUF_BYTE(37) <= "D";
                    `UART_TX_BUF_BYTE(38) <= "A"; `UART_TX_BUF_BYTE(39) <= "B";
                    `UART_TX_BUF_BYTE(40) <= "C"; `UART_TX_BUF_BYTE(41) <= "D";
                    `UART_TX_BUF_BYTE(42) <= " "; `UART_TX_BUF_BYTE(43) <= "r";
                    `UART_TX_BUF_BYTE(44) <= "e"; `UART_TX_BUF_BYTE(45) <= "a";
                    `UART_TX_BUF_BYTE(46) <= "d"; `UART_TX_BUF_BYTE(47) <= " ";
                    `UART_TX_BUF_BYTE(48) <= "0"; `UART_TX_BUF_BYTE(49) <= "x";
                    `UART_TX_BUF_BYTE(50) <= hex_nibble(readback[31:28]);
                    `UART_TX_BUF_BYTE(51) <= hex_nibble(readback[27:24]);
                    `UART_TX_BUF_BYTE(52) <= hex_nibble(readback[23:20]);
                    `UART_TX_BUF_BYTE(53) <= hex_nibble(readback[19:16]);
                    `UART_TX_BUF_BYTE(54) <= hex_nibble(readback[15:12]);
                    `UART_TX_BUF_BYTE(55) <= hex_nibble(readback[11:8]);
                    `UART_TX_BUF_BYTE(56) <= hex_nibble(readback[7:4]);
                    `UART_TX_BUF_BYTE(57) <= hex_nibble(readback[3:0]);
                    `UART_TX_BUF_BYTE(58) <= ")";
                    `UART_TX_BUF_BYTE(59) <= 8'h0D; `UART_TX_BUF_BYTE(60) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd61;
                end
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            eJEDEC_INIT_EN:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h0000_0000;  // config_en = 0 (cfg-mode)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_INIT_OE;
                end
            end

            eJEDEC_INIT_OE:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0010;
                flash_cfg_wdata <= 32'h0000_0100;  // oe = 4'b0001 (MOSI=out, MISO=in)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_INIT_CSB_HI;
                end
            end

            eJEDEC_INIT_CSB_HI:                                                 begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_INIT_CSB_LO;
                end
            end

            eJEDEC_INIT_CSB_LO:                                                 begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0000;  // CSB=0, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    jedec_bit_idx       <= 6'd0;
                    i_demo_system_state <= eJEDEC_BIT_LO;
                end
            end

            eJEDEC_BIT_LO:                                                      begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b0, 3'h0, jedec_mosi_bit};
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_BIT_HI;
                end
            end

            eJEDEC_BIT_HI:                                                      begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b1, 3'h0, jedec_mosi_bit};
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_BIT_CAP;
                end
            end

            eJEDEC_BIT_CAP:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0000;  // pure read
                if (flash_cfg_ready) begin
                    if (jedec_bit_idx >= 6'd8) begin
                        jedec_id_in <= {jedec_id_in[22:0], flash_cfg_rdata[1]};
                    end
                    if (jedec_bit_idx == 6'd31) begin
                        i_demo_system_state <= eJEDEC_END;
                    end else begin
                        jedec_bit_idx       <= jedec_bit_idx + 6'd1;
                        i_demo_system_state <= eJEDEC_BIT_LO;
                    end
                end
            end

            eJEDEC_END:                                                         begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_RESTORE;
                end
            end

            eJEDEC_RESTORE:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h8000_0000;  // config_en = 1 (XIP mode)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eJEDEC_COMPARE;
                end
            end

            eJEDEC_COMPARE:                                                     begin
                // "Testing Flash ID... "
                `UART_TX_BUF_BYTE(0) <= "T"; `UART_TX_BUF_BYTE(1) <= "e"; `UART_TX_BUF_BYTE(2) <= "s";
                `UART_TX_BUF_BYTE(3) <= "t"; `UART_TX_BUF_BYTE(4) <= "i"; `UART_TX_BUF_BYTE(5) <= "n";
                `UART_TX_BUF_BYTE(6) <= "g"; `UART_TX_BUF_BYTE(7) <= " "; `UART_TX_BUF_BYTE(8) <= "F";
                `UART_TX_BUF_BYTE(9) <= "l"; `UART_TX_BUF_BYTE(10) <= "a"; `UART_TX_BUF_BYTE(11) <= "s";
                `UART_TX_BUF_BYTE(12) <= "h"; `UART_TX_BUF_BYTE(13) <= " "; `UART_TX_BUF_BYTE(14) <= "I";
                `UART_TX_BUF_BYTE(15) <= "D"; `UART_TX_BUF_BYTE(16) <= "."; `UART_TX_BUF_BYTE(17) <= ".";
                `UART_TX_BUF_BYTE(18) <= "."; `UART_TX_BUF_BYTE(19) <= " ";
                if (jedec_id_in == EXPECTED_JEDEC_ID) begin
                    `UART_TX_BUF_BYTE(20) <= "p"; `UART_TX_BUF_BYTE(21) <= "a";
                    `UART_TX_BUF_BYTE(22) <= "s"; `UART_TX_BUF_BYTE(23) <= "s";
                    `UART_TX_BUF_BYTE(24) <= 8'h0D; `UART_TX_BUF_BYTE(25) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd26;
                end else begin
                    // "FAIL (read 0xXXXXXX expected 0xYYYYYY)\r\n"
                    `UART_TX_BUF_BYTE(20) <= "F"; `UART_TX_BUF_BYTE(21) <= "A";
                    `UART_TX_BUF_BYTE(22) <= "I"; `UART_TX_BUF_BYTE(23) <= "L";
                    `UART_TX_BUF_BYTE(24) <= " "; `UART_TX_BUF_BYTE(25) <= "(";
                    `UART_TX_BUF_BYTE(26) <= "r"; `UART_TX_BUF_BYTE(27) <= "e";
                    `UART_TX_BUF_BYTE(28) <= "a"; `UART_TX_BUF_BYTE(29) <= "d";
                    `UART_TX_BUF_BYTE(30) <= " "; `UART_TX_BUF_BYTE(31) <= "0";
                    `UART_TX_BUF_BYTE(32) <= "x";
                    `UART_TX_BUF_BYTE(33) <= hex_nibble(jedec_id_in[23:20]);
                    `UART_TX_BUF_BYTE(34) <= hex_nibble(jedec_id_in[19:16]);
                    `UART_TX_BUF_BYTE(35) <= hex_nibble(jedec_id_in[15:12]);
                    `UART_TX_BUF_BYTE(36) <= hex_nibble(jedec_id_in[11:8]);
                    `UART_TX_BUF_BYTE(37) <= hex_nibble(jedec_id_in[7:4]);
                    `UART_TX_BUF_BYTE(38) <= hex_nibble(jedec_id_in[3:0]);
                    `UART_TX_BUF_BYTE(39) <= " "; `UART_TX_BUF_BYTE(40) <= "e";
                    `UART_TX_BUF_BYTE(41) <= "x"; `UART_TX_BUF_BYTE(42) <= "p";
                    `UART_TX_BUF_BYTE(43) <= "e"; `UART_TX_BUF_BYTE(44) <= "c";
                    `UART_TX_BUF_BYTE(45) <= "t"; `UART_TX_BUF_BYTE(46) <= "e";
                    `UART_TX_BUF_BYTE(47) <= "d"; `UART_TX_BUF_BYTE(48) <= " ";
                    `UART_TX_BUF_BYTE(49) <= "0"; `UART_TX_BUF_BYTE(50) <= "x";
                    `UART_TX_BUF_BYTE(51) <= hex_nibble(EXPECTED_JEDEC_ID[23:20]);
                    `UART_TX_BUF_BYTE(52) <= hex_nibble(EXPECTED_JEDEC_ID[19:16]);
                    `UART_TX_BUF_BYTE(53) <= hex_nibble(EXPECTED_JEDEC_ID[15:12]);
                    `UART_TX_BUF_BYTE(54) <= hex_nibble(EXPECTED_JEDEC_ID[11:8]);
                    `UART_TX_BUF_BYTE(55) <= hex_nibble(EXPECTED_JEDEC_ID[7:4]);
                    `UART_TX_BUF_BYTE(56) <= hex_nibble(EXPECTED_JEDEC_ID[3:0]);
                    `UART_TX_BUF_BYTE(57) <= ")";
                    `UART_TX_BUF_BYTE(58) <= 8'h0D; `UART_TX_BUF_BYTE(59) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd60;
                end
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            eFW_INIT_EN:                                                        begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h0000_0000;  // config_en = 0 (cfg-mode)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_INIT_OE;
                end
            end

            eFW_INIT_OE:                                                        begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0010;
                flash_cfg_wdata <= 32'h0000_0100;  // oe = 4'b0001 (MOSI=out, MISO=in)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_INIT_CSB_HI;
                end
            end

            eFW_INIT_CSB_HI:                                                    begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_SETUP_WREN_ERASE;
                end
            end

            eFW_SETUP_WREN_ERASE:                                               begin
                fw_shift          <= {FLASH_CMD_WREN, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd8;
                fw_capture_status <= 1'b0;
                fw_next_state     <= eFW_SETUP_ERASE;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_SETUP_ERASE:                                                    begin
                fw_shift          <= {FLASH_CMD_ERASE, FLASH_TEST_ADDR, 32'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd32;
                fw_capture_status <= 1'b0;
                fw_next_state     <= eFW_SETUP_POLL_ERASE;
                fw_poll_ms        <= 10'd0;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_SETUP_POLL_ERASE:                                               begin
                fw_shift          <= {FLASH_CMD_RDSR, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd16;
                fw_status         <= 8'd0;
                fw_capture_status <= 1'b1;
                fw_next_state     <= eFW_CHECK_POLL_ERASE;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_CHECK_POLL_ERASE:                                               begin
                if (fw_status[0]) begin
                    if (millisecond_tick) begin
                        if (fw_poll_ms == FLASH_POLL_LIMIT) begin
                            readback            <= {24'd0, fw_status};
                            fw_next_state       <= eFW_COMPARE;
                            i_demo_system_state <= eFW_RESTORE;
                        end else begin
                            fw_poll_ms          <= fw_poll_ms + 10'd1;
                            i_demo_system_state <= eFW_SETUP_POLL_ERASE;
                        end
                    end
                end else begin
                    fw_poll_ms          <= 10'd0;
                    i_demo_system_state <= eFW_SETUP_WREN_PROGRAM;
                end
            end

            eFW_SETUP_WREN_PROGRAM:                                             begin
                fw_shift          <= {FLASH_CMD_WREN, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd8;
                fw_capture_status <= 1'b0;
                fw_next_state     <= eFW_SETUP_PROGRAM;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_SETUP_PROGRAM:                                                  begin
                fw_shift          <= {FLASH_CMD_PROGRAM, FLASH_TEST_ADDR,
                                      FLASH_TEST_DATA[7:0],
                                      FLASH_TEST_DATA[15:8],
                                      FLASH_TEST_DATA[23:16],
                                      FLASH_TEST_DATA[31:24]};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd64;
                fw_capture_status <= 1'b0;
                fw_next_state     <= eFW_SETUP_POLL_PROGRAM;
                fw_poll_ms        <= 10'd0;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_SETUP_POLL_PROGRAM:                                             begin
                fw_shift          <= {FLASH_CMD_RDSR, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd16;
                fw_status         <= 8'd0;
                fw_capture_status <= 1'b1;
                fw_next_state     <= eFW_CHECK_POLL_PROGRAM;
                i_demo_system_state <= eFW_SPI_CSB_LO;
            end

            eFW_CHECK_POLL_PROGRAM:                                             begin
                if (fw_status[0]) begin
                    if (millisecond_tick) begin
                        if (fw_poll_ms == FLASH_POLL_LIMIT) begin
                            readback            <= {24'd0, fw_status};
                            fw_next_state       <= eFW_COMPARE;
                            i_demo_system_state <= eFW_RESTORE;
                        end else begin
                            fw_poll_ms          <= fw_poll_ms + 10'd1;
                            i_demo_system_state <= eFW_SETUP_POLL_PROGRAM;
                        end
                    end
                end else begin
                    fw_next_state       <= eFW_XIP_READ;
                    i_demo_system_state <= eFW_RESTORE;
                end
            end

            eFW_SPI_CSB_LO:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0000;  // CSB=0, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_SPI_BIT_LO;
                end
            end

            eFW_SPI_BIT_LO:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b0, 3'h0, fw_shift[63]};
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_SPI_BIT_HI;
                end
            end

            eFW_SPI_BIT_HI:                                                     begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b1, 3'h0, fw_shift[63]};
                if (flash_cfg_ready) begin
                    i_demo_system_state <= eFW_SPI_BIT_CAP;
                end
            end

            eFW_SPI_BIT_CAP:                                                    begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0000;
                if (flash_cfg_ready) begin
                    if (fw_capture_status && fw_bit_idx >= 7'd8) begin
                        fw_status <= {fw_status[6:0], flash_cfg_rdata[1]};
                    end
                    fw_shift <= {fw_shift[62:0], 1'b0};
                    if (fw_bit_idx + 7'd1 == fw_bit_count) begin
                        i_demo_system_state <= eFW_SPI_END;
                    end else begin
                        fw_bit_idx          <= fw_bit_idx + 7'd1;
                        i_demo_system_state <= eFW_SPI_BIT_LO;
                    end
                end
            end

            eFW_SPI_END:                                                        begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    i_demo_system_state <= fw_next_state;
                end
            end

            eFW_RESTORE:                                                        begin
                flash_cfg_valid <= 1'b1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h8000_0000;  // config_en = 1 (XIP mode)
                if (flash_cfg_ready) begin
                    i_demo_system_state <= fw_next_state;
                end
            end

            eFW_XIP_READ:                                                       begin
                flash_xip_valid <= 1'b1;
                flash_xip_addr  <= {8'd0, FLASH_TEST_ADDR};
                flash_xip_wstrb <= 4'h0;
                if (flash_xip_ready) begin
                    readback            <= flash_xip_rdata;
                    i_demo_system_state <= eFW_COMPARE;
                end
            end

            eFW_COMPARE:                                                        begin
                // "Testing Flash W/R/V... "
                `UART_TX_BUF_BYTE(0) <= "T"; `UART_TX_BUF_BYTE(1) <= "e"; `UART_TX_BUF_BYTE(2) <= "s";
                `UART_TX_BUF_BYTE(3) <= "t"; `UART_TX_BUF_BYTE(4) <= "i"; `UART_TX_BUF_BYTE(5) <= "n";
                `UART_TX_BUF_BYTE(6) <= "g"; `UART_TX_BUF_BYTE(7) <= " "; `UART_TX_BUF_BYTE(8) <= "F";
                `UART_TX_BUF_BYTE(9) <= "l"; `UART_TX_BUF_BYTE(10) <= "a"; `UART_TX_BUF_BYTE(11) <= "s";
                `UART_TX_BUF_BYTE(12) <= "h"; `UART_TX_BUF_BYTE(13) <= " "; `UART_TX_BUF_BYTE(14) <= "W";
                `UART_TX_BUF_BYTE(15) <= "/"; `UART_TX_BUF_BYTE(16) <= "R"; `UART_TX_BUF_BYTE(17) <= "/";
                `UART_TX_BUF_BYTE(18) <= "V"; `UART_TX_BUF_BYTE(19) <= "."; `UART_TX_BUF_BYTE(20) <= ".";
                `UART_TX_BUF_BYTE(21) <= "."; `UART_TX_BUF_BYTE(22) <= " ";
                if (readback == FLASH_TEST_DATA) begin
                    `UART_TX_BUF_BYTE(23) <= "p"; `UART_TX_BUF_BYTE(24) <= "a";
                    `UART_TX_BUF_BYTE(25) <= "s"; `UART_TX_BUF_BYTE(26) <= "s";
                    `UART_TX_BUF_BYTE(27) <= 8'h0D; `UART_TX_BUF_BYTE(28) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd29;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    `UART_TX_BUF_BYTE(23) <= "F"; `UART_TX_BUF_BYTE(24) <= "A";
                    `UART_TX_BUF_BYTE(25) <= "I"; `UART_TX_BUF_BYTE(26) <= "L";
                    `UART_TX_BUF_BYTE(27) <= " "; `UART_TX_BUF_BYTE(28) <= "(";
                    `UART_TX_BUF_BYTE(29) <= "w"; `UART_TX_BUF_BYTE(30) <= "r";
                    `UART_TX_BUF_BYTE(31) <= "o"; `UART_TX_BUF_BYTE(32) <= "t";
                    `UART_TX_BUF_BYTE(33) <= "e"; `UART_TX_BUF_BYTE(34) <= " ";
                    `UART_TX_BUF_BYTE(35) <= "0"; `UART_TX_BUF_BYTE(36) <= "x";
                    `UART_TX_BUF_BYTE(37) <= "A"; `UART_TX_BUF_BYTE(38) <= "B";
                    `UART_TX_BUF_BYTE(39) <= "C"; `UART_TX_BUF_BYTE(40) <= "D";
                    `UART_TX_BUF_BYTE(41) <= "A"; `UART_TX_BUF_BYTE(42) <= "B";
                    `UART_TX_BUF_BYTE(43) <= "C"; `UART_TX_BUF_BYTE(44) <= "D";
                    `UART_TX_BUF_BYTE(45) <= " "; `UART_TX_BUF_BYTE(46) <= "r";
                    `UART_TX_BUF_BYTE(47) <= "e"; `UART_TX_BUF_BYTE(48) <= "a";
                    `UART_TX_BUF_BYTE(49) <= "d"; `UART_TX_BUF_BYTE(50) <= " ";
                    `UART_TX_BUF_BYTE(51) <= "0"; `UART_TX_BUF_BYTE(52) <= "x";
                    `UART_TX_BUF_BYTE(53) <= hex_nibble(readback[31:28]);
                    `UART_TX_BUF_BYTE(54) <= hex_nibble(readback[27:24]);
                    `UART_TX_BUF_BYTE(55) <= hex_nibble(readback[23:20]);
                    `UART_TX_BUF_BYTE(56) <= hex_nibble(readback[19:16]);
                    `UART_TX_BUF_BYTE(57) <= hex_nibble(readback[15:12]);
                    `UART_TX_BUF_BYTE(58) <= hex_nibble(readback[11:8]);
                    `UART_TX_BUF_BYTE(59) <= hex_nibble(readback[7:4]);
                    `UART_TX_BUF_BYTE(60) <= hex_nibble(readback[3:0]);
                    `UART_TX_BUF_BYTE(61) <= ")";
                    `UART_TX_BUF_BYTE(62) <= 8'h0D; `UART_TX_BUF_BYTE(63) <= 8'h0A;
                    i_uart_tx_buf_count <= 7'd64;
                end
                i_uart_tx_buf_counter <= 7'd0;
                print_next_state <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            ePRINT_BUF:                                                         begin
                if (i_uart_tx_buf_count == 7'd0) begin
                    i_demo_system_state <= print_next_state;
                end else begin
                    uart_tx_valid   <= 1'b1;
                    uart_tx_data    <= i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                                        UART_TX_BUF_BITS-8];

                    if (uart_tx_valid && uart_tx_ready) begin
                        if (i_uart_tx_buf_counter + 7'd1 == i_uart_tx_buf_count) begin
                            uart_tx_valid       <= 1'b0;
                            i_demo_system_state <= print_next_state;
                        end else begin
                            i_uart_tx_buf_counter   <= i_uart_tx_buf_counter + 7'd1;
                            i_uart_tx_buf           <= i_uart_tx_buf << 8;
                            uart_tx_data            <= i_uart_tx_buf[UART_TX_BUF_BITS-9 -: 8];
                        end
                    end
                end
            end

            eIDLE:                                                              begin
                i_demo_system_state <= eIDLE;
            end
        endcase

        // NOTE: reduce control sets...
        if (sysclk_resetn == 1'b0) begin
            uart_tx_valid       <= 1'b0;
            uart_rx_ready       <= 1'b0;
            print_next_state    <= ePREP_NEXT_UART_STARTUP_MSG;
            i_uart_tx_buf       <= 0;
            i_uart_tx_buf_count <= 0;
            i_uart_tx_buf_counter <= 0;

            i_demo_system_state <= eRESET;
        end
    end


    assign io[15:0]     = 'z;
    assign io[31:16]    = i_io[31:16];

    always @(posedge sysclk) begin
        i_io[31:16] <= io[15:0];

        if (sysclk_resetn == 1'b0) begin
            i_io <= 0;
        end
    end

endmodule

`undef UART_TX_BUF_BYTE
