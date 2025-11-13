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

module uart #(
    parameter int       OUTPUT_BUFFER_ENABLE,
    parameter int       INPUT_BUFFER_ENABLE,

    parameter int       INC_RX_ESC_SEQUENCE_FILTER
)(
    input               clk,

    input               resetn,

    input               rx_esc_seq_filter_disable,

    input       [15:0]  divider,

    output              ser_tx,
    input               ser_rx,

    input               tx_valid,
    output reg          tx_ready,
    input       [7:0]   tx_data,

    output reg          rx_valid,
    input               rx_ready,
    output reg  [7:0]   rx_data
);
localparam SUPPORT_ESCAPE_SEQUENCE_HOME_END         = 0;

localparam  [7:0] ASCII_CHAR_NULL                   = 8'h00;
localparam  [7:0] ASCII_CHAR_BACKSPACE              = 8'h08;
localparam  [7:0] ASCII_CHAR_NEWLINE                = 8'h0A;
localparam  [7:0] ASCII_CHAR_CARRIAGE_RETURN        = 8'h0D;
localparam  [7:0] ASCII_CHAR_ESCAPE                 = 8'h1B;
localparam  [7:0] ASCII_CHAR_SPACE                  = 8'h20;
localparam  [7:0] ASCII_CHAR_ONE                    = 8'h31;
localparam  [7:0] ASCII_CHAR_TWO                    = 8'h32;
localparam  [7:0] ASCII_CHAR_THREE                  = 8'h33;
localparam  [7:0] ASCII_CHAR_FOUR                   = 8'h34;
localparam  [7:0] ASCII_CHAR_FIVE                   = 8'h35;
localparam  [7:0] ASCII_CHAR_SIX                    = 8'h36;
localparam  [7:0] ASCII_CHAR_SEVEN                  = 8'h37;
localparam  [7:0] ASCII_CHAR_EIGHT                  = 8'h38;
localparam  [7:0] ASCII_CHAR_NINE                   = 8'h39;
localparam  [7:0] ASCII_CHAR_UPPERCASE_A            = 8'h41;
localparam  [7:0] ASCII_CHAR_UPPERCASE_B            = 8'h42;
localparam  [7:0] ASCII_CHAR_UPPERCASE_C            = 8'h43;
localparam  [7:0] ASCII_CHAR_UPPERCASE_D            = 8'h44;
localparam  [7:0] ASCII_CHAR_UPPERCASE_E            = 8'h45;
localparam  [7:0] ASCII_CHAR_UPPERCASE_F            = 8'h46;
localparam  [7:0] ASCII_CHAR_UPPERCASE_G            = 8'h47;
localparam  [7:0] ASCII_CHAR_UPPERCASE_H            = 8'h48;
localparam  [7:0] ASCII_CHAR_SQUARE_BRACKET_OPEN    = 8'h5B;
localparam  [7:0] ASCII_CHAR_TILDA                  = 8'h7E;
localparam  [7:0] ASCII_CHAR_DEL                    = 8'h7F;

