--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11.01 Education (64-bit)
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Sun Apr 13 00:24:54 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_pROM
    port (
        dout: out std_logic_vector(15 downto 0);
        clk: in std_logic;
        oce: in std_logic;
        ce: in std_logic;
        reset: in std_logic;
        ad: in std_logic_vector(13 downto 0)
    );
end component;

your_instance_name: Gowin_pROM
    port map (
        dout => dout,
        clk => clk,
        oce => oce,
        ce => ce,
        reset => reset,
        ad => ad
    );

----------Copy end-------------------
