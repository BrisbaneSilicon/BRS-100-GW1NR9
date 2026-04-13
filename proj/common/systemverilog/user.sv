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

    localparam S_WRITE        = 4'd0;
    localparam S_READ         = 4'd1;
    localparam S_COMPARE      = 4'd2;
    localparam S_HRAM_WAIT    = 4'd3;   // wait for HyperRAM controller init (~160us)
    localparam S_HRAM_WRITE   = 4'd4;
    localparam S_HRAM_READ    = 4'd5;
    localparam S_HRAM_COMPARE = 4'd6;
    localparam S_DONE         = 4'd7;
    localparam S_PRINT        = 4'd8;
    localparam S_FLASH_READ   = 4'd9;
    localparam S_FLASH_RESULT = 4'd10;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    reg [3:0]  state;
    reg [31:0] readback;

    reg [7:0]  print_buf [0:23];
    reg [4:0]  print_idx;
    reg [4:0]  print_len;
    reg [3:0]  return_state;

    reg [7:0]  hram_init_us;    // counts microsecond ticks during HyperRAM init wait


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
                // Write "TEST" (0x54455354) to SRAM address 0
                ram_valid <= 1;
                ram_addr  <= 32'h0000_0000;
                ram_wdata <= 32'h5445_5354;
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
                if (readback == 32'h5445_5354) begin
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
                ram_wdata <= 32'h5445_5354;
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
                if (readback == 32'h5445_5354) begin
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
                return_state <= S_FLASH_READ;
                state        <= S_PRINT;
            end

            S_FLASH_READ: begin
                flash_xip_valid <= 1;
                flash_xip_addr  <= 32'h0000_0000;
                if (flash_xip_ready) begin
                    readback <= flash_xip_rdata;
                    state    <= S_FLASH_RESULT;
                end
            end

            S_FLASH_RESULT: begin
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
                print_buf[16] <= "P"; print_buf[17] <= "A";
                print_buf[18] <= "S"; print_buf[19] <= "S";
                print_buf[20] <= 8'h0D;
                print_buf[21] <= 8'h0A;
                print_len    <= 5'd22;
                return_state <= S_DONE;
                state        <= S_PRINT;
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

            S_DONE: begin
                // Hold LEDs, do nothing
            end

        endcase

        // Reset overrides everything above
        if (sysclk_resetn == 1'b0) begin
            state           <= S_WRITE;
            readback        <= 0;
            leds            <= 0;
            uart_tx_valid   <= 1'b0;
            uart_rx_ready   <= 1'b0;
            print_idx       <= 5'd0;
            hram_init_us    <= 8'd0;
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

    assign io = 0;

endmodule
