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
    input       [7:0]   uart_rx_data
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
        eIDLE
    } tDEMONSTRATE_SYSTEM_STATE;

    typedef enum {
        eRESET_SCREEN,
        eOUTPUT_BEGIN_MSG,
        eOUTPUT_NLCR_1,
        eOUTPUT_VERSION_MSG,
        eOUTPUT_NLCR_2,
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


    // ----------------------------------------------
    //  Implementation
    // ----------------------------------------------

    always @(posedge sysclk) begin
        // defaults
        uart_tx_valid <= 1'b0;
        uart_rx_ready <= 1'b0;

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
                    i_next_startup_task                     <= eNONE;
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
