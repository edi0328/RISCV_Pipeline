library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	port (
		clk : in  std_logic; -- Rising edge read, falling edge write for structural hazard
		reg_write : in  std_logic;
		
		addr_a : in  std_logic_vector(4 downto 0); -- rs1
		addr_b : in  std_logic_vector(4 downto 0); -- rs2
		addr_dest : in  std_logic_vector(4 downto 0); -- rd
		write_data : in  std_logic_vector(31 downto 0);
		
		read_data_a : out std_logic_vector(31 downto 0);
		read_data_b : out std_logic_vector(31 downto 0)

		-- Feel free to add output ports for debugging below
	);
end registers;