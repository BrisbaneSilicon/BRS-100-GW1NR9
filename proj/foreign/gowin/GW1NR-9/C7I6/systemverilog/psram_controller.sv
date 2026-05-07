module psram_controller #(
    parameter FREQ,
    parameter LATENCY
) (
    input               clk,
    input               clk_p,

    input               resetn,

    input               read,
    input               write,
    input       [21:0]  addr,
    input       [15:0]  din,
    input               byte_write,

    output reg  [15:0]  dout = 0,
    output reg          busy,

    output              psram_clk,
    output              psram_clk_n,
    inout               psram_rd_wr,
    inout       [7:0]   psram_data_q,
    output              psram_chip_sel_n
);

    reg [2:0] state;
    localparam [2:0] INIT_ST = 3'd0;
    localparam [2:0] CONFIG_ST= 3'd1;
    localparam [2:0] IDLE_ST = 3'd2;
    localparam [2:0] READ_ST = 3'd3;
    localparam [2:0] WRITE_ST = 3'd4;

    reg cfg_now, dq_oen, ram_cs_n, ck_e, ck_e_p;
    reg wait_for_rd_data;
    reg ub;
    reg [15:0] w_din;
    reg [23:0] cycles_sr;
    reg [63:0] dq_sr;


    wire [7:0] dq_out_ris = dq_sr[63:56];
    wire [7:0] dq_out_fal = dq_sr[55:48];
    wire [7:0] dq_in_ris;
    wire [7:0] dq_in_fal;
    reg rwds_out_ris, rwds_out_fal, rwds_oen;
    wire rwds_in_ris, rwds_in_fal;
    reg additional_latency;

    assign busy = (state != IDLE_ST);

    localparam [3:0] CR_LATENCY = LATENCY == 3 ? 4'b1110 :
                                  LATENCY == 4 ? 4'b1111 :
                                  LATENCY == 5 ? 4'b0 :
                                  LATENCY == 6 ? 4'b0001 : 4'b1110;


    always @(posedge clk) begin
        cycles_sr <= {cycles_sr[22:0], 1'b0};
        dq_sr <= {dq_sr[47:0], 16'b0};
        ck_e_p <= ck_e;

        if (state == INIT_ST && cfg_now) begin
            cycles_sr <= 24'b1;
            ram_cs_n <= 0;
            state <= CONFIG_ST;
        end
        if (state == CONFIG_ST) begin
            if (cycles_sr[0]) begin
                dq_sr <= {8'h60, 8'h00, 8'h01, 8'h00, 8'h00, 8'h00, 8'h8f, CR_LATENCY, 4'h7};
                dq_oen <= 0;
                ck_e <= 1;
            end
            if (cycles_sr[4]) begin
                state <= IDLE_ST;
                ck_e <= 0;
                cycles_sr <= 24'b1;
                dq_oen <= 1;
                ram_cs_n <= 1;
            end
        end
        if (state == IDLE_ST) begin
            rwds_oen <= 1;
            ck_e <= 0;
            ram_cs_n <= 1;
            if (read || write) begin

                dq_sr <= {~write, 13'b010_0000_0000_00, addr[21:4], 13'b0, addr[3:1], 16'b0000_0100_1101_0100};

                ram_cs_n <= 0;
                ck_e <= 1;
                dq_oen <= 0;
                wait_for_rd_data <= 0;
                w_din <= din;
                cycles_sr <= 32'b10;
                state <= write ? WRITE_ST : READ_ST;
            end
        end

        if (state == READ_ST)  begin
            if (cycles_sr[3]) begin

                dq_oen <= 1;
            end
            if (cycles_sr[2+LATENCY])
                wait_for_rd_data <= 1;
            if (wait_for_rd_data && (rwds_in_ris ^ rwds_in_fal)) begin
                dout        <= {dq_in_ris, dq_in_fal};
                ram_cs_n    <= 1;
                ck_e        <= 0;
                state       <= IDLE_ST;
            end
        end

        if (state == WRITE_ST) begin
            if (cycles_sr[5])
                additional_latency <= rwds_in_fal;


            if (cycles_sr[2+LATENCY] && (LATENCY == 3 ? ~rwds_in_fal : ~additional_latency)
                || cycles_sr[2+LATENCY*2])
            begin
                rwds_oen <= 0;
                rwds_out_ris <= byte_write ? ~addr[0] : 1'b0;
                rwds_out_fal <= byte_write ? addr[0] : 1'b0;
                dq_sr[63:48] <= w_din;
                state <= IDLE_ST;
            end
        end

        if (~resetn) begin
            ram_cs_n    <= 1;
            ck_e        <= 0;

            state       <= INIT_ST;
        end
    end


    localparam INIT_TIME = FREQ / 1000 * 160 / 1000;
    reg  [$clog2(INIT_TIME+1):0]   rst_cnt;
    reg rst_done, rst_done_p1, cfg_busy;

    always @(posedge clk) begin
        rst_done_p1 <= rst_done;
        cfg_now     <= rst_done & ~rst_done_p1;

        if (rst_cnt != INIT_TIME) begin
            rst_cnt  <= rst_cnt[$clog2(INIT_TIME+1):0] + 1;
            rst_done <= 0;
            cfg_busy <= 1;
        end else begin
            rst_done <= 1;
            cfg_busy <= 0;
        end

        if (~resetn) begin
            rst_cnt  <= 15'd0;
            rst_done <= 0;
            cfg_busy <= 1;
        end
    end

    wire ck_tbuf;
    wire cs_n_tbuf;
    wire rwds_tbuf;
    wire rwds_oen_tbuf;

    wire dq_out_tbuf[7:0];
    wire dq_oen_tbuf[7:0];


    genvar i1, i2;
    generate
        ODDR oddr_cs_n(
            .CLK(clk), .D0(ram_cs_n), .D1(ram_cs_n), .Q0(cs_n_tbuf)
        );
        assign psram_chip_sel_n = cs_n_tbuf;

        ODDR oddr_rwds(
            .CLK(clk), .D0(rwds_out_ris), .D1(rwds_out_fal), .TX(rwds_oen), .Q0(rwds_tbuf), .Q1(rwds_oen_tbuf)
        );
        assign psram_rd_wr = rwds_oen_tbuf ? 1'bz : rwds_tbuf;

        for (i1=0; i1<=7; i1=i1+1) begin: gen_i1
            ODDR oddr_dq_i1(
                .CLK(clk), .D0(dq_out_ris[i1]), .D1(dq_out_fal[i1]), .TX(dq_oen), .Q0(dq_out_tbuf[i1]), .Q1(dq_oen_tbuf[i1])
            );
            assign psram_data_q[i1] = dq_oen_tbuf[i1] ? 1'bz : dq_out_tbuf[i1];
        end

        ODDR oddr_ck(
            .CLK(clk_p), .D0(ck_e_p), .D1(1'b0), .Q0(ck_tbuf)
        );
        assign psram_clk = ck_tbuf;

        ODDR oddr_ck_n(
            .CLK(clk_p), .D0(~ck_e_p), .D1(1'b0), .Q0(ck_tbuf_n)
        );
        assign psram_clk_n = ck_tbuf_n;

        IDDR iddr_rwds(
            .CLK(clk), .D(psram_rd_wr), .Q0(rwds_in_ris), .Q1(rwds_in_fal)
        );

        for (i2=0; i2<=7; i2=i2+1) begin: gen_i2
            IDDR iddr_dq_i2(
                .CLK(clk), .D(psram_data_q[i2]), .Q0(dq_in_ris[i2]), .Q1(dq_in_fal[i2])
            );
        end
    endgenerate

endmodule