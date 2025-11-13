`timescale 1ns/1ps

module mbus_mux4 #(
    parameter MUX_IND_LOWER,
    parameter MUX_IND_UPPER,

    parameter PICOS0_ADDR_BASE,
    parameter PICOS1_ADDR_BASE,
    parameter PICOS2_ADDR_BASE,
    parameter PICOS3_ADDR_BASE
) (
    input       [31:0]  picom_addr,
    input       [31:0]  picom_wdata,
    input       [3:0]   picom_wstrb,
    output  reg [31:0]  picom_rdata,
    output  reg         picom_ready,
    input               picom_valid,


    output      [31:0]  picos0_addr,
    output      [31:0]  picos0_wdata,
    output      [3:0]   picos0_wstrb,
    input       [31:0]  picos0_rdata,
    output reg          picos0_valid,
    input               picos0_ready,

    output      [31:0]  picos1_addr,
    output      [31:0]  picos1_wdata,
    output      [3:0]   picos1_wstrb,
    input       [31:0]  picos1_rdata,
    output reg          picos1_valid,
    input               picos1_ready,

    output      [31:0]  picos2_addr,
    output      [31:0]  picos2_wdata,
    output      [3:0]   picos2_wstrb,
    input       [31:0]  picos2_rdata,
    output reg          picos2_valid,
    input               picos2_ready,

    output      [31:0]  picos3_addr,
    output      [31:0]  picos3_wdata,
    output      [3:0]   picos3_wstrb,
    input       [31:0]  picos3_rdata,
    output reg          picos3_valid,
    input               picos3_ready
);

    wire picos0_match;
    wire picos1_match;
    wire picos2_match;
    wire picos3_match;


    assign picos0_match = (picom_addr[MUX_IND_UPPER:MUX_IND_LOWER] == PICOS0_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]) ? 1'b1 : 1'b0;
    assign picos1_match = (picom_addr[MUX_IND_UPPER:MUX_IND_LOWER] == PICOS1_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]) ? 1'b1 : 1'b0;
    assign picos2_match = (picom_addr[MUX_IND_UPPER:MUX_IND_LOWER] == PICOS2_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]) ? 1'b1 : 1'b0;
    assign picos3_match = (picom_addr[MUX_IND_UPPER:MUX_IND_LOWER] == PICOS3_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]) ? 1'b1 : 1'b0;

    assign picos0_valid = picom_valid & picos0_match;
    assign picos0_addr  = picom_addr;
    assign picos0_wdata = picom_wdata;
    assign picos0_wstrb = picom_wstrb;

    assign picos1_valid = picom_valid & picos1_match;
    assign picos1_addr  = picom_addr;
    assign picos1_wdata = picom_wdata;
    assign picos1_wstrb = picom_wstrb;

    assign picos2_valid = picom_valid & picos2_match;
    assign picos2_addr  = picom_addr;
    assign picos2_wdata = picom_wdata;
    assign picos2_wstrb = picom_wstrb;

    assign picos3_valid = picom_valid & picos3_match;
    assign picos3_addr  = picom_addr;
    assign picos3_wdata = picom_wdata;
    assign picos3_wstrb = picom_wstrb;

    always_comb begin
        case (picom_addr[MUX_IND_UPPER:MUX_IND_LOWER])
            PICOS0_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]: begin
                picom_rdata <= picos0_rdata;
                picom_ready <= picos0_ready;
            end
            PICOS1_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]: begin
                picom_rdata <= picos1_rdata;
                picom_ready <= picos1_ready;
            end
            PICOS2_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]: begin
                picom_rdata <= picos2_rdata;
                picom_ready <= picos2_ready;
            end
            PICOS3_ADDR_BASE[MUX_IND_UPPER:MUX_IND_LOWER]: begin
                picom_rdata <= picos3_rdata;
                picom_ready <= picos3_ready;
            end
        endcase
    end

endmodule


module mbus_mux2 #(
    parameter MUX_IND,

    parameter PICOS0_ADDR_BASE,
    parameter PICOS1_ADDR_BASE
) (
    input       [31:0]  picom_addr,
    input       [31:0]  picom_wdata,
    input       [3:0]   picom_wstrb,
    output  reg [31:0]  picom_rdata,
    output  reg         picom_ready,
    input               picom_valid,


    output      [31:0]  picos0_addr,
    output      [31:0]  picos0_wdata,
    output      [3:0]   picos0_wstrb,
    input       [31:0]  picos0_rdata,
    output reg          picos0_valid,
    input               picos0_ready,

    output      [31:0]  picos1_addr,
    output      [31:0]  picos1_wdata,
    output      [3:0]   picos1_wstrb,
    input       [31:0]  picos1_rdata,
    output reg          picos1_valid,
    input               picos1_ready
);

    wire picos0_match;
    wire picos1_match;


    assign picos0_match = (picom_addr[MUX_IND] == PICOS0_ADDR_BASE[MUX_IND]) ? 1'b1 : 1'b0;
    assign picos1_match = (picom_addr[MUX_IND] == PICOS1_ADDR_BASE[MUX_IND]) ? 1'b1 : 1'b0;

    assign picos0_valid = picom_valid & picos0_match;
    assign picos0_addr  = picom_addr;
    assign picos0_wdata = picom_wdata;
    assign picos0_wstrb = picom_wstrb;

    assign picos1_valid = picom_valid & picos1_match;
    assign picos1_addr  = picom_addr;
    assign picos1_wdata = picom_wdata;
    assign picos1_wstrb = picom_wstrb;

    always_comb begin
        case (picom_addr[MUX_IND])
            PICOS0_ADDR_BASE[MUX_IND]: begin
                picom_rdata <= picos0_rdata;
                picom_ready <= picos0_ready;
            end
            PICOS1_ADDR_BASE[MUX_IND]: begin
                picom_rdata <= picos1_rdata;
                picom_ready <= picos1_ready;
            end
        endcase
    end

endmodule