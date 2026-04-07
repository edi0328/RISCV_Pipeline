library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
	port (
		A : in std_logic_vector(31 downto 0);
		B: in std_logic_vector(31 downto 0);
		op : in std_logic_vector(3 downto 0);
		result : out std_logic_vector(31 downto 0);
		-- Branching only has beq, bne, blt, bge
		zero : out std_logic;
		lt : out std_logic
		-- Feel free to add output ports for debugging below
	);
end alu;
