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

-- Mem stage signals
-- Expected signals from EX
signal WB_mem : std_logic_vector(1 downto 0); -- (1): RegWrite, (0): MemToReg
signal M_mem : std_logic_vector(2 downto 0); -- (2):Branch, (1):MemRead, (0):MemWrite
signal branch_addr : std_logic_vector(31 downto 0); -- Branch address
signal res_memaddr : std_logic_vector(31 downto 0); -- ALU result
signal func3_mem : std_logic_vector(2 downto 0); -- Func3 for conditional
signal flags : std_logic_vector(1 downto 0); -- (1) lt, (0) eq
signal rd_mem : std_logic_vector(4 downto 0); -- Instruction[11-7]


-- Intermediate signals in Mem
signal branch_taken : std_logic;
signal write_data_mem : std_logic_vector(31 downto 0);
signal d_memout : std_logic_vector(31 downto 0);

-- WB stage signals
signal WB_wb : std_logic_vector(1 downto 0); -- RegWrite and MemToReg
signal mem_data_wb, alu_res_wb : std_logic_vector(31 downto 0); -- Data from load or R instructions
signal rd_wb : std_logic_vector(4 downto 0); -- Destination register


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
									 memwrite => M_mem(0),
									 memread => M_mem(1),
									 writedata => write_data_mem, 
									 address => to_integer(unsigned(res_memaddr)), 
									 readdata => d_memout,
									 waitrequest => d_waitrequest);
	
	pc4 <= pc + 4;
	pc_sel <= branch_taken;
	pc_branch <= to_integer(unsigned(branch_addr));
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
		
		
		-- MEM stage
		WB_wb <= WB_mem;
		mem_data_wb <= d_memout;
		alu_res_wb <= res_memaddr;
		rd_wb <= rd_mem;
	end process;
	
	
	-- Mem stage combinational
	branch_taken <= '1' when (M_mem(2) = '1' and (
                    (func3_mem = "000" and flags(0) = '1') or -- beq: branch if equal
                    (func3_mem = "001" and flags(0) = '0') or -- bne: branch if NOT equal
                    (func3_mem = "100" and flags(1) = '1') or -- blt: branch if less than
                    (func3_mem = "101" and flags(1) = '0') -- bge: branch if NOT less than (greater or equal)
                )) else '0';
	
	-- WB stage combinational
	RegWrite <= WB_wb(1);
	MemToReg <= WB_wb(0);
	WriteRegister <= rd_wb;
	with memToReg select
		write_data <= mem_data_wb when '1',
						  alu_res_wb when others;
	
end top;
