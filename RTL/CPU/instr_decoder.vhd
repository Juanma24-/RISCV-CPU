library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;


entity instr_decoder is
  generic (
    G_RSTTYPESEL : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    -- 
    instr_i      : in std_logic_vector(31 downto 0);  -- Fetched Instruction
    -- To ALU
    op_decoded_o : out op_t;                                -- Operation Decoded record Output
    f3_decoded_o : out f3_t;                                -- Operation Decoded record Output
    rd_o         : out std_logic_vector(5 downto 0);        -- Register Destination Output
    imm_o        : out std_logic_vector(XLEN_C-1 downto 0); -- Immediate Value
    -- To REGISTER MEMORY
    rs1_o        : out mem32_in_t;                            -- Register Selection 1 Output
    rs2_o        : out mem32_in_t                             -- Register Selection 2 Output
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
  --
  signal op_decoded_r : op_t;                                -- Operation Decoded register
  signal f3_decoded_r : f3_t;                                -- function 3 decoded register
  signal imm_r        : std_logic_vector(XLEN_C-1 downto 0);
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

  -- Aynchronous to read the memory on time
  rs1_o.addr <= instr_i(19 downto 15); -- Always at the same place
  rs1_o.data <= (others => '0');
  rs1_o.en   <= '1';                   -- Always Read (Conflict solved at memory level)
  rs1_o.wr   <= '0';                   -- Always Read (Conflict solved at memory level)
  rs2_o.addr <= instr_i(24 downto 20); -- Always at the same place
  rs2_o.data <= (others => '0');
  rs2_o.en   <= '1';                   -- Always Read (Conflict solved at memory level)
  rs2_o.wr   <= '0';                   -- Always Read (Conflict solved at memory level)
  -- To ALU
  op_decoded_o <= op_decoded_r;
  f3_decoded_o <= f3_decoded_r;
  rd_o         <= instr_i(11 downto 7);  -- Always at the same place
  imm_o        <= imm_r;

  -- -----------------------------------------
  -- INSTRUCTIONS DECODER
  -- -----------------------------------------
  decoder_p : process( clk_i, rst_i )
  procedure Reset is
    begin
      f3_decoded_r <= (others => '0');
      imm_r        <= (others => '0');
      op_decoded_r <= (others => '0');
  end procedure;
  begin
    if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then

      -- OPCODE Selector
      op_decoded_r <= (others => '0');

      case instr_i(7 downto 0) is
        when OP_IMM_C =>
          -- Immediate operations (I type)
          op_decoded_r.op_imm <= '1';
        when OP_C =>
          -- Register Register Operations
          op_decoded_r.op <= '1';
        when LUI_C => 
          -- Load Upper Immediate (U Type)
          op_decoded_r.lui <= '1';
        when AUIPC_C =>
          -- Add Upper Immediate to PC (U type)
          op_decoded_r.auipc <= '1';
        when JAL_C =>
          -- Jump and link operation

        when JALR_C =>
          -- Jump and Link register operation

        when BRANCH_C => 
          -- Branch Operations

        when LOAD_C =>
          -- LOAD Operation

        when STORE_C =>
          -- STORE Operation 

        when others =>
          -- Operation field with non-defined value

      end case;


      -- FUNCT3_R Selector
      f3_decoded_r <= (others => '0');
      case instr_i(14 downto 12) is 
          when F3_ADD_C | F3_ADDI_C | F3_SUB_C =>
            -- Funct 7 decoding
            if instr_i(30) = '1' then
              f3_decoded_r.subs <= '1'; -- Select substraction
            else
              f3_decoded_r.add <= '1';  -- Select addition
            end if;
          when F3_SLT_C | F3_SLTI_C =>
            f3_decoded_r.slt <= '1';
          when F3_SLTU_C | F3_SLTIU_C =>
            f3_decoded_r.sltu <= '1';
          when F3_AND_C | F3_ANDI_C =>
            f3_decoded_r.andop <= '1';
          when F3_OR_C | F3_ORI_C =>
            f3_decoded_r.orop <= '1';
          when F3_XOR_C | F3_XORI_C =>
            f3_decoded_r.xorop <= '1';
          when F3_SLL_C | F3_SLLI_C =>
            f3_decoded_r.shiftl <= '1';
          when F3_SLR_C | F3_SLRI_C =>
            -- Funct 7 decoding
            if instr_i(30) = '0' then
              f3_decoded_r.shiftr <= '1';               
            else 
              f3_decoded_r.shifta <= '1';
            end if;
          when others =>
            f3_decoded_r <= (others => '0');
      end case ;

      -- IMMEDIATE DECODER
      if (type_i_s = '1') then
        imm_r (XLEN_C-1 downto 11) <= (others => instr_i(31)); -- Sign extension
        imm_r(10 downto 0) <= instr_i(30 downto 20);
      elsif(type_s_s = '1') then
        imm_r (XLEN_C-1 downto 11) <= (others => instr_i(31)); -- Sign extension
        imm_r(10 downto 5) <= instr_i(30 downto 25);
        imm_r(4 downto 0)  <= instr_i(11 downto 7);
      elsif(type_b_s = '1') then
        imm_r(XLEN_C-1 downto 12)  <= (others => instr_i(31)); -- Sign extension
        imm_r(11)            <= instr_i(7);
        imm_r(10 downto 5)   <= instr_i(30 downto 25);
        imm_r(4 downto 1)    <= instr_i(11 downto 8);
        imm_r(0) <= '0';
      elsif(type_u_s = '1') then
        imm_r(XLEN_C-1 downto 12) <= instr_i(31 downto 12);
        imm_r(11 downto 0)  <= (others => '0');
      elsif(type_j_s = '1') then
        imm_r(XLEN_C-1 downto 20) <= (others => instr_i(31)); -- Sign extension
        imm_r(19 downto 12) <= instr_i(19 downto 12);
        imm_r(11)           <= instr_i(20);
        imm_r(10 downto 1)  <= instr_i(30 downto 21);
        imm_r(0) <= '0'; 
      else
        imm_r <= (others => '0');
      end if;

      if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process ; -- decoder_p


end arch ; -- arch