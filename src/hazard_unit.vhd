library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hazard_unit is
	port (
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
end hazard_unit;

architecture rtl of hazard_unit is
	signal ex_hazard   : std_logic;
	signal mem_hazard  : std_logic;
	signal data_hazard : std_logic;
begin

	-- Hazard with instruction currently in EX stage
	ex_hazard <= '1' when
		(ex_reg_write = '1') and
		(ex_rd /= "00000") and
		((id_rs1 = ex_rd) or (id_rs2 = ex_rd))
	else
		'0';

	-- Hazard with instruction currently in MEM stage
	mem_hazard <= '1' when
		(mem_reg_write = '1') and
		(mem_rd /= "00000") and
		((id_rs1 = mem_rd) or (id_rs2 = mem_rd))
	else
		'0';

	data_hazard <= ex_hazard or mem_hazard;

	process(all)
	begin
		-- Default: normal pipeline operation
		pc_write     <= '1';
		if_id_write  <= '1';
		id_ex_flush  <= '0';
		if_id_flush  <= '0';
		ex_mem_flush <= '0';

		-- Stall pipeline if memory is waiting
		if mem_waitrequest = '1' then
			pc_write     <= '0';
			if_id_write  <= '0';
			id_ex_flush  <= '1';

		-- Stall pipeline on data hazard
		elsif data_hazard = '1' then
			pc_write     <= '0';
			if_id_write  <= '0';
			id_ex_flush  <= '1';

		-- Flush younger instructions on taken branch
		elsif branch_taken = '1' then
			if_id_flush  <= '1';
			id_ex_flush  <= '1';
			ex_mem_flush <= '1';
		end if;
	end process;

end rtl;
