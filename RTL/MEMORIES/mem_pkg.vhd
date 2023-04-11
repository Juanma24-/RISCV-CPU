library ieee;
use ieee.std_logic_1164.all;

package MEM_PKG is


    constant XLEN_C : integer := 32; -- Registers Width

    -- --------------------------
    -- TYPES
    -- --------------------------

    -- MEMORY IN/OUT
    type mem32_in_t is record
        addr : std_logic_vector(4 downto 0);        -- x0-x31
        data : std_logic_vector(XLEN_C-1 downto 0); -- Data for Write
        en   : std_logic;                           -- Enable memory access
        wr   : std_logic;                           -- If '1' write, otherwise read
    end record mem32_in_t;

    type mem_out_t is record
        rd_data : std_logic_vector(XLEN_C-1 downto 0); -- Read Data
        rd_vd   : std_logic;                           -- Read Valid
    end record mem_out_t;


end package;