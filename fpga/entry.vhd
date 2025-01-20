library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Disp4x7Seg_Types.all;


entity Entry is
	port (
		-- core
		in_clk_50mhz			: in std_logic;
		-- simple input
		in_keys 					: in std_logic_vector(3 downto 0);
		-- simple output
		out_buzzer 				: out std_logic							:= '0';		
		out_leds 				: out std_logic_vector(3 downto 0) 	:= (others => '0');
		-- 7seg output
		out_7seg 				: out std_logic_vector(7 downto 0) 	:= (others => '0');
		out_7segDigitSelect 	: out std_logic_vector(3 downto 0)	:= (others => '0');
		-- vga output
		out_vgaHSync			: out std_logic	:= '0';
		out_vgaVSync			: out std_logic	:= '0';
		out_vgaRGB				: out std_logic_vector(2 downto 0) := (others => '0')
	);
end Entry;

architecture behaviour of Entry is

-- import components
	component VgaGenerator is
		generic (
			clkFreq					: integer := 50_000_000;
			pixelFreq				: integer := 25_175_000;

			hSync_visibleArea		: integer := 640;
			hSync_frontPorch    	: integer := 16;
			hSync_syncPulse		: integer := 96;
			hSync_backPorch     	: integer := 48;

			vSync_visibleArea		: integer := 480;
			vSync_frontPorch    	: integer := 11;
			vSync_syncPulse		: integer := 2;
			vSync_backPorch     	: integer := 31
		);
		port (
			in_clk					: in  std_logic := '0';
			
			out_vgaRGB				: out std_logic_vector(2 downto 0) := (others => '0');
			out_vgaHSync			: out std_logic := '0';
			out_vgaVSync			: out std_logic := '0';

			out_isDisplaying		: out std_logic := '0';
			out_hPos					: out integer := 0;
			out_vPos					: out integer := 0;
			in_vgaRGB				: in  std_logic_vector(2 downto 0) := "001"
		);	
	end component;
	
	component Disp4x7Seg is
		port (
			in_clk					: in std_logic;
			
			in_7seg 					: in Array4x7Seg;
			
			out_7seg 				: out std_logic_vector(7 downto 0) 	:= (others => '0');
			out_7segDigitSelect 	: out std_logic_vector(3 downto 0) 	:= (others => '0')
		);
	end component;
	
	
	component Vram is
		port
		(
			address_a		: in std_logic_vector (4 downto 0);
			address_b		: in std_logic_vector (4 downto 0);
			clock				: in std_logic  := '1';
			data_a			: in std_logic_vector (63 downto 0);
			data_b			: in std_logic_vector (63 downto 0);
			wren_a			: in std_logic  := '0';
			wren_b			: in std_logic  := '0';
			q_a				: out std_logic_vector (63 downto 0);
			q_b				: out std_logic_vector (63 downto 0)
		);
	end component;
	
	component Ram IS
	port
	(
		address	: in std_logic_vector (11 downto 0);
		clock		: in std_logic  := '1';
		data		: in std_logic_vector (7 downto 0);
		wren		: in std_logic ;
		q			: out std_logic_vector (7 downto 0)
	);
	end component;
	
-- signals

	signal notBuzzer 				: std_logic								:= '0';	
	signal notLeds					: std_logic_vector(3 downto 0) 	:= (others => '0'); 
	signal not7seg 				: std_logic_vector(7 downto 0) 	:= (others => '0');
	signal not7segDigitSelect 	: std_logic_vector(3 downto 0) 	:= (others => '0');
	
	signal vga_isDisplaying		: std_logic := '0';
	signal vga_xPos				: integer := 0;
	signal vga_yPos				: integer := 0;
	signal vga_outColor			: std_logic_vector(2 downto 0) := (others => '0');
	
	signal vram_b_addr			: std_logic_vector (4 downto 0) := (others => '0');
	signal vram_b_out				: std_logic_vector (63 downto 0);
	
	signal vram_a_addr  : std_logic_vector (4 downto 0) 	:= (others => '0');
	signal vram_a_data  : std_logic_vector (63 downto 0) 	:= (others => '0');
	signal vram_a_write : std_logic 								:= '0';
	signal vram_a_out	  : std_logic_vector (63 downto 0) 	:= (others => '0');
	
	signal mapped_xPos			: integer := 0;
	signal mapped_yPos			: integer := 0;
	
	signal display4Seg 	 		: Array4x7Seg := (CONST7SEG_3,CONST7SEG_2,CONST7SEG_1,CONST7SEG_0);
	
	signal ram_addr			: std_logic_vector (11 downto 0) := (others => '0');
	signal ram_out				: std_logic_vector (7 downto 0) 	:= (others => '0');
	signal ram_data			: std_logic_vector (7 downto 0) 	:= (others => '0');
	signal ram_write			: std_logic := '0';
	
	
	constant MEMORY_READ_DELAY   : integer := 10;
	
	--cpu!
	type TgenericReg is array(15 downto 0) of unsigned(7 downto 0);
	
	signal regs_generic		: TgenericReg 				:= ( others => (others => '0') );
	signal reg_i				: unsigned(15 downto 0) := (others => '0');
	signal reg_pc				: unsigned(15 downto 0) := X"0200";
	
	signal reg_delay			: unsigned(7 downto 0) 	:= X"00";
	
	signal current_opcode	: unsigned(15 downto 0) := X"3210";
	
	alias  opcode_nibble0 	: unsigned(3 downto 0)  is current_opcode(3  downto 0);
	alias  opcode_nibble1 	: unsigned(3 downto 0)  is current_opcode(7  downto 4);
	alias  opcode_nibble2 	: unsigned(3 downto 0)  is current_opcode(11 downto 8);
	alias  opcode_nibble3 	: unsigned(3 downto 0)  is current_opcode(15 downto 12);
	
	alias  opcode_x 			: unsigned(3 	downto 0)  	is current_opcode(11 downto 8);
	alias  opcode_y 			: unsigned(3 	downto 0)  	is current_opcode(7 	downto 4);
	alias  opcode_n 			: unsigned(3 	downto 0)  	is current_opcode(3  downto 0);
	alias  opcode_nn 			: unsigned(7 	downto 0)  	is current_opcode(7  downto 0);
	alias  opcode_nnn 		: unsigned(11 	downto 0)  	is current_opcode(11 downto 0);
	
	type TStack is array(15 downto 0) of unsigned(15 downto 0);
	signal stack				: TStack  := ( others => (others => '0') );
	signal stack_pointer		: integer := 0;
	
	signal cls_counter		: integer := 0;
	signal draw_counter		: integer := 0;
	signal regLoadSave_counter	: integer := 0;
	signal rnd_counter		: unsigned(7 	downto 0) := (others => '0');
	signal frame_counter		: integer := 0;
	
	signal keyPress				: std_logic_vector(15 downto 0) 	:= (others => '0');
	signal prev_keyPress			: std_logic_vector(15 downto 0) 	:= (others => '0');
	
	signal draw_collision		: std_logic := '0';
		
	type TState is (
		TState_Fetch_Begin,
		TState_Fetch_StoreFirstByte,
		TState_Fetch_StoreSecondByte,
		TState_Fetch_ParseAndInitOpcode,
		
		
		TState_Cls,
		TState_Draw_ReadLine,
		TState_Draw_WriteLine,
		TState_Draw_Increment,
		
		TState_Return,
		TState_Call,
		
		TState_LoadReg_PrepareAddress,
		TState_LoadReg_Store,
		
		TState_SaveReg_PrepareAddress,
		TState_SaveReg_Store,
		
		TState_BCD1,
		TState_BCD2
	);
	
	
	signal currentState		: TState := TState_Fetch_Begin;
	signal nextState			: TState := TState_Fetch_Begin;
	
	signal nextState_delay  : integer 	:= 0;

-- initiate components
begin
	e_vram : Vram
	port map
	(
		address_a		=> vram_a_addr,
		address_b		=> vram_b_addr,
		clock				=> in_clk_50mhz,
		data_a			=> vram_a_data,
		data_b			=> (others => '0'),
		wren_a			=> vram_a_write,
		wren_b			=> '0',
		q_a				=> vram_a_out,
		q_b				=> vram_b_out
	);
	
	e_ram : Ram
	port map
	(
		address	=> ram_addr,
		clock		=> in_clk_50mhz,
		data		=> ram_data,
		wren		=> ram_write,
		q			=> ram_out
	);

	e_vgaController: VgaGenerator 
	generic map
	(
		clkFreq 		=> 50_000_000,
		pixelFreq 	=> 25_175_000,

		hSync_visibleArea	=> 640,
		hSync_frontPorch 	=> 16,
		hSync_syncPulse 	=> 96,
		hSync_backPorch	=> 48,

		vSync_visibleArea	=> 480,
		vSync_frontPorch 	=> 11,
		vSync_syncPulse 	=> 2,
		vSync_backPorch 	=> 31	
	)
	port map
	(
		in_clk => in_clk_50mhz,
		
		out_vgaRGB 	 => out_vgaRGB,
		out_vgaHSync => out_vgaHSync,
		out_vgaVSync => out_vgaVSync,

		out_isDisplaying	=> vga_isDisplaying,
		out_hPos				=> vga_xPos,
		out_vPos				=> vga_yPos,
		in_vgaRGB  			=> vga_outColor
	);
	
	e_disp4x7seg: Disp4x7Seg port map
	(
		in_clk					=> in_clk_50mhz,
		
		in_7seg					=> display4Seg,
		
		out_7seg 				=> not7seg,
		out_7segDigitSelect 	=> not7segDigitSelect
	);
	

	--procesoor
	display4Seg(0) <= BinTo7SegHex(std_logic_vector(current_opcode(3 downto 0)));
	display4Seg(1) <= BinTo7SegHex(std_logic_vector(current_opcode(7 downto 4)));
	display4Seg(2) <= BinTo7SegHex(std_logic_vector(current_opcode(11 downto 8)));
	display4Seg(3) <= BinTo7SegHex(std_logic_vector(current_opcode(15 downto 12)));
	
	--notLeds <= std_logic_vector(to_unsigned(TState'pos(currentState),4));
	keyPress(15 downto 4) <= (others=> '0');
	keyPress(3 	downto 0) <= not in_keys;
	notLeds <= keyPress(3 	downto 0);
	
	logic: process(in_clk_50mhz) 
		variable temp_line : std_logic_vector(63 downto 0);
	begin
		if rising_edge(in_clk_50mhz) then
			prev_keyPress <= keyPress;
			rnd_counter <= rnd_counter+1;
			if frame_counter >= integer( (real(1)/real(60)) / (real(1)/real(50_000_000)) ) then
				if reg_delay > 0 then
					reg_delay <= reg_delay -1;
				end if;
				frame_counter <= 0;
			else
				frame_counter <= frame_counter+1;
			end if;

			if currentState = nextState and nextState_delay = 0 then
				--nextState_delay <= 1_000_000;
				--FSM
				case currentState is
					when TState_Fetch_Begin =>
						vram_a_write 	<= '0';
						ram_write		<= '0';
						
						ram_addr  <= std_logic_vector(reg_pc(11 downto 0));
		
						nextState <= TState_Fetch_StoreFirstByte;
						nextState_delay <= MEMORY_READ_DELAY;
						
					when TState_Fetch_StoreFirstByte =>
						current_opcode(15 downto 8) <=  unsigned(ram_out(7 downto 0));
						
						ram_addr  <= std_logic_vector(reg_pc+1)(11 downto 0);
						nextState <= TState_Fetch_StoreSecondByte;
						nextState_delay <= MEMORY_READ_DELAY;
						
					when TState_Fetch_StoreSecondByte =>
						current_opcode(7 downto 0) <=  unsigned(ram_out(7 downto 0));
						nextState <= TState_Fetch_ParseAndInitOpcode;
						
					when TState_Fetch_ParseAndInitOpcode =>
						if current_opcode = X"00E0" then --00E0 - Clear the screen
							reg_pc <= reg_pc+2;
							cls_counter <= 0;
							nextState <= TState_Cls;
							
						elsif current_opcode = X"00EE" then --00EE - return from subroutine
							stack_pointer <= stack_pointer-1;
							nextState <= TState_Return;
						
						elsif opcode_nibble3 = X"0" then 	--0nnn - sys - ignore
							reg_pc <= reg_pc+2;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = X"1" then 	--1nnn - Jump (goto) 
							reg_pc(15 downto 12) 	<= (others => '0');
							reg_pc(11 downto 0) 	<= opcode_nnn;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = X"2" then 	--2nnn - call nnn (subroutine)
							stack(stack_pointer) <= reg_pc+2;
							nextState <= TState_Call;
							
						elsif opcode_nibble3 = X"3" then 	--3xnn - if vX == nn, skip next opcode
							if regs_generic(to_integer(opcode_x)) = opcode_nn then
								reg_pc <= reg_pc+4;
							else
								reg_pc <= reg_pc+2;
							end if;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = X"4" then 	--4xnn - if vX != nn, skip next opcode
							if regs_generic(to_integer(opcode_x)) /= opcode_nn then
								reg_pc <= reg_pc+4;
							else
								reg_pc <= reg_pc+2;
							end if;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = X"5" then 	--5xy0 - if vX == vY, skip next opcode
							if regs_generic(to_integer(opcode_x)) = regs_generic(to_integer(opcode_y)) then
								reg_pc <= reg_pc+4;
							else
								reg_pc <= reg_pc+2;
							end if;
							nextState <= TState_Fetch_Begin;
						
						elsif opcode_nibble3 = x"6" then --6xnn - Load normal register with immediate value 
							reg_pc <= reg_pc+2;
							regs_generic(to_integer(opcode_x)) <= opcode_nn;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = x"7" then --7xnn - Add immediate value to normal register
							reg_pc <= reg_pc+2;
							regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) + opcode_nn;
							nextState <= TState_Fetch_Begin;
							
							
						elsif opcode_nibble3 = x"8" then --8xy? - operation on two registers
							if opcode_nibble0 = x"0" then --8xy0 - vX = vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_y));
								
							elsif opcode_nibble0 = x"1" then --8xy1 - vX |= vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) or regs_generic(to_integer(opcode_y));
								regs_generic(15) <= (others => '0');
								
							elsif opcode_nibble0 = x"2" then --8xy2 - vX &= vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) and regs_generic(to_integer(opcode_y));
								regs_generic(15) <= (others => '0');
								
							elsif opcode_nibble0 = x"3" then --8xy3 - vX ^= vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) xor regs_generic(to_integer(opcode_y));
								regs_generic(15) <= (others => '0');
								
							elsif opcode_nibble0 = x"4" then --8xy4 - vX += vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) + regs_generic(to_integer(opcode_y));
								if( to_integer(regs_generic(to_integer(opcode_x))) + to_integer(regs_generic(to_integer(opcode_y))) > 255 ) then
									regs_generic(15) <= X"01";
								else
									regs_generic(15) <= X"00";
								end if;
								
							elsif opcode_nibble0 = x"5" then --8xy5 - vX -= vY
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_x)) - regs_generic(to_integer(opcode_y));
								if regs_generic(to_integer(opcode_x)) >= regs_generic(to_integer(opcode_y)) then
									regs_generic(15) <= X"01";
								else
									regs_generic(15) <= X"00";
								end if;
								
							elsif opcode_nibble0 = x"6" then --8xy6 - vX = vY >> 1
								regs_generic(to_integer(opcode_x)) <= shift_right(regs_generic(to_integer(opcode_y)),1);
								if regs_generic(to_integer(opcode_x))(0) = '1' then
									regs_generic(15) <= X"00";
								else
									regs_generic(15) <= X"00";
								end if;
								
							elsif opcode_nibble0 = x"7" then --8xy7 - vX = vY - vX
								regs_generic(to_integer(opcode_x)) <= regs_generic(to_integer(opcode_y)) - regs_generic(to_integer(opcode_x));
								if regs_generic(to_integer(opcode_y)) >= regs_generic(to_integer(opcode_x)) then
									regs_generic(15) <= X"01";
								else
									regs_generic(15) <= X"00";
								end if;
								
							elsif opcode_nibble0 = x"E" then --8xyE - vX = vY << 1
								regs_generic(to_integer(opcode_x)) <= shift_left(regs_generic(to_integer(opcode_y)),1);
								if regs_generic(to_integer(opcode_x))(7) = '1' then
									regs_generic(15) <= X"01";
								else
									regs_generic(15) <= X"00";
								end if;
								
							end if;
							
							reg_pc <= reg_pc+2;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = X"9" then 	--9xy0 - if vX != vY, skip next opcode
							if regs_generic(to_integer(opcode_x)) /= regs_generic(to_integer(opcode_y)) then
								reg_pc <= reg_pc+4;
							else
								reg_pc <= reg_pc+2;
							end if;
							nextState <= TState_Fetch_Begin;
							
						elsif opcode_nibble3 = x"A" then --Annn Load index register with immediate value
							reg_pc <= reg_pc+2;
							reg_i(15 downto 12) 	<= (others => '0');
							reg_i(11 downto 0) 	<= opcode_nnn;
							nextState <= TState_Fetch_Begin;
							
													
						elsif opcode_nibble3 = x"C" then --Cxkk - RND Vx, byte
							reg_pc <= reg_pc+2;
							regs_generic(to_integer(opcode_x)) <= rnd_counter and opcode_nn;
							nextState <= TState_Fetch_Begin;	
							
						elsif opcode_nibble3 = x"D" then --Dxyn - Draw sprite to screen
							reg_pc <= reg_pc+2;
							draw_counter <= 0;
							regs_generic(15) <= x"00";
							nextState <= TState_Draw_ReadLine;
							
						elsif opcode_nibble3 = x"E" then --8x?? - operation on one register and keyboard
							if opcode_nn = x"9E" then --Ex9E - SKP Vx
								if keyPress( to_integer(regs_generic(to_integer(opcode_x))) ) = '1' then
									reg_pc <= reg_pc+4;
									nextState <= TState_Fetch_Begin;
								else 
									reg_pc <= reg_pc+2;
									nextState <= TState_Fetch_Begin;
								end if;
								
							elsif opcode_nn = x"A1" then --ExA1 - SKNP Vx
								if keyPress( to_integer(regs_generic(to_integer(opcode_x))) ) = '0' then
									reg_pc <= reg_pc+4;
									nextState <= TState_Fetch_Begin;
								else 
									reg_pc <= reg_pc+2;
									nextState <= TState_Fetch_Begin;
								end if;
							end if;
							
						elsif opcode_nibble3 = x"F" then --Ex?? - operation on one register
							if opcode_nn = x"07" then --Fx07 Set Vx = delay timer value
								regs_generic(to_integer(opcode_x)) <= reg_delay;
								reg_pc <= reg_pc+2;
								nextState <= TState_Fetch_Begin;
								
							elsif opcode_nn = x"15" then --Fx15 Set delay timer = Vx.
								reg_delay <= regs_generic(to_integer(opcode_x));
								reg_pc <= reg_pc+2;
								nextState <= TState_Fetch_Begin;
								
							elsif opcode_nn = x"65" then --Fx65 - load registers v0 - vX from memory starting at i
								regLoadSave_counter <= 0;
								reg_pc <= reg_pc+2;
								nextState <= TState_LoadReg_PrepareAddress;
								
							elsif opcode_nn = x"55" then --Fx55 - save registers v0 - vX to memory starting at i
								regLoadSave_counter <= 0;
								reg_pc <= reg_pc+2;
								nextState <= TState_SaveReg_PrepareAddress;
								
							elsif opcode_nn = x"33" then --Fx33 - store binary-coded decimal representation of vX to memory at i, i + 1 and i + 2
								
								ram_write <= '1';
								ram_data  <= std_logic_vector(regs_generic(to_integer(opcode_x)) mod 10);
								ram_addr  <= std_logic_vector(reg_i+2)(11 downto 0);
								
								reg_pc <= reg_pc+2;
								nextState <= TState_BCD1;
								
							elsif opcode_nn = x"1E" then --Fx1E - i += vX
								reg_i <= reg_i+regs_generic(to_integer(opcode_x));
								reg_pc <= reg_pc+2;
								nextState <= TState_Fetch_Begin;
								
							elsif opcode_nn = x"29" then --Fx29 - i = digit_addr(Vx)
								reg_i <= regs_generic(to_integer(opcode_x)) *5;
								reg_pc <= reg_pc+2;
								nextState <= TState_Fetch_Begin;
								
							elsif opcode_nn = x"0A" then --Fx0A - Wait for a key press, store the value of the key in Vx.
								iterate : for k in 0 to 15 loop
									if prev_keyPress(k) = '1' and keyPress(k) = '0' then
										regs_generic(to_integer(opcode_x)) <= to_unsigned(k,8);
										reg_pc <= reg_pc+2;
										nextState <= TState_Fetch_Begin;
									end if;
								end loop iterate;
								
							end if;	
						end if;
						
						
					when TState_Cls =>
						vram_a_write 	<= '1';
						vram_a_addr 	<= std_logic_vector(to_unsigned(cls_counter,5));
						vram_a_data 	<= (others => '0');

						if cls_counter <= 31 then
							cls_counter <= cls_counter+1;
						else
							nextState <= TState_Fetch_Begin;
						end if;
						
					when TState_Draw_ReadLine =>
						vram_a_addr 	 <= std_logic_vector(to_unsigned(draw_counter + to_integer(regs_generic(to_integer(opcode_y))),5));
						ram_addr  		 <= std_logic_vector(reg_i+to_unsigned(draw_counter,12))(11 downto 0);
						nextState_delay <= MEMORY_READ_DELAY;
						nextState <= TState_Draw_WriteLine;
						
					when TState_Draw_WriteLine =>
						temp_line := vram_a_out;
						draw_line : for k in 0 to ram_out'length-1 loop
							if temp_line( to_integer(regs_generic(to_integer(opcode_x)))+k ) = '1' and ram_out(7-k) = '1' then
								regs_generic(15) <= x"01";
							end if;
							
							if (to_integer(regs_generic(to_integer(opcode_x))) mod 64)+k < 64 then
								temp_line( to_integer(regs_generic(to_integer(opcode_x)))+k ) :=
								temp_line( to_integer(regs_generic(to_integer(opcode_x)))+k ) xor ram_out(7-k); -- make it better
							end if;
						end loop draw_line;
						
						--if temp_line( to_integer(regs_generic(to_integer(opcode_x))) ) = '1' then
						--	regs_generic(15) <= x"01";
						--end if;
					
						vram_a_data		<= temp_line;
						vram_a_write	<= '1';
					
						--nextState_delay <= MEMORY_DELAY;
						nextState <= TState_Draw_Increment;
						
					when TState_Draw_Increment =>
						vram_a_write	<= '0';
						
						if ( draw_counter+1 < opcode_n ) and ( (to_integer(regs_generic(to_integer(opcode_y))) mod 32) + draw_counter+1 < 32 ) then
							draw_counter <= draw_counter+1;
							nextState <= TState_Draw_ReadLine;
						else
							nextState <= TState_Fetch_Begin;
						end if;
						
					when TState_Return =>
						reg_pc <= stack(stack_pointer);
						nextState <= TState_Fetch_Begin;
						
					when TState_Call =>
						stack_pointer <= stack_pointer+1;
						reg_pc(15 downto 12) <= (others => '0');
						reg_pc(11 downto 0) 	<= opcode_nnn;
						nextState <= TState_Fetch_Begin;
						
					when TState_LoadReg_PrepareAddress =>
						ram_addr(11 downto 0)  <= std_logic_vector(reg_i+to_unsigned(regLoadSave_counter,12))(11 downto 0);
						
						nextState <= TState_LoadReg_Store;
						nextState_delay <= MEMORY_READ_DELAY;
						
					when TState_LoadReg_Store =>
						regs_generic(regLoadSave_counter) <= unsigned(ram_out);
						
						if regLoadSave_counter < opcode_x then
							regLoadSave_counter <= regLoadSave_counter+1;
							nextState <= TState_LoadReg_PrepareAddress;
						else
							nextState <= TState_Fetch_Begin;
						end if;
					
					when TState_SaveReg_PrepareAddress =>
						ram_addr(11 downto 0)  <= std_logic_vector(reg_i+to_unsigned(regLoadSave_counter,12))(11 downto 0);
						ram_write <= '1';
						ram_data <= std_logic_vector(regs_generic(regLoadSave_counter));
						
						nextState <= TState_SaveReg_Store;
						--nextState_delay <= MEMORY_DELAY;
						
					when TState_SaveReg_Store =>
						ram_write <= '0';
						
						if regLoadSave_counter < opcode_x then
							regLoadSave_counter <= regLoadSave_counter+1;
							nextState <= TState_SaveReg_PrepareAddress;
						else
							nextState <= TState_Fetch_Begin;
						end if;

					when TState_BCD1 =>
						ram_write <= '1';
						ram_data  <= std_logic_vector((regs_generic(to_integer(opcode_x)) mod 100) / 10);
						ram_addr  <= std_logic_vector(reg_i+1)(11 downto 0);
					
						nextState <= TState_BCD2;
						
					when TState_BCD2 =>
						ram_write <= '1';
						ram_data  <= std_logic_vector(regs_generic(to_integer(opcode_x)) / 100);
						ram_addr  <= std_logic_vector(reg_i)(11 downto 0);
					
						nextState <= TState_Fetch_Begin;
				end case;
				
				if nextState_delay = 0 then 
					currentState <= nextState;
				end if;
				
			else
				if nextState_delay <= 1 then -- one tick is already consumed at entering this part code for first time
					currentState <= nextState;
					nextState_delay <= 0;
				else 
					nextState_delay <= nextState_delay - 1;
				end if;
			end if;
		end if;	
	end process;			
			
	-- display		

	mapped_xPos <= to_integer(shift_right(to_unsigned(vga_xPos,10), 3));
	mapped_yPos <= to_integer(shift_right(to_unsigned(vga_yPos,10), 3));
	vram_b_addr <= std_logic_vector( to_unsigned(mapped_yPos,5));
	
	display: process(in_clk_50mhz)
	begin
		if rising_edge(in_clk_50mhz) then
			--bound
			if vga_xPos >= 0 and vga_xPos < 64*8 and vga_yPos >= 0 and vga_yPos < 32*8 then
				if vram_b_out(mapped_xPos) = '1' then
					vga_outColor <= "100";
				else
					vga_outColor <= "000";
				end if;
			else
				vga_outColor <= "001";
			end if;
		end if;
	end process;
	
	out_leds <= not notLeds;
	out_7seg <= not not7seg;
	out_7segDigitSelect <= not not7segDigitSelect;
	out_buzzer <= not notBuzzer;

	
	
end behaviour;