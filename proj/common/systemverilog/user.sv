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

module user (
    input               sysclk,
    input               sysclk_resetn,

    input               microsecond_tick,
    input               millisecond_tick,
    input               second_tick,

    output  reg [5:0]   leds,

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


    // ----------------------------------------------
    //  Definitions
    // ----------------------------------------------

    localparam S_WRITE          = 6'd0;
    localparam S_READ           = 6'd1;
    localparam S_COMPARE        = 6'd2;
    localparam S_HRAM_WAIT      = 6'd3;   // wait for HyperRAM controller init (~160us)
    localparam S_HRAM_WRITE     = 6'd4;
    localparam S_HRAM_READ      = 6'd5;
    localparam S_HRAM_COMPARE   = 6'd6;
    localparam S_DONE           = 6'd7;
    localparam S_PRINT          = 6'd8;
    // ---- Stage 0 diagnostic: JEDEC ID read via flash_cfg port ----
    localparam S_FJ_INIT_EN     = 6'd9;   // config_en = 0 (take cfg-mode control)
    localparam S_FJ_INIT_OE     = 6'd10;  // config_oe = 0001 (MOSI=output, MISO=input)
    localparam S_FJ_INIT_CSB_HI = 6'd11;  // CSB=1 (idle, reset slave state)
    localparam S_FJ_INIT_CSB_LO = 6'd12;  // CSB=0 (start transaction)
    localparam S_FJ_BIT_LO      = 6'd13;  // CLK=0, MOSI=tx_bit
    localparam S_FJ_BIT_HI      = 6'd14;  // CLK=1, MOSI=tx_bit (flash samples)
    localparam S_FJ_BIT_CAP     = 6'd15;  // read MISO via rdata[1], shift into jedec_id_in
    localparam S_FJ_END         = 6'd16;  // CSB=1 (deassert)
    localparam S_FJ_RESTORE     = 6'd17;  // config_en = 1 (back to XIP mode)
    localparam S_FJ_PRINT_PREP  = 6'd18;  // format "JEDEC: XXXXXX\r\n"
    localparam S_INIT_WAIT      = 6'd19;  // wait 1 ms after reset before first TX

    localparam S_FW_INIT_EN             = 6'd20;
    localparam S_FW_INIT_OE             = 6'd21;
    localparam S_FW_INIT_CSB_HI         = 6'd22;
    localparam S_FW_SETUP_WREN_ERASE    = 6'd23;
    localparam S_FW_SETUP_ERASE         = 6'd24;
    localparam S_FW_SETUP_POLL_ERASE    = 6'd25;
    localparam S_FW_CHECK_POLL_ERASE    = 6'd26;
    localparam S_FW_SETUP_WREN_PROGRAM  = 6'd27;
    localparam S_FW_SETUP_PROGRAM       = 6'd28;
    localparam S_FW_SETUP_POLL_PROGRAM  = 6'd29;
    localparam S_FW_CHECK_POLL_PROGRAM  = 6'd30;
    localparam S_FW_SPI_CSB_LO          = 6'd31;
    localparam S_FW_SPI_BIT_LO          = 6'd32;
    localparam S_FW_SPI_BIT_HI          = 6'd33;
    localparam S_FW_SPI_BIT_CAP         = 6'd34;
    localparam S_FW_SPI_END             = 6'd35;
    localparam S_FW_RESTORE             = 6'd36;
    localparam S_FW_XIP_READ            = 6'd37;
    localparam S_FW_COMPARE             = 6'd38;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    reg [5:0]  state;
    reg [31:0] readback;

    reg [7:0]  print_buf [0:21];
    reg [4:0]  print_idx;
    reg [4:0]  print_len;
    reg [5:0]  return_state;

    reg [7:0]  hram_init_us;    // counts microsecond ticks during HyperRAM init wait

    // JEDEC ID bit-bang state (Stage 0 diagnostic)
    // bit_idx 0..7 = transmit cmd 0x9F, 8..31 = receive 24-bit ID
    reg [5:0]  jedec_bit_idx;
    reg [23:0] jedec_id_in;

    localparam [7:0]  JEDEC_CMD       = 8'h9F;
    localparam [31:0] MEM_TEST_DATA   = 32'hABCD_ABCD;
    localparam [23:0] FLASH_TEST_ADDR   = 24'h01_0000;
    localparam [31:0] FLASH_TEST_DATA   = MEM_TEST_DATA;
    localparam [7:0]  FLASH_CMD_WREN    = 8'h06;
    localparam [7:0]  FLASH_CMD_RDSR    = 8'h05;
    localparam [7:0]  FLASH_CMD_ERASE   = 8'h20;
    localparam [7:0]  FLASH_CMD_PROGRAM = 8'h02;
    localparam [9:0]  FLASH_POLL_LIMIT  = 10'd1000;

    wire [2:0] jedec_tx_idx = 3'd7 - jedec_bit_idx[2:0];
    wire       jedec_mosi_bit = (jedec_bit_idx < 6'd8) ? JEDEC_CMD[jedec_tx_idx] : 1'b0;

    reg [63:0] fw_shift;
    reg [6:0]  fw_bit_idx;
    reg [6:0]  fw_bit_count;
    reg [7:0]  fw_status;
    reg [9:0]  fw_poll_ms;
    reg        fw_capture_status;
    reg [5:0]  fw_next_state;


    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------

    function automatic [7:0] hex_nibble;
        input [3:0] n;
        hex_nibble = (n < 4'd10) ? (8'h30 + {4'h0, n}) : (8'h37 + {4'h0, n});
    endfunction

    always @(posedge sysclk) begin

        uart_tx_valid <= 1'b0;
        uart_rx_ready <= 1'b0;

        // Default: keep memory buses idle
        ram_valid       <= 0;
        ram_addr        <= 0;
        ram_wdata       <= 0;
        ram_wstrb       <= 0;
        flash_cfg_valid <= 0;
        flash_cfg_addr  <= 0;
        flash_cfg_wdata <= 0;
        flash_cfg_wstrb <= 0;
        flash_xip_valid <= 0;
        flash_xip_addr  <= 0;
        flash_xip_wdata <= 0;
        flash_xip_wstrb <= 0;

        case (state)

            S_WRITE: begin
                // Write test pattern to SRAM address 0
                ram_valid <= 1;
                ram_addr  <= 32'h0000_0000;
                ram_wdata <= MEM_TEST_DATA;
                ram_wstrb <= 4'hF;
                if (ram_ready) begin
                    state <= S_READ;
                end
            end

            S_READ: begin
                // Read back from SRAM address 0
                ram_valid <= 1;
                ram_addr  <= 32'h0000_0000;
                ram_wstrb <= 4'h0;
                if (ram_ready) begin
                    readback <= ram_rdata;
                    state    <= S_COMPARE;
                end
            end

            S_COMPARE: begin
                leds[0] <= 1;
                print_buf[0] <= "S"; print_buf[1] <= "R"; print_buf[2] <= "A";
                print_buf[3] <= "M"; print_buf[4] <= ":"; print_buf[5] <= " ";
                print_buf[6]  <= hex_nibble(readback[31:28]);
                print_buf[7]  <= hex_nibble(readback[27:24]);
                print_buf[8]  <= hex_nibble(readback[23:20]);
                print_buf[9]  <= hex_nibble(readback[19:16]);
                print_buf[10] <= hex_nibble(readback[15:12]);
                print_buf[11] <= hex_nibble(readback[11:8]);
                print_buf[12] <= hex_nibble(readback[7:4]);
                print_buf[13] <= hex_nibble(readback[3:0]);
                print_buf[14] <= " ";
                if (readback == MEM_TEST_DATA) begin
                    leds[1] <= 1;
                    print_buf[15] <= "P"; print_buf[16] <= "A";
                    print_buf[17] <= "S"; print_buf[18] <= "S";
                end else begin
                    leds[2] <= 1;
                    print_buf[15] <= "F"; print_buf[16] <= "A";
                    print_buf[17] <= "I"; print_buf[18] <= "L";
                end
                print_buf[19] <= 8'h0D;
                print_buf[20] <= 8'h0A;
                print_len    <= 5'd21;
                return_state <= S_HRAM_WAIT;
                state        <= S_PRINT;
            end

            S_HRAM_WAIT: begin
                // HyperRAM controller needs ~160us after reset before it accepts
                // transactions. Wait 250us (safe margin) before first access.
                if (microsecond_tick) begin
                    hram_init_us <= hram_init_us + 8'd1;
                    if (hram_init_us == 8'd249) begin
                        state <= S_HRAM_WRITE;
                    end
                end
            end

            S_HRAM_WRITE: begin
                ram_valid <= 1;
                ram_addr  <= 32'h0000_8000;
                ram_wdata <= MEM_TEST_DATA;
                ram_wstrb <= 4'hF;
                if (ram_ready) begin
                    state <= S_HRAM_READ;
                end
            end

            S_HRAM_READ: begin
                ram_valid <= 1;
                ram_addr  <= 32'h0000_8000;
                ram_wstrb <= 4'h0;
                if (ram_ready) begin
                    readback <= ram_rdata;
                    state    <= S_HRAM_COMPARE;
                end
            end

            S_HRAM_COMPARE: begin
                leds[3] <= 1;
                print_buf[0] <= "H"; print_buf[1] <= "R"; print_buf[2] <= "A";
                print_buf[3] <= "M"; print_buf[4] <= ":"; print_buf[5] <= " ";
                print_buf[6]  <= hex_nibble(readback[31:28]);
                print_buf[7]  <= hex_nibble(readback[27:24]);
                print_buf[8]  <= hex_nibble(readback[23:20]);
                print_buf[9]  <= hex_nibble(readback[19:16]);
                print_buf[10] <= hex_nibble(readback[15:12]);
                print_buf[11] <= hex_nibble(readback[11:8]);
                print_buf[12] <= hex_nibble(readback[7:4]);
                print_buf[13] <= hex_nibble(readback[3:0]);
                print_buf[14] <= " ";
                if (readback == MEM_TEST_DATA) begin
                    leds[4] <= 1;
                    print_buf[15] <= "P"; print_buf[16] <= "A";
                    print_buf[17] <= "S"; print_buf[18] <= "S";
                end else begin
                    leds[5] <= 1;
                    print_buf[15] <= "F"; print_buf[16] <= "A";
                    print_buf[17] <= "I"; print_buf[18] <= "L";
                end
                print_buf[19] <= 8'h0D;
                print_buf[20] <= 8'h0A;
                print_len    <= 5'd21;
                return_state <= S_FJ_INIT_EN;
                state        <= S_PRINT;
            end

            // ---- Stage 0 diagnostic: JEDEC ID read via flash_cfg port ----
            // Bit-bang sequence (SPI mode 0):
            //   1. Take cfg control (config_en=0).
            //   2. Enable MOSI as output (config_oe=4'b0001).
            //   3. Pulse CSB high then low to reset/start a transaction.
            //   4. For each of 32 bits (8 cmd + 24 response):
            //        a. CLK=0, MOSI=tx_bit (slave shifts on this falling edge for RX bits).
            //        b. CLK=1 (slave samples MOSI; flash_cfg_rdata[1] reflects current MISO).
            //        c. Read cfg port; capture rdata[1] as MISO bit; shift into jedec_id_in.
            //   5. CSB=1 (deassert), then config_en=1 (restore XIP mode).

            S_FJ_INIT_EN: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b1000;        // we[3] writes config_en (bit 31)
                flash_cfg_wdata <= 32'h0000_0000;  // config_en = 0
                if (flash_cfg_ready) begin
                    state <= S_FJ_INIT_OE;
                end
            end

            S_FJ_INIT_OE: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0010;        // we[1] writes config_oe (bits 11:8)
                flash_cfg_wdata <= 32'h0000_0100;  // oe = 4'b0001 (MOSI=out, MISO=in)
                if (flash_cfg_ready) begin
                    state <= S_FJ_INIT_CSB_HI;
                end
            end

            S_FJ_INIT_CSB_HI: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;        // we[0] writes csb/clk/do
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    state <= S_FJ_INIT_CSB_LO;
                end
            end

            S_FJ_INIT_CSB_LO: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0000;  // CSB=0, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    jedec_bit_idx <= 6'd0;
                    state         <= S_FJ_BIT_LO;
                end
            end

            S_FJ_BIT_LO: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b0, 3'h0, jedec_mosi_bit};
                if (flash_cfg_ready) begin
                    state <= S_FJ_BIT_HI;
                end
            end

            S_FJ_BIT_HI: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b1, 3'h0, jedec_mosi_bit};
                if (flash_cfg_ready) begin
                    state <= S_FJ_BIT_CAP;
                end
            end

            S_FJ_BIT_CAP: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0000;        // pure read
                if (flash_cfg_ready) begin
                    if (jedec_bit_idx >= 6'd8) begin
                        jedec_id_in <= {jedec_id_in[22:0], flash_cfg_rdata[1]};
                    end
                    if (jedec_bit_idx == 6'd31) begin
                        state <= S_FJ_END;
                    end else begin
                        jedec_bit_idx <= jedec_bit_idx + 6'd1;
                        state         <= S_FJ_BIT_LO;
                    end
                end
            end

            S_FJ_END: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    state <= S_FJ_RESTORE;
                end
            end

            S_FJ_RESTORE: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h8000_0000;  // config_en = 1 (XIP mode)
                if (flash_cfg_ready) begin
                    state <= S_FJ_PRINT_PREP;
                end
            end

            S_FJ_PRINT_PREP: begin
                // Format: "JEDEC: XXXXXX\r\n" (15 chars)
                print_buf[0]  <= "J"; print_buf[1] <= "E"; print_buf[2] <= "D";
                print_buf[3]  <= "E"; print_buf[4] <= "C"; print_buf[5] <= ":";
                print_buf[6]  <= " ";
                print_buf[7]  <= hex_nibble(jedec_id_in[23:20]);
                print_buf[8]  <= hex_nibble(jedec_id_in[19:16]);
                print_buf[9]  <= hex_nibble(jedec_id_in[15:12]);
                print_buf[10] <= hex_nibble(jedec_id_in[11:8]);
                print_buf[11] <= hex_nibble(jedec_id_in[7:4]);
                print_buf[12] <= hex_nibble(jedec_id_in[3:0]);
                print_buf[13] <= 8'h0D;
                print_buf[14] <= 8'h0A;
                print_len    <= 5'd15;
                return_state <= S_FW_INIT_EN;
                state        <= S_PRINT;
            end

            S_FW_INIT_EN: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h0000_0000;  // config_en = 0
                if (flash_cfg_ready) begin
                    state <= S_FW_INIT_OE;
                end
            end

            S_FW_INIT_OE: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0010;
                flash_cfg_wdata <= 32'h0000_0100;  // oe = 4'b0001 (MOSI=out, MISO=in)
                if (flash_cfg_ready) begin
                    state <= S_FW_INIT_CSB_HI;
                end
            end

            S_FW_INIT_CSB_HI: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    state <= S_FW_SETUP_WREN_ERASE;
                end
            end

            S_FW_SETUP_WREN_ERASE: begin
                fw_shift          <= {FLASH_CMD_WREN, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd8;
                fw_capture_status <= 1'b0;
                fw_next_state     <= S_FW_SETUP_ERASE;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_SETUP_ERASE: begin
                fw_shift          <= {FLASH_CMD_ERASE, FLASH_TEST_ADDR, 32'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd32;
                fw_capture_status <= 1'b0;
                fw_next_state     <= S_FW_SETUP_POLL_ERASE;
                fw_poll_ms        <= 10'd0;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_SETUP_POLL_ERASE: begin
                fw_shift          <= {FLASH_CMD_RDSR, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd16;
                fw_status         <= 8'd0;
                fw_capture_status <= 1'b1;
                fw_next_state     <= S_FW_CHECK_POLL_ERASE;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_CHECK_POLL_ERASE: begin
                if (fw_status[0]) begin
                    if (millisecond_tick) begin
                        if (fw_poll_ms == FLASH_POLL_LIMIT) begin
                            readback      <= {24'd0, fw_status};
                            fw_next_state <= S_FW_COMPARE;
                            state         <= S_FW_RESTORE;
                        end else begin
                            fw_poll_ms <= fw_poll_ms + 10'd1;
                            state      <= S_FW_SETUP_POLL_ERASE;
                        end
                    end
                end else begin
                    fw_poll_ms <= 10'd0;
                    state      <= S_FW_SETUP_WREN_PROGRAM;
                end
            end

            S_FW_SETUP_WREN_PROGRAM: begin
                fw_shift          <= {FLASH_CMD_WREN, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd8;
                fw_capture_status <= 1'b0;
                fw_next_state     <= S_FW_SETUP_PROGRAM;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_SETUP_PROGRAM: begin
                fw_shift          <= {FLASH_CMD_PROGRAM, FLASH_TEST_ADDR,
                                      FLASH_TEST_DATA[7:0],
                                      FLASH_TEST_DATA[15:8],
                                      FLASH_TEST_DATA[23:16],
                                      FLASH_TEST_DATA[31:24]};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd64;
                fw_capture_status <= 1'b0;
                fw_next_state     <= S_FW_SETUP_POLL_PROGRAM;
                fw_poll_ms        <= 10'd0;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_SETUP_POLL_PROGRAM: begin
                fw_shift          <= {FLASH_CMD_RDSR, 56'd0};
                fw_bit_idx        <= 7'd0;
                fw_bit_count      <= 7'd16;
                fw_status         <= 8'd0;
                fw_capture_status <= 1'b1;
                fw_next_state     <= S_FW_CHECK_POLL_PROGRAM;
                state             <= S_FW_SPI_CSB_LO;
            end

            S_FW_CHECK_POLL_PROGRAM: begin
                if (fw_status[0]) begin
                    if (millisecond_tick) begin
                        if (fw_poll_ms == FLASH_POLL_LIMIT) begin
                            readback      <= {24'd0, fw_status};
                            fw_next_state <= S_FW_COMPARE;
                            state         <= S_FW_RESTORE;
                        end else begin
                            fw_poll_ms <= fw_poll_ms + 10'd1;
                            state      <= S_FW_SETUP_POLL_PROGRAM;
                        end
                    end
                end else begin
                    fw_next_state <= S_FW_XIP_READ;
                    state         <= S_FW_RESTORE;
                end
            end

            S_FW_SPI_CSB_LO: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0000;  // CSB=0, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    state <= S_FW_SPI_BIT_LO;
                end
            end

            S_FW_SPI_BIT_LO: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b0, 3'h0, fw_shift[63]};
                if (flash_cfg_ready) begin
                    state <= S_FW_SPI_BIT_HI;
                end
            end

            S_FW_SPI_BIT_HI: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= {26'h0, 1'b0, 1'b1, 3'h0, fw_shift[63]};
                if (flash_cfg_ready) begin
                    state <= S_FW_SPI_BIT_CAP;
                end
            end

            S_FW_SPI_BIT_CAP: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0000;
                if (flash_cfg_ready) begin
                    if (fw_capture_status && fw_bit_idx >= 7'd8) begin
                        fw_status <= {fw_status[6:0], flash_cfg_rdata[1]};
                    end
                    fw_shift <= {fw_shift[62:0], 1'b0};
                    if (fw_bit_idx + 7'd1 == fw_bit_count) begin
                        state <= S_FW_SPI_END;
                    end else begin
                        fw_bit_idx <= fw_bit_idx + 7'd1;
                        state      <= S_FW_SPI_BIT_LO;
                    end
                end
            end

            S_FW_SPI_END: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b0001;
                flash_cfg_wdata <= 32'h0000_0020;  // CSB=1, CLK=0, MOSI=0
                if (flash_cfg_ready) begin
                    state <= fw_next_state;
                end
            end

            S_FW_RESTORE: begin
                flash_cfg_valid <= 1;
                flash_cfg_wstrb <= 4'b1000;
                flash_cfg_wdata <= 32'h8000_0000;  // config_en = 1
                if (flash_cfg_ready) begin
                    state <= fw_next_state;
                end
            end

            S_FW_XIP_READ: begin
                flash_xip_valid <= 1;
                flash_xip_addr  <= {8'd0, FLASH_TEST_ADDR};
                flash_xip_wstrb <= 4'h0;
                if (flash_xip_ready) begin
                    readback <= flash_xip_rdata;
                    state    <= S_FW_COMPARE;
                end
            end

            S_FW_COMPARE: begin
                print_buf[0] <= "F"; print_buf[1] <= "L"; print_buf[2] <= "A";
                print_buf[3] <= "S"; print_buf[4] <= "H"; print_buf[5] <= ":";
                print_buf[6] <= " ";
                print_buf[7]  <= hex_nibble(readback[31:28]);
                print_buf[8]  <= hex_nibble(readback[27:24]);
                print_buf[9]  <= hex_nibble(readback[23:20]);
                print_buf[10] <= hex_nibble(readback[19:16]);
                print_buf[11] <= hex_nibble(readback[15:12]);
                print_buf[12] <= hex_nibble(readback[11:8]);
                print_buf[13] <= hex_nibble(readback[7:4]);
                print_buf[14] <= hex_nibble(readback[3:0]);
                print_buf[15] <= " ";
                if (readback == FLASH_TEST_DATA) begin
                    print_buf[16] <= "P"; print_buf[17] <= "A";
                    print_buf[18] <= "S"; print_buf[19] <= "S";
                end else begin
                    print_buf[16] <= "F"; print_buf[17] <= "A";
                    print_buf[18] <= "I"; print_buf[19] <= "L";
                end
                print_buf[20] <= 8'h0D;
                print_buf[21] <= 8'h0A;
                print_len     <= 5'd22;
                return_state  <= S_DONE;
                state         <= S_PRINT;
            end

            S_PRINT: begin
                uart_tx_valid <= 1'b1;
                uart_tx_data  <= print_buf[print_idx];
                if (uart_tx_ready && uart_tx_valid) begin
                    if (print_idx == print_len - 1) begin
                        uart_tx_valid <= 1'b0;
                        print_idx     <= 5'd0;
                        state         <= return_state;
                    end else begin
                        print_idx    <= print_idx + 5'd1;
                        uart_tx_data <= print_buf[print_idx + 5'd1];
                    end
                end
            end

            S_INIT_WAIT: begin
                if (millisecond_tick) state <= S_WRITE;
            end

            S_DONE: begin
                // Hold LEDs, do nothing
            end

        endcase

        // Reset overrides everything above
        if (sysclk_resetn == 1'b0) begin
            state           <= S_INIT_WAIT;
            readback        <= 0;
            leds            <= 0;
            uart_tx_valid   <= 1'b0;
            uart_rx_ready   <= 1'b0;
            print_idx       <= 5'd0;
            hram_init_us    <= 8'd0;
            jedec_bit_idx   <= 6'd0;
            jedec_id_in     <= 24'h0;
            fw_shift        <= 64'd0;
            fw_bit_idx      <= 7'd0;
            fw_bit_count    <= 7'd0;
            fw_status       <= 8'd0;
            fw_poll_ms      <= 10'd0;
            fw_capture_status <= 1'b0;
            fw_next_state   <= S_DONE;
            ram_valid       <= 0;
            ram_addr        <= 0;
            ram_wdata       <= 0;
            ram_wstrb       <= 0;
            flash_cfg_valid <= 0;
            flash_cfg_addr  <= 0;
            flash_cfg_wdata <= 0;
            flash_cfg_wstrb <= 0;
            flash_xip_valid <= 0;
            flash_xip_addr  <= 0;
            flash_xip_wdata <= 0;
            flash_xip_wstrb <= 0;
        end
    end

endmodule
