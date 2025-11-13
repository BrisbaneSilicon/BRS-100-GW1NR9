library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

library std;
use std.textio.all;

package utils is

    constant c_gnd_stdlogic     : std_logic := '0';
    constant c_vcc_stdlogic     : std_logic := '1';


    function max                (l, r: integer)                             return integer;
    function min                (l, r: integer)                             return integer;

    function or_reduce_us       (vector: unsigned)                          return std_logic;
    function and_reduce_us      (vector: unsigned)                          return std_logic;

    function log2ceil           (n: natural)                                return integer;
    function numbytes_toceil    (n: natural)                                return natural;

    function nat_to_bool        (n: natural)                                return boolean;
    function bool_to_sl         (b: boolean)                                return std_logic;

    procedure rand_int_with_limits  (
                                        variable seed1  : inout integer;
                                        variable seed2  : inout integer;
                                        min_lim         : in    integer;
                                        max_lim         : in    integer;
                                        rand_int        : out   integer
                                    );

end utils;

package body utils is

    function max                (l, r : integer)        return integer  is
    begin
        if l > r then
            return l;
        else
            return r;
        end if;
    end;

    function min                (l, r : integer)        return integer  is
    begin
        if l < r then
            return l;
        else
            return r;
        end if;
    end;


    function or_reduce_us       (vector: unsigned)      return std_logic is
    begin
        return or_reduce(std_logic_vector(vector));
    end function or_reduce_us;

    function and_reduce_us      (vector: unsigned)      return std_logic is
    begin
        return and_reduce(std_logic_vector(vector));
    end function and_reduce_us;


    function log2ceil           (n: natural)            return integer is
        variable v_i        : natural;
        variable v_n_slv    : std_logic_vector(64-1 downto 0);
    begin
        if n = 0 then
            return 0;
        end if;

        v_i     := 0;
        v_n_slv := std_logic_vector(to_unsigned(n-1, v_n_slv'length));
        while or_reduce(v_n_slv) = '1' loop
            v_n_slv := '0' & v_n_slv(v_n_slv'high downto 1);
            v_i     := v_i + 1;
        end loop;

        return v_i;
    end function;

    function numbytes_toceil    (n: natural)            return natural is
    begin
        if n = 0 then
            return 0;
        end if;

        -- REVISIT: handle overflow condition ?

        return (n + 7) / 8;
    end function;

    function nat_to_bool        (n: natural)            return boolean is
    begin
        if n = 0 then
            return false;
        end if;

        return true;
    end function;

    function bool_to_sl         (b: boolean)            return std_logic is
    begin
        if b then
            return '1';
        end if;

        return '0';
    end function;

    procedure rand_int_with_limits  (
                                    variable seed1  : inout integer;
                                    variable seed2  : inout integer;
                                    min_lim         : in    integer;
                                    max_lim         : in    integer;
                                    rand_int        : out   integer
                                ) is
        variable v_rand_real : real;
    begin
        uniform(seed1, seed2, v_rand_real);

        rand_int := integer(round((v_rand_real * real((max_lim-min_lim)+1)) + (real(min_lim)-0.5)));
    end procedure;

end utils;
