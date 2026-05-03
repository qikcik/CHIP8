library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Entry is
	port ( 
		in_clk_27mhz			: in std_logic;
		--out_leds 				: out std_logic_vector(5 downto 0) 	:= (others => '0');

        out_lcd_rgb565 			: out std_logic_vector(15 downto 0) := (others => '0');
        out_lcd_vSync			: out std_logic;
        out_lcd_hSync			: out std_logic;
        out_lcd_clk			    : out std_logic;
        out_lcd_dataEn          : out std_logic;

        out_keypad_rows         : out std_logic_vector(3 downto 0);
        in_keypad_cols          : in  std_logic_vector(3 downto 0);
	);
end Entry;

architecture behaviour of Entry is

-- import components
    component VgaController is
        generic (
            pixelFreq			: integer := 30_000_000;

            h_displayArea	    : integer := 800;
            h_pulseWidth       : integer := 40;
            h_backPorch        : integer := 48;
            h_frontPorch       : integer := 88;

            v_displayArea	    : integer := 800;
            v_pulseWidth       : integer := 40;
            v_backPorch        : integer := 48;
            v_frontPorch       : integer := 88
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
    end component;

    component Gowin_rPLL
        port (
            clkout: out std_logic;
            clkin: in std_logic
        );
    end component;
	
	component Vram is
        port (
            douta: out std_logic_vector(63 downto 0);
            doutb: out std_logic_vector(63 downto 0);
            clka: in std_logic;
            ocea: in std_logic;
            cea: in std_logic;
            reseta: in std_logic;
            wrea: in std_logic;
            clkb: in std_logic;
            oceb: in std_logic;
            ceb: in std_logic;
            resetb: in std_logic;
            wreb: in std_logic;
            ada: in std_logic_vector(4 downto 0);
            dina: in std_logic_vector(63 downto 0);
            adb: in std_logic_vector(4 downto 0);
            dinb: in std_logic_vector(63 downto 0)
        );
	end component;
	
	component Ram IS
        port (
            dout: out std_logic_vector(7 downto 0);
            clk: in std_logic;
            oce: in std_logic;
            ce: in std_logic;
            reset: in std_logic;
            wre: in std_logic;
            ad: in std_logic_vector(14 downto 0); --3 for bank and 11 for acual address
            din: in std_logic_vector(7 downto 0)
        );
	end component;

    component Keypad is
        port (
            clk_27mhz       : in  std_logic;
            cols             : in  std_logic_vector(3 downto 0);
            rows             : out std_logic_vector(3 downto 0);
            keyPress        : out std_logic_vector(15 downto 0)-- Wykorzystanie adresu z wliczonym bankiem
        );
    end component;
	
-- signals

	signal notLeds					: std_logic_vector(3 downto 0) 	:= (others => '0'); 
	
    signal clk_9mhz	    : std_logic := '0';
    signal isDisplaying	: std_logic := '0';
	signal hPos			: integer := 0;
	signal vPos			: integer := 0;
    signal rgb			: std_logic_vector(15 downto 0) := (others => '0');
	
	signal vram_b_addr			: std_logic_vector (4 downto 0) := (others => '0');
	signal vram_b_out				: std_logic_vector (63 downto 0);
	
	signal vram_a_addr  : std_logic_vector (4 downto 0) 	:= (others => '0');
	signal vram_a_data  : std_logic_vector (63 downto 0) 	:= (others => '0');
	signal vram_a_write : std_logic 								:= '0';
	signal vram_a_out	  : std_logic_vector (63 downto 0) 	:= (others => '0');
	
	signal mapped_xPos			: integer := 0;
	signal mapped_yPos			: integer := 0;



	signal ram_addr			: std_logic_vector (11 downto 0) := (others => '0');
	signal ram_out				: std_logic_vector (7 downto 0) 	:= (others => '0');
	signal ram_data			: std_logic_vector (7 downto 0) 	:= (others => '0');
	signal ram_write			: std_logic := '0';

    signal current_bank        : unsigned(2 downto 0) := "000";
    signal physical_ram_addr   : std_logic_vector(14 downto 0) := (others => '0');
    signal effective_ram_write : std_logic := '0'; -- guard for writing to 00
	
	
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
	signal prev_keyPress			: std_logic_vector(15 downto 0) := (others => '0');
	
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
        clka   => in_clk_27mhz,   
        cea    => '1',            
        ocea   => '1',            
        reseta => '0',            
        wrea   => vram_a_write,   
        ada    => vram_a_addr,    
        dina   => vram_a_data,    
        douta  => vram_a_out,     

        clkb   => in_clk_27mhz,   
        ceb    => '1',            
        oceb   => '1',            
        resetb => '0',            
        wreb   => '0',            
        adb    => vram_b_addr,    
        dinb   => (others => '0'),
        doutb  => vram_b_out      
    );
	
    physical_ram_addr <= std_logic_vector(current_bank) & ram_addr;
    effective_ram_write <= '0' when (ram_write = '1' and ram_addr = x"000") else ram_write; -- guard for writing to 0

    e_ram : Ram
    port map
    (
        ad    => physical_ram_addr,
        clk   => in_clk_27mhz,
        din   => ram_data,
        wre   => effective_ram_write,
        dout  => ram_out,

        ce    => '1',            
        oce   => '1',            
        reset => '0'             
    );

	e_vgaController: VgaController 
	generic map
	(
        --pixelFreq		    => 51_000_000,

        --h_displayArea	    => 1024,
        --h_pulseWidth        => 1,
        --h_backPorch         => 160,
        --h_frontPorch        => 160,

        --v_displayArea	    => 600,
        --v_pulseWidth        => 1,
        --v_backPorch         => 23,
        --v_frontPorch        => 12
        pixelFreq		    => 9_000_000,

        h_displayArea	    => 480,
        h_pulseWidth        => 1,
        h_backPorch         => 43,
        h_frontPorch        => 4,

        v_displayArea	    => 272,
        v_pulseWidth        => 1,
        v_backPorch         => 12,
        v_frontPorch        => 4
	)
	port map
	(
		in_clk              => clk_9mhz,
		
		out_vgaRGB 	        => out_lcd_rgb565,
		out_vgaHSync        => out_lcd_hSync,
		out_vgaVSync        => out_lcd_vSync,

		out_isDisplaying	=> isDisplaying,
		out_hPos			=> hPos,
		out_vPos			=> vPos,
		in_vgaRGB			=> rgb
	);


    e_keypad : Keypad
    port map (
        clk_27mhz => in_clk_27mhz, 
        cols      => in_keypad_cols,
        rows      => out_keypad_rows,
        keyPress  => keyPress 
    );

    e_clk: Gowin_rPLL
    port map (
        clkout => clk_9mhz,
        clkin  => in_clk_27mhz
    );

	
	--notLeds <= std_logic_vector(to_unsigned(TState'pos(currentState),5));
	--keyPress(15 downto 4) <= (others=> '0');
	--keyPress(3 	downto 0) <= not in_keys;
	--notLeds <= keyPress(5 	downto 0);
	
	logic: process(in_clk_27mhz) 
		variable temp_line : std_logic_vector(63 downto 0);
	begin
		if rising_edge(in_clk_27mhz) then
            --SOFT RESET (corners: 1,C,A,F)
            if (keyPress(1) = '1' and keyPress(12) = '1' and keyPress(10) = '1' and keyPress(15) = '1') 
               or (ram_write = '1' and ram_addr = x"000") then
                
                if (ram_write = '1' and ram_addr = x"000") then -- user selected bank
                    current_bank <= unsigned(ram_data(2 downto 0)); 
                else
                    current_bank <= "000"; -- fallthrough to bank 0
                end if;

                -- internal reset
                reg_pc              <= X"0200";
                reg_i               <= (others => '0');
                reg_delay           <= (others => '0');
                stack_pointer       <= 0;
                currentState        <= TState_Fetch_Begin;
                nextState           <= TState_Cls;
                nextState_delay     <= 27_000_000;
                frame_counter       <= 0;
                regs_generic        <= (others => (others => '0'));
            
                vram_a_write        <= '0'; 
                ram_write           <= '0';
            else
                prev_keyPress <= keyPress;
                rnd_counter <= rnd_counter+1;
                if frame_counter >= integer( (real(1)/real(60)) / (real(1)/real(27_000_000)) ) then
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
                            
                            ram_addr  <= std_logic_vector(to_unsigned(to_integer(reg_pc) + 1, 12));
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
                                regs_generic(to_integer(unsigned(opcode_x))) <= unsigned(opcode_nn);
                                
                                reg_pc <= reg_pc+2;
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
                                    regs_generic(to_integer(opcode_x)) <= shift_right(regs_generic(to_integer(opcode_y)), 1);
                                    if regs_generic(to_integer(opcode_y))(0) = '1' then
                                        regs_generic(15) <= X"01";
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
                                    ram_addr  <= std_logic_vector(to_unsigned(to_integer(reg_i) + 2, 12));
                                    
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
                            ram_addr  		 <= std_logic_vector(reg_i(11 downto 0) + to_unsigned(draw_counter, 12));
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
                            ram_addr(11 downto 0)  <= std_logic_vector(reg_i(11 downto 0) + to_unsigned(regLoadSave_counter, 12));
                            
                            nextState <= TState_LoadReg_Store;
                            nextState_delay <= MEMORY_READ_DELAY;
                            
                        when TState_LoadReg_Store =>
                            regs_generic(regLoadSave_counter) <= unsigned(ram_out);
                            
                            if regLoadSave_counter < opcode_x then
                                regLoadSave_counter <= regLoadSave_counter+1;
                                nextState <= TState_LoadReg_PrepareAddress;
                            else
                                reg_i <= reg_i + opcode_x + 1; -- quirks
                                nextState <= TState_Fetch_Begin;
                            end if;
                        
                        when TState_SaveReg_PrepareAddress =>
                            ram_addr(11 downto 0)  <= std_logic_vector(reg_i(11 downto 0) + to_unsigned(regLoadSave_counter, 12));
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
                            ram_addr  <= std_logic_vector(to_unsigned(to_integer(reg_i) + 1, 12));
                        
                            nextState <= TState_BCD2;
                            
                        when TState_BCD2 =>
                            ram_write <= '1';
                            ram_data  <= std_logic_vector(regs_generic(to_integer(opcode_x)) / 100);
                            ram_addr  <= std_logic_vector(to_unsigned(to_integer(reg_i), 12)); 
                        
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
        end if;
	end process;			
			
-- display        
    mapped_xPos <= (hPos - 16) / 7 when (hPos >= 16) else 0;
    mapped_yPos <= (vPos - 24) / 7 when (vPos >= 24) else 0;
    
    vram_b_addr <= std_logic_vector(to_unsigned(mapped_yPos, 5));
    
    display: process(clk_9mhz)
    begin
        if rising_edge(clk_9mhz) then
            if (hPos >= 16) and (hPos < 464) and (vPos >= 24) and (vPos < 248) then

                if vram_b_out(mapped_xPos) = '1' then
                    rgb <= "1111100000000000"; 
                else
                    rgb <= "0000000000000000";
                end if;
                
            else
                rgb <= "0000000000011111";     
            end if;
        end if;
    end process;
    
    --out_leds <= not notLeds;
    out_lcd_clk <= clk_9mhz;
    out_lcd_dataEn <= isDisplaying;

	
end behaviour;