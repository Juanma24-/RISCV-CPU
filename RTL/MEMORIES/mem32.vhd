library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MEM_PKG.all;

entity mem32 is
  generic (
    G_RSTTYPESEL   : integer := 0;       -- 0: Asynchronous Reset, 1: Synchronous Reset
    G_RSTACTIVELVL : std_logic := '0'  -- Reset active level
  );
  port (
    clk_i        : in std_logic;
    rst_i        : in std_logic;
    --
    p1_i : in mem32_in_t;
    p1_o : out mem_out_t;
    --
    p2_i : in mem32_in_t;
    p2_o : out mem_out_t;
    --
    p3_i : in mem32_in_t;
    p3_o : out mem_out_t
  );
end mem32;

architecture arch of mem32 is
    type memory_array is array (0 to 31) of std_logic_vector(31 downto 0);
    signal mem_r : memory_array;
    --
    signal p1_rd_data_r : std_logic_vector(31 downto 0);
    signal p2_rd_data_r : std_logic_vector(31 downto 0);
begin

    -- 


    mem_inf_p : process (clk_i, rst_i)
    procedure Reset is
     begin
 
    end procedure;
    begin
        if (G_RSTTYPESEL= '0' and  G_RSTACTIVELVL = rst_i) then
            Reset;
        elsif(rising_edge(clk_i)) then

            -- WRITE
            if p3_i.en = '1' then
                mem_r(to_integer(unsigned(p3_i.addr))) <= p3_i.data;
            end if;
            -- READ
            if p1_i.en = '1' then
                p1_rd_data_r <= mem_r(to_integer(unsigned(p1_i.addr)));
            end if;
            if p2_i.en = '1' then
                p2_rd_data_r <= mem_r(to_integer(unsigned(p2_i.addr)));
            end if; 

            if(G_RSTTYPESEL = '1' and G_RSTACTIVELVL = rst_i) then
                Reset;
            end if;
        end if;
    end process mem_inf_p;

    
end arch;
