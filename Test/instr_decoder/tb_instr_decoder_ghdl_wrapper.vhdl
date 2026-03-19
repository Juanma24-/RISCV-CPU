-- =============================================================================
-- instr_decoder_tb_wrapper.vhd
--
-- Purpose
-- -------
-- GHDL exposes only scalar ports (std_logic / std_logic_vector / integer)
-- through its VPI layer.  VHDL record-typed ports are invisible to cocotb.
--
-- This wrapper instantiates the real instr_decoder and re-exports every
-- record field as a named flat std_logic port.  Point cocotb at this entity
-- as the top-level (TOPLEVEL = instr_decoder_tb_wrapper in the Makefile).
--
-- Naming convention used for flattened ports (matches the testbench):
--   <record_port>_<field>
-- e.g.  op_branch_o_beq_op,  op_alu_o_add_op,  op_err_o_undef_opcode
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;   -- adjust to your actual package name
use work.mem_pkg.all;

entity instr_decoder_tb_wrapper is
    port (
        -- ----------------------------------------------------------------
        -- Pass-through scalars (unchanged)
        -- ----------------------------------------------------------------
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        instr_i     : in  std_logic_vector(31 downto 0);
        imm_o       : out std_logic_vector(XLEN_C-1 downto 0);
        imm_valid_o : out std_logic;
        rs1_o       : out std_logic_vector(4 downto 0);  -- adjust width to mem_in_t
        rs2_o       : out std_logic_vector(4 downto 0);
        rd_o        : out std_logic_vector(4 downto 0);

        -- ----------------------------------------------------------------
        -- op_reg_t  (flattened)
        -- ----------------------------------------------------------------
        op_reg_o_lui_op    : out std_logic;
        op_reg_o_auipc_op  : out std_logic;

        -- ----------------------------------------------------------------
        -- op_branch_t  (flattened)
        -- ----------------------------------------------------------------
        op_branch_o_beq_op  : out std_logic;
        op_branch_o_bne_op  : out std_logic;
        op_branch_o_blt_op  : out std_logic;
        op_branch_o_bge_op  : out std_logic;
        op_branch_o_bltu_op : out std_logic;
        op_branch_o_bgeu_op : out std_logic;
        op_branch_o_jal_op  : out std_logic;
        op_branch_o_jalr_op : out std_logic;

        -- ----------------------------------------------------------------
        -- op_lsu_t  (flattened)
        -- ----------------------------------------------------------------
        op_lsu_o_lb_op  : out std_logic;
        op_lsu_o_lh_op  : out std_logic;
        op_lsu_o_lw_op  : out std_logic;
        op_lsu_o_lbu_op : out std_logic;
        op_lsu_o_lhu_op : out std_logic;
        op_lsu_o_sb_op  : out std_logic;
        op_lsu_o_sh_op  : out std_logic;
        op_lsu_o_sw_op  : out std_logic;

        -- ----------------------------------------------------------------
        -- op_alu_t  (flattened)
        -- ----------------------------------------------------------------
        op_alu_o_add_op  : out std_logic;
        op_alu_o_sub_op  : out std_logic;
        op_alu_o_slt_op  : out std_logic;
        op_alu_o_sltu_op : out std_logic;
        op_alu_o_srl_op  : out std_logic;
        op_alu_o_sll_op  : out std_logic;
        op_alu_o_sra_op  : out std_logic;
        op_alu_o_xor_op  : out std_logic;
        op_alu_o_and_op  : out std_logic;
        op_alu_o_or_op   : out std_logic;

        -- ----------------------------------------------------------------
        -- op_err_t  (flattened)
        -- ----------------------------------------------------------------
        op_err_o_undef_opcode : out std_logic;
        op_err_o_undef_f3code : out std_logic;
        op_err_o_undef_f7code : out std_logic
    );
end entity instr_decoder_tb_wrapper;

architecture rtl of instr_decoder_tb_wrapper is

    -- Internal record signals – connect to the DUT
    signal op_reg_s    : op_reg_t;
    signal op_branch_s : op_branch_t;
    signal op_lsu_s    : op_lsu_t;
    signal op_alu_s    : op_alu_t;
    signal op_err_s    : op_err_t;

    -- Internal scalar signals for mem_in_t ports
    -- (adjust the type / width to match your mem_in_t definition)
    signal rs1_s : mem_in_t;
    signal rs2_s : mem_in_t;
    signal rd_s  : mem_in_t;

begin

    -- -----------------------------------------------------------------------
    -- Instantiate the real decoder
    -- -----------------------------------------------------------------------
    u_dut : entity work.instr_decoder
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            instr_i     => instr_i,
            op_reg_o    => op_reg_s,
            op_branch_o => op_branch_s,
            op_lsu_o    => op_lsu_s,
            op_alu_o    => op_alu_s,
            op_err_o    => op_err_s,
            imm_o       => imm_o,
            imm_valid_o => imm_valid_o,
            rs1_o       => rs1_s,
            rs2_o       => rs2_s,
            rd_o        => rd_s
        );

    -- -----------------------------------------------------------------------
    -- Flatten mem_in_t register index outputs
    -- If mem_in_t is std_logic_vector(4 downto 0), assign directly.
    -- If it is a record itself, map each field here.
    -- -----------------------------------------------------------------------
    rs1_o <= std_logic_vector(rs1_s.addr);  -- adjust cast if mem_in_t differs
    rs2_o <= std_logic_vector(rs2_s.addr);
    rd_o  <= std_logic_vector(rd_s.addr);

    -- -----------------------------------------------------------------------
    -- Flatten op_reg_t
    -- -----------------------------------------------------------------------
    op_reg_o_lui_op   <= op_reg_s.lui_op;
    op_reg_o_auipc_op <= op_reg_s.auipc_op;

    -- -----------------------------------------------------------------------
    -- Flatten op_branch_t
    -- -----------------------------------------------------------------------
    op_branch_o_beq_op  <= op_branch_s.beq_op;
    op_branch_o_bne_op  <= op_branch_s.bne_op;
    op_branch_o_blt_op  <= op_branch_s.blt_op;
    op_branch_o_bge_op  <= op_branch_s.bge_op;
    op_branch_o_bltu_op <= op_branch_s.bltu_op;
    op_branch_o_bgeu_op <= op_branch_s.bgeu_op;
    op_branch_o_jal_op  <= op_branch_s.jal_op;
    op_branch_o_jalr_op <= op_branch_s.jalr_op;

    -- -----------------------------------------------------------------------
    -- Flatten op_lsu_t
    -- -----------------------------------------------------------------------
    op_lsu_o_lb_op  <= op_lsu_s.lb_op;
    op_lsu_o_lh_op  <= op_lsu_s.lh_op;
    op_lsu_o_lw_op  <= op_lsu_s.lw_op;
    op_lsu_o_lbu_op <= op_lsu_s.lbu_op;
    op_lsu_o_lhu_op <= op_lsu_s.lhu_op;
    op_lsu_o_sb_op  <= op_lsu_s.sb_op;
    op_lsu_o_sh_op  <= op_lsu_s.sh_op;
    op_lsu_o_sw_op  <= op_lsu_s.sw_op;

    -- -----------------------------------------------------------------------
    -- Flatten op_alu_t
    -- -----------------------------------------------------------------------
    op_alu_o_add_op  <= op_alu_s.add_op;
    op_alu_o_sub_op  <= op_alu_s.sub_op;
    op_alu_o_slt_op  <= op_alu_s.slt_op;
    op_alu_o_sltu_op <= op_alu_s.sltu_op;
    op_alu_o_srl_op  <= op_alu_s.srl_op;
    op_alu_o_sll_op  <= op_alu_s.sll_op;
    op_alu_o_sra_op  <= op_alu_s.sra_op;
    op_alu_o_xor_op  <= op_alu_s.xor_op;
    op_alu_o_and_op  <= op_alu_s.and_op;
    op_alu_o_or_op   <= op_alu_s.or_op;

    -- -----------------------------------------------------------------------
    -- Flatten op_err_t
    -- -----------------------------------------------------------------------
    op_err_o_undef_opcode <= op_err_s.undef_opcode;
    op_err_o_undef_f3code <= op_err_s.undef_f3code;
    op_err_o_undef_f7code <= op_err_s.undef_f7code;

end architecture rtl;
