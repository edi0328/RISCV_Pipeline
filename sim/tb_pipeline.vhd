library ieee;
use ieee.std_logic_1164.all;

entity tb_pipeline is
end tb_pipeline;

architecture behavioral of tb_pipeline is
    -- Internal signals to drive the pipeline
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';

    component pipeline is
        port (
            clk   : in std_logic;
            reset : in std_logic
        );
    end component;

begin
    -- 1 GHz Clock Generation: 1ns period
    -- 0.5ns high, 0.5ns low ensures the 1 GHz frequency
    clk <= not clk after 0.5 ns;

    -- Reset Process: Initialize the system
    -- pipeline registers are cleared to zero.
    process
    begin
        reset <= '1';
        wait for 2 ns; 
        reset <= '0';
        wait; 
    end process;

    dut: pipeline 
        port map (
            clk   => clk,
            reset => reset
        );

end behavioral;
