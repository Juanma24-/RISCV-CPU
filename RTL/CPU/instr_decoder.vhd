library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;

entity instr_decoder is
  generic (
    G_RSTTYPESEL : integer := 0; -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0' -- Reset active level
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    instr_i : std_logic_vector(31 downto 0); -- Fetched Instruction
    instr_vd_i : std_logic -- Instruction Valid
  );
end instr_decoder;

architecture arch of instr_decoder is
  -- INSTRUCTION TYPE SELECTION MUXES
  signal type_r_s : std_logic := '0'; -- Asserted if Type R instruction is fetched
  signal type_i_s : std_logic := '0'; -- Asserted if Type I instruction is fetched
  signal type_s_s : std_logic := '0'; -- Asserted if Type S instruction is fetched
  signal type_b_s : std_logic := '0'; -- Asserted if Type B instruction is fetched
  signal type_u_s : std_logic := '0'; -- Asserted if Type U instruction is fetched
  signal type_j_s : std_logic := '0'; -- Asserted if Type J instruction is fetched

  -- Decoded fields
  signal rd_r     : std_logic_vector(4 downto 0);  -- RD field 
  signal funct3_r : std_logic_vector(2 downto 0);  -- FUNCT3 field
  signal rs1_r    : std_logic_vector(3 downto 0);  -- RS1 field 
  signal rs2_r    : std_logic_vector(4 downto 0);  -- RS2 field
  signal funct7_r : std_logic_vector(6 downto 0);  -- FUNCT7 field
  signal imm_r    : std_logic_vector(31 downto 0); -- IMM Field



begin

  -- ----------------------------------------
  -- INSTRUCTION TYPE SELECTORS
  -- ----------------------------------------
  type_r_s <= '1' when instr_i(R_TYPE_ACT_BIT_C) = '1' else '0'; 
  type_i_s <= '1' when instr_i(I_TYPE_ACT_BIT_C) = '1' else '0'; 
  type_s_s <= '1' when instr_i(S_TYPE_ACT_BIT_C) = '1' else '0'; 
  type_b_s <= '1' when instr_i(B_TYPE_ACT_BIT_C) = '1' else '0'; 
  type_u_s <= '1' when instr_i(U_TYPE_ACT_BIT_C) = '1' else '0'; 
  type_j_s <= '1' when instr_i(J_TYPE_ACT_BIT_C) = '1' else '0'; 


  -- -----------------------------------------
  -- INSTRUCTIONS DECODER
  -- -----------------------------------------

  -- INSTRUCTION DECODER
  decoder_p : process( clk_i, rst_i )
  procedure Reset is
    begin

  end procedure;
  begin
    if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then

      -- Default value
      imm_r <= (others => '0');

      -- Decode fields always located at the same place
      rs1_r <= instr_i(19 downto 15);
      rs2_r <= instr_i(24 downto 20);
      rd_r  <= instr_i(11 downto 7);

      -- OPCODE Selector
      case instr_i(7 downto 0) is
        when others =>
        when others =>
      end case;


      -- FUNCT3_R Selector
      case instr_i(14 downto 12) is 
          when F3_ADD_C | F3_ADDI_C | F3_SUB_C =>
          when F3_SLT_C | F3_SLTI_C =>
          when F3_SLTU_C | F3_SLTIU_C =>
          when F3_AND_C | F3_ANDI_C =>
          when F3_OR_C | F3_ORI_C =>
          when F3_XOR_C | F3_XORI_C =>
          when F3_SLL_C | F3_SLLI_C =>
          when F3_SLR_C | F3_SLRI_C =>
          when F3_SRA_C | F3_SRAI_C =>
          when others =>
            -- Execute NOP
      end case ;

      -- FUNCT7_R Selector
      case instr_i(31 downto 25) is
        when F7_SUB_C =>
        when F7_SRA_C =>
        when others =>
      end case;

      -- IMMEDIATE DECODER
      if (type_i_s = '1') then
        imm_r(11 downto 0) <= instr_i(31 downto 20);
      elsif(type_s_s = '1') then
        imm_r(11 downto 5) <= instr_i(31 downto 25);
        imm_r(4 downto 0)  <= instr_i(11 downto 7);
      elsif(type_b_s = '1') then
        imm_r(12)          <= instr_i(31);
        imm_r(11)          <= instr_i(7);
        imm_r(10 downto 5) <= instr_i(30 downto 25);
        imm_r(4 downto 1)  <= instr_i(11 downto 8);
      elsif(type_u_s = '1') then
        imm_r(31 downto 12) <= instr_i(31 downto 12);
      elsif(type_j_s = '1') then
        imm_r(20)           <= instr_i(31);
        imm_r(19 downto 12) <= instr_i(19 downto 12);
        imm_r(11)           <= instr_i(20);
        imm_r(10 downto 1)  <= instr_i(30 downto 21);
      else
        imm_r <= (others => '0');
      end if;

      if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process ; -- decoder_p


end arch ; -- arch