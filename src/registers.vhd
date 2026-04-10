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

architecture behavioral of registers is
	type reg_array is array(0 to 31) of std_logic_vector(31 downto 0);
	signal regs : reg_array := (others => (others => '0'));
begin
	-- Write on falling edge
	process(clk)
	begin
		if falling_edge(clk) then
			if reg_write = '1' and addr_dest /= "00000" then
				regs(to_integer(unsigned(addr_dest))) <= write_data;
			end if;
		end if;
	end process;

	-- Read combinatorially (effectively "on rising edge" since writes happen on falling edge)
	read_data_a <= (others => '0') when addr_a = "00000" else
	               regs(to_integer(unsigned(addr_a)));

	read_data_b <= (others => '0') when addr_b = "00000" else
	               regs(to_integer(unsigned(addr_b)));

end behavioral;