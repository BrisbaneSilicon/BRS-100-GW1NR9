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

    localparam S_WRITE   = 2'd0;
    localparam S_READ    = 2'd1;
    localparam S_COMPARE = 2'd2;
    localparam S_DONE    = 2'd3;


    // ----------------------------------------------
    //  Internal signals
    // ----------------------------------------------

    reg [1:0]  state;
    reg [31:0] readback;


    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------

    always @(posedge sysclk) begin

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
                // Compare and light LEDs
                leds[0] <= 1;   // test done
                if (readback == 32'h5445_5354) begin
                    leds[1] <= 1;   // PASS
                end else begin
                    leds[2] <= 1;   // FAIL
                end
                state <= S_DONE;
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
