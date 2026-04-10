library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_temp is
end tb_temp;

architecture behavioral of tb_temp is

    -- =========================================================
    -- Component declarations
    -- =========================================================
    component registers is
        port (
            clk         : in  std_logic;
            reg_write   : in  std_logic;
            addr_a      : in  std_logic_vector(4 downto 0);
            addr_b      : in  std_logic_vector(4 downto 0);
            addr_dest   : in  std_logic_vector(4 downto 0);
            write_data  : in  std_logic_vector(31 downto 0);
            read_data_a : out std_logic_vector(31 downto 0);
            read_data_b : out std_logic_vector(31 downto 0)
        );
    end component;

    component alu_ctrl is
        port (
            funct3 : in  std_logic_vector(2 downto 0);
            funct7 : in  std_logic_vector(6 downto 0);
            ALUOp  : in  std_logic_vector(1 downto 0);
            op     : out std_logic_vector(3 downto 0)
        );
    end component;

    component alu is
        port (
            A      : in  std_logic_vector(31 downto 0);
            B      : in  std_logic_vector(31 downto 0);
            op     : in  std_logic_vector(3 downto 0);
            result : out std_logic_vector(31 downto 0);
            zero   : out std_logic;
            lt     : out std_logic
        );
    end component;

    -- =========================================================
    -- Signals for registers
    -- =========================================================
    signal clk         : std_logic := '0';
    signal reg_write   : std_logic := '0';
    signal addr_a      : std_logic_vector(4 downto 0) := (others => '0');
    signal addr_b      : std_logic_vector(4 downto 0) := (others => '0');
    signal addr_dest   : std_logic_vector(4 downto 0) := (others => '0');
    signal write_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal read_data_a : std_logic_vector(31 downto 0);
    signal read_data_b : std_logic_vector(31 downto 0);

    -- =========================================================
    -- Signals for alu_ctrl
    -- =========================================================
    signal funct3 : std_logic_vector(2 downto 0) := (others => '0');
    signal funct7 : std_logic_vector(6 downto 0) := (others => '0');
    signal ALUOp  : std_logic_vector(1 downto 0) := (others => '0');
    signal op     : std_logic_vector(3 downto 0);

    -- =========================================================
    -- Signals for ALU
    -- =========================================================
    signal alu_A      : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_B      : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_op     : std_logic_vector(3 downto 0)  := (others => '0');
    signal alu_result : std_logic_vector(31 downto 0);
    signal alu_zero   : std_logic;
    signal alu_lt     : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    -- =========================================================
    -- Instantiations
    -- =========================================================
    u_registers : registers port map (
        clk         => clk,
        reg_write   => reg_write,
        addr_a      => addr_a,
        addr_b      => addr_b,
        addr_dest   => addr_dest,
        write_data  => write_data,
        read_data_a => read_data_a,
        read_data_b => read_data_b
    );

    u_alu_ctrl : alu_ctrl port map (
        funct3 => funct3,
        funct7 => funct7,
        ALUOp  => ALUOp,
        op     => op
    );

    u_alu : alu port map (
        A      => alu_A,
        B      => alu_B,
        op     => alu_op,
        result => alu_result,
        zero   => alu_zero,
        lt     => alu_lt
    );

    clk <= not clk after CLK_PERIOD / 2;

    -- =========================================================
    -- Test process
    -- =========================================================
    process
        variable pass_count : integer := 0;
        variable fail_count : integer := 0;

        procedure check32(actual : std_logic_vector(31 downto 0);
                          expected : std_logic_vector(31 downto 0);
                          test_name : string) is
        begin
            if actual = expected then
                report "PASS [" & test_name & "]" severity note;
                pass_count := pass_count + 1;
            else
                report "FAIL [" & test_name & "]: got 0x" &
                       integer'image(to_integer(unsigned(actual))) &
                       " expected 0x" &
                       integer'image(to_integer(unsigned(expected)))
                severity error;
                fail_count := fail_count + 1;
            end if;
        end procedure;

        procedure check4(actual : std_logic_vector(3 downto 0);
                         expected : std_logic_vector(3 downto 0);
                         test_name : string) is
        begin
            if actual = expected then
                report "PASS [" & test_name & "]" severity note;
                pass_count := pass_count + 1;
            else
                report "FAIL [" & test_name & "]: got " &
                       integer'image(to_integer(unsigned(actual))) &
                       " expected " &
                       integer'image(to_integer(unsigned(expected)))
                severity error;
                fail_count := fail_count + 1;
            end if;
        end procedure;

        procedure check1(actual : std_logic; expected : std_logic;
                         test_name : string) is
        begin
            if actual = expected then
                report "PASS [" & test_name & "]" severity note;
                pass_count := pass_count + 1;
            else
                report "FAIL [" & test_name & "]: got " &
                       std_logic'image(actual) & " expected " &
                       std_logic'image(expected)
                severity error;
                fail_count := fail_count + 1;
            end if;
        end procedure;

    begin

        -- =================================================
        -- REGISTERS TESTS
        -- =================================================
        report "--- Testing registers ---" severity note;

        -- x0 is hardwired to 0
        reg_write <= '1'; addr_dest <= "00000"; write_data <= x"DEADBEEF";
        addr_a <= "00000";
        wait until falling_edge(clk);
        wait until rising_edge(clk); wait for 1 ns;
        check32(read_data_a, x"00000000", "REG: x0 hardwired zero");

        -- Write 0xABCD1234 to x1, read back on port A
        reg_write <= '1'; addr_dest <= "00001"; write_data <= x"ABCD1234";
        wait until falling_edge(clk);
        wait until rising_edge(clk); wait for 1 ns;
        addr_a <= "00001"; wait for 1 ns;
        check32(read_data_a, x"ABCD1234", "REG: write/read x1 port A");

        -- Write 0x00000005 to x2, read back on port B
        reg_write <= '1'; addr_dest <= "00010"; write_data <= x"00000005";
        wait until falling_edge(clk);
        wait until rising_edge(clk); wait for 1 ns;
        addr_b <= "00010"; wait for 1 ns;
        check32(read_data_b, x"00000005", "REG: write/read x2 port B");

        -- Read two registers simultaneously
        addr_a <= "00001"; addr_b <= "00010"; wait for 1 ns;
        check32(read_data_a, x"ABCD1234", "REG: simultaneous read A");
        check32(read_data_b, x"00000005", "REG: simultaneous read B");

        -- reg_write=0 must not overwrite
        reg_write <= '0'; addr_dest <= "00001"; write_data <= x"00000000";
        wait until falling_edge(clk);
        wait until rising_edge(clk); wait for 1 ns;
        addr_a <= "00001"; wait for 1 ns;
        check32(read_data_a, x"ABCD1234", "REG: no write when reg_write=0");

        -- =================================================
        -- ALU_CTRL TESTS
        -- =================================================
        report "--- Testing alu_ctrl ---" severity note;

        -- Load/Store: ALUOp=00 -> ADD (0000)
        ALUOp <= "00"; funct3 <= "000"; funct7 <= "0000000"; wait for 5 ns;
        check4(op, "0000", "CTRL: Load/Store ADD");

        -- Branch: ALUOp=01 -> branch compare (1011)
        ALUOp <= "01"; funct3 <= "000"; funct7 <= "0000000"; wait for 5 ns;
        check4(op, "1011", "CTRL: Branch compare");

        -- R/I-type, funct7=0000000
        ALUOp <= "10"; funct7 <= "0000000";
        funct3 <= "000"; wait for 5 ns; check4(op, "0000", "CTRL: ADD");
        funct3 <= "001"; wait for 5 ns; check4(op, "0101", "CTRL: SLL");
        funct3 <= "010"; wait for 5 ns; check4(op, "1000", "CTRL: SLT");
        funct3 <= "011"; wait for 5 ns; check4(op, "1001", "CTRL: SLTU");
        funct3 <= "100"; wait for 5 ns; check4(op, "0100", "CTRL: XOR");
        funct3 <= "101"; wait for 5 ns; check4(op, "0110", "CTRL: SRL");
        funct3 <= "110"; wait for 5 ns; check4(op, "0011", "CTRL: OR");
        funct3 <= "111"; wait for 5 ns; check4(op, "0010", "CTRL: AND");

        -- funct7=0100000 -> SUB, SRA
        ALUOp <= "10"; funct7 <= "0100000";
        funct3 <= "000"; wait for 5 ns; check4(op, "0001", "CTRL: SUB");
        funct3 <= "101"; wait for 5 ns; check4(op, "0111", "CTRL: SRA");

        -- funct7=0000001 -> MUL
        ALUOp <= "10"; funct7 <= "0000001";
        funct3 <= "000"; wait for 5 ns; check4(op, "1010", "CTRL: MUL");

        -- =================================================
        -- ALU TESTS
        -- =================================================
        report "--- Testing ALU ---" severity note;

        alu_A <= x"00000003"; alu_B <= x"00000005"; alu_op <= "0000"; wait for 5 ns;
        check32(alu_result, x"00000008", "ALU: ADD 3+5");

        alu_A <= x"FFFFFFFF"; alu_B <= x"00000001"; alu_op <= "0000"; wait for 5 ns;
        check32(alu_result, x"00000000", "ALU: ADD overflow wraps");

        alu_A <= x"0000000A"; alu_B <= x"00000003"; alu_op <= "0001"; wait for 5 ns;
        check32(alu_result, x"00000007", "ALU: SUB 10-3");

        alu_A <= x"00000003"; alu_B <= x"0000000A"; alu_op <= "0001"; wait for 5 ns;
        check32(alu_result, x"FFFFFFF9", "ALU: SUB 3-10 negative");

        alu_A <= x"FF00FF00"; alu_B <= x"0F0F0F0F"; alu_op <= "0010"; wait for 5 ns;
        check32(alu_result, x"0F000F00", "ALU: AND");

        alu_A <= x"F0F00000"; alu_B <= x"0F0F0F0F"; alu_op <= "0011"; wait for 5 ns;
        check32(alu_result, x"FFFF0F0F", "ALU: OR");

        alu_A <= x"FFFFFFFF"; alu_B <= x"0F0F0F0F"; alu_op <= "0100"; wait for 5 ns;
        check32(alu_result, x"F0F0F0F0", "ALU: XOR");

        alu_A <= x"00000001"; alu_B <= x"00000004"; alu_op <= "0101"; wait for 5 ns;
        check32(alu_result, x"00000010", "ALU: SLL 1<<4");

        alu_A <= x"80000000"; alu_B <= x"00000001"; alu_op <= "0110"; wait for 5 ns;
        check32(alu_result, x"40000000", "ALU: SRL logical");

        alu_A <= x"80000000"; alu_B <= x"00000001"; alu_op <= "0111"; wait for 5 ns;
        check32(alu_result, x"C0000000", "ALU: SRA arithmetic");

        alu_A <= x"FFFFFFFF"; alu_B <= x"00000001"; alu_op <= "1000"; wait for 5 ns;
        check32(alu_result, x"00000001", "ALU: SLT -1 < 1");

        alu_A <= x"00000001"; alu_B <= x"FFFFFFFF"; alu_op <= "1000"; wait for 5 ns;
        check32(alu_result, x"00000000", "ALU: SLT 1 not < -1 signed");

        alu_A <= x"FFFFFFFF"; alu_B <= x"00000001"; alu_op <= "1001"; wait for 5 ns;
        check32(alu_result, x"00000000", "ALU: SLTU large not less");

        alu_A <= x"00000001"; alu_B <= x"FFFFFFFF"; alu_op <= "1001"; wait for 5 ns;
        check32(alu_result, x"00000001", "ALU: SLTU small less");

        alu_A <= x"00000006"; alu_B <= x"00000007"; alu_op <= "1010"; wait for 5 ns;
        check32(alu_result, x"0000002A", "ALU: MUL 6*7=42");

        alu_A <= x"FFFFFFFF"; alu_B <= x"00000001"; alu_op <= "1010"; wait for 5 ns;
        check32(alu_result, x"FFFFFFFF", "ALU: MUL -1*1");

        -- Branch flags
        alu_A <= x"00000005"; alu_B <= x"00000005"; alu_op <= "1011"; wait for 5 ns;
        check1(alu_zero, '1', "ALU: branch A==B zero=1");
        check1(alu_lt,   '0', "ALU: branch A==B lt=0");

        alu_A <= x"00000003"; alu_B <= x"00000005"; alu_op <= "1011"; wait for 5 ns;
        check1(alu_zero, '0', "ALU: branch A<B zero=0");
        check1(alu_lt,   '1', "ALU: branch A<B lt=1");

        alu_A <= x"00000009"; alu_B <= x"00000005"; alu_op <= "1011"; wait for 5 ns;
        check1(alu_zero, '0', "ALU: branch A>B zero=0");
        check1(alu_lt,   '0', "ALU: branch A>B lt=0");

        -- =================================================
        report "--- DONE: " &
               integer'image(pass_count) & " passed, " &
               integer'image(fail_count) & " failed ---"
        severity note;
        wait;
    end process;

end behavioral;
