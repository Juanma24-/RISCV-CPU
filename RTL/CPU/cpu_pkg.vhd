-- CPU Related Package
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package CPU_PKG is

  -- --------------------------
  -- TYPES
  -- --------------------------
  -- INSTRUCTION DECODER TYPES
  type op_tbd_t is record
    lui_op   : std_logic;
    auipc_op : std_logic;
    jal_op   : std_logic;
    jalr_op  : std_logic;
  end record op_tbd_t;
  constant OP_TBD_NONE_C : op_tbd_t := (others => '0');
  --
  -- Branch Operations
  type op_branch_t is record
    beq_op  : std_logic;
    bne_op  : std_logic;
    blt_op  : std_logic;
    bge_op  : std_logic;
    bltu_op : std_logic;
    bgeu_op : std_logic;
  end record op_branch_t;
  constant OP_BRANCH_NONE_C : op_branch_t := (others => '0');
  -- Load Operations
  type op_load_t is record
    lb_op  : std_logic;
    lh_op  : std_logic;
    lw_op  : std_logic;
    lbu_op : std_logic;
    lhu_op : std_logic;
  end record op_load_t;
  constant OP_LOAD_NONE_C : op_load_t := (others => '0');
  -- Store Operations
  type op_store_t is record
    sb_op : std_logic;
    sh_op : std_logic;
    sw_op : std_logic;
  end record op_store_t;
  constant OP_STORE_NONE_C : op_store_t := (others => '0');
  -- ALU Operations
  type op_alu_t is record
    add_op  : std_logic;                        -- Addition
    sub_op  : std_logic;                        -- Substraction
    slt_op  : std_logic;
    sltu_op : std_logic;
    srl_op  : std_logic;                        -- Shift Right Logic
    sll_op  : std_logic;                        -- Shift Left Logic
    sra_op  : std_logic;                        -- Shift Right Arithmetic
    xor_op  : std_logic;                        -- Logic XOR
    and_op  : std_logic;                        -- Logic AND
    or_op   : std_logic;                        -- Logic OR
  end record op_alu_t;
  constant OP_ALU_NONE_C : op_alu_t := (others => '0');
  -- SYSTEM Operations
  type op_system_t is record
    fence_op     : std_logic;
    fence_tso_op : std_logic;
    pause_op     : std_logic;
    ecall        : std_logic;
    ebreak       : std_logic;
  end record op_system_t;
  constant OP_SYSTEM_NONE_C : op_system_t := (others => '0');
  -- OPCODE ERRORS
  type op_err_t is record
    undef_opcode : std_logic;
    undef_f3code : std_logic;
    undef_f7code : std_logic;
  end record op_err_t;
  constant OP_ERR_NONE_C : op_err_t := (others => '0');
  -- DATA extracted from Instruction
  type instr_data_t is record
    imm_valid : std_logic;
    rs1_valid : std_logic;
    rs2_valid : std_logic;
    rd_valid  : std_logic;
    imm       : signed(31 downto 0);  -- Max length
    rs1_addr  : std_logic_vector(4 downto 0);
    rs2_addr  : std_logic_vector(4 downto 0);
    rd_addr   : std_logic_vector(4 downto 0);
  end record instr_data_t;
  constant INSTR_DATA_NONE_C : instr_data_t := ('0', '0', '0', '0',
                                                (others => '0'), (others => '0'),
                                                (others => '0'), (others => '0'));

  -- TODO: NOT USED RIGHT NOW (to be Removed)
  type op_base_t is record
    load      : std_logic;
    load_fp   : std_logic;
    custom_0  : std_logic;
    misc_mem  : std_logic;
    op_imm    : std_logic;
    auipc     : std_logic;
    op_imm_32 : std_logic;
    store     : std_logic;
    store_fp  : std_logic;
    custom_1  : std_logic;
    amo       : std_logic;
    op        : std_logic;
    lui       : std_logic;
    op_32     : std_logic;
    madd      : std_logic;
    msub      : std_logic;
    nmsub     : std_logic;
    nmadd     : std_logic;
    op_fp     : std_logic;
    op_v      : std_logic;
    custom_2  : std_logic;
    branch    : std_logic;
    jalr      : std_logic;
    jal       : std_logic;
    system    : std_logic;
    op_ve     : std_logic;
    custom_3  : std_logic;
  end record op_base_t;



  -- --------------------------
  -- OPCODES
  -- --------------------------
  -- OP CODES (See Chapter 35 Table 74) ---------
  -- ROW 1
  constant LOAD_C      : std_logic_vector(6 downto 0) := "0000011";  -- LOAD (I-Type)
  constant LOAD_FP_C   : std_logic_vector(6 downto 0) := "0000111";  -- LOAD-FP
  constant CUSTOM_0_C  : std_logic_vector(6 downto 0) := "0001011";  --
  constant MISC_MEM_C  : std_logic_vector(6 downto 0) := "0001111";  --
  constant OP_IMM_C    : std_logic_vector(6 downto 0) := "0010011";  --  (I-Type)
  constant AUIPC_C     : std_logic_vector(6 downto 0) := "0010111";  -- Add Upper Immediate to PC
  constant OP_IMM_32_C : std_logic_vector(6 downto 0) := "0011011";  --
  -- ROW 2
  constant STORE_C     : std_logic_vector(6 downto 0) := "0100011";  -- (S-Type)
  constant STORE_FP_C  : std_logic_vector(6 downto 0) := "0100111";  --
  constant CUSTOM_1_C  : std_logic_vector(6 downto 0) := "0101011";  --
  constant AMO_C       : std_logic_vector(6 downto 0) := "0101111";  --
  constant OP_C        : std_logic_vector(6 downto 0) := "0110011";  --
  constant LUI_C       : std_logic_vector(6 downto 0) := "0110111";  -- Load Upper Immediate
  constant OP_32_C     : std_logic_vector(6 downto 0) := "0111011";  --
  -- ROW 3
  constant MADD_C      : std_logic_vector(6 downto 0) := "1000011";  --
  constant MSUB_C      : std_logic_vector(6 downto 0) := "1000111";  --
  constant NMSUB_C     : std_logic_vector(6 downto 0) := "1001011";  --
  constant NMADD_C     : std_logic_vector(6 downto 0) := "1001111";  --
  constant OP_FP_C     : std_logic_vector(6 downto 0) := "1010011";  --
  constant OP_V_C      : std_logic_vector(6 downto 0) := "1010111";  --
  constant CUSTOM_2_C  : std_logic_vector(6 downto 0) := "1011011";  --
  -- ROW 4
  constant BRANCH_C    : std_logic_vector(6 downto 0) := "1100011";  --
  constant JALR_C      : std_logic_vector(6 downto 0) := "1100111";  -- Jump and Link Register I-Type
  constant JAL_C       : std_logic_vector(6 downto 0) := "1101111";  -- Jump and Link
  constant SYSTEM_C    : std_logic_vector(6 downto 0) := "1110011";  --
  constant OP_VE_C     : std_logic_vector(6 downto 0) := "1110111";  --
  constant CUSTOM_3_C  : std_logic_vector(6 downto 0) := "1111011";  --

  -- =======================================
  -- FUNCTION 3 CODES (See Chapter 35)
  -- =======================================
  -- (JALR_C)
  constant F3_JALR_C      : std_logic_vector(2 downto 0) := "000";  --
  -- CONTROL TRANSFER FUNCTIONS (BRANCH_C)
  constant F3_BEQ_C       : std_logic_vector(2 downto 0) := "000";  -- BEQ take the branch if registers rs1 and rs2 are equal
  constant F3_BNE_C       : std_logic_vector(2 downto 0) := "001";  -- BNE take the branch if registers rs1 and rs2 are unequal
  constant F3_BLT_C       : std_logic_vector(2 downto 0) := "100";  -- BLT take the branch if rs1 is less than rs2, using signed comparison
  constant F3_BGE_C       : std_logic_vector(2 downto 0) := "101";  -- BGE take the branch if rs1 is greater than or equal to rs2, using signed comparison
  constant F3_BLTU_C      : std_logic_vector(2 downto 0) := "110";  -- BLTU take the branch if rs1 is less than rs2, using unsigned comparison
  constant F3_BGEU_C      : std_logic_vector(2 downto 0) := "111";  -- BGEU take the branch if rs1 is greater than or equal to rs2, using unsigned comparison
  -- LOAD FUNCTIONS (LOAD_C)
  constant F3_LB_C        : std_logic_vector(2 downto 0) := "000";  --
  constant F3_LH_C        : std_logic_vector(2 downto 0) := "001";  --
  constant F3_LW_C        : std_logic_vector(2 downto 0) := "010";  --
  constant F3_LBU_C       : std_logic_vector(2 downto 0) := "100";  --
  constant F3_LHU_C       : std_logic_vector(2 downto 0) := "101";  --
  -- STORE FUNCTIONS (STORE_C)
  constant F3_SB_C        : std_logic_vector(2 downto 0) := "000";  --
  constant F3_SH_C        : std_logic_vector(2 downto 0) := "001";  --
  constant F3_SW_C        : std_logic_vector(2 downto 0) := "010";  --
  -- INTEGER REGISTER-IMMEDIATE INSTRUCTIONS (OP_IMM_C)
  constant F3_ADDI_C      : std_logic_vector(2 downto 0) := "000";  -- ADDI adds the sign-extended 12-bit immediate to register rs1.
  constant F3_SLTI_C      : std_logic_vector(2 downto 0) := "010";  -- SLTI (set less than immediate SIGNED) places rd = 1 if rs1 is less than the signextended imm , else rd = 0.
  constant F3_SLTIU_C     : std_logic_vector(2 downto 0) := "011";  -- SLTIU (set less than immediate UNSIGNED) places rd = 1 if rs1 is less than the imm , else rd = 0.
  constant F3_XORI_C      : std_logic_vector(2 downto 0) := "100";  -- XORI perform bitwise XOR
  constant F3_ORI_C       : std_logic_vector(2 downto 0) := "110";  -- ORI perform bitwise OR
  constant F3_ANDI_C      : std_logic_vector(2 downto 0) := "111";  -- ANDI perform bitwise AND
  constant F3_SLLI_C      : std_logic_vector(2 downto 0) := "001";  -- SLLI is a logical left shift (zeros are shifted into the lower bits)
  constant F3_SRLI_SRAI_C : std_logic_vector(2 downto 0) := "101";  -- SRLI is a logical right shift (zeros are shifted into the upper bits)
  -- INTEGER REGISTER-REGISTER INSTRUCTIONS (OP_C)
  constant F3_ADD_SUB_C   : std_logic_vector(2 downto 0) := "000";  -- ADD performs the addition of rs1 and rs2.
  constant F3_SLL_C       : std_logic_vector(2 downto 0) := "001";  -- SLL performs logical left shift
  constant F3_SLT_C       : std_logic_vector(2 downto 0) := "010";  -- SLT performs signed comparison, 1 to rd if rs1 < rs2, 0 otherwise.
  constant F3_SLTU_C      : std_logic_vector(2 downto 0) := "011";  -- SLTU performs unsigned comparison, 1 to rd if rs1 < rs2, 0 otherwise.
  constant F3_XOR_C       : std_logic_vector(2 downto 0) := "100";  -- AND, OR, and XOR perform bitwise logical operations
  constant F3_SRL_SRA_C   : std_logic_vector(2 downto 0) := "101";  -- SRL performs logical right shift
  constant F3_OR_C        : std_logic_vector(2 downto 0) := "110";  -- OR  perform bitwise logical operations
  constant F3_AND_C       : std_logic_vector(2 downto 0) := "111";  -- AND perform bitwise logical operations
  -- ====================================
  -- FUNCTION 7 (See Chapter 35)
  -- ====================================
  constant F7_SLLI_C      : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SRLI_C      : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SRAI_C      : std_logic_vector(6 downto 0) := "0100000";  --
  constant F7_ADD_C       : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SUB_C       : std_logic_vector(6 downto 0) := "0100000";  -- SUB performs the subtraction of rs2 from rs1.
  constant F7_SLL_C       : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SLT_C       : std_logic_vector(6 downto 0) := "0000000";  -- SRL performs logical right shift
  constant F7_SLTU_C      : std_logic_vector(6 downto 0) := "0100000";  -- SRA performs  arithmetic right shifts on the value in register rs1 by the shift amount held in the lower 5 bits of register rs2
  constant F7_XOR_C       : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SRL_C       : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_SRA_C       : std_logic_vector(6 downto 0) := "0100000";  --
  constant F7_OR_C        : std_logic_vector(6 downto 0) := "0000000";  --
  constant F7_AND_C       : std_logic_vector(6 downto 0) := "0000000";  --

end package;
