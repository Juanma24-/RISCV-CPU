library ieee;
use ieee.std_logic_1164.all;

library work;
use work.MEM_PKG.all;

entity mem32 is
  generic (
    G_RSTTYPESEL   : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    --
    p1_i : in mem32_in_t;
    p1_o : out mem_out_t;
    --
    p2_i : in mem32_in_t;
    p2_o : out mem_out_t;
    --
    p3_i : in mem32_in_t;
    p3_o : out mem_out_t
  );
end mem32;

architecture arch of mem32 is
begin

    -- 

end arch;
