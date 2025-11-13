library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.utils.all;

entity axis_fifo_sync is
    generic (
        g_data_bits     : positive;
        g_depth         : positive range 2 to integer'high
    );
    port (
        clk             : in  std_logic;
        srst            : in  std_logic;
            -- NOTE: srst == synchronous reset

        s_tvalid        : in  std_logic;
        s_tready        : out std_logic;
        s_tdata         : in  std_logic_vector(g_data_bits-1 downto 0);
        s_talmost_full  : out std_logic;

        m_tvalid        : out std_logic;
        m_tready        : in  std_logic;
        m_tdata         : out std_logic_vector(g_data_bits-1 downto 0)
    );
end axis_fifo_sync;

architecture rtl of axis_fifo_sync is

    type slv_array_t is array (integer range <>) of std_logic_vector;

    signal wr_pntr  : unsigned(log2ceil(g_depth)-1 downto 0);
    signal rd_pntr  : unsigned(log2ceil(g_depth)-1 downto 0);

    signal count    : unsigned(log2ceil(g_depth)-1 downto 0);

    signal memory   : slv_array_t(g_depth-1 downto 0)(g_data_bits-1 downto 0) := (others => (others => '0'));

begin

    s_tready        <= not and_reduce_us(count);
    s_talmost_full  <= and_reduce_us(count(count'high downto 1));

    wr_pntr_p: process(clk)
    begin
        if rising_edge(clk) then
            if s_tvalid = '1' and s_tready = '1' then
                wr_pntr <= wr_pntr + 1;
                if wr_pntr = to_unsigned(g_depth-1, wr_pntr'length) then
                    wr_pntr <= (others => '0');
                end if;
            end if;

            if srst = '1' then
                wr_pntr <= (others => '0');
            end if;
        end if;
    end process;

    memory_p: process(clk)
    begin
        if rising_edge(clk) then
            if s_tvalid = '1' and s_tready = '1' then
                memory(to_integer(wr_pntr)) <= s_tdata;
            end if;
        end if;
    end process;

    rd_pntr_p: process(clk)
    begin
        if rising_edge(clk) then
            if m_tvalid = '1' and m_tready = '1' then
                rd_pntr <= rd_pntr + 1;
                if rd_pntr = to_unsigned(g_depth-1, rd_pntr'length) then
                    rd_pntr <= (others => '0');
                end if;
            end if;

            if srst = '1' then
                rd_pntr <= (others => '0');
            end if;
        end if;
    end process;

    count_p: process(clk)
        variable v_count_next : unsigned(log2ceil(g_depth)-1 downto 0);
    begin
        if rising_edge(clk) then
            -- defaults
            v_count_next := count;

            if s_tvalid = '1' and s_tready = '1' then
                v_count_next := v_count_next + 1;
            end if;
            if m_tvalid = '1' and m_tready = '1' then
                v_count_next := v_count_next - 1;
            end if;

            if srst = '1' then
                v_count_next := (others => '0');
            end if;

            count <= v_count_next;
        end if;
    end process;

    m_tvalid    <= or_reduce_us(count);
    m_tdata     <= memory(to_integer(rd_pntr));

end architecture;