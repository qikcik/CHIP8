--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11.03 Education
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Sun Apr 12 21:27:52 2026

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Vram
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

your_instance_name: Vram
    port map (
        douta => douta,
        doutb => doutb,
        clka => clka,
        ocea => ocea,
        cea => cea,
        reseta => reseta,
        wrea => wrea,
        clkb => clkb,
        oceb => oceb,
        ceb => ceb,
        resetb => resetb,
        wreb => wreb,
        ada => ada,
        dina => dina,
        adb => adb,
        dinb => dinb
    );

----------Copy end-------------------
