// -------------------------------------------------------------------------
// COPYRIGHT (C) 2025, BRISBANE SILICON, PTY LTD.
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
// DESCRIPTION : Default user firmware.
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
    //  Implementation
    // ----------------------------------------------

    assign io = 32'hzzzz_zzzz;

    always @(posedge sysclk) begin
        uart_tx_valid   <= 1'b0;
        uart_tx_data    <= 8'd0;
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

        if (second_tick) begin
            leds <= ~leds;
        end

        if (sysclk_resetn == 1'b0) begin
            leds <= 6'd0;
        end
    end

endmodule
