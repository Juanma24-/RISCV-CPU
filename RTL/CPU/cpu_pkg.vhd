-- CPU Related Package
library ieee;
use ieee.std_logic_1164.all;

package CPU_PKG is


    constant XLEN_C : integer := 32; -- Registers Width

    -- --------------------------
    -- TYPES
    -- --------------------------
    -- INSTRUCTION DECODER
    type op_t is record
        op_imm : std_logic; -- Covers OP_IMM
        op     : std_logic; -- Covers OP
        lui    : std_logic; -- Covers LUI
        auipc  : std_logic; -- Cover AUIPC
    end record op_t;
    type f3_t is record
        add    : std_logic; -- Covers ADDI
        subs   : std_logic;
        slt    : std_logic; -- Covers SLTI
        sltu   : std_logic; -- Covers SLTIU TODO: Merge with SLT??
        andop  : std_logic; -- Covers ANDI
        orop   : std_logic; -- Covers ORI
        xorop  : std_logic; -- Covers XORI
        shiftl : std_logic; -- Covers SLLI, SLL
        shiftr : std_logic; -- Covers SRLI, SRL
        shifta : std_logic; -- Covers SRAI, SRA
    end record f3_t;

    -- --------------------------
    -- OPCODES
    -- --------------------------
    -- The basic encoding of OPCODES takes the following rule: 
    -- R-Type: "00000100" 0x4 
    -- I-Type: "00001000" 0x8
    -- S-Type: "00010000" 0x10
    -- B-Type: "00100000" 0x20
    -- U-Type: "01000000" 0x40
    -- J-Type: "10000000" 0x80

    constant R_TYPE_ACT_BIT_C : integer := 2; 
    constant I_TYPE_ACT_BIT_C : integer := 3; 
    constant S_TYPE_ACT_BIT_C : integer := 4; 
    constant B_TYPE_ACT_BIT_C : integer := 5; 
    constant U_TYPE_ACT_BIT_C : integer := 6; 
    constant J_TYPE_ACT_BIT_C : integer := 7; 

    constant OP_C     : std_logic_vector(7 downto 0) := "00000100"; -- OP instructions are encoded with OPCODE 0x8
    constant OP_IMM_C : std_logic_vector(7 downto 0) := "00001000"; -- OP-IMM instructions are encoded with OPCODE 0x4 (I-Type)
    constant LUI_C    : std_logic_vector(7 downto 0) := "01000000"; -- LUI (load upper immediate) places the U-immediate value in the top 20 bits of the destination register rd, filling in the lowest 12 bits with zeros.
    constant AUIPC_C  : std_logic_vector(7 downto 0) := "01000001"; -- AUIPC (add upper immediate to pc)
    constant JAL_C    : std_logic_vector(7 downto 0) := "10000000"; -- JAL (Jump and Link) 
    constant JALR_C   : std_logic_vector(7 downto 0) := "00001001"; -- JALR (Jump and Link Register) I-Type
    constant BRANCH_C : std_logic_vector(7 downto 0) := "00100000"; -- BRANCH 
    constant LOAD_C   : std_logic_vector(7 downto 0) := "00001010"; -- LOAD (I-Type)
    constant STORE_C  : std_logic_vector(7 downto 0) := "00010000"; -- STORE (S-Type)

    -- =======================================
    -- FUNCTION 3
    -- =======================================
 
    constant F3_ADDI_C  : std_logic_vector(2 downto 0) := "000"; -- ADDI adds the sign-extended 12-bit immediate to register rs1.
    constant F3_ADD_C  : std_logic_vector(2 downto 0) := "000"; -- ADD performs the addition of rs1 and rs2.
    constant F3_SUB_C  : std_logic_vector(2 downto 0) := "000"; -- SUB performs the subtraction of rs2 from rs1.

    constant F3_SLTI_C  : std_logic_vector(2 downto 0) := "001"; -- SLTI (set less than immediate SIGNED) places rd = 1 if rs1 is less than the signextended imm , else rd = 0.
    constant F3_SLT_C  : std_logic_vector(2 downto 0) := "001"; -- SLT perforñs signed comparison, 1 to rd if rs1 < rs2, 0 otherwise.

    constant F3_SLTIU_C : std_logic_vector(2 downto 0) := "010"; -- SLTIU (set less than immediate UNSIGNED) places rd = 1 if rs1 is less than the imm , else rd = 0.
    constant F3_SLTU_C : std_logic_vector(2 downto 0) := "010"; -- SLTU performs unsigned comparison, 1 to rd if rs1 < rs2, 0 otherwise.

    constant F3_ANDI_C  : std_logic_vector(2 downto 0) := "011"; -- ANDI are logical operations that perform bitwise AND
    constant F3_AND_C  : std_logic_vector(2 downto 0) := "011"; -- AND, OR, and XOR perform bitwise logical operations

    constant F3_ORI_C   : std_logic_vector(2 downto 0) := "100"; -- ORI are logical operations that perform bitwise OR
    constant F3_OR_C   : std_logic_vector(2 downto 0) := "100"; -- AND, OR, and XOR perform bitwise logical operations

    constant F3_XORI_C  : std_logic_vector(2 downto 0) := "101"; -- XORI are logical operations that perform bitwise XOR
    constant F3_XOR_C  : std_logic_vector(2 downto 0) := "101"; -- AND, OR, and XOR perform bitwise logical operations

    constant F3_SLLI_C  : std_logic_vector(2 downto 0) := "110"; -- SLLI is a logical left shift (zeros are shifted into the lower bits)
    constant F3_SLL_C  : std_logic_vector(2 downto 0) := "110"; -- SLL performs logical left shift

    constant F3_SLRI_C  : std_logic_vector(2 downto 0) := "111"; -- SRLI is a logical right shift (zeros are shifted into the upper bits)
    constant F3_SLR_C  : std_logic_vector(2 downto 0) := "111"; -- SRL performs logical right shift

    constant F3_SRAI_C  : std_logic_vector(2 downto 0) := "111"; -- SRAI is an arithmetic right shift (the original sign bit is copied into the vacated upper bits)
    constant F3_SRA_C  : std_logic_vector(2 downto 0) := "111"; -- SRA performs  arithmetic right shifts on the value in register rs1 by the shift amount held in the lower 5 bits of register rs2


    -- ====================================
    -- FUNCTION 7
    -- ====================================
    constant F7_ADD_C  : std_logic_vector(6 downto 0) := "0000000"; -- ADD performs the addition of rs1 and rs2.
    constant F7_SUB_C  : std_logic_vector(9 downto 0) := "0100000"; -- SUB performs the subtraction of rs2 from rs1.
    constant F7_SRL_C  : std_logic_vector(9 downto 0) := "0000000"; -- SRL performs logical right shift
    constant F7_SRA_C  : std_logic_vector(9 downto 0) := "0100000"; -- SRA performs  arithmetic right shifts on the value in register rs1 by the shift amount held in the lower 5 bits of register rs2

    -- ====================================
    -- CONTROL TRANSFER FUNCTIONS
    -- ====================================

    constant F_BEQ_C  : std_logic_vector(2 downto 0) := "000"; -- BEQ take the branch if registers rs1 and rs2 are equal 
    constant F_BNE_C  : std_logic_vector(2 downto 0) := "001"; -- BNE take the branch if registers rs1 and rs2 are unequal
    constant F_BLT_C  : std_logic_vector(2 downto 0) := "010"; -- BLT take the branch if rs1 is less than rs2, using signed comparison
    constant F_BLTU_C : std_logic_vector(2 downto 0) := "011"; -- BLTU take the branch if rs1 is less than rs2, using unsigned comparison 
    constant F_BGE_C  : std_logic_vector(2 downto 0) := "100"; -- BGE take the branch if rs1 is greater than or equal to rs2, using signed comparison
    constant F_BGEU_C : std_logic_vector(2 downto 0) := "101"; -- BGEU take the branch if rs1 is greater than or equal to rs2, using unsigned comparison
 
    end package;