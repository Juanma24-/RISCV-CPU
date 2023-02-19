-- CPU Related Package
library ieee;

use ieee.std_logic_1164.all;

package CPU_PKG is
    -- --------------------------
    -- OPCODES
    -- --------------------------

    -- INTEGER REGISTER-IMMEDIATE INSTRUCTIONS
    constant OP-IMM_C : std_logic_vector(7 downto 0) := "00000000"; -- OP-IMM instructions are encoded with OPCODE 0x0
 
    constant F3_ADDI_C  : std_logic_vector(7 downto 0) := ; -- ADDI adds the sign-extended 12-bit immediate to register rs1.
    constant F3_SLTI_C  : std_logic_vector(7 downto 0) := ; -- SLTI (set less than immediate SIGNED) places rd = 1 if rs1 is less than the signextended imm , else rd = 0.
    constant F3_SLTIU_C : std_logic_vector(7 downto 0) := ; -- SLTIU (set less than immediate UNSIGNED) places rd = 1 if rs1 is less than the imm , else rd = 0.
    constant F3_ANDI_C  : std_logic_vector(7 downto 0) := ; -- ANDI are logical operations that perform bitwise AND
    constant F3_ORI_C   : std_logic_vector(7 downto 0) := ; -- ORI are logical operations that perform bitwise OR
    constant F3_XORI_C  : std_logic_vector(7 downto 0) := ; -- XORI are logical operations that perform bitwise XOR
    constant F3_SLLI_C  : std_logic_vector(7 downto 0) := ; -- 
    constant F3_SLRI_C  : std_logic_vector(7 downto 0) := ; -- 
    constant F3_SRAI_C  : std_logic_vector(7 downto 0) := ; --   
end package;