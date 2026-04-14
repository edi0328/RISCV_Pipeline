--Adapted from Example 12-15 of Quartus Design and Synthesis handbook
-- Modified to be byte addressable while only used for lw and sw
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY memory IS
	GENERIC(
		ram_size : INTEGER := 32768;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
	PORT (
		clock: IN STD_LOGIC;
		writedata: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		address: IN INTEGER RANGE 0 TO ram_size-1;
		memwrite: IN STD_LOGIC;
		memread: IN STD_LOGIC;
		readdata: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		waitrequest: OUT STD_LOGIC
	);
END memory;

ARCHITECTURE rtl OF memory IS
	-- Adjusted to map byte addresses to array indices
	TYPE MEM IS ARRAY((ram_size / 4) -1 downto 0) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ram_block: MEM := (others => (others =>'0')); -- 0 init
BEGIN
	--This is the main section of the SRAM model
	mem_process: PROCESS (clock)
	BEGIN

		--This is the actual synthesizable SRAM block
		IF (clock'event AND clock = '1') THEN
			IF (memwrite = '1') THEN
				ram_block(address/4) <= writedata;
			END IF;
		END IF;
	END PROCESS;
	readdata <= ram_block(address/4) when memread = '1' else (others => '0');


	--The waitrequest signal is used to vary response time in simulation
	--Read and write should never happen at the same time.
	process (memread, memwrite)
	begin
		if (memread = '1' or memwrite = '1') then
			waitrequest <= '1';
			waitrequest <= '0' after mem_delay;
		else
			waitrequest <= '0';
		end if;

	end process;


END rtl;
