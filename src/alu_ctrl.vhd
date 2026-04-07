library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_ctrl is
	port (
		-- To differentiate R instructions
		funct3 : in std_logic_vector(2 downto 0);
		funct7 : in std_logic_vector(6 downto 0);

		ALUOp : in std_logic_vector(1 downto 0);
		op : out std_logic_vector(3 downto 0)
		-- Feel free to add output ports for debugging below
	);
end alu_ctrl;