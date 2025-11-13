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
// DESCRIPTION : Helper functions / tasks.
//
// -------------------------------------------------------------------------

package util;

    // ----------------------------------------------
    //  Types
    // ----------------------------------------------

    typedef int int_array_t[];


    // ----------------------------------------------
    //  Functions
    // ----------------------------------------------

    function automatic int log2ceil_min1;
        input int x;
    begin
        if (x == 0) begin
            return 1;
        end
        if (x == 1) begin
            return 1;
        end

        return $clog2(x);
    end endfunction : log2ceil_min1

    function automatic int is_pow2;
        input int x;
    begin
        if (x == 0) begin
            return 0;
        end

        return (x & (x-1)) ? 0 : 1;
    end endfunction : is_pow2

    function automatic int max;
        input int x;
        input int y;
    begin
        if (x > y) begin
            return x;
        end

        return y;
    end endfunction : max

    function automatic logic [0:0] int_to_bit;
        input int int_in;
    begin
        int_to_bit = |int_in;
    end endfunction : int_to_bit

    function automatic logic [7:0] lfsr_8bit_next;
        input logic [7:0] lfsr_in;
    begin
        lfsr_8bit_next[7:1] = lfsr_in[6:0];
        lfsr_8bit_next[0] = (lfsr_in[7] ^ lfsr_in[5] ^ lfsr_in[4] ^ lfsr_in[3]);
    end endfunction : lfsr_8bit_next

    function automatic logic [12:0] lfsr_13bit_next;
        input logic [12:0] lfsr_in;
    begin
        lfsr_13bit_next[12:1] = lfsr_in[11:0];
        lfsr_13bit_next[0] = (lfsr_in[12] ^ lfsr_in[11] ^ lfsr_in[10] ^ lfsr_in[7]);
    end endfunction : lfsr_13bit_next

    function automatic logic [13:0] lfsr_14bit_next;
        input logic [13:0] lfsr_in;
    begin
        lfsr_14bit_next[13:1] = lfsr_in[12:0];
        lfsr_14bit_next[0] = (lfsr_in[13] ^ lfsr_in[12] ^ lfsr_in[11] ^ lfsr_in[1]);
    end endfunction : lfsr_14bit_next

    function automatic logic [14:0] lfsr_15bit_next;
        input logic [14:0] lfsr_in;
    begin
        lfsr_15bit_next[14:1] = lfsr_in[13:0];
        lfsr_15bit_next[0] = (lfsr_in[14] ^ lfsr_in[13]);
    end endfunction : lfsr_15bit_next

    function automatic logic [15:0] lfsr_16bit_next;
        input logic [15:0] lfsr_in;
    begin
        lfsr_16bit_next[15:1] = lfsr_in[14:0];
        lfsr_16bit_next[0] = (lfsr_in[15] ^ lfsr_in[14] ^ lfsr_in[12] ^ lfsr_in[3]);
    end endfunction : lfsr_16bit_next

    function automatic logic [16:0] lfsr_17bit_next;
        input logic [16:0] lfsr_in;
    begin
        lfsr_17bit_next[16:1] = lfsr_in[15:0];
        lfsr_17bit_next[0] = (lfsr_in[16] ^ lfsr_in[13]);
    end endfunction : lfsr_17bit_next

    function automatic logic [31:0] lfsr_32bit_next;
        input logic [31:0] lfsr_in;
    begin
        lfsr_32bit_next[31:1] = lfsr_in[30:0];
        lfsr_32bit_next[0] = (lfsr_in[31] ^ lfsr_in[21] ^ lfsr_in[1] ^ lfsr_in[0]);
    end endfunction : lfsr_32bit_next

    function automatic logic [31:0] lfsr_32bit_next_alt;
        input logic [31:0] lfsr_in;
    begin
        lfsr_32bit_next_alt[31:1] = lfsr_in[30:0];
        lfsr_32bit_next_alt[0] = (lfsr_in[23] ^ lfsr_in[21] ^ lfsr_in[7] ^ lfsr_in[0]);
    end endfunction : lfsr_32bit_next_alt


endpackage : util