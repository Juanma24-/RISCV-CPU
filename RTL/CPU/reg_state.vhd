library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;

entity reg_state is
  generic (
    G_RSTTYPESEL   : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    --
    --
    rs1_i        : in mem32_in_t;   -- Register Selection 1 Input
    rs1_o        : out mem_out_t; -- Register Selection 1 Output
    --
    rs2_i        : in mem32_in_t;   -- Register Selection 2 Input
    rs2_o        : out mem_out_t; -- Register Selection 2 Output
    --
    rd_i         : in mem32_in_t    -- Register Destination Input
  );
end reg_state;

architecture arch of reg_state is
  -- Program Counter Management Signals
  signal pc_r : std_logic_vector(XLEN_C-1 downto 0);
  -- Register Management Signals
  signal rs1_en_r : std_logic; -- Register Enable for 1 one cycle delay
  signal rs2_en_r : std_logic; -- Register Enable for 1 one cycle delay
  -- Memory Connections Signals
  signal p1_en_s : std_logic; -- P1 (Read) Enable Signal
  signal p2_en_s : std_logic; -- P2 (Read) Enable Signal
begin
-- ---------------------------------------
-- Program counter management process
pc_mngt_p : process (clk_i, rst_i)
  procedure Reset is
  begin
    pc_r <= (others => '0');
  end procedure;
begin
  if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
      Reset;
  elsif(rising_edge(clk_i)) then


    pc_r <= std_logic_vector(unsigned(pc_r) + 4); -- Address in Bytes! (32b = 4B)

    if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
    end if;
  end if;
end process pc_mngt_p;
-- ---------------------------------------

-- ---------------------------------------

-- Registers Management
regs_mngt_p : process (clk_i, rst_i)
  procedure Reset is
  begin
    rs1_en_r <= (others => '0');
    rs2_en_r <= (others => '0');
  end procedure;
begin
  if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
      Reset;
  elsif(rising_edge(clk_i)) then


    rs1_en_r <= rs1_i.en; -- Delay
    rs2_en_r <= rs1_i.en; -- Delay


    if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
    end if;
  end if;
end process regs_mngt_p;





end arch;