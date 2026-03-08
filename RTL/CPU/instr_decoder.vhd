library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;


entity instr_decoder is
  generic (
    G_RSTTYPESEL   : natural range 0 to 1 := 0;  -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic            := '0'    -- Reset active level
    );
  port (
    clk_i       : in  std_logic;
    rst_i       : in  std_logic;
    -- 
    instr_i     : in  std_logic_vector(31 downto 0);  -- Fetched Instruction
    -- To other CPU modules (Operations Decoded)
    op_tbd_o    : out op_tbd_t;
    op_branch_o : out op_branch_t;
    op_load_o   : out op_load_t;
    op_store_o  : out op_store_t;
    op_alu_o    : out op_alu_t;
    op_err_o    : out op_err_t;
    -- IMMEDIATE Decoded
    imm_o       : out std_logic_vector(XLEN_C-1 downto 0);  -- Immediate Value
    imm_valid_o : out std_logic;
    -- To REGISTER MEMORY
    rs1_o       : out mem32_in_t;       -- Register Selection 1 Output
    rs2_o       : out mem32_in_t;       -- Register Selection 2 Output
    rd_o        : out std_logic_vector(4 downto 0)  -- Register Destination Output

    );
end instr_decoder;

architecture arch of instr_decoder is

  -- ALIAS --
  -- This alias are generated to better understand the decoding process
  -- depending on the type of instruction
  alias op_al         : std_logic_vector(6 downto 0) is instr_i(6 downto 0);  --
  alias funct3_al     : std_logic_vector(2 downto 0) is instr_i(14 downto 12);
  alias funct7_al     : std_logic_vector(6 downto 0) is instr_i(31 downto 25);
  alias rs1_al        : std_logic_vector(4 downto 0) is instr_i(19 downto 15);
  alias rs2_al        : std_logic_vector(4 downto 0) is instr_i(24 downto 20);
  alias rd_al         : std_logic_vector(4 downto 0) is instr_i(11 downto 7);
  -- SIGNALS
  signal op_tbd_r     : op_tbd_t     := OP_TBD_NONE_C;
  signal op_branch_r  : op_branch_t  := OP_BRANCH_NONE_C;
  signal op_load_r    : op_load_t    := OP_LOAD_NONE_C;
  signal op_store_r   : op_store_t   := OP_STORE_NONE_C;
  signal op_alu_r     : op_alu_t     := OP_ALU_NONE_C;  -- Operation ALU Selection
  signal op_err_r     : op_err_t     := OP_ERR_NONE_C;
  signal instr_data_r : instr_data_t := INSTR_DATA_NONE_C;  -- Data encoded in
                                                            -- the instruction
begin
  -- ------------------------------------------
  -- REGISTER FILE SELECTORS
  -- ------------------------------------------
  -- TODO: Aynchronous to read the memory on time
  rs1_o.en   <= instr_data_r.rs1_valid;  -- Always Read (Conflict solved at memory level)
  rs1_o.addr <= instr_data_r.rs1_addr;
  rs1_o.data <= (others => '0');        -- Always read
  rs1_o.wr   <= '0';  -- Always Read (Conflict solved at memory level)
  --
  rs2_o.en   <= instr_data_r.rs2_valid;
  rs2_o.addr <= instr_data_r.rs2_addr;
  rs2_o.data <= (others => '0');        -- Always Read
  rs2_o.wr   <= '0';  -- Always Read (Conflict solved at memory level)

  -- To other modules of the CPU (Operations Decoded)
  op_tbd_o    <= op_tbd_r;
  op_branch_o <= op_branch_r;
  op_load_o   <= op_load_r;
  op_store_o  <= op_store_r;
  op_alu_o    <= op_alu_r;
  op_err_o    <= op_err_r;
  --
  rd_o        <= instr_data_r.rd_addr;

  -- -----------------------------------------
  -- INSTRUCTION DECODER
  -- -----------------------------------------
  decoder_op_p : process(clk_i, rst_i)
    procedure Reset is
    begin
      op_tbd_r     <= OP_TBD_NONE_C;
      op_branch_r  <= OP_BRANCH_NONE_C;
      op_load_r    <= OP_LOAD_NONE_C;
      op_store_r   <= OP_STORE_NONE_C;
      op_alu_r     <= OP_ALU_NONE_C;
      op_err_r     <= OP_ERR_NONE_C;
      instr_data_r <= INSTR_DATA_NONE_C;
    end procedure;
    -- Variables
    variable type_i_v : std_logic := '0';
    variable type_r_v : std_logic := '0';
    variable type_s_v : std_logic := '0';
    variable type_b_v : std_logic := '0';
    variable type_u_v : std_logic := '0';
    variable type_j_v : std_logic := '0';
  begin
    if (G_RSTTYPESEL = 0 and G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then

      -- Defaults (Pulse behaviour)
      op_tbd_r    <= OP_TBD_NONE_C;
      op_branch_r <= OP_BRANCH_NONE_C;
      op_load_r   <= OP_LOAD_NONE_C;
      op_store_r  <= OP_STORE_NONE_C;
      op_alu_r    <= OP_ALU_NONE_C;
      op_err_r    <= OP_ERR_NONE_C;

      -- OPCODE Selector
      case op_al is
        when LUI_C   => op_tbd_r.lui_op   <= '1'; type_u_v := '1';
        when AUIPC_C => op_tbd_r.auipc_op <= '1'; type_u_v := '1';
        when JAL_C   => op_tbd_r.jal_op   <= '1'; type_j_v := '1';
        when JALR_C  => type_i_v          := '1';
                       if (funct3_al = F3_JALR_C) then op_tbd_r.jalr_op <= '1'; else op_err_r.undef_f3code <= '1'; end if;
        when BRANCH_C =>
          case funct3_al is
            when F3_BEQ_C  => op_branch_r.beq_op    <= '1'; type_b_v := '1';
            when F3_BNE_C  => op_branch_r.bne_op    <= '1'; type_b_v := '1';
            when F3_BLT_C  => op_branch_r.blt_op    <= '1'; type_b_v := '1';
            when F3_BGE_C  => op_branch_r.bge_op    <= '1'; type_b_v := '1';
            when F3_BLTU_C => op_branch_r.bltu_op   <= '1'; type_b_v := '1';
            when F3_BGEU_C => op_branch_r.bgeu_op   <= '1'; type_b_v := '1';
            when others    => op_err_r.undef_f3code <= '1';
          end case;
        when LOAD_C =>
          case funct3_al is
            when F3_LB_C  => op_load_r.lb_op       <= '1'; type_i_v := '1';
            when F3_LH_C  => op_load_r.lh_op       <= '1'; type_i_v := '1';
            when F3_LW_C  => op_load_r.lw_op       <= '1'; type_i_v := '1';
            when F3_LBU_C => op_load_r.lbu_op      <= '1'; type_i_v := '1';
            when F3_LHU_C => op_load_r.lhu_op      <= '1'; type_i_v := '1';
            when others   => op_err_r.undef_f3code <= '1';
          end case;
        when STORE_C =>
          case funct3_al is
            when F3_SB_C => op_store_r.sb_op      <= '1'; type_s_v := '1';
            when F3_SH_C => op_store_r.sh_op      <= '1'; type_s_v := '1';
            when F3_SW_C => op_store_r.sw_op      <= '1'; type_s_v := '1';
            when others  => op_err_r.undef_f3code <= '1';
          end case;
        when OP_IMM_C =>
          -- ALU Instruction using IMM
          case funct3_al is
            when F3_ADDI_C  => op_alu_r.add_op  <= '1'; type_i_v := '1';
            when F3_SLTI_C  => op_alu_r.slt_op  <= '1'; type_i_v := '1';
            when F3_SLTIU_C => op_alu_r.sltu_op <= '1'; type_i_v := '1';
            when F3_XORI_C  => op_alu_r.xor_op  <= '1'; type_i_v := '1';
            when F3_ORI_C   => op_alu_r.or_op   <= '1'; type_i_v := '1';
            when F3_ANDI_C  => op_alu_r.and_op  <= '1'; type_i_v := '1';
            when F3_SLLI_C =>
              if (funct7_al = F7_SLLI_C) then op_alu_r.sll_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                        := '1';
            when F3_SRLI_SRAI_C =>
              case funct7_al is
                when F7_SRLI_C => op_alu_r.srl_op       <= '1'; type_r_v := '1';
                when F7_SRAI_C => op_alu_r.sra_op       <= '1'; type_r_v := '1';
                when others    => op_err_r.undef_f7code <= '1';
              end case;
            when others =>
              op_err_r.undef_f3code <= '1';
          end case;
        when OP_C =>
          case funct3_al is
            when F3_ADD_SUB_C =>
              case funct7_al is
                when F7_ADD_C => op_alu_r.add_op       <= '1'; type_r_v := '1';
                when F7_SUB_C => op_alu_r.sub_op       <= '1'; type_r_v := '1';
                when others   => op_err_r.undef_f7code <= '1';
              end case;
            when F3_SLL_C =>
              if (funct7_al = F7_SLL_C) then op_alu_r.sll_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                       := '1';
            when F3_SLT_C =>
              if (funct7_al = F7_SLT_C) then op_alu_r.slt_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                       := '1';
            when F3_SLTU_C =>
              if (funct7_al = F7_SLTU_C) then op_alu_r.sltu_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                         := '1';
            when F3_XOR_C =>
              if (funct7_al = F7_XOR_C) then op_alu_r.xor_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                       := '1';
            when F3_SRL_SRA_C =>
              case funct7_al is
                when F7_SRL_C => op_alu_r.srl_op       <= '1'; type_r_v := '1';
                when F7_SRA_C => op_alu_r.sra_op       <= '1'; type_r_v := '1';
                when others   => op_err_r.undef_f7code <= '1';
              end case;
            when F3_OR_C =>
              if (funct7_al = F7_OR_C) then op_alu_r.or_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                     := '1';
            when F3_AND_C =>
              if (funct7_al = F7_AND_C) then op_alu_r.and_op <= '1'; else op_err_r.undef_f7code <= '1'; end if;
              type_r_v                                       := '1';
            when others =>
              op_err_r.undef_f3code <= '1';
          end case;
        when SYSTEM_C =>
          -- TODO: DO not correspond to any instruction type. To do manually
          op_err_r.undef_opcode <= '1';
        when others =>
          -- Operation field with non-defined value
          op_err_r.undef_opcode <= '1';
      end case;

      -- -----------------------------------------------------------------
      -- Data decoder depending on instruction type
      -- -----------------------------------------------------------------
      -- RS1, RS2 and RD are always decode in the same way as they depend
      -- on its valid signal. An instruction w/o one of these fields will
      -- ignore these values.
      instr_data_r.rs1_addr <= rs1_al;
      instr_data_r.rs2_addr <= rs2_al;
      instr_data_r.rd_addr  <= rd_al;

      if (type_r_v = '1') then
        instr_data_r.imm       <= (others => '0');
        instr_data_r.imm_valid <= '0';
        instr_data_r.rs1_valid <= '1';
        instr_data_r.rs2_valid <= '1';
        instr_data_r.rd_valid  <= '1';
      elsif (type_i_v = '1') then
        instr_data_r.imm       <= resize(signed(instr_i(31 downto 20)), XLEN_C);
        instr_data_r.imm_valid <= '1';
        instr_data_r.rs1_valid <= '1';
        instr_data_r.rs2_valid <= '0';
        instr_data_r.rd_valid  <= '1';
      elsif(type_s_v = '1') then
        instr_data_r.imm       <= resize(signed(instr_i(31 downto 25) & instr_i(11 downto 7)), XLEN_C);
        instr_data_r.imm_valid <= '1';
        instr_data_r.rs1_valid <= '1';
        instr_data_r.rs2_valid <= '0';
        instr_data_r.rd_valid  <= '0';
      elsif(type_b_v = '1') then
        instr_data_r.imm       <= resize(signed(instr_i(31) & instr_i(7) & instr_i(30 downto 25) & instr_i(11 downto 6) & '0'), XLEN_C);
        instr_data_r.imm_valid <= '1';
        instr_data_r.rs1_valid <= '1';
        instr_data_r.rs2_valid <= '1';
        instr_data_r.rd_valid  <= '0';
      elsif(type_u_v = '1') then
        instr_data_r.imm       <= resize(signed(instr_i(31 downto 12) & x"000"), XLEN_C);
        instr_data_r.imm_valid <= '1';
        instr_data_r.rs1_valid <= '0';
        instr_data_r.rs2_valid <= '0';
        instr_data_r.rd_valid  <= '1';
      elsif(type_j_v = '1') then
        instr_data_r.imm       <= resize(signed(instr_i(31) & instr_i(19 downto 12) & instr_i(20) & instr_i(30 downto 21) & '0'), XLEN_C);
        instr_data_r.imm_valid <= '1';
        instr_data_r.rs1_valid <= '0';
        instr_data_r.rs2_valid <= '0';
        instr_data_r.rd_valid  <= '1';
      else
        instr_data_r <= INSTR_DATA_NONE_C;
      end if;

      if(G_RSTTYPESEL = 1 and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process decoder_op_p;

end arch;  -- arch
