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

-- IF/ID signals
signal if_id_in, if_id_out : std_logic_vector(31 downto 0);
signal pc_if_id_in, pc_if_id_out : integer;

-- HAZARD signals

-- REGISTERS signals

-- ID/EX signals
signal id_ex_in, id_ex_out : std_logic_vector(104 downto 0);
signal pc_id_ex_in, pc_id_ex_out : integer;
signal ex_id_ex_in, ex_id_ex_out : std_logic_vector(2 downto 0);
signal m_id_ex_in, m_id_ex_out : std_logic_vector(3 downto 0);
signal wb_id_ex_in, wb_id_ex_out : std_logic_vector(1 downto 0);

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

component hazard_unit
	port(
		-- Registers in the Decode stage (from IF/ID register)
		id_rs1 : in  std_logic_vector(4 downto 0);
		id_rs2 : in  std_logic_vector(4 downto 0);

		-- Destination registers and write-enable signals from later stages
		ex_rd : in  std_logic_vector(4 downto 0);
		ex_reg_write : in  std_logic; -- From ID/EX
		mem_rd : in  std_logic_vector(4 downto 0);
		mem_reg_write : in  std_logic; -- From EX/MEM

		-- Memory status and Branch results
		mem_waitrequest : in  std_logic; -- From memory.vhd
		branch_taken : in  std_logic; -- From MEM stage logic

		-- Outputs to control the pipeline flow
		pc_write : out std_logic; -- Enable for the PC
		if_id_write : out std_logic; -- Enable for the IF/ID register
		id_ex_flush : out std_logic; -- Clear for ID/EX (inserts NOP)
		if_id_flush : out std_logic;  -- Clear for IF/ID (clears fetched instr)
		ex_mem_flush : out std_logic -- For mem flushes
	);
end component;

component registers is
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

	hazard : hazard_unit port map (clk => clk,
									 id_rs1 => ,
									 id_rs2 => ,
									 ex_rd => ,
									 ex_reg_write => ,
									 mem_rd => ,
									 mem_reg_write => ,
									 mem_waitrequest => ,
									 branch_taken => ,
									 pc_write => ,
									 if_id_write => ,
									 id_ex_flush => ,
									 if_id_flush => ,
									 ex_mem_flush => ,
									 );

	rgs : registers port map (clk => clk,
									 reg_write => MEM_WB_WRITE,
									 addr_a => if_id_out(24 downto 20),
									 addr_b => if_id_out(19 downto 15),
									 addr_dest => MEM_WB_REG,
									 write_data => MEM_WB_DATA,
									 read_data_a => id_ex_in(104 downto 73),
									 read_data_b => id_ex_in(72 downto 41),
									 );

	
	pc4 <= pc + 4;
	with pc_sel select
		next_pc <= pc4 when '0',
						pc_branch when others;
	
	
	process(clk, reset)	
	begin
		if reset = '1' then
			pc <= 0;
		elsif rising_edge(clk) then
			----------
			---------------------------------------------------------------------------------------
			---------------------------------------- FETCH ----------------------------------------
			---------------------------------------------------------------------------------------
			-- PC changes on fetch or branch, when hazard_unit allows
			if pc_write = '1' then
				pc <= next_pc;
			end if;
			
			-- IF/ID registers logic
			-- no stall
			if if_id_write = '1' then
				-- branch
				if if_id_flush = '1' then
					if_id_in <= 0x0;
				else
				-- store instruction for next stage
					if_id_in <= i_out;
				end if;
			end if;

			-- stall: do nothing

			---------------------------------------------------------------------------------------
			---------------------------------------- DECODE ----------------------------------------
			---------------------------------------------------------------------------------------
			if_id_out <= if_id_in;

			-- wire addresses to registers
			-- rs1[20 to 24], rs2[15 to 19], funct3[12 to 14], funct7[25 to 31]
			-- opcode[0 to 6] for branch, load, store, or operation

			-- immediate value logic
			if if_id_out(6 downto 0) = "0110011" then -- R-type
				id_ex_in(40 downto 9) <= 0x0;
			
			elif if_id_out(6 downto 0) = "0010011" or if_id_out(6 downto 0) = '0000011' 
			or if_id_out(6 downto 0) = '1100111' or if_id_out(6 downto 0) = '1110011' then -- I-type
				id_ex_in(40 downto 9) <= 0x0 && if_id_out(31 downto 20);
			
			elif if_id_out(6 downto 0) = "0100011" then -- S-type
				id_ex_in(40 downto 9) <= 0x0 && if_id_out(31 downto 25) && if_id_out(11 downto 7);
			
			elif if_id_out(6 downto 0) = "1100011" then -- B-type
				id_ex_in(40 downto 9) <= 0x0 && if_id_out(31) && if_id_out(7) && if_id_out(30 downto 25) && if_id_out(11 downto 8) && "0";

			elif if_id_out(6 downto 0) = "1101111" then -- J-type
				id_ex_in(40 downto 9) <= 0x0 && if_id_out(31) && if_id_out(19 downto 12) && if_id_out(20) && if_id_out(30 downto 21) && "0";

			else -- U-type
				id_ex_in(40 downto 9) <= if_id_out(31 downto 12) && 0x0;
			end if;


			-- ALU control
			id_ex_in(8 downto 5) <= if_id_out(30) && if_id_out(14 downto 12)


			-- writeback register
			id_ex_in(4 downto 0) <= if_id_out(11 downto 7)


			-- control module
			-- if not R-type select imm
			if if_id_out(6 downto 0) /= "0110011" then
				ex_id_ex_in(0) = '1'
			else
				ex_id_ex_in(0) = '0'
			end if;

			case if_id_out(6 downto 0) is
				when "0000011" => -- load
					ex_id_ex_in(2 downto 1) <= 00;
				
				when "0100011" => -- store
					ex_id_ex_in(2 downto 1) <= 00;
				
				when "1100011" => -- branch
					ex_id_ex_in(2 downto 1) <= 01;

				when "0010011" or "0000011" or "1100111" or "1110011" => -- R and I style instructions
					ex_id_ex_in(2 downto 1) <= 10;

				when others =>
					ex_id_ex_in(2 downto 1) <= 11;
			end case;
			
			-- ******TODO***** m and wb control module
			m_id_ex_in <= ;
			wb_id_ex_in <= ;

			pc_id_ex_in <= pc_if_id_out
			
			---------------------------------------------------------------------------------------
			---------------------------------------- EXECUTE ----------------------------------------
			---------------------------------------------------------------------------------------
			#
			
		end if;
	end process;
end top;
