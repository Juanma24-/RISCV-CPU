library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;

entity reg_state is
  generic (
    G_RSTTYPESEL   : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    --
    rs1_i        : in mem_in_t;   -- Register Selection 1 Input
    rs1_o        : out mem_out_t; -- Register Selection 1 Output
    --
    rs2_i        : in mem_in_t;   -- Register Selection 2 Input
    rs2_o        : out mem_out_t; -- Register Selection 2 Output
    --
    rd_i         : in mem_in_t    -- Register Destination Input
  );
end reg_state;

architecture arch of reg_state is
begin

end arch;