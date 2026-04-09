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

-- op encoding:
-- 0000 = ADD
-- 0001 = SUB
-- 0010 = AND
-- 0011 = OR
-- 0100 = XOR
-- 0101 = SLL
-- 0110 = SRL
-- 0111 = SRA
-- 1000 = SLT  (signed)
-- 1001 = SLTU (unsigned)
-- 1010 = MUL
-- 1011 = branch compare (zero/lt flags used by pipeline, result unused)

architecture behavioral of alu_ctrl is
begin
	process(ALUOp, funct3, funct7)
	begin
		case ALUOp is

			-- Load / Store: always ADD
			when "00" =>
				op <= "0000";

			-- Branch: use funct3 to pick comparison type
			-- The ALU computes A-B and pipeline reads zero/lt flags
			when "01" =>
				op <= "1011"; -- branch compare mode

			-- R-type and I-type ALU instructions
			when "10" =>
				-- RV32M multiply (funct7 = 0000001, only mul rd=rs1*rs2[31:0])
				if funct7 = "0000001" then
					op <= "1010"; -- MUL

				elsif funct7 = "0100000" then
					-- SUB or SRA
					case funct3 is
						when "000"  => op <= "0001"; -- SUB
						when "101"  => op <= "0111"; -- SRA
						when others => op <= "0000"; -- fallback ADD
					end case;

				else
					-- funct7 = 0000000 (R-type) or ignored (I-type immediate)
					case funct3 is
						when "000"  => op <= "0000"; -- ADD / ADDI
						when "001"  => op <= "0101"; -- SLL / SLLI
						when "010"  => op <= "1000"; -- SLT / SLTI
						when "011"  => op <= "1001"; -- SLTU / SLTIU
						when "100"  => op <= "0100"; -- XOR / XORI
						when "101"  => op <= "0110"; -- SRL / SRLI
						when "110"  => op <= "0011"; -- OR / ORI
						when "111"  => op <= "0010"; -- AND / ANDI
						when others => op <= "0000";
					end case;
				end if;

			when others =>
				op <= "0000";

		end case;
	end process;
end behavioral;