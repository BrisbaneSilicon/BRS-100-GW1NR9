`timescale 1ns / 1ps

import util::*;

module top_tb();

    localparam CLK_PERIOD                               = 2.5;
    localparam CLK_FREQUENCY_HZ                         = 200000000;

    localparam VERSION_CHARS                            = 36;

    parameter reg   [(8*VERSION_CHARS)-1:0] VERSION     = "TEST";



    reg                                             i_clk           = 1'b0;
    reg                                             i_srst_n        = 1'b0;

    reg     [12:0]                                  i_stim_lfsr13   = ~0;
    reg     [13:0]                                  i_stim_lfsr14   = ~0;


    reg                                             i_button_1;
    reg                                             i_button_2;

    reg                                             i_locked;
    reg     [CORES-1:0]                     [5:0]   i_leds;

    reg     [CORES-1:0]                             i_user_comms_uart_rxd;
    reg     [CORES-1:0]                             i_user_comms_uart_txd;

    logic   [(MAX_IO_PER_CORE*CORES)-1:0]           i_io;


    // NOTE: TB
    // ----------

    initial begin
        forever begin
            i_clk = #CLK_PERIOD ~i_clk;
        end
    end

    initial begin
        i_stim_lfsr13 <= ~0;
        i_stim_lfsr14 <= ~0;

        forever begin
            @(posedge i_clk);

            i_stim_lfsr13 <= lfsr_13bit_next(i_stim_lfsr13);
            i_stim_lfsr14 <= lfsr_14bit_next(i_stim_lfsr14);
        end
    end


    // Inputs
    // --------

    assign i_button_1               = 1'b0;
    assign i_button_2               = 1'b0;

    assign i_user_comms_uart_rxd[0] = ~0;


    // NOTE: UUT
    // ----------

    top #(
        .VERSION                        (VERSION),

        .CLK_FREQUENCY_HZ               (CLK_FREQUENCY_HZ)
    ) top_inst (
        .sysclk                         (i_clk),
        .sysclk_resetn                  (i_srst_n),

        .user_pushbutton_reset          ({i_button_2, i_button_1}),

        .leds                           (i_leds),

        .io                             (),

        .user_comms_uart_rx             (i_user_comms_uart_rxd),
        .user_comms_uart_tx             (i_user_comms_uart_txd),
        .user_comms_uart_tx_interrupt   (),

        .qspi_dq                        (),
        .qspi_cs                        ()
    );


    initial begin
        $display("STIM: BEGIN");

        i_srst_n <= 1'b0;
        repeat (100)
            @(posedge i_clk);

        $display("STIM: UUT de-assert SRST");
        i_srst_n <= 1'b1;
        repeat (100)
            @(posedge i_clk);


        repeat (10000)
            @(posedge i_clk);

        $display("STIM: END");
        $stop();
    end

endmodule
