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
		
		-- Feel free to add output ports for debugging below
	);
end hazard_unit;
