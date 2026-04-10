library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline is
	port (
		clk : in std_logic;
		reset : in std_logic
		-- Feel free to add output ports for debugging below
    );
end pipeline;

architecture top of pipeline is

constant ram_size : integer := 32768;
signal pc, pc_branch, pc4, next_pc : integer range 0 to ram_size - 1;
signal pc_sel : std_logic;
signal i_out : std_logic_vector(31 downto 0);

signal i_waitrequest, d_waitrequest, mem_waitrequest : std_logic;

component memory
	port(clock, memwrite, memread : in std_logic;
			writedata: in std_logic_vector(31 downto 0);
			address : in integer range 0 to ram_size - 1;
			readdata : out std_logic_vector(31 downto 0);
			waitrequest : out std_logic);
end component;

component alu
	port(A : in std_logic_vector(31 downto 0);
		B: in std_logic_vector(31 downto 0);
		op : in std_logic_vector(3 downto 0);
		result : out std_logic_vector(31 downto 0);
		zero, lt: out std_logic);
end component;

component alu_ctrl
	port(funct3 : in std_logic_vector(2 downto 0);
		funct7 : in std_logic_vector(6 downto 0);
		ALUOp : in std_logic_vector(1 downto 0);
		op : out std_logic_vector(3 downto 0));
end component;

begin
	I_mem : memory port map (clock => clk, 
									 memwrite => '0', -- read only
									 memread => '1',
									 writedata => (others => '0'),
									 address => pc,
									 readdata => i_out,
									 waitrequest => i_waitrequest);
									 
	D_mem : memory port map (clock => clk,
									 memwrite => d_memwrite,
									 memread => d_memread,
									 writedata => d_memaddr,
									 readdata => d_memout,
									 waitrequest => d_waitrequest);
	
	pc4 <= pc + 4;
	with pc_sel select
		next_pc <= pc4 when '0',
						pc_branch when others;
	
	
	process(clk, reset)	
	begin
		if reset = '1' then
			pc <= 0;
		elsif rising_edge(clk) then
			if pc_write = '1' and mem_waitrequest = '1' then
				pc <= next_pc;
			end if;
			
			if mem_waitrequest = '1' then
				-- flush logic (TO BE DONE)
				pc_id <= pc;
				instruction_id <= i_out;
			end if;
			
		end if;
	end process;
end top;
