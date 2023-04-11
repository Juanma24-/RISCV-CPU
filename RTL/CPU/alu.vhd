library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;


entity alu is
  generic (
    G_RSTTYPESEL   : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    -- from Instruction Decoder
    op_decoded_i : in op_t;                                -- Operation Decoded record Input
    f3_decoded_i : in f3_t;                                -- Operation Decoded record Input
    rd_i         : in std_logic_vector(5 downto 0);        -- Register Destination Address
    imm_i        : in std_logic_vector(XLEN_C-1 downto 0); -- Immediate Value
    -- From Registers
    rs1_i        : in mem_out_t; -- Register Selection 1 Input
    rs2_i        : in mem_out_t; -- Register Selection 2 Input
    -- To Registers
    rd_o         : out mem32_in_t
  );
end alu;

architecture arch of alu is
begin









end arch;