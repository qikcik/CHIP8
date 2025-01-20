library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clockDivider is
	generic(
		inClock_speed 	: integer	:= 50_000_000;
		outClock_speed	: integer	:= 50_000_000
	);
	port(
		in_clk			: in std_logic 	:= '0';
		out_clk			: out std_logic	:= '0'
	);
end entity clockDivider;

architecture behaviour of clockDivider is

	function numBits(n: natural) return natural is
	begin
		if n > 0 then
			return 1 + numBits(n / 2);
		else
			return 1;
		end if;
	end numBits;

	constant maxCounter: natural := inClock_speed / outClock_speed / 2;
	constant counterBits: natural := numBits(maxCounter);

	signal counter: unsigned(counterBits - 1 downto 0) := (others => '0');
	signal clock: std_logic;

begin
	out_clk <= clock;

	process(in_clk)
	begin
		if rising_edge(in_clk) then
			if counter = maxCounter then
				counter <= to_unsigned(0, counterBits);
				clock <= not clock;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;
	
end architecture behaviour;