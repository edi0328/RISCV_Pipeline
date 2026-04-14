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
signal i_out : std_logic_vector(31 downto 0); --output from Instruction Memory

signal i_waitrequest, d_waitrequest, pipeline_ready : std_logic;

-- Mem stage signals
-- Expected signals from EX
signal WB_mem : std_logic_vector(1 downto 0); -- (1): RegWrite, (0): MemToReg
signal M_mem : std_logic_vector(2 downto 0); -- (2):Branch, (1):MemRead, (0):MemWrite
signal branch_addr : std_logic_vector(31 downto 0); -- Branch address
signal res_memaddr : std_logic_vector(31 downto 0); -- ALU result
signal func3_mem : std_logic_vector(2 downto 0); -- Func3 for conditional
signal flags : std_logic_vector(1 downto 0); -- (1) lt, (0) eq
signal rd_mem : std_logic_vector(4 downto 0); -- Instruction[11-7]

signal RegWrite      : std_logic; -- To write or not
signal MemToReg      : std_logic; -- Choose WB using mem if 1, else ALU result
signal WriteRegister : std_logic_vector(4 downto 0); -- Which register to write
signal write_data    : std_logic_vector(31 downto 0); -- What to write to registers

-- Intermediate signals in Mem
signal branch_taken : std_logic; -- 1 if branch
signal write_data_mem : std_logic_vector(31 downto 0);
signal d_memout : std_logic_vector(31 downto 0);

-- WB stage signals
signal WB_wb : std_logic_vector(1 downto 0); -- RegWrite and MemToReg
signal mem_data_wb, alu_res_wb : std_logic_vector(31 downto 0); -- Data from load or R instructions
signal rd_wb : std_logic_vector(4 downto 0); -- Destination register

-- IF/ID signals
signal im_read : std_logic := '0';
signal if_id_out : std_logic_vector(31 downto 0);
signal pc_if_id_out : integer;
signal if_id_write : std_logic;
signal if_id_flush : std_logic;
signal id_ex_flush : std_logic;
signal ex_mem_flush : std_logic;

-- HAZARD signals
signal pc_write : std_logic;

-- REGISTERS signals

-- ID/EX signals
signal id_ex_out : std_logic_vector(104 downto 0);
signal pc_id_ex_out : integer;
signal ex_id_ex_out : std_logic_vector(2 downto 0);
signal m_id_ex_out : std_logic_vector(2 downto 0);
signal wb_id_ex_out : std_logic_vector(1 downto 0);

-- EX/MEM signals
signal ex_mem_out : std_logic_vector(70 downto 0);
signal m_ex_mem_out : std_logic_vector(2 downto 0);
signal wb_ex_mem_out : std_logic_vector(1 downto 0);
signal operation : std_logic_vector(3 downto 0);
signal B : std_logic_vector(31 downto 0);
signal branch_add : std_logic_vector(32 downto 0);
signal pc_ex_mem_out : std_logic_vector(32 downto 0);
signal read_data_a, read_data_b : std_logic_vector(31 downto 0);

signal alu_res : std_logic_vector(31 downto 0);
signal alu_zero, alu_lt : std_logic;


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
									 memread => im_read,
									 writedata => (others => '0'),
									 address => pc,

									 readdata => i_out,
									 waitrequest => i_waitrequest);
									 
	D_mem : memory port map (clock => clk,
									 memwrite => M_mem(0),
									 memread => M_mem(1),
									 writedata => write_data_mem, 
									 address => to_integer(unsigned(ex_mem_out(68 downto 37))),

									 readdata => d_memout,
									 waitrequest => d_waitrequest);

	hazard : hazard_unit port map (id_rs2 => if_id_out(24 downto 20),
									 id_rs1 => if_id_out(19 downto 15),
									 ex_rd => id_ex_out(4 downto 0),
									 ex_reg_write => wb_id_ex_out(1),
									 mem_rd => ex_mem_out(4 downto 0),
									 mem_reg_write => wb_ex_mem_out(1),
									 mem_waitrequest => d_waitrequest OR i_waitrequest,
									 branch_taken => branch_taken,

									 pc_write => pc_write,
									 if_id_write => if_id_write,
									 id_ex_flush => id_ex_flush,
									 if_id_flush => if_id_flush,
									 ex_mem_flush => ex_mem_flush
									 );

	rgs : registers port map (clk => clk,
									 reg_write => RegWrite,
									 addr_a => if_id_out(19 downto 15),
									 addr_b => if_id_out(24 downto 20),
									 addr_dest => WriteRegister,
									 write_data => write_data,
									 read_data_a => read_data_a,
									 read_data_b => read_data_b
									 );

	alu_ctrl_unit : alu_ctrl port map (-- To differentiate R instructions
									 funct3 => id_ex_out(7 downto 5),
									 funct7 => "0" & id_ex_out(8) & "00000",
									 ALUOp => ex_id_ex_out(2 downto 1),

									 op => operation
									 );

	alu_unit : alu port map (A => id_ex_out(104 downto 73),
									 B => B,
									 op => operation,

									 result => alu_res,
									 -- Branching only has beq, bne, blt, bge
									 zero => alu_zero,
									 lt => alu_lt
									 );

	pipeline_ready <= not (i_waitrequest or d_waitrequest); -- 0 means done, 
	
	-- PC combinational logic
	pc4 <= pc + 4;
	pc_sel <= branch_taken;
	pc_branch <= to_integer(unsigned(branch_addr));
	with pc_sel select
		next_pc <= pc4 when '0',
						pc_branch when others;
	
	im_read <= pc_write and pipeline_ready and not reset;
	
	-- ID combinational logic
	process(clk, reset)	
	begin
		if reset = '1' then
			pc <= 0;
			if_id_out <= (others => '0');
			id_ex_out <= (others => '0');
			ex_mem_out <= (others => '0');
			pc_if_id_out <= 0;
			pc_id_ex_out <= 0;
		elsif rising_edge(clk) and pipeline_ready = '1' then
			----------
			-- PC changes on fetch or branch, when hazard_unit allows
			if pc_write = '1' then
				pc <= next_pc;
			end if;
			
			---------------------------------------------------------------------------------------
			---------------------------------------- FETCH ----------------------------------------
			---------------------------------------------------------------------------------------
			
			-- IF/ID registers logic
			if if_id_write = '1' then
				-- branch
				if if_id_flush = '1' then
					if_id_out <= x"00000013"; -- NOP is addi x0, x0, 0
					pc_if_id_out <= 0;
				else -- normal assignment
					if_id_out <= i_out;
					pc_if_id_out <= pc; -- TO CHECK IF NEEDS OFFSET OR +4
				end if;
			end if;

			-- stall: do nothing

			---------------------------------------------------------------------------------------
			---------------------------------------- DECODE ----------------------------------------
			---------------------------------------------------------------------------------------

			-- wire addresses to registers
			-- rs2[20 to 24], rs1[15 to 19], funct3[12 to 14], funct7[25 to 31]
			-- opcode[0 to 6] for branch, load, store, or operation

			
			-- immediate value logic (40 downto 9)
			if if_id_out(6 downto 0) = "0110011" then -- R-type
				id_ex_out(40 downto 9) <= (others => '0'); -- no immediate for R-type
				id_ex_out(72 downto 41) <= read_data_b;
				id_ex_out(104 downto 73) <= read_data_a;
				
			elsif if_id_out(6 downto 0) = "0010011" or if_id_out(6 downto 0) = "0000011" -- Immediate or load
			or if_id_out(6 downto 0) = "1100111" or if_id_out(6 downto 0) = "1110011" then -- I-type
				id_ex_out(40 downto 9) <= (19 downto 0 => if_id_out(31)) & if_id_out(31 downto 20); -- Sign extend immediate
				id_ex_out(72 downto 41) <= read_data_b; -- Will be replaced by immediate
				id_ex_out(104 downto 73) <= read_data_a;
				
			
			elsif if_id_out(6 downto 0) = "0100011" then -- S-type
				id_ex_out(40 downto 9) <= (19 downto 0 => if_id_out(31)) & if_id_out(31 downto 25) & if_id_out(11 downto 7);
				id_ex_out(72 downto 41) <= read_data_b;
				id_ex_out(104 downto 73) <= read_data_a;
			
			elsif if_id_out(6 downto 0) = "1100011" then -- B-type
				id_ex_out(40 downto 9) <= (18 downto 0 => if_id_out(31)) & if_id_out(31) & if_id_out(7) & if_id_out(30 downto 25) & if_id_out(11 downto 8) & "0";
				id_ex_out(72 downto 41) <= read_data_b;
				id_ex_out(104 downto 73) <= read_data_a;
			
			elsif if_id_out(6 downto 0) = "0110111" or if_id_out(6 downto 0) = "0010111" then -- U-type
				id_ex_out(40 downto 9) <= if_id_out(31 downto 12) & (11 downto 0 => '0');
				
			elsif if_id_out(6 downto 0) = "1101111" then -- J-type
				id_ex_out(40 downto 9) <= (10 downto 0 => if_id_out(31)) & if_id_out(31) & if_id_out(19 downto 12) & if_id_out(20) & if_id_out(30 downto 21) & "0";

			end if;


			-- ALU control 8-5 is funct3, 30 for funct7 bit
			id_ex_out(8 downto 5) <= if_id_out(30) & if_id_out(14 downto 12);


			-- writeback register 4 downto 0
			id_ex_out(4 downto 0) <= if_id_out(11 downto 7);


			-- control module
			-- if not R-type select imm
			if if_id_out(6 downto 0) /= "0110011" then
				ex_id_ex_out(0) <= '1'; --ALUSrc
			else
				ex_id_ex_out(0) <= '0'; -- Use read_data_2 if is R-type
			end if;

			case if_id_out(6 downto 0) is
				when "0000011" => -- load
					ex_id_ex_out(2 downto 1) <= "00";
					m_id_ex_out <= "010"; -- branch & read & write
					wb_id_ex_out <= "11"; -- regwrite & memtoreg
				
				when "0100011" => -- store
					ex_id_ex_out(2 downto 1) <= "00";
					m_id_ex_out <= "001";
					wb_id_ex_out <= "00";
				
				when "1100011" => -- branch
					ex_id_ex_out(2 downto 1) <= "01";
					m_id_ex_out <= "100";
					wb_id_ex_out <= "00";

				when "0010011" | "1100111" | "1110011" => -- R and I style instructions
					ex_id_ex_out(2 downto 1) <= "10";
					m_id_ex_out <= "000";
					wb_id_ex_out <= "10";

				when others =>
					ex_id_ex_out(2 downto 1) <= "11";
					m_id_ex_out <= "000";
					wb_id_ex_out <= "00";
			end case;

			pc_id_ex_out <= pc_if_id_out;

			if id_ex_flush = '1' then
				id_ex_out <= (others => '0');
			end if;
			
			---------------------------------------------------------------------------------------
			---------------------------------------- EXECUTE ----------------------------------------
			---------------------------------------------------------------------------------------
			-- pass signals to next stage
			ex_mem_out(4 downto 0) <= id_ex_out(4 downto 0);
			ex_mem_out(36 downto 5) <= id_ex_out(72 downto 41);

			M_mem <= m_id_ex_out;
			WB_mem <= wb_id_ex_out; -- wb_ex_mem_out
			
			-- Connect port map wires
			ex_mem_out(68 downto 37) <= alu_res;
			ex_mem_out(69) <= alu_zero;
			ex_mem_out(70) <= alu_lt;
			
			-- calculate branch address (TO BE VERIFIED AGAIN)
			branch_addr <= std_logic_vector(
    				to_signed(pc_id_ex_out, 32) + signed(id_ex_out(40 downto 9)) -- Signed to go either direction
			);
		
			
			if (ex_mem_flush = '1') then
				ex_mem_out <= (others => '0');
			end if;
			------------------------------------------------------------------------
													--MEM stage to WB
			------------------------------------------------------------------------
			
			WB_wb <= WB_mem; -- WriteBack register
			mem_data_wb <= d_memout;
			alu_res_wb <= ex_mem_out(68 downto 37); --Fed also to D-mem in port map
			rd_wb <= ex_mem_out(4 downto 0); --
			
		end if;
	end process;
	
	-- EX stage combinational
	B <= id_ex_out(40 downto 9) when ex_id_ex_out(0) = '1' else id_ex_out(72 downto 41); -- imm or register value
	func3_mem <= id_ex_out(7 downto 5); -- Needed to branch conditionals
	flags(0) <= ex_mem_out(69); --zero
	flags(1) <= ex_mem_out(70); --lt
	
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
	with MemToReg select
		write_data <= mem_data_wb when '1',
						  alu_res_wb when others;
	
end top;
