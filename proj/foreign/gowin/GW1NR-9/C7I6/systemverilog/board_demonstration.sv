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
    parameter int VERSION_LEN = 0,
    parameter int TEST_STRING_CHARS = 32,
    parameter reg [(8*TEST_STRING_CHARS)-1:0] TEST_STRING = "Default SRAM/HRAM Test Data",
    parameter int TEST_STRING_LEN = 27
) (
    input               sysclk,
    input               sysclk_resetn,

    input               microsecond_tick,
    input               millisecond_tick,
    input               second_tick,

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
localparam [7:0]                        UART_CR             = 8'h0D;
localparam [7:0]                        UART_LF             = 8'h0A;
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
        eFW_DEMO_PRINT_WRITE,
        eFW_DEMO_READ_PREP,
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
        eDEMO_FLASH,
        eNONE
    } tSTARTUP_TASKS;

    typedef enum {
        eFW_OP_TEST,
        eFW_OP_DEMO
    } tFLASH_OPERATION;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    tSTARTUP_TASKS                                      i_next_startup_task;
    tDEMONSTRATE_SYSTEM_STATE                           i_demo_system_state;
    reg                         [UART_TX_BUF_BITS-1:0]  i_uart_tx_buf;
    reg                         [6:0]                   i_uart_tx_buf_counter;
    reg                         [6:0]                   i_uart_tx_buf_count;

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
    localparam [31:0] FLASH_TEST_DATA   = 32'hA5C3_6D12;
    localparam [23:0] FLASH_DEMO_ADDR   = 24'h01_0010;
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
    tFLASH_OPERATION                                    fw_operation;

    localparam int VERSION_SAFE_LEN = (VERSION_LEN > VERSION_CHARS) ? VERSION_CHARS : VERSION_LEN;
    localparam int TEST_LEN         = (TEST_STRING_LEN > TEST_STRING_CHARS) ? TEST_STRING_CHARS : TEST_STRING_LEN;
    localparam int TEST_WORDS       = (TEST_LEN + 3) / 4;
    localparam int DEMO_LINE_LEN    = 20 + TEST_LEN + 2;
    localparam int FLASH_DEMO_LINE_LEN = 21 + TEST_LEN + 2;
    localparam [6:0] TEST_LEN_7           = TEST_LEN;
    localparam [6:0] DEMO_LINE_LEN_7      = DEMO_LINE_LEN;
    localparam [6:0] FLASH_DEMO_LINE_LEN_7 = FLASH_DEMO_LINE_LEN;
    localparam [6:0] SRAM_DEMO_PREFIX_LEN = 7'd20;
    localparam [6:0] HRAM_DEMO_PREFIX_LEN = 7'd20;
    localparam [6:0] FLASH_DEMO_PREFIX_LEN = 7'd21;

    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_BIST_PASS_MSG =
        {"Testing SRAM... pass", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-22){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_BIST_FAIL_MSG =
        {"Testing SRAM... FAIL (wrote 0xABCDABCD read 0x00000000)", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-57){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_DEMO_WRITE_PREFIX =
        {"SRAM W @0x00000010: ", {(UART_TX_BUF_CHARS-20){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_DEMO_READ_PREFIX =
        {"SRAM R @0x00000010: ", {(UART_TX_BUF_CHARS-20){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_DEMO_PASS_MSG =
        {"SRAM demo... pass", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-19){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] SRAM_DEMO_FAIL_MSG =
        {"SRAM demo... FAIL", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-19){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_BIST_PASS_MSG =
        {"Testing HyperRAM... pass", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-26){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_BIST_FAIL_MSG =
        {"Testing HyperRAM... FAIL (wrote 0xABCDABCD read 0x00000000)", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-61){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_DEMO_WRITE_PREFIX =
        {"HRAM W @0x00008010: ", {(UART_TX_BUF_CHARS-20){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_DEMO_READ_PREFIX =
        {"HRAM R @0x00008010: ", {(UART_TX_BUF_CHARS-20){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_DEMO_PASS_MSG =
        {"HRAM demo... pass", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-19){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] HRAM_DEMO_FAIL_MSG =
        {"HRAM demo... FAIL", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-19){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] FLASH_TEST_PASS_MSG =
        {"Testing Flash W/R/V... pass", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-29){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] FLASH_TEST_FAIL_MSG =
        {"Testing Flash W/R/V... FAIL", UART_CR, UART_LF,
         {(UART_TX_BUF_CHARS-29){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] FLASH_DEMO_WRITE_PREFIX =
        {"FLASH W @0x00010010: ", {(UART_TX_BUF_CHARS-21){8'h00}}};
    localparam reg [UART_TX_BUF_BITS-1:0] FLASH_DEMO_READ_PREFIX =
        {"FLASH R @0x00010010: ", {(UART_TX_BUF_CHARS-21){8'h00}}};

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
            if (idx < VERSION_SAFE_LEN) begin
                version_byte = (VERSION >> ((VERSION_SAFE_LEN - idx - 1) * 8)) & 8'hFF;
            end else begin
                version_byte = 8'h00;
            end
        end
    endfunction

    function automatic [7:0] test_byte;
        input [6:0] idx;
        begin
            if (idx < TEST_LEN) begin
                test_byte = (TEST_STRING >> ((TEST_LEN - idx - 1) * 8)) & 8'hFF;
            end else begin
                test_byte = 8'h00;
            end
        end
    endfunction

    function automatic [31:0] test_word;
        input [4:0] word_idx;
        reg [6:0] base;
        begin
            base = {word_idx, 2'b00};
            test_word = {
                test_byte(base),
                test_byte(base + 7'd1),
                test_byte(base + 7'd2),
                test_byte(base + 7'd3)
            };
        end
    endfunction

    function automatic [UART_TX_BUF_BITS-1:0] uart_tx_set_byte;
        input [UART_TX_BUF_BITS-1:0] tx_buf;
        input [6:0] idx;
        input [7:0] value;
        begin
            uart_tx_set_byte = tx_buf;
            uart_tx_set_byte[UART_TX_BUF_BITS-1 - (idx * 8) -: 8] = value;
        end
    endfunction

    function automatic [UART_TX_BUF_BITS-1:0] uart_tx_set_hex32;
        input [UART_TX_BUF_BITS-1:0] tx_buf;
        input [6:0] idx;
        input [31:0] value;
        reg [UART_TX_BUF_BITS-1:0] next_buf;
        begin
            next_buf = tx_buf;
            next_buf = uart_tx_set_byte(next_buf, idx,        hex_nibble(value[31:28]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd1, hex_nibble(value[27:24]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd2, hex_nibble(value[23:20]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd3, hex_nibble(value[19:16]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd4, hex_nibble(value[15:12]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd5, hex_nibble(value[11:8]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd6, hex_nibble(value[7:4]));
            next_buf = uart_tx_set_byte(next_buf, idx + 7'd7, hex_nibble(value[3:0]));
            uart_tx_set_hex32 = next_buf;
        end
    endfunction

    function automatic [UART_TX_BUF_BITS-1:0] uart_tx_set_test_string;
        input [UART_TX_BUF_BITS-1:0] tx_buf;
        input [6:0] idx;
        integer test_i;
        reg [UART_TX_BUF_BITS-1:0] next_buf;
        begin
            next_buf = tx_buf;
            for (test_i = 0; test_i < TEST_LEN; test_i = test_i + 1) begin
                next_buf = uart_tx_set_byte(next_buf, idx + test_i[6:0], test_byte(test_i[6:0]));
            end
            uart_tx_set_test_string = next_buf;
        end
    endfunction

    function automatic [UART_TX_BUF_BITS-1:0] uart_tx_set_word_bytes;
        input [UART_TX_BUF_BITS-1:0] tx_buf;
        input [6:0] idx;
        input [6:0] word_base;
        input [31:0] word_data;
        reg [UART_TX_BUF_BITS-1:0] next_buf;
        begin
            next_buf = tx_buf;
            if (word_base < TEST_LEN) begin
                next_buf = uart_tx_set_byte(next_buf, idx + word_base, word_data[31:24]);
            end
            if (word_base + 7'd1 < TEST_LEN) begin
                next_buf = uart_tx_set_byte(next_buf, idx + word_base + 7'd1, word_data[23:16]);
            end
            if (word_base + 7'd2 < TEST_LEN) begin
                next_buf = uart_tx_set_byte(next_buf, idx + word_base + 7'd2, word_data[15:8]);
            end
            if (word_base + 7'd3 < TEST_LEN) begin
                next_buf = uart_tx_set_byte(next_buf, idx + word_base + 7'd3, word_data[7:0]);
            end
            uart_tx_set_word_bytes = next_buf;
        end
    endfunction

    task automatic set_uart_tx_buf;
        input [UART_TX_BUF_BITS-1:0] tx_buf;
        input [6:0] len;
        begin
            i_uart_tx_buf         <= tx_buf;
            i_uart_tx_buf_count   <= len;
            i_uart_tx_buf_counter <= 7'd0;
        end
    endtask

    task automatic start_uart_tx_buf_print;
        input [6:0] len;
        input tDEMONSTRATE_SYSTEM_STATE next_state;
        begin
            i_uart_tx_buf_count   <= len;
            i_uart_tx_buf_counter <= 7'd0;
            print_next_state      <= next_state;
            i_demo_system_state   <= ePRINT_BUF;
        end
    endtask

    function automatic [23:0] flash_demo_addr;
        input [4:0] word_idx;
        begin
            flash_demo_addr = FLASH_DEMO_ADDR + {17'd0, word_idx, 2'b00};
        end
    endfunction

    function automatic [63:0] flash_program_shift;
        input [23:0] flash_addr;
        input [31:0] word_data;
        begin
            flash_program_shift = {FLASH_CMD_PROGRAM, flash_addr,
                                   word_data[7:0], word_data[15:8],
                                   word_data[23:16], word_data[31:24]};
        end
    endfunction

    function automatic [63:0] flash_demo_program_shift;
        input [4:0] word_idx;
        reg [6:0] base;
        begin
            base = {word_idx, 2'b00};
            flash_demo_program_shift = {FLASH_CMD_PROGRAM, flash_demo_addr(word_idx),
                                        test_byte(base + 7'd3),
                                        test_byte(base + 7'd2),
                                        test_byte(base + 7'd1),
                                        test_byte(base)};
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
                    for (demo_i = 0; demo_i < VERSION_SAFE_LEN; demo_i = demo_i + 1) begin
                        `UART_TX_BUF_BYTE(demo_i) <= version_byte(demo_i[6:0]);
                    end
                    i_uart_tx_buf_count <= VERSION_SAFE_LEN[6:0];
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
                    i_next_startup_task <= eDEMO_FLASH;
                    demo_word_idx       <= 5'd0;
                    demo_pass           <= 1'b1;
                    fw_operation        <= eFW_OP_TEST;
                    fw_poll_ms          <= 10'd0;
                    i_demo_system_state <= eFW_INIT_EN;
                end

                if (i_next_startup_task == eDEMO_FLASH) begin
                    i_next_startup_task <= eNONE;
                    demo_word_idx       <= 5'd0;
                    fw_operation        <= eFW_OP_DEMO;
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
                if (readback == 32'hABCD_ABCD) begin
                    set_uart_tx_buf(SRAM_BIST_PASS_MSG, 7'd22);
                    start_uart_tx_buf_print(7'd22, ePREP_NEXT_UART_STARTUP_MSG);
                end else begin
                    set_uart_tx_buf(uart_tx_set_hex32(SRAM_BIST_FAIL_MSG, 7'd46, readback), 7'd57);
                    start_uart_tx_buf_print(7'd57, ePREP_NEXT_UART_STARTUP_MSG);
                end
            end

            eSRAM_DEMO_WRITE_PREP:                                             begin
                demo_word_idx       <= 5'd0;
                demo_pass           <= 1'b1;
                i_demo_system_state <= eSRAM_DEMO_WRITE;
            end

            eSRAM_DEMO_WRITE:                                                  begin
                ram_valid <= 1'b1;
                ram_addr  <= SRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wdata <= test_word(demo_word_idx);
                ram_wstrb <= 4'hF;
                if (ram_valid && ram_ready) begin
                    if (demo_word_idx + 5'd1 == TEST_WORDS) begin
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
                set_uart_tx_buf(
                    uart_tx_set_byte(
                        uart_tx_set_byte(
                            uart_tx_set_test_string(SRAM_DEMO_WRITE_PREFIX, SRAM_DEMO_PREFIX_LEN),
                            SRAM_DEMO_PREFIX_LEN + TEST_LEN_7,
                            UART_CR),
                        SRAM_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                        UART_LF),
                    DEMO_LINE_LEN_7);
                start_uart_tx_buf_print(DEMO_LINE_LEN_7, eSRAM_DEMO_READ_PREP);
            end

            eSRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                i_uart_tx_buf       <= SRAM_DEMO_READ_PREFIX;
                i_demo_system_state <= eSRAM_DEMO_READ;
            end

            eSRAM_DEMO_READ:                                                   begin
                if (~(ram_valid && ram_ready)) begin
                    ram_valid <= 1'b1;
                end
                ram_addr  <= SRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wstrb <= 4'h0;
                if (ram_valid && ram_ready) begin
                    i_uart_tx_buf <= uart_tx_set_word_bytes(i_uart_tx_buf, SRAM_DEMO_PREFIX_LEN,
                                                            demo_word_base, ram_rdata);
                    if (demo_word_base < TEST_LEN) begin
                        if (ram_rdata[31:24] != test_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < TEST_LEN) begin
                        if (ram_rdata[23:16] != test_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < TEST_LEN) begin
                        if (ram_rdata[15:8] != test_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < TEST_LEN) begin
                        if (ram_rdata[7:0] != test_byte(demo_word_base + 7'd3)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_idx + 5'd1 == TEST_WORDS) begin
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
                i_uart_tx_buf <= uart_tx_set_byte(
                    uart_tx_set_byte(i_uart_tx_buf, SRAM_DEMO_PREFIX_LEN + TEST_LEN_7, UART_CR),
                    SRAM_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                    UART_LF);
                start_uart_tx_buf_print(DEMO_LINE_LEN_7, eSRAM_DEMO_PRINT_RESULT);
            end

            eSRAM_DEMO_PRINT_RESULT:                                           begin
                if (demo_pass) begin
                    set_uart_tx_buf(SRAM_DEMO_PASS_MSG, 7'd19);
                end else begin
                    set_uart_tx_buf(SRAM_DEMO_FAIL_MSG, 7'd19);
                end
                start_uart_tx_buf_print(7'd19, ePREP_NEXT_UART_STARTUP_MSG);
            end

            eHRAM_DEMO_WRITE_PREP:                                             begin
                demo_word_idx       <= 5'd0;
                demo_pass           <= 1'b1;
                i_demo_system_state <= eHRAM_DEMO_WRITE;
            end

            eHRAM_DEMO_WRITE:                                                  begin
                ram_valid <= 1'b1;
                ram_addr  <= HRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wdata <= test_word(demo_word_idx);
                ram_wstrb <= 4'hF;
                if (ram_valid && ram_ready) begin
                    if (demo_word_idx + 5'd1 == TEST_WORDS) begin
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
                set_uart_tx_buf(
                    uart_tx_set_byte(
                        uart_tx_set_byte(
                            uart_tx_set_test_string(HRAM_DEMO_WRITE_PREFIX, HRAM_DEMO_PREFIX_LEN),
                            HRAM_DEMO_PREFIX_LEN + TEST_LEN_7,
                            UART_CR),
                        HRAM_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                        UART_LF),
                    DEMO_LINE_LEN_7);
                start_uart_tx_buf_print(DEMO_LINE_LEN_7, eHRAM_DEMO_READ_PREP);
            end

            eHRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                i_uart_tx_buf       <= HRAM_DEMO_READ_PREFIX;
                i_demo_system_state <= eHRAM_DEMO_READ;
            end

            eHRAM_DEMO_READ:                                                   begin
                if (~(ram_valid && ram_ready)) begin
                    ram_valid <= 1'b1;
                end
                ram_addr  <= HRAM_DEMO_ADDR + {25'd0, demo_word_base};
                ram_wstrb <= 4'h0;
                if (ram_valid && ram_ready) begin
                    i_uart_tx_buf <= uart_tx_set_word_bytes(i_uart_tx_buf, HRAM_DEMO_PREFIX_LEN,
                                                            demo_word_base, ram_rdata);
                    if (demo_word_base < TEST_LEN) begin
                        if (ram_rdata[31:24] != test_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < TEST_LEN) begin
                        if (ram_rdata[23:16] != test_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < TEST_LEN) begin
                        if (ram_rdata[15:8] != test_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < TEST_LEN) begin
                        if (ram_rdata[7:0] != test_byte(demo_word_base + 7'd3)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_idx + 5'd1 == TEST_WORDS) begin
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
                i_uart_tx_buf <= uart_tx_set_byte(
                    uart_tx_set_byte(i_uart_tx_buf, HRAM_DEMO_PREFIX_LEN + TEST_LEN_7, UART_CR),
                    HRAM_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                    UART_LF);
                start_uart_tx_buf_print(DEMO_LINE_LEN_7, eHRAM_DEMO_PRINT_RESULT);
            end

            eHRAM_DEMO_PRINT_RESULT:                                           begin
                if (demo_pass) begin
                    set_uart_tx_buf(HRAM_DEMO_PASS_MSG, 7'd19);
                end else begin
                    set_uart_tx_buf(HRAM_DEMO_FAIL_MSG, 7'd19);
                end
                start_uart_tx_buf_print(7'd19, ePREP_NEXT_UART_STARTUP_MSG);
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
                if (readback == 32'hABCD_ABCD) begin
                    set_uart_tx_buf(HRAM_BIST_PASS_MSG, 7'd26);
                    start_uart_tx_buf_print(7'd26, ePREP_NEXT_UART_STARTUP_MSG);
                end else begin
                    set_uart_tx_buf(uart_tx_set_hex32(HRAM_BIST_FAIL_MSG, 7'd50, readback), 7'd61);
                    start_uart_tx_buf_print(7'd61, ePREP_NEXT_UART_STARTUP_MSG);
                end
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
                    if (fw_operation == eFW_OP_TEST) begin
                        i_demo_system_state <= eFW_SETUP_WREN_ERASE;
                    end else begin
                        // Re-erase before the demo so reruns do not program
                        // the custom string over stale zero bits.
                        i_demo_system_state <= eFW_SETUP_WREN_ERASE;
                    end
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
                fw_shift          <= {FLASH_CMD_ERASE,
                                      (fw_operation == eFW_OP_TEST) ? FLASH_TEST_ADDR : FLASH_DEMO_ADDR,
                                      32'd0};
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
                if (fw_operation == eFW_OP_TEST) begin
                    fw_shift      <= flash_program_shift(FLASH_TEST_ADDR, FLASH_TEST_DATA);
                end else begin
                    fw_shift      <= flash_demo_program_shift(demo_word_idx);
                end
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
                    if (fw_operation == eFW_OP_TEST) begin
                        fw_next_state       <= eFW_XIP_READ;
                        i_demo_system_state <= eFW_RESTORE;
                    end else begin
                        if (demo_word_idx + 5'd1 == TEST_WORDS) begin
                            i_demo_system_state <= eFW_DEMO_PRINT_WRITE;
                        end else begin
                            demo_word_idx       <= demo_word_idx + 5'd1;
                            i_demo_system_state <= eFW_SETUP_WREN_PROGRAM;
                        end
                    end
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
                if (fw_operation == eFW_OP_TEST) begin
                    flash_xip_addr <= {8'd0, FLASH_TEST_ADDR};
                end else begin
                    flash_xip_addr <= {8'd0, flash_demo_addr(demo_word_idx)};
                end
                flash_xip_wstrb <= 4'h0;
                if (flash_xip_ready) begin
                    readback            <= flash_xip_rdata;
                    i_demo_system_state <= eFW_COMPARE;
                end
            end

            eFW_COMPARE:                                                        begin
                if (fw_operation == eFW_OP_TEST) begin
                    if (readback == FLASH_TEST_DATA) begin
                        set_uart_tx_buf(FLASH_TEST_PASS_MSG, 7'd29);
                    end else begin
                        set_uart_tx_buf(FLASH_TEST_FAIL_MSG, 7'd29);
                    end
                    start_uart_tx_buf_print(7'd29, ePREP_NEXT_UART_STARTUP_MSG);
                end else begin
                    if (demo_word_idx + 5'd1 == TEST_WORDS) begin
                        i_uart_tx_buf <= uart_tx_set_byte(
                            uart_tx_set_byte(
                                uart_tx_set_word_bytes(i_uart_tx_buf, FLASH_DEMO_PREFIX_LEN,
                                                       demo_word_base, readback),
                                FLASH_DEMO_PREFIX_LEN + TEST_LEN_7,
                                UART_CR),
                            FLASH_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                            UART_LF);
                        start_uart_tx_buf_print(FLASH_DEMO_LINE_LEN_7, ePREP_NEXT_UART_STARTUP_MSG);
                    end else begin
                        i_uart_tx_buf <= uart_tx_set_word_bytes(i_uart_tx_buf, FLASH_DEMO_PREFIX_LEN,
                                                                demo_word_base, readback);
                        demo_word_idx       <= demo_word_idx + 5'd1;
                        i_demo_system_state <= eFW_XIP_READ;
                    end
                end
            end

            eFW_DEMO_PRINT_WRITE:                                               begin
                set_uart_tx_buf(
                    uart_tx_set_byte(
                        uart_tx_set_byte(
                            uart_tx_set_test_string(FLASH_DEMO_WRITE_PREFIX, FLASH_DEMO_PREFIX_LEN),
                            FLASH_DEMO_PREFIX_LEN + TEST_LEN_7,
                            UART_CR),
                        FLASH_DEMO_PREFIX_LEN + TEST_LEN_7 + 7'd1,
                        UART_LF),
                    FLASH_DEMO_LINE_LEN_7);
                demo_word_idx <= 5'd0;
                fw_next_state <= eFW_DEMO_READ_PREP;
                start_uart_tx_buf_print(FLASH_DEMO_LINE_LEN_7, eFW_RESTORE);
            end

            eFW_DEMO_READ_PREP:                                                 begin
                i_uart_tx_buf <= FLASH_DEMO_READ_PREFIX;
                demo_word_idx <= 5'd0;
                i_demo_system_state <= eFW_XIP_READ;
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

endmodule

`undef UART_TX_BUF_BYTE
