library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package Disp4x7Seg_Types is
 
	type Array4x7Seg is array(3 downto 0) of  std_logic_vector(7 downto 0);
	
	constant CONST7SEG_EMPTY 	: std_logic_vector(7 downto 0) 	:= "00000000";
	constant CONST7SEG_DOT 		: std_logic_vector(7 downto 0) 	:= "00000001";
	
	constant CONST7SEG_0 : std_logic_vector(7 downto 0) := "11111100";
	constant CONST7SEG_1 : std_logic_vector(7 downto 0) := "01100000";
	constant CONST7SEG_2 : std_logic_vector(7 downto 0) := "11011010";
	constant CONST7SEG_3 : std_logic_vector(7 downto 0) := "11110010";
	constant CONST7SEG_4 : std_logic_vector(7 downto 0) := "01100110";
	constant CONST7SEG_5 : std_logic_vector(7 downto 0) := "10110110";
	constant CONST7SEG_6 : std_logic_vector(7 downto 0) := "10111110";
	constant CONST7SEG_7 : std_logic_vector(7 downto 0) := "11100000";
	constant CONST7SEG_8 : std_logic_vector(7 downto 0) := "11111110";
	constant CONST7SEG_9 : std_logic_vector(7 downto 0) := "11110110";
	
	constant CONST7SEG_A : std_logic_vector(7 downto 0) := "11101110";
	constant CONST7SEG_B : std_logic_vector(7 downto 0) := "00111110";
	constant CONST7SEG_C : std_logic_vector(7 downto 0) := "10011100";
	constant CONST7SEG_D : std_logic_vector(7 downto 0) := "01111010";
	constant CONST7SEG_E : std_logic_vector(7 downto 0) := "10011110";
	constant CONST7SEG_F : std_logic_vector(7 downto 0) := "10001110";
	
	constant CONST7SEG_H : std_logic_vector(7 downto 0) := "01101110";
	constant CONST7SEG_J : std_logic_vector(7 downto 0) := "11111000";
	constant CONST7SEG_L : std_logic_vector(7 downto 0) := "00011100";
	constant CONST7SEG_N : std_logic_vector(7 downto 0) := "00101010";
	constant CONST7SEG_P : std_logic_vector(7 downto 0) := "11001110";
	constant CONST7SEG_S : std_logic_vector(7 downto 0) := "10110110";
	constant CONST7SEG_U : std_logic_vector(7 downto 0) := "01111100";
	constant CONST7SEG_Y : std_logic_vector(7 downto 0) := "01001110";
	
	constant CONST7SEG_r : std_logic_vector(7 downto 0) := "00001010";
	constant CONST7SEG_t : std_logic_vector(7 downto 0) := "00011110";
	constant CONST7SEG_o : std_logic_vector(7 downto 0) := "00111010";
	
	function BinTo7SegHex(inBin : std_logic_vector(3 downto 0)) 
		return std_logic_vector; 

end package Disp4x7Seg_Types;

package body Disp4x7Seg_Types is

	function BinTo7SegHex(inBin : std_logic_vector(3 downto 0)) 
		return std_logic_vector
	is
		variable result : std_logic_vector(7 downto 0) ;
	begin
		case inBin is
			when "0000" => result := CONST7SEG_0;
			when "0001" => result := CONST7SEG_1;
			when "0010" => result := CONST7SEG_2;
			when "0011" => result := CONST7SEG_3;
			when "0100" => result := CONST7SEG_4;
			when "0101" => result := CONST7SEG_5;
			when "0110" => result := CONST7SEG_6;
			when "0111" => result := CONST7SEG_7;
			when "1000" => result := CONST7SEG_8;
			when "1001" => result := CONST7SEG_9;
			when "1010" => result := CONST7SEG_A;
			when "1011" => result := CONST7SEG_B;
			when "1100" => result := CONST7SEG_C;
			when "1101" => result := CONST7SEG_D;
			when "1110" => result := CONST7SEG_E;
			when "1111" => result := CONST7SEG_F;
			when others => result := CONST7SEG_EMPTY;
		end case;
	
		return result;
	end function;
	
end package body Disp4x7Seg_Types;