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
    parameter reg [(8*UART_TX_BUF_CHARS)-1:0] VERSION,
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
localparam                              UART_TX_BUF_CHARS   = 63;
localparam                              UART_TX_BUF_BITS    = UART_TX_BUF_CHARS * 8;
localparam reg  [UART_TX_BUF_BITS-1:0]  RST_SCRN            = "\033[2J\033[3J\033[0;0H";
localparam reg  [UART_TX_BUF_BITS-1:0]  BEGIN_MSG           = "BOARD: BRS-100-GW1NR9";


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
    int                                                 i_uart_tx_buf_counter;
    int                                                 i_uart_tx_buf_count;

    reg                         [31:0]                  i_io;

    reg                         [31:0]                  readback;
    reg                         [7:0]                   print_buf [0:95];
    reg                         [6:0]                   print_idx;
    reg                         [6:0]                   print_len;
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

    localparam int DEMO_MAX_LEN       = UART_TX_BUF_CHARS;
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
                i_next_startup_task     <= eOUTPUT_BEGIN_MSG;

                if (i_next_startup_task == eRESET_SCREEN) begin
                    i_uart_tx_buf       <= RST_SCRN;
                    i_next_startup_task <= eOUTPUT_BEGIN_MSG;
                end
                if (i_next_startup_task == eOUTPUT_BEGIN_MSG) begin
                    i_uart_tx_buf       <= BEGIN_MSG;
                    i_next_startup_task <= eOUTPUT_NLCR_1;
                end
                if (i_next_startup_task == eOUTPUT_NLCR_1) begin
                    i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                    UART_TX_BUF_BITS-16]    <= 16'h0A0D;
                    i_next_startup_task                     <= eOUTPUT_VERSION_MSG;
                end
                if (i_next_startup_task == eOUTPUT_VERSION_MSG) begin
                    i_uart_tx_buf       <= VERSION;
                    i_next_startup_task <= eOUTPUT_NLCR_2;
                end
                if (i_next_startup_task == eOUTPUT_NLCR_2) begin
                    i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                    UART_TX_BUF_BITS-16]    <= 16'h0A0D;
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
                uart_tx_valid   <= 1'b1;
                uart_tx_data    <= i_uart_tx_buf[UART_TX_BUF_BITS-1:
                                                    UART_TX_BUF_BITS-8];

                if (uart_tx_valid == 1'b1 && uart_tx_ready == 1'b1) begin
                    i_uart_tx_buf_counter   <= i_uart_tx_buf_counter + 1;
                    i_uart_tx_buf           <= i_uart_tx_buf << 8;
                end
                if (i_uart_tx_buf_counter == UART_TX_BUF_CHARS) begin
                    uart_tx_valid       <= 1'b0;

                    i_demo_system_state <= ePREP_NEXT_UART_STARTUP_MSG;
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
                print_buf[0]  <= "T"; print_buf[1]  <= "e"; print_buf[2]  <= "s";
                print_buf[3]  <= "t"; print_buf[4]  <= "i"; print_buf[5]  <= "n";
                print_buf[6]  <= "g"; print_buf[7]  <= " "; print_buf[8]  <= "S";
                print_buf[9]  <= "R"; print_buf[10] <= "A"; print_buf[11] <= "M";
                print_buf[12] <= "."; print_buf[13] <= "."; print_buf[14] <= ".";
                print_buf[15] <= " ";
                if (readback == 32'hABCD_ABCD) begin
                    print_buf[16] <= "p"; print_buf[17] <= "a";
                    print_buf[18] <= "s"; print_buf[19] <= "s";
                    print_buf[20] <= 8'h0D; print_buf[21] <= 8'h0A;
                    print_len <= 7'd22;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    print_buf[16] <= "F"; print_buf[17] <= "A";
                    print_buf[18] <= "I"; print_buf[19] <= "L";
                    print_buf[20] <= " "; print_buf[21] <= "(";
                    print_buf[22] <= "w"; print_buf[23] <= "r";
                    print_buf[24] <= "o"; print_buf[25] <= "t";
                    print_buf[26] <= "e"; print_buf[27] <= " ";
                    print_buf[28] <= "0"; print_buf[29] <= "x";
                    print_buf[30] <= "A"; print_buf[31] <= "B";
                    print_buf[32] <= "C"; print_buf[33] <= "D";
                    print_buf[34] <= "A"; print_buf[35] <= "B";
                    print_buf[36] <= "C"; print_buf[37] <= "D";
                    print_buf[38] <= " "; print_buf[39] <= "r";
                    print_buf[40] <= "e"; print_buf[41] <= "a";
                    print_buf[42] <= "d"; print_buf[43] <= " ";
                    print_buf[44] <= "0"; print_buf[45] <= "x";
                    print_buf[46] <= hex_nibble(readback[31:28]);
                    print_buf[47] <= hex_nibble(readback[27:24]);
                    print_buf[48] <= hex_nibble(readback[23:20]);
                    print_buf[49] <= hex_nibble(readback[19:16]);
                    print_buf[50] <= hex_nibble(readback[15:12]);
                    print_buf[51] <= hex_nibble(readback[11:8]);
                    print_buf[52] <= hex_nibble(readback[7:4]);
                    print_buf[53] <= hex_nibble(readback[3:0]);
                    print_buf[54] <= ")";
                    print_buf[55] <= 8'h0D; print_buf[56] <= 8'h0A;
                    print_len <= 7'd57;
                end
                print_idx <= 7'd0;
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
                print_buf[0]  <= "S"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "W";
                print_buf[6]  <= " "; print_buf[7]  <= "@"; print_buf[8]  <= "0";
                print_buf[9]  <= "x"; print_buf[10] <= "0"; print_buf[11] <= "0";
                print_buf[12] <= "0"; print_buf[13] <= "0"; print_buf[14] <= "0";
                print_buf[15] <= "0"; print_buf[16] <= "1"; print_buf[17] <= "0";
                print_buf[18] <= ":"; print_buf[19] <= " ";
                for (demo_i = 0; demo_i < DEMO_LEN; demo_i = demo_i + 1) begin
                    print_buf[20 + demo_i] <= version_byte(demo_i[6:0]);
                end
                print_buf[20 + DEMO_LEN] <= 8'h0D;
                print_buf[21 + DEMO_LEN] <= 8'h0A;
                print_len         <= SRAM_DEMO_LINE_LEN;
                print_idx         <= 7'd0;
                print_next_state  <= eSRAM_DEMO_READ_PREP;
                i_demo_system_state <= ePRINT_BUF;
            end

            eSRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                print_buf[0]  <= "S"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "R";
                print_buf[6]  <= " "; print_buf[7]  <= "@"; print_buf[8]  <= "0";
                print_buf[9]  <= "x"; print_buf[10] <= "0"; print_buf[11] <= "0";
                print_buf[12] <= "0"; print_buf[13] <= "0"; print_buf[14] <= "0";
                print_buf[15] <= "0"; print_buf[16] <= "1"; print_buf[17] <= "0";
                print_buf[18] <= ":"; print_buf[19] <= " ";
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
                        print_buf[20 + demo_word_base] <= ram_rdata[31:24];
                        if (ram_rdata[31:24] != version_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd1] <= ram_rdata[23:16];
                        if (ram_rdata[23:16] != version_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd2] <= ram_rdata[15:8];
                        if (ram_rdata[15:8] != version_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd3] <= ram_rdata[7:0];
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
                print_buf[20 + DEMO_LEN] <= 8'h0D;
                print_buf[21 + DEMO_LEN] <= 8'h0A;
                print_len         <= SRAM_DEMO_LINE_LEN;
                print_idx         <= 7'd0;
                print_next_state  <= eSRAM_DEMO_PRINT_RESULT;
                i_demo_system_state <= ePRINT_BUF;
            end

            eSRAM_DEMO_PRINT_RESULT:                                           begin
                print_buf[0]  <= "S"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "d";
                print_buf[6]  <= "e"; print_buf[7]  <= "m"; print_buf[8]  <= "o";
                print_buf[9]  <= "."; print_buf[10] <= "."; print_buf[11] <= ".";
                print_buf[12] <= " ";
                if (demo_pass) begin
                    print_buf[13] <= "p"; print_buf[14] <= "a";
                    print_buf[15] <= "s"; print_buf[16] <= "s";
                end else begin
                    print_buf[13] <= "F"; print_buf[14] <= "A";
                    print_buf[15] <= "I"; print_buf[16] <= "L";
                end
                print_buf[17] <= 8'h0D;
                print_buf[18] <= 8'h0A;
                print_len         <= 7'd19;
                print_idx         <= 7'd0;
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
                print_buf[0]  <= "H"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "W";
                print_buf[6]  <= " "; print_buf[7]  <= "@"; print_buf[8]  <= "0";
                print_buf[9]  <= "x"; print_buf[10] <= "0"; print_buf[11] <= "0";
                print_buf[12] <= "0"; print_buf[13] <= "0"; print_buf[14] <= "8";
                print_buf[15] <= "0"; print_buf[16] <= "1"; print_buf[17] <= "0";
                print_buf[18] <= ":"; print_buf[19] <= " ";
                for (demo_i = 0; demo_i < DEMO_LEN; demo_i = demo_i + 1) begin
                    print_buf[20 + demo_i] <= version_byte(demo_i[6:0]);
                end
                print_buf[20 + DEMO_LEN] <= 8'h0D;
                print_buf[21 + DEMO_LEN] <= 8'h0A;
                print_len         <= SRAM_DEMO_LINE_LEN;
                print_idx         <= 7'd0;
                print_next_state  <= eHRAM_DEMO_READ_PREP;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_DEMO_READ_PREP:                                              begin
                demo_word_idx       <= 5'd0;
                print_buf[0]  <= "H"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "R";
                print_buf[6]  <= " "; print_buf[7]  <= "@"; print_buf[8]  <= "0";
                print_buf[9]  <= "x"; print_buf[10] <= "0"; print_buf[11] <= "0";
                print_buf[12] <= "0"; print_buf[13] <= "0"; print_buf[14] <= "8";
                print_buf[15] <= "0"; print_buf[16] <= "1"; print_buf[17] <= "0";
                print_buf[18] <= ":"; print_buf[19] <= " ";
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
                        print_buf[20 + demo_word_base] <= ram_rdata[31:24];
                        if (ram_rdata[31:24] != version_byte(demo_word_base)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd1 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd1] <= ram_rdata[23:16];
                        if (ram_rdata[23:16] != version_byte(demo_word_base + 7'd1)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd2 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd2] <= ram_rdata[15:8];
                        if (ram_rdata[15:8] != version_byte(demo_word_base + 7'd2)) begin
                            demo_pass <= 1'b0;
                        end
                    end
                    if (demo_word_base + 7'd3 < DEMO_LEN) begin
                        print_buf[20 + demo_word_base + 7'd3] <= ram_rdata[7:0];
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
                print_buf[20 + DEMO_LEN] <= 8'h0D;
                print_buf[21 + DEMO_LEN] <= 8'h0A;
                print_len         <= SRAM_DEMO_LINE_LEN;
                print_idx         <= 7'd0;
                print_next_state  <= eHRAM_DEMO_PRINT_RESULT;
                i_demo_system_state <= ePRINT_BUF;
            end

            eHRAM_DEMO_PRINT_RESULT:                                           begin
                print_buf[0]  <= "H"; print_buf[1]  <= "R"; print_buf[2]  <= "A";
                print_buf[3]  <= "M"; print_buf[4]  <= " "; print_buf[5]  <= "d";
                print_buf[6]  <= "e"; print_buf[7]  <= "m"; print_buf[8]  <= "o";
                print_buf[9]  <= "."; print_buf[10] <= "."; print_buf[11] <= ".";
                print_buf[12] <= " ";
                if (demo_pass) begin
                    print_buf[13] <= "p"; print_buf[14] <= "a";
                    print_buf[15] <= "s"; print_buf[16] <= "s";
                end else begin
                    print_buf[13] <= "F"; print_buf[14] <= "A";
                    print_buf[15] <= "I"; print_buf[16] <= "L";
                end
                print_buf[17] <= 8'h0D;
                print_buf[18] <= 8'h0A;
                print_len         <= 7'd19;
                print_idx         <= 7'd0;
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
                print_buf[0]  <= "T"; print_buf[1]  <= "e"; print_buf[2]  <= "s";
                print_buf[3]  <= "t"; print_buf[4]  <= "i"; print_buf[5]  <= "n";
                print_buf[6]  <= "g"; print_buf[7]  <= " "; print_buf[8]  <= "H";
                print_buf[9]  <= "y"; print_buf[10] <= "p"; print_buf[11] <= "e";
                print_buf[12] <= "r"; print_buf[13] <= "R"; print_buf[14] <= "A";
                print_buf[15] <= "M"; print_buf[16] <= "."; print_buf[17] <= ".";
                print_buf[18] <= "."; print_buf[19] <= " ";
                if (readback == 32'hABCD_ABCD) begin
                    print_buf[20] <= "p"; print_buf[21] <= "a";
                    print_buf[22] <= "s"; print_buf[23] <= "s";
                    print_buf[24] <= 8'h0D; print_buf[25] <= 8'h0A;
                    print_len <= 7'd26;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    print_buf[20] <= "F"; print_buf[21] <= "A";
                    print_buf[22] <= "I"; print_buf[23] <= "L";
                    print_buf[24] <= " "; print_buf[25] <= "(";
                    print_buf[26] <= "w"; print_buf[27] <= "r";
                    print_buf[28] <= "o"; print_buf[29] <= "t";
                    print_buf[30] <= "e"; print_buf[31] <= " ";
                    print_buf[32] <= "0"; print_buf[33] <= "x";
                    print_buf[34] <= "A"; print_buf[35] <= "B";
                    print_buf[36] <= "C"; print_buf[37] <= "D";
                    print_buf[38] <= "A"; print_buf[39] <= "B";
                    print_buf[40] <= "C"; print_buf[41] <= "D";
                    print_buf[42] <= " "; print_buf[43] <= "r";
                    print_buf[44] <= "e"; print_buf[45] <= "a";
                    print_buf[46] <= "d"; print_buf[47] <= " ";
                    print_buf[48] <= "0"; print_buf[49] <= "x";
                    print_buf[50] <= hex_nibble(readback[31:28]);
                    print_buf[51] <= hex_nibble(readback[27:24]);
                    print_buf[52] <= hex_nibble(readback[23:20]);
                    print_buf[53] <= hex_nibble(readback[19:16]);
                    print_buf[54] <= hex_nibble(readback[15:12]);
                    print_buf[55] <= hex_nibble(readback[11:8]);
                    print_buf[56] <= hex_nibble(readback[7:4]);
                    print_buf[57] <= hex_nibble(readback[3:0]);
                    print_buf[58] <= ")";
                    print_buf[59] <= 8'h0D; print_buf[60] <= 8'h0A;
                    print_len <= 7'd61;
                end
                print_idx <= 7'd0;
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
                print_buf[0]  <= "T"; print_buf[1]  <= "e"; print_buf[2]  <= "s";
                print_buf[3]  <= "t"; print_buf[4]  <= "i"; print_buf[5]  <= "n";
                print_buf[6]  <= "g"; print_buf[7]  <= " "; print_buf[8]  <= "F";
                print_buf[9]  <= "l"; print_buf[10] <= "a"; print_buf[11] <= "s";
                print_buf[12] <= "h"; print_buf[13] <= " "; print_buf[14] <= "I";
                print_buf[15] <= "D"; print_buf[16] <= "."; print_buf[17] <= ".";
                print_buf[18] <= "."; print_buf[19] <= " ";
                if (jedec_id_in == EXPECTED_JEDEC_ID) begin
                    print_buf[20] <= "p"; print_buf[21] <= "a";
                    print_buf[22] <= "s"; print_buf[23] <= "s";
                    print_buf[24] <= 8'h0D; print_buf[25] <= 8'h0A;
                    print_len <= 7'd26;
                end else begin
                    // "FAIL (read 0xXXXXXX expected 0xYYYYYY)\r\n"
                    print_buf[20] <= "F"; print_buf[21] <= "A";
                    print_buf[22] <= "I"; print_buf[23] <= "L";
                    print_buf[24] <= " "; print_buf[25] <= "(";
                    print_buf[26] <= "r"; print_buf[27] <= "e";
                    print_buf[28] <= "a"; print_buf[29] <= "d";
                    print_buf[30] <= " "; print_buf[31] <= "0";
                    print_buf[32] <= "x";
                    print_buf[33] <= hex_nibble(jedec_id_in[23:20]);
                    print_buf[34] <= hex_nibble(jedec_id_in[19:16]);
                    print_buf[35] <= hex_nibble(jedec_id_in[15:12]);
                    print_buf[36] <= hex_nibble(jedec_id_in[11:8]);
                    print_buf[37] <= hex_nibble(jedec_id_in[7:4]);
                    print_buf[38] <= hex_nibble(jedec_id_in[3:0]);
                    print_buf[39] <= " "; print_buf[40] <= "e";
                    print_buf[41] <= "x"; print_buf[42] <= "p";
                    print_buf[43] <= "e"; print_buf[44] <= "c";
                    print_buf[45] <= "t"; print_buf[46] <= "e";
                    print_buf[47] <= "d"; print_buf[48] <= " ";
                    print_buf[49] <= "0"; print_buf[50] <= "x";
                    print_buf[51] <= hex_nibble(EXPECTED_JEDEC_ID[23:20]);
                    print_buf[52] <= hex_nibble(EXPECTED_JEDEC_ID[19:16]);
                    print_buf[53] <= hex_nibble(EXPECTED_JEDEC_ID[15:12]);
                    print_buf[54] <= hex_nibble(EXPECTED_JEDEC_ID[11:8]);
                    print_buf[55] <= hex_nibble(EXPECTED_JEDEC_ID[7:4]);
                    print_buf[56] <= hex_nibble(EXPECTED_JEDEC_ID[3:0]);
                    print_buf[57] <= ")";
                    print_buf[58] <= 8'h0D; print_buf[59] <= 8'h0A;
                    print_len <= 7'd60;
                end
                print_idx <= 7'd0;
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
                print_buf[0]  <= "T"; print_buf[1]  <= "e"; print_buf[2]  <= "s";
                print_buf[3]  <= "t"; print_buf[4]  <= "i"; print_buf[5]  <= "n";
                print_buf[6]  <= "g"; print_buf[7]  <= " "; print_buf[8]  <= "F";
                print_buf[9]  <= "l"; print_buf[10] <= "a"; print_buf[11] <= "s";
                print_buf[12] <= "h"; print_buf[13] <= " "; print_buf[14] <= "W";
                print_buf[15] <= "/"; print_buf[16] <= "R"; print_buf[17] <= "/";
                print_buf[18] <= "V"; print_buf[19] <= "."; print_buf[20] <= ".";
                print_buf[21] <= "."; print_buf[22] <= " ";
                if (readback == FLASH_TEST_DATA) begin
                    print_buf[23] <= "p"; print_buf[24] <= "a";
                    print_buf[25] <= "s"; print_buf[26] <= "s";
                    print_buf[27] <= 8'h0D; print_buf[28] <= 8'h0A;
                    print_len <= 7'd29;
                end else begin
                    // "FAIL (wrote 0xABCDABCD read 0xRRRRRRRR)\r\n"
                    print_buf[23] <= "F"; print_buf[24] <= "A";
                    print_buf[25] <= "I"; print_buf[26] <= "L";
                    print_buf[27] <= " "; print_buf[28] <= "(";
                    print_buf[29] <= "w"; print_buf[30] <= "r";
                    print_buf[31] <= "o"; print_buf[32] <= "t";
                    print_buf[33] <= "e"; print_buf[34] <= " ";
                    print_buf[35] <= "0"; print_buf[36] <= "x";
                    print_buf[37] <= "A"; print_buf[38] <= "B";
                    print_buf[39] <= "C"; print_buf[40] <= "D";
                    print_buf[41] <= "A"; print_buf[42] <= "B";
                    print_buf[43] <= "C"; print_buf[44] <= "D";
                    print_buf[45] <= " "; print_buf[46] <= "r";
                    print_buf[47] <= "e"; print_buf[48] <= "a";
                    print_buf[49] <= "d"; print_buf[50] <= " ";
                    print_buf[51] <= "0"; print_buf[52] <= "x";
                    print_buf[53] <= hex_nibble(readback[31:28]);
                    print_buf[54] <= hex_nibble(readback[27:24]);
                    print_buf[55] <= hex_nibble(readback[23:20]);
                    print_buf[56] <= hex_nibble(readback[19:16]);
                    print_buf[57] <= hex_nibble(readback[15:12]);
                    print_buf[58] <= hex_nibble(readback[11:8]);
                    print_buf[59] <= hex_nibble(readback[7:4]);
                    print_buf[60] <= hex_nibble(readback[3:0]);
                    print_buf[61] <= ")";
                    print_buf[62] <= 8'h0D; print_buf[63] <= 8'h0A;
                    print_len <= 7'd64;
                end
                print_idx <= 7'd0;
                print_next_state <= ePREP_NEXT_UART_STARTUP_MSG;
                i_demo_system_state <= ePRINT_BUF;
            end

            ePRINT_BUF:                                                         begin
                uart_tx_valid <= 1'b1;
                uart_tx_data  <= print_buf[print_idx];
                if (uart_tx_valid && uart_tx_ready) begin
                    if (print_idx + 7'd1 == print_len) begin
                        uart_tx_valid       <= 1'b0;
                        i_demo_system_state <= print_next_state;
                    end else begin
                        print_idx <= print_idx + 7'd1;
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
            for (demo_i = 0; demo_i < 96; demo_i = demo_i + 1) begin
                print_buf[demo_i] <= 8'd0;
            end

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