localparam  [7:0] CUSTOM_LEFT_ARROW                 = 8'h11;
localparam  [7:0] CUSTOM_RIGHT_ARROW                = 8'h12;
localparam  [7:0] CUSTOM_UP_ARROW                   = 8'h13;
localparam  [7:0] CUSTOM_DOWN_ARROW                 = 8'h14;
localparam  [7:0] CUSTOM_HOME                       = 8'h15;
localparam  [7:0] CUSTOM_END                        = 8'h16;


    reg [15:0]  i_cfg_divider;
    reg [15:0]  i_cfg_divider_half;
    reg         i_divider_configured_p1 = 1'b0;
    reg         i_divider_configured    = 1'b0;

    reg         i_recv_buffer_reset;
    reg [3:0]   i_recv_state;
    reg [15:0]  i_recv_divcnt;
    reg         i_recv_divcnt_larger_cfg_divider_half;
    reg         i_recv_divcnt_larger_cfg_divider;
    reg [7:0]   i_recv_pattern;
    reg         i_recv_data_valid;
    reg         i_recv_data_ready;
    reg [7:0]   i_recv_data;

    reg         i_rx_esc_seq_filter_disable_reg;
    reg [3:0]   i_recv_filtr_state;
    reg [7:0]   i_recv_data_filtrd;
    reg [7:0]   i_recv_data_filtrd_prev;

    reg         i_recv_wr_data_valid;
    reg         i_recv_wr_data_ready;
    reg [7:0]   i_recv_wr_data;
    reg         i_recv_rd_data_valid;
    reg         i_recv_rd_data_ready;
    reg [7:0]   i_recv_rd_data;
    reg         i_recv_fifo_overflow;

    reg [9:0]   i_send_pattern;
    reg [4:0]   i_send_bitcnt;
    reg [15:0]  i_send_divcnt;
    reg         i_send_divcnt_larger_cfg_divider;
    reg         i_tx_wr_data_ready;
    reg         i_tx_rd_data_valid;
    reg         i_tx_rd_data_ready;
    reg [7:0]   i_tx_rd_data;



    // NOTE: Outputs
    // ------------

    assign tx_ready     = i_tx_wr_data_ready;

    assign ser_tx       = i_send_pattern[0];


    // NOTE: RX Side
    // ------------

    always @(posedge clk) begin
        // defaults
        i_cfg_divider_half      <= { 1'b0, i_cfg_divider[15:1] };

        i_divider_configured    <= i_divider_configured_p1;

        i_recv_buffer_reset     <= ~i_divider_configured;

        i_cfg_divider           <= divider;
        i_divider_configured_p1 <= 1'b1;

        if (resetn == 1'b0) begin
            i_divider_configured_p1 <= 1'b0;
        end
    end

    always @(posedge clk) begin
        // defaults
        i_recv_divcnt <= i_recv_divcnt + 1;

        // default clauses
        if (i_recv_data_ready == 1'b1 || i_recv_buffer_reset == 1'b1) begin
            i_recv_data_valid <= 1'b0;
        end

        if (i_recv_divcnt > i_cfg_divider_half) begin
            i_recv_divcnt_larger_cfg_divider_half <= 1'b1;
        end else begin
            i_recv_divcnt_larger_cfg_divider_half <= 1'b0;
        end
        if (i_recv_divcnt > i_cfg_divider) begin
            i_recv_divcnt_larger_cfg_divider <= 1'b1;
        end else begin
            i_recv_divcnt_larger_cfg_divider <= 1'b0;
        end

        case (i_recv_state)
            0: begin
                i_recv_divcnt                           <= 1;
                i_recv_divcnt_larger_cfg_divider_half   <= 1'b0;

                if (!ser_rx) begin
                    i_recv_state <= 1;
                end
            end
            1: begin
                if (i_recv_divcnt_larger_cfg_divider_half == 1'b1) begin
                    i_recv_divcnt   <= 1;

                    i_recv_state    <= 2;
                end
            end
            default: begin
                if (i_recv_divcnt_larger_cfg_divider == 1'b1) begin
                    i_recv_pattern                      <= {ser_rx, i_recv_pattern[7:1]};
                    i_recv_divcnt                       <= 1;
                    i_recv_divcnt_larger_cfg_divider    <= 1'b0;

                    i_recv_state                        <= i_recv_state + 1;
                end
            end
            10: begin
                if (i_recv_divcnt_larger_cfg_divider == 1'b1) begin
                    i_recv_data_valid    <= 1'b1;
                    i_recv_data          <= i_recv_pattern;

                    if (i_recv_data_valid == 1'b1) begin
                        i_recv_fifo_overflow <= 1'b1;
                    end

                    i_recv_state <= 0;
                end
            end

        endcase


        if (resetn == 1'b0 || i_divider_configured == 1'b0) begin
            i_recv_data_valid       <= 0;
            i_recv_fifo_overflow    <= 1'b0;
                // TODO: expose the overflow flag to CPU ?

            i_recv_state            <= 0;
        end
    end

    generate
        if (INC_RX_ESC_SEQUENCE_FILTER) begin

            always @(posedge clk) begin
                // defaults
                i_recv_data_ready               <= 1'b0;

                i_recv_wr_data_valid            <= 1'b0;

                i_rx_esc_seq_filter_disable_reg <= rx_esc_seq_filter_disable;


                case (i_recv_filtr_state)
                    0: begin
                        // default
                        i_recv_data_ready <= 1'b1;

                        if (i_recv_data_valid == 1'b1 && i_recv_data_ready == 1'b1) begin
                            i_recv_data_ready <= 1'b0;

                            if (i_rx_esc_seq_filter_disable_reg == 1'b0) begin
                                i_recv_data_filtrd      <= i_recv_data;
                                i_recv_data_filtrd_prev <= i_recv_data_filtrd;

                                i_recv_filtr_state      <= 1;
                            end else begin
                                i_recv_wr_data          <= i_recv_data;
                                i_recv_wr_data_valid    <= 1'b1;

                                i_recv_filtr_state      <= 8;
                            end
                        end
                    end
                    1: begin
                        if (i_recv_data_filtrd == ASCII_CHAR_ESCAPE) begin
                            i_recv_filtr_state <= 0;
                        end else begin
                            i_recv_filtr_state <= 2;
                        end
                    end
                    2: begin
                        if ((i_recv_data_filtrd == ASCII_CHAR_SQUARE_BRACKET_OPEN) &&
                                (i_recv_data_filtrd_prev == ASCII_CHAR_ESCAPE)) begin
                            i_recv_filtr_state <= 3;
                        end else begin
                            // default
                            i_recv_filtr_state <= 0;

                            if ((i_recv_data_filtrd >= ASCII_CHAR_SPACE) &&
                                (i_recv_data_filtrd < ASCII_CHAR_DEL)) begin
                                    i_recv_wr_data          <= i_recv_data_filtrd;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                            end
                            if (i_recv_data_filtrd == ASCII_CHAR_DEL) begin
                                i_recv_wr_data          <= ASCII_CHAR_BACKSPACE;
                                i_recv_wr_data_valid    <= 1'b1;

                                i_recv_filtr_state      <= 8;
                            end
                            if ((i_recv_data_filtrd == ASCII_CHAR_BACKSPACE) ||
                                (i_recv_data_filtrd == ASCII_CHAR_NEWLINE)) begin
                                    i_recv_wr_data          <= i_recv_data_filtrd;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                            end
                            if (i_recv_data_filtrd == ASCII_CHAR_CARRIAGE_RETURN) begin
                                i_recv_wr_data          <= ASCII_CHAR_NEWLINE;
                                i_recv_wr_data_valid    <= 1'b1;

                                i_recv_filtr_state      <= 8;
                            end

                        end
                    end
                    3: begin
                        // default
                        i_recv_data_ready <= 1'b1;

                        if (i_recv_data_valid == 1'b1 && i_recv_data_ready == 1'b1) begin
                            i_recv_data_ready       <= 1'b0;

                            i_recv_data_filtrd      <= i_recv_data;
                            i_recv_data_filtrd_prev <= i_recv_data_filtrd;

                            i_recv_filtr_state      <= 4;
                        end
                    end
                    4: begin
                        // default
                        i_recv_filtr_state <= 5;

                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_A) begin
                            i_recv_wr_data          <= CUSTOM_UP_ARROW;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_B) begin
                            i_recv_wr_data          <= CUSTOM_DOWN_ARROW;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_C) begin
                            i_recv_wr_data          <= CUSTOM_RIGHT_ARROW;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_D) begin
                            i_recv_wr_data          <= CUSTOM_LEFT_ARROW;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_H) begin
                            i_recv_wr_data          <= CUSTOM_HOME;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                        if (i_recv_data_filtrd == ASCII_CHAR_UPPERCASE_F) begin
                            i_recv_wr_data          <= CUSTOM_END;
                            i_recv_wr_data_valid    <= 1'b1;

                            i_recv_filtr_state      <= 8;
                        end
                            end
                    5: begin
                        // default
                        i_recv_data_ready <= 1'b1;

                        if (i_recv_data_valid == 1'b1 && i_recv_data_ready == 1'b1) begin
                            i_recv_data_ready       <= 1'b0;

                            i_recv_data_filtrd      <= i_recv_data;
                            i_recv_data_filtrd_prev <= i_recv_data_filtrd;

                            i_recv_filtr_state      <= 6;
                        end
                    end
                    6: begin
                        if (i_recv_data_filtrd == ASCII_CHAR_TILDA) begin
                            // default
                            i_recv_filtr_state <= 0;

                            if (i_recv_data_filtrd_prev == ASCII_CHAR_THREE) begin
                                i_recv_wr_data          <= ASCII_CHAR_DEL;
                                i_recv_wr_data_valid    <= 1'b1;

                                i_recv_filtr_state      <= 8;
                            end

                            if (SUPPORT_ESCAPE_SEQUENCE_HOME_END) begin
                                if (i_recv_data_filtrd_prev == ASCII_CHAR_ONE) begin
                                    i_recv_wr_data          <= CUSTOM_HOME;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                                end
                                if (i_recv_data_filtrd_prev == ASCII_CHAR_FOUR) begin
                                    i_recv_wr_data          <= CUSTOM_END;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                                end
                                if (i_recv_data_filtrd_prev == ASCII_CHAR_SEVEN) begin
                                    i_recv_wr_data          <= CUSTOM_HOME;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                                end
                                if (i_recv_data_filtrd_prev == ASCII_CHAR_EIGHT) begin
                                    i_recv_wr_data          <= CUSTOM_END;
                                    i_recv_wr_data_valid    <= 1'b1;

                                    i_recv_filtr_state      <= 8;
                                end
                            end
                        end else begin
                            i_recv_filtr_state <= 0;
                        end
                    end

                    8: begin
                        // default
                        i_recv_wr_data_valid    <= 1'b1;

                        i_recv_data_filtrd_prev <= ASCII_CHAR_NULL;

                        if (i_recv_wr_data_valid == 1'b1 && i_recv_wr_data_ready == 1'b1) begin
                            i_recv_wr_data_valid    <= 1'b0;

                            i_recv_filtr_state      <= 0;
                        end
                    end

                    default: begin
                        i_recv_filtr_state <= 0;
                    end

                endcase

                if (resetn == 1'b0) begin
                    i_recv_data_ready       <= 1'b0;

                    i_recv_data_filtrd_prev <= ASCII_CHAR_NULL;

                    i_recv_wr_data_valid    <= 1'b0;

                    i_recv_filtr_state      <= 0;
                end
            end

        end else begin
            assign i_recv_wr_data       = i_recv_data;
            assign i_recv_wr_data_valid = i_recv_data_valid;

            assign i_recv_data_ready    = i_recv_wr_data_ready;

        end
    endgenerate

    generate
        if (INPUT_BUFFER_ENABLE) begin
            axis_fifo_sync
            #(
                .g_data_bits    ($size(i_recv_wr_data)),
                .g_depth        (128)
            ) rx_buffer_inst
            (
                .clk            (clk),
                .srst           (i_recv_buffer_reset),

                .s_tvalid       (i_recv_wr_data_valid),
                .s_tready       (i_recv_wr_data_ready),
                .s_tdata        (i_recv_wr_data),

                .m_tvalid       (i_recv_rd_data_valid),
                .m_tready       (i_recv_rd_data_ready),
                .m_tdata        (i_recv_rd_data)
            );
        end else begin
            axis_skid_buffer_fp_opt
            #(
                .pDATA_LEN      ($size(i_recv_wr_data)),
                .pID_LEN        (1),
                .pUSER_LEN      (1)
            ) rx_skid_buffer_inst
            (
                .clk            (clk),
                .srst           (i_recv_buffer_reset),

                .s_valid        (i_recv_wr_data_valid),
                .s_ready        (i_recv_wr_data_ready),
                .s_data         (i_recv_wr_data),

                .m_valid        (i_recv_rd_data_valid),
                .m_ready        (i_recv_rd_data_ready),
                .m_data         (i_recv_rd_data)
            );
        end
    endgenerate

    always_comb begin
        i_recv_rd_data_ready    = rx_ready;

        rx_valid                = i_recv_rd_data_valid & resetn;
        rx_data                 = i_recv_rd_data;
    end


    // -- TX Side
    // ------------

    generate
        if (OUTPUT_BUFFER_ENABLE) begin
            axis_fifo_sync
            #(
                .g_data_bits    (8),
                .g_depth        (128)
            ) tx_buffer_inst
            (
                .clk            (clk),
                .srst           (~resetn),

                .s_tvalid       (tx_valid),
                .s_tready       (i_tx_wr_data_ready),
                .s_tdata        (tx_data[7:0]),

                .m_tvalid       (i_tx_rd_data_valid),
                .m_tready       (i_tx_rd_data_ready),
                .m_tdata        (i_tx_rd_data)
            );
        end else begin
            axis_skid_buffer_fp_opt
            #(
                .pDATA_LEN      ($size(tx_data[7:0])),
                .pID_LEN        (1),
                .pUSER_LEN      (1)
            ) tx_skid_buffer_inst
            (
                .clk            (clk),
                .srst           (~resetn),

                .s_valid        (tx_valid),
                .s_ready        (i_tx_wr_data_ready),
                .s_data         (tx_data[7:0]),

                .m_valid        (i_tx_rd_data_valid),
                .m_ready        (i_tx_rd_data_ready),
                .m_data         (i_tx_rd_data)
            );
        end
    endgenerate

    always @(posedge clk) begin
        // defaults
        i_tx_rd_data_ready  <= 1'b0;
        i_send_divcnt       <= i_send_divcnt + 1;

        if (i_send_divcnt > i_cfg_divider) begin
            i_send_divcnt_larger_cfg_divider <= 1'b1;
        end else begin
            i_send_divcnt_larger_cfg_divider <= 1'b0;
        end

        if (i_tx_rd_data_valid && !i_send_bitcnt) begin
            i_send_pattern                      <= {1'b1, i_tx_rd_data, 1'b0};
            i_send_bitcnt                       <= 20;
                // NOTE: delay of at least one
                // characters, to avoid confusing
                // some receivers..

            i_send_divcnt                       <= 1;
            i_send_divcnt_larger_cfg_divider    <= 1'b0;

            i_tx_rd_data_ready                  <= 1'b1;
        end else begin
            if (i_send_divcnt_larger_cfg_divider && i_send_bitcnt) begin
                i_send_pattern                      <= {1'b1, i_send_pattern[9:1]};
                i_send_bitcnt                       <= i_send_bitcnt - 1;

                i_send_divcnt                       <= 1;
                i_send_divcnt_larger_cfg_divider    <= 1'b0;
            end
        end

        if (resetn == 1'b0 || i_divider_configured == 1'b0) begin
            i_send_bitcnt       <= 0;

            i_tx_rd_data_ready  <= 1'b0;
        end
    end

endmodule
