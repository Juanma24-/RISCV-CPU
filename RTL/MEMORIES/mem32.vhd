library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MEM_PKG.all;

entity mem_3p2r1w_inferred is
  generic (
    G_RSTTYPESEL   : integer   := 0;  -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'   -- Reset active level
    G_MEM_DEPTH    : positive  := 32;   -- Memory Depth
    G_MEM_WIDTH    : positive  := 32    -- Memory Width
    );
  port (
    clk_i : in  std_logic;
    rst_i : in  std_logic;
    -- Port 1 (Only Read)
    p1_i  : in  mem_in_t;
    p1_o  : out mem_out_t;
    -- Port 2 (Only Read)
    p2_i  : in  mem_in_t;
    p2_o  : out mem_out_t;
    -- Port 3 (Only Write)
    p3_i  : in  mem_in_t;
    p3_o  : out mem_out_t
    );
end mem_3p2r1w_inferred;

architecture arch of mem_3p2r1w_inferred is
  type memory_array is array (0 to G_MEM_DEPTH-1) of std_logic_vector(G_MEM_WIDTH-1 downto 0);
  signal mem_r        : memory_array;
  --
  signal p1_rd_data_r : std_logic_vector(G_MEM_WIDTH-1 downto 0);
  signal p2_rd_data_r : std_logic_vector(G_MEM_WIDTH-1 downto 0);
  --
  signal p1_rw_coll_s : std_logic;
  signal p2_rw_coll_s : std_logic;
  --
  signal p1_en_s : std_logic;
  signal p2_en_s : std_logic;
begin

  -- COLLISION SOLVING (DONE AT THIS LEVEL) -------------
  -- READ-WRITE (Pass the written value)
  p1_rw_coll_s <= '1'          when (p1_i.en = '1' and p1_i.en = '1' and to_integer(unsigned(p1_i.addr)) = to_integer(unsigned(p3_i.addr))) else '0';
  p2_rw_coll_s <= '1'          when (p2_i.en = '1' and p3_i.en = '1' and to_integer(unsigned(p2_i.addr)) = to_integer(unsigned(p3_i.addr))) else '0';
  p1_en_s      <= '0'          when (p1_rw_coll_s = '1')                                                                                    else p1_i.en;
  p2_en_s      <= '0'          when (p2_rw_coll_s = '1')                                                                                    else p2_i.en;
  p1_o.rd_data <= p3_i.wr_data when (p1_rw_coll_s = '1')                                                                                    else p1_rd_data_r;
  p2_o.rd_data <= p3_i.wr_data when (p2_rw_coll_s = '1')                                                                                    else p2_rd_data_r;
  -- TODO: Is it needed to keep always the correct last value in the output?
  -- Right now when RW collision, the correct value is good for one cycle.

  mem_inf_p : process (clk_i, rst_i)
  begin
    if(rising_edge(clk_i)) then

      --PORT 1 (READ)
      if (p1_en_s = '1') then
        p1_rd_data_r <= mem_r(to_integer(unsigned(p1_i.addr)));
      end if;
      -- READ
      if (p2_en_s = '1') then
        p2_rd_data_r <= mem_r(to_integer(unsigned(p2_i.addr)));
      end if;
      -- WRITE
      if p3_i.en = '1' then
        mem_r(to_integer(unsigned(p3_i.addr))) <= p3_i.data;
      end if;
    end if;
  end process mem_inf_p;


end arch;
