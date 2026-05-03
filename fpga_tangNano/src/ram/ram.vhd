library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

entity Ram is
    port (
        dout  : out std_logic_vector(7 downto 0);
        clk   : in  std_logic;
        oce   : in  std_logic;
        ce    : in  std_logic;
        reset : in  std_logic;
        wre   : in  std_logic;
        ad    : in  std_logic_vector(14 downto 0);
        din   : in  std_logic_vector(7 downto 0)
    );
end Ram;

architecture Behavioral of Ram is
    type ram_type is array (0 to 32767) of std_logic_vector(7 downto 0);
    
    impure function init_ram_from_file(file_name : string) return ram_type is
        file text_file      : text open read_mode is file_name;
        variable text_line  : line;
        variable bit_val    : bit_vector(7 downto 0);
        variable ram_content: ram_type := (others => (others => '0'));
    begin
        for i in 0 to 32767 loop
            if not endfile(text_file) then
                readline(text_file, text_line);
                read(text_line, bit_val);
                ram_content(i) := to_stdlogicvector(bit_val);
            end if;
        end loop;
        return ram_content;
    end function;

    signal RAM_BLOCK : ram_type := init_ram_from_file("src/ram_init.txt");

    attribute syn_ramstyle : string;
    attribute syn_ramstyle of RAM_BLOCK : signal is "block_ram";

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if wre = '1' then
                    RAM_BLOCK(to_integer(unsigned(ad))) <= din;
                end if;
                dout <= RAM_BLOCK(to_integer(unsigned(ad)));
            end if;
        end if;
    end process;

end Behavioral;