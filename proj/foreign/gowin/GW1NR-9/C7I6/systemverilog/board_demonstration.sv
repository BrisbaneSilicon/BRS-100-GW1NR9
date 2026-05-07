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
    parameter reg [(8*UART_TX_BUF_CHARS)-1:0] VERSION
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
        eHRAM_WAIT,
        eHRAM_WRITE,
        eHRAM_READ,
        eHRAM_COMPARE,
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
        eTEST_HRAM,
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
    reg                         [7:0]                   print_buf [0:63];
    reg                         [5:0]                   print_idx;
    reg                         [5:0]                   print_len;
    reg                         [7:0]                   hram_init_us;

    function automatic [7:0] hex_nibble;
        input [3:0] n;
        hex_nibble = (n < 4'd10) ? (8'h30 + {4'h0, n}) : (8'h37 + {4'h0, n});
    endfunction


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
                    i_next_startup_task <= eTEST_HRAM;
                    i_demo_system_state <= eSRAM_WRITE;
                end

                if (i_next_startup_task == eTEST_HRAM) begin
                    i_next_startup_task <= eNONE;
                    hram_init_us        <= 8'd0;
                    i_demo_system_state <= eHRAM_WAIT;
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
                ram_wdata <= 32'h5445_5354;
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
                if (readback == 32'h5445_5354) begin
                    print_buf[16] <= "p"; print_buf[17] <= "a";
                    print_buf[18] <= "s"; print_buf[19] <= "s";
                    print_buf[20] <= 8'h0D; print_buf[21] <= 8'h0A;
                    print_len <= 6'd22;
                end else begin
                    // "FAIL (wrote 0x54455354 read 0xRRRRRRRR)\r\n"
                    print_buf[16] <= "F"; print_buf[17] <= "A";
                    print_buf[18] <= "I"; print_buf[19] <= "L";
                    print_buf[20] <= " "; print_buf[21] <= "(";
                    print_buf[22] <= "w"; print_buf[23] <= "r";
                    print_buf[24] <= "o"; print_buf[25] <= "t";
                    print_buf[26] <= "e"; print_buf[27] <= " ";
                    print_buf[28] <= "0"; print_buf[29] <= "x";
                    print_buf[30] <= "5"; print_buf[31] <= "4";
                    print_buf[32] <= "4"; print_buf[33] <= "5";
                    print_buf[34] <= "5"; print_buf[35] <= "3";
                    print_buf[36] <= "5"; print_buf[37] <= "4";
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
                    print_len <= 6'd57;
                end
                print_idx <= 6'd0;
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
                ram_wdata <= 32'h5445_5354;
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
                if (readback == 32'h5445_5354) begin
                    print_buf[20] <= "p"; print_buf[21] <= "a";
                    print_buf[22] <= "s"; print_buf[23] <= "s";
                    print_buf[24] <= 8'h0D; print_buf[25] <= 8'h0A;
                    print_len <= 6'd26;
                end else begin
                    // "FAIL (wrote 0x54455354 read 0xRRRRRRRR)\r\n"
                    print_buf[20] <= "F"; print_buf[21] <= "A";
                    print_buf[22] <= "I"; print_buf[23] <= "L";
                    print_buf[24] <= " "; print_buf[25] <= "(";
                    print_buf[26] <= "w"; print_buf[27] <= "r";
                    print_buf[28] <= "o"; print_buf[29] <= "t";
                    print_buf[30] <= "e"; print_buf[31] <= " ";
                    print_buf[32] <= "0"; print_buf[33] <= "x";
                    print_buf[34] <= "5"; print_buf[35] <= "4";
                    print_buf[36] <= "4"; print_buf[37] <= "5";
                    print_buf[38] <= "5"; print_buf[39] <= "3";
                    print_buf[40] <= "5"; print_buf[41] <= "4";
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
                    print_len <= 6'd61;
                end
                print_idx <= 6'd0;
                i_demo_system_state <= ePRINT_BUF;
            end

            ePRINT_BUF:                                                         begin
                uart_tx_valid <= 1'b1;
                uart_tx_data  <= print_buf[print_idx];
                if (uart_tx_valid && uart_tx_ready) begin
                    if (print_idx + 6'd1 == print_len) begin
                        uart_tx_valid       <= 1'b0;
                        i_demo_system_state <= ePREP_NEXT_UART_STARTUP_MSG;
                    end else begin
                        print_idx <= print_idx + 6'd1;
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
