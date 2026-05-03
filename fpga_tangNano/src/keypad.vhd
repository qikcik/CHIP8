library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Keypad is
    port (
        clk_27mhz       : in  std_logic;
        cols            : in  std_logic_vector(3 downto 0);
        rows            : out std_logic_vector(3 downto 0);
        keyPress        : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of Keypad is

    signal scan_timer : integer range 0 to 270000 := 0;
    signal row_idx    : integer range 0 to 3 := 0;
    signal keys_reg   : std_logic_vector(15 downto 0) := (others => '0');

begin
    process(clk_27mhz)
    begin
        if rising_edge(clk_27mhz) then
            if scan_timer = 270000 then
                scan_timer <= 0;

                case row_idx is 
                    when 0 => 
                        keys_reg(1)  <= not cols(0); -- Klawisz 1
                        keys_reg(2)  <= not cols(1); -- Klawisz 2
                        keys_reg(3)  <= not cols(2); -- Klawisz 3
                        keys_reg(12) <= not cols(3); -- Klawisz C
                    when 1 => 
                        keys_reg(4)  <= not cols(0); -- Klawisz 4
                        keys_reg(5)  <= not cols(1); -- Klawisz 5
                        keys_reg(6)  <= not cols(2); -- Klawisz 6
                        keys_reg(13) <= not cols(3); -- Klawisz D
                    when 2 => 
                        keys_reg(7)  <= not cols(0); -- Klawisz 7
                        keys_reg(8)  <= not cols(1); -- Klawisz 8
                        keys_reg(9)  <= not cols(2); -- Klawisz 9
                        keys_reg(14) <= not cols(3); -- Klawisz E
                    when 3 => 
                        keys_reg(10) <= not cols(0); -- Klawisz A
                        keys_reg(0)  <= not cols(1); -- Klawisz 0
                        keys_reg(11) <= not cols(2); -- Klawisz B
                        keys_reg(15) <= not cols(3); -- Klawisz F
                end case;

                if row_idx = 3 then
                    row_idx <= 0;
                else
                    row_idx <= row_idx + 1;
                end if;
                
            else
                scan_timer <= scan_timer + 1;
            end if;
        end if;
    end process;

    process(row_idx)
    begin
        case row_idx is
            when 0 => rows <= "1110";
            when 1 => rows <= "1101";
            when 2 => rows <= "1011";
            when 3 => rows <= "0111";
            when others => rows <= "1111";
        end case;
    end process;

    keyPress <= keys_reg;

end architecture;