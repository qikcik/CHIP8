library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Disp4x7Seg_Types.all;

entity Disp4x7Seg is
	port (
		in_clk					: in std_logic;
		
		in_7seg 					: in Array4x7Seg;
		
		out_7seg 				: out std_logic_vector(7 downto 0) 	:= (others => '0');
		out_7segDigitSelect 	: out std_logic_vector(3 downto 0) 	:= (others => '0')
	);
end Disp4x7Seg;

architecture behaviour of Disp4x7Seg is
	component clockDivider is
		generic(
			inClock_speed 	: integer	:= 50_000_000;
			outClock_speed	: integer	:= 50_000_000
		);
		port(
			in_clk			: in std_logic 	:= '0';
			out_clk			: out std_logic	:= '0'
		);
	end component;
	
	signal digitSelect : unsigned(1 downto 0) := to_unsigned(0,2);
	signal clkEnabled  	: std_logic := '0';
	
begin 
	e_clockDivider: ClockDivider 
	generic map(
		inClock_speed 	=> 50_000_000,
		outClock_speed => 1_000
	)
	port map(
		in_clk	=> in_clk,
		out_clk	=> clkEnabled
	);
	
	with digitSelect select out_7seg <=
		in_7seg(0) when "00",
		in_7seg(1) when "01",
		in_7seg(2) when "10",
		in_7seg(3) when "11",
		"00000000" when others;
		
	with digitSelect select out_7segDigitSelect <=
		"0001" when "00",
		"0010" when "01",
		"0100" when "10",
		"1000" when "11",
		"0000" when others;
	
	process(in_clk,clkEnabled)
	begin
		if rising_edge(clkEnabled) then
			digitSelect <= digitSelect + 1;
		end if;
	end process;
	
end behaviour;

