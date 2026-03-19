library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;

entity reg_file is
  generic (
    G_RSTTYPESEL   : integer   := 0;  -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'   -- Reset active level
    );
  port (
    clk_i       : in  std_logic;
    rst_i       : in  std_logic;
    --
    op_reg_i    : in  op_reg_t;         -- Register File operations
    op_branch_i : in  op_branch_t;      -- Branch Operations
    --
    imm_i       : in  std_logic_vector(XLEN_C-1 downto 0);
    imm_valid_i : in  std_logic;
    --
    rs1_req_i   : in  mem_in_t;         -- Register Selection 1 Input
    rs1_rsp_o   : out mem_out_t;        -- Register Selection 1 Output
    --
    rs2_req_i   : in  mem_in_t;         -- Register Selection 2 Input
    rs2_rsp_o   : out mem_out_t;        -- Register Selection 2 Output
    --
    rd_req_i    : in  mem_in_t          -- Register Destination Input
    rd_rsp_i    : out mem_out_t         -- Register Destination Output
    );
end reg_file;

architecture arch of reg_file is
  -- Program Counter Management Signals
  signal pc_r     : std_logic_vector(XLEN_C-1 downto 0);
  -- Register Management Signals
  signal rs1_en_r : std_logic;  -- Register Enable for 1 one cycle delay
  signal rs2_en_r : std_logic;  -- Register Enable for 1 one cycle delay
  -- Memory Connections Signals
  signal p1_en_s  : std_logic;          -- P1 (Read) Enable Signal
  signal p2_en_s  : std_logic;          -- P2 (Read) Enable Signal
  --
  signal rd_req_r : mem_in_t;
begin
-- ---------------------------------------
-- Program counter management process
  pc_mngt_p : process (clk_i, rst_i)
    procedure Reset is
    begin
      pc_r <= (others => '0');
    end procedure;
  begin
    if (G_RSTTYPESEL = '0' and G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then


      pc_r <= std_logic_vector(unsigned(pc_r) + 4);  -- Address in Bytes! (32b = 4B)

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
    end procedure;
  begin
    if (G_RSTTYPESEL = '0' and G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then
      if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process regs_mngt_p;

  rd_mngt_p : process (clk_i, rst_i)
    procedure Reset is
    begin
    end procedure;
  begin
    if (G_RSTTYPESEL = '0' and G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then
      -- TODO: Not sure if it must be registered
      -- If LUI operation selected, perform the write into rd
      -- Write has already been selected by instruction decoder
      rd_reg_r.wr_data <= imm_r when (op_reg_i.lui = '1') else rd_req_i;


      if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process regs_mngt_p;


  -- -----------------------------------------------
  -- REGISTER FILE MEMORY (32xXLEN)
  -- -----------------------------------------------
  inst_reg_mem : entity mem.mem_3p2r1w_inferred
    generic map (
      G_RSTTYPESEL   => G_RSTTYPESEL,
      G_RSTACTIVELVL => G_RSTACTIVELVL,
      G_MEM_DEPTH    => 32,
      G_MEM_WIDTH    => XLEN_C
      )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      -- Port 1 (Only Read)
      p1_i  => rs1_req_i,
      p1_o  => rs1_rsp_o,
      -- Port 2 (Only Read)
      p2_i  => rs2_req_i,
      p2_o  => rs2_rsp_o,
      -- Port 3 (Only Write)
      p3_i  => rd_req_r,
      p3_o  => rd_rsp_o
      );

end arch;
