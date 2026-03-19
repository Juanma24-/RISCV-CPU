library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;

entity cpu_top is
  generic (
    G_RSTTYPESEL   : natural range 0 to 1 := 0;  -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic            := '0'  -- Reset active level
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
   --
    );
end cpu_top;
architecture RTL of cpu_top is
  -- SIGNALS ------------------
  signal instr_s      : std_logic_vector(XLEN_C-1 downto 0);
  -- Operation Flags
  signal op_tbd_s     : op_tbd_t;
  signal op_branch_s  : op_branch_t;
  signal op_lsu_s     : op_lsu_t;
  signal op_alu_s     : op_alu_t;
  signal op_err_s     : op_err_t;
  -- Immediate Value & valid
  signal imm_o        : std_logic_vector(XLEN_C-1 downto 0);
  signal imm_valid_s  : std_logic;
  -- Register File signals
  -- TODO: Move the 32 to undefined length
  signal rs1_req_s    : mem_req_t;
  signal rs1_rsp_s    : mem_rsp_t;
  signal rs2_req_s    : mem_req_t;
  signal rs2_rsp_s    : mem_rsp_t;
  signal rd_addr_s    : std_logic_vector(4 downto 0);
  signal rd_req_alu_s : mem_req_t;
  signal rd_req_lsu_s : mem_req_t;
begin



  -- ===========================
  -- INSTANCES
  -- ===========================
  -- INSTRUCTION DECODER
  inst_instr_decoder : entity work.instr_decoder
    generic map (
      G_RSTTYPESEL   => G_RSTTYPESEL,
      G_RSTACTIVELVL => G_RSTACTIVELVL
      )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      instr_i     => instr_s,
      --
      op_reg_o    => op_reg_s,
      op_branch_o => op_branch_s,
      op_lsu_o    => op_lsu_s,
      op_alu_o    => op_alu_s,
      op_err_o    => op_err_s,
      --
      imm_o       => imm_s,
      imm_valid_o => imm_valid_s,
      --
      rs1_o       => rs1_req_s,
      rs2_o       => rs2_req_s,
      rd_o        => rd_addr_s
      );

  -- REGISTER FILE
  inst_register_file : entity work.reg_file
    generic map (
      G_RSTTYPESEL   => G_RSTTYPESEL,
      G_RSTACTIVELVL => G_RSTACTIVELVL
      )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      --
      op_reg_i    => op_reg_s,
      op_branch_i => op_branch_s,
      --
      imm_i => imm_s,
      imm_valid_i => imm_valid_s,
      --
      rs1_req_i   => rs1_req_s,
      rs1_rsp_o   => rs1_rsp_s,
      --
      rs2_req_i   => rs2_req_s,
      rs2_rsp_o   => rs2_rsp_s,
      --
      rd_req_i    => rd_req_s,
      rd_rsp_o    => rd_rsp_s
      );

  -- ARITHMETIC LOGIC UNIT (ALU)
  inst_alu : entity work.alu
    generic map (
      G_RSTTYPESEL   => G_RSTTYPESEL,
      G_RSTACTIVELVL => G_RSTACTIVELVL
      )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      -- Operation
      op_alu_i    => op_alu_s,
      -- Data In
      rs1_rsp_i   => rs1_rsp_s,
      rs2_rsp_i   => rs1_rsp_s,
      imm_i       => imm_s,
      imm_valid_i => imm_valid_s,
      -- Data Out
      rd_req_o    => rd_req_alu_s
      );

  -- LOAD STORE UNIT (LSU)
  inst_lsu : entity work.lsu
    generic map (
      G_RSTTYPESEL   => G_RSTTYPESEL,
      G_RSTACTIVELVL => G_RSTACTIVELVL
      )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      -- Operation
      op_lsu_i    => op_lsu_s,
      -- Data In
      rs1_rsp_i   => rs1_rsp_s,
      rs2_rsp_i   => rs1_rsp_s,
      imm_i       => imm_s,
      imm_valid_i => imm_valid_s,
      -- Data Out
      rd_req_o    => rd_req_lsu_s
      );





end RTL;
