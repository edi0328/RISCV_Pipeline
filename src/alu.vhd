library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
	port (
		A : in std_logic_vector(31 downto 0);
		B: in std_logic_vector(31 downto 0);
		op : in std_logic_vector(3 downto 0);
		result : out std_logic_vector(31 downto 0);
		-- Branching only has beq, bne, blt, bge
		zero : out std_logic;
		lt : out std_logic
		-- Feel free to add output ports for debugging below
	);
end alu;

-- op encoding (must match alu_ctrl):
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
-- 1010 = MUL  (lower 32 bits of signed multiplication)
-- 1011 = branch compare (result = A - B; zero and lt flags are meaningful)

architecture behavioral of alu is
	signal a_signed  : signed(31 downto 0);
	signal b_signed  : signed(31 downto 0);
	signal a_unsigned: unsigned(31 downto 0);
	signal b_unsigned: unsigned(31 downto 0);
	signal sub_result: signed(31 downto 0);
begin
	a_signed   <= signed(A);
	b_signed   <= signed(B);
	a_unsigned <= unsigned(A);
	b_unsigned <= unsigned(B);
	sub_result <= a_signed - b_signed;

	-- Combinatorial ALU operation
	process(op, A, B, a_signed, b_signed, a_unsigned, b_unsigned, sub_result)
		variable shift_amt : integer;
	begin
		shift_amt := to_integer(unsigned(B(4 downto 0)));

		case op is
			when "0000" => -- ADD
				result <= std_logic_vector(a_signed + b_signed);

			when "0001" => -- SUB
				result <= std_logic_vector(sub_result);

			when "0010" => -- AND
				result <= A and B;

			when "0011" => -- OR
				result <= A or B;

			when "0100" => -- XOR
				result <= A xor B;

			when "0101" => -- SLL
				result <= std_logic_vector(shift_left(a_unsigned, shift_amt));

			when "0110" => -- SRL (logical right shift)
				result <= std_logic_vector(shift_right(a_unsigned, shift_amt));

			when "0111" => -- SRA (arithmetic right shift)
				result <= std_logic_vector(shift_right(a_signed, shift_amt));

			when "1000" => -- SLT (signed)
				if a_signed < b_signed then
					result <= (0 => '1', others => '0');
				else
					result <= (others => '0');
				end if;

			when "1001" => -- SLTU (unsigned)
				if a_unsigned < b_unsigned then
					result <= (0 => '1', others => '0');
				else
					result <= (others => '0');
				end if;

			when "1010" => -- MUL (lower 32 bits of signed product)
				result <= std_logic_vector(resize(a_signed * b_signed, 32));

			when "1011" => -- Branch compare (A - B, flags used by pipeline)
				result <= std_logic_vector(sub_result);

			when others =>
				result <= (others => '0');
		end case;
	end process;

	-- Flags (always driven combinatorially from A and B directly)
	zero <= '1' when A = B else '0';
	lt   <= '1' when a_signed < b_signed else '0';

end behavioral;
