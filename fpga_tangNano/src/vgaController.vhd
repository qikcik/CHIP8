library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity VgaController is
	generic (
		 pixelFreq			: integer := 30_000_000;
		 
		 h_displayArea	    : integer := 800;
		 h_pulseWidth       : integer := 40;
		 h_backPorch        : integer := 48;
		 h_frontPorch       : integer := 88;
		 
		 v_displayArea	    : integer := 480;
		 v_pulseWidth       : integer := 3;
		 v_backPorch        : integer := 32;
		 v_frontPorch       : integer := 1
	);
	port (
		in_clk			    : in  std_logic := '0';
		
		out_vgaRGB		    : out std_logic_vector(15 downto 0) := (others => '0');
		out_vgaHSync	    : out std_logic := '0';
		out_vgaVSync	    : out std_logic := '0';

		out_isDisplaying	: out std_logic := '0';
		out_hPos			: out integer := 0;
		out_vPos			: out integer := 0;
		in_vgaRGB			: in  std_logic_vector(15 downto 0) := (others => '0')
	);
end VgaController;

architecture behaviour of VgaController is
	constant wholeLine 	: integer := h_displayArea + h_backPorch + h_frontPorch;
	constant wholeFrame : integer := v_displayArea + v_backPorch + v_frontPorch;
  
	signal hCounter : integer range 0 to  wholeLine-1 	:= 0; 
	signal vCounter : integer range 0 to  wholeFrame-1 	:= 0;

	signal isDisplaying  : boolean := false; 	
  
begin

	out_vgaHSync <= '1' when hCounter < h_pulseWidth  else '0';
							  
	out_vgaVSync <= '1' when vCounter < v_pulseWidth  else '0';
		

	out_isDisplaying 	<= '1' when (hCounter >= h_backPorch) and (hCounter < h_displayArea+h_backPorch) and (vCounter >= v_backPorch) and (vCounter < v_displayArea+v_backPorch) else '0';
	out_vgaRGB 	        <= in_vgaRGB when (hCounter >= h_backPorch) and (hCounter < h_displayArea+h_backPorch) and (vCounter >= v_backPorch) and (vCounter < v_displayArea+v_backPorch) else (others => '0');
	
	out_hPos <= hCounter-h_backPorch when (hCounter >= h_backPorch) and (hCounter < h_displayArea+h_backPorch) else -1;
	out_vPos <= vCounter-v_backPorch when (vCounter >= v_backPorch) and (vCounter < v_displayArea+v_backPorch) else -1;

	process(in_clk)
	begin 
		if rising_edge(in_clk) then
			if(hCounter < wholeLine-1) then    --horizontal counter (pixels)
				hCounter <= hCounter + 1;
			else
				hCounter <= 0;
				
				if(vCounter < wholeFrame-1) then  --veritcal counter (rows)
					vCounter <= vCounter + 1;
				else
					vCounter <= 0;
				end if;
				
			end if;
			
		end if;
	end process;
end behaviour;