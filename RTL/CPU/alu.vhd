library ieee;
use ieee.std_logic_1164.all;

library work;
use work.CPU_PKG.all;
use work.MEM_PKG.all;


entity alu is
  generic (
    G_RSTTYPESEL   : integer   := 0;  -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'   -- Reset active level
    );
  port (
    clk_i       : in  std_logic;
    rst_i       : in  std_logic;
    -- Operation
    op_alu_i    : in  op_alu_t;
    -- Data In
    rs1_rsp_i   : in  mem_rsp_t;
    rs2_rsp_i   : in  mem_rsp_t;
    imm_i       : in  std_logic_vector(XLEN_C-1 downto 0);
    imm_valid_i : in  std_logic;
    -- Data Out
    rd_req_o    : out mem_req_t
    );
end alu;

architecture arch of alu is
  signal op1_s    : std_logic_vector(XLEN_C-1 downto 0);  -- Operand 1 for ALU Operations
  signal op2_s    : std_logic_vector(XLEN_C-1 downto 0);  -- Operand 2 for ALU Operations
  signal result_r : std_logic_vector(XLEN_C-1 downto 0);  -- ALU Operation


begin
  -- Operator Data Selection
  op1_s <= rs1_rsp_i.rdata;
  op2_s <= rs2_rsp_i.rdata when (imm_valid_i = '0') else imm_i;


  -- -----------------------------------------
  -- ARITHEMTIC LOGIC UNIT
  -- -----------------------------------------
  alu_op_p : process(clk_i, rst_i)
    procedure Reset is
    begin
      result_r <= (others => '0');
    end procedure;
  begin
    if (G_RSTTYPESEL = 0 and G_RSTACTIVELVL = rst_i) then
      Reset;
    elsif(rising_edge(clk_i)) then

      if(op_alu_i.add_op = '1') then
        result_r <=;
      elsif(op_alu_i.sub_op = '1') then
        result_r <=;
      elsif(op_alu_i.slt_op = '1') then
        -- Set Less Than [Signed]
        result_r <= std_logic_vector(to_signed(1, XLEN_C)) when (signed(op1_s) < signed(op2_s)) else
                    std_logic_vector(to_signed(0, XLEN_C));
      elsif(op_alu_i.sltu_op = '1') then
        -- Set Less Than [Unsigned]
        result_r <= std_logic_vector(to_unsigned(1, XLEN_C)) when (unsigned(op1_s) < unsigned(op2_s)) else
                    std_logic_vector(to_unsigned(0, XLEN_C));
      elsif(op_alu_i.srl_op = '1') then
        -- Shift Right Logical
        result_r <=;
      elsif(op_alu_i.sll_op = '1') then
        -- Shift Left Logical
        result_r <=;
      elsif(op_alu_i.sra_op = '1') then
        -- Shift Right Arithmetic
        result_r <=;
      elsif(op_alu_i.xor_op = '1') then
        -- XOR: Bitwise RS1 XOR RS2
        -- XORI: Bitwise RS1 XOR IMM(11..0) [Sign Extended]
        result_r <=;
      elsif(op_alu_i.and_op = '1') then
        -- AND: Bitwise RS1 AND RS2
        -- ANDI: Bitwise RS1 AND IMM(11..0) [Sign Extended]
        result_r <=;
      elsif(op_alu_i.or_op = '1') then
        -- OR: Bitwise RS1 OR RS2
        -- ORI: Bitwise RS1 OR IMM(11..0) [Sign Extended]
        result_r <=;
      end if;

      if(G_RSTTYPESEL = 1 and G_RSTACTIVELVL = rst_i) then
        Reset;
      end if;
    end if;
  end process alu_op_p;

end arch;
