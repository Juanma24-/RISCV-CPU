library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;

entity instr_decoder is
  generic (
    G_RSTTYPESEL : integer := 0; -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'; -- Reset active level
  )
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    instr_i : std_logic_vector(31 downto 0); -- Fetched Instruction
    instr_vd_i : std_logic; -- Instruction Valid
  ) ;
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
  signal imm_r    : std_logic_vector(20 downto 0); -- IMM Field



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
  -- INSTRUCTIONS DECODERS (ONE PER TYPE)
  -- -----------------------------------------

  -- R TYPE DECODER
  r_decoder_p : process( clk_i, rst_i )
  procedure Reset is
    begin

  end procedure;
  begin
    if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then

      if(type_r_s = '1') then



      end if;

      if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process ; -- r_decoder_p


end arch ; -- arch