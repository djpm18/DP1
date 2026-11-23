-- Design Candidate: Multi-level Carry-Lookahead Adder (64-bit)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 4-bit Look-Ahead Carry Unit (LCU)
entity LCU is
    port (
        G      : in  std_logic_vector(3 downto 0);
        P      : in  std_logic_vector(3 downto 0);
        Cin    : in  std_logic;
        C      : out std_logic_vector(3 downto 1);
        Cout   : out std_logic;
        PGroup : out std_logic;
        GGroup : out std_logic
    );
end entity LCU;

architecture structural of LCU is
begin
    C(1) <= G(0) or (P(0) and Cin);
    C(2) <= G(1) or (P(1) and G(0)) or (P(1) and P(0) and Cin);
    C(3) <= G(2) or (P(2) and G(1)) or (P(2) and P(1) and G(0)) or (P(2) and P(1) and P(0) and Cin);
    Cout <= G(3) or (P(3) and G(2)) or (P(3) and P(2) and G(1)) or (P(3) and P(2) and P(1) and G(0)) or (P(3) and P(2) and P(1) and P(0) and Cin);

    PGroup <= P(3) and P(2) and P(1) and P(0);
    GGroup <= G(3) or (P(3) and G(2)) or (P(3) and P(2) and G(1)) or (P(3) and P(2) and P(1) and G(0));
end architecture structural;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity Adder is
	Generic ( N : natural := 64 );
	Port ( A, B : in std_logic_vector( N-1 downto 0 );
	 S : out std_logic_vector( N-1 downto 0 );
	 Cin : in std_logic;
	 Cout, Ovfl : out std_logic );
End Entity Adder;

architecture CarryLookahead of Adder is

    constant BLOCK_SIZE : positive := 4;
    constant NUM_BLOCKS : natural := N / BLOCK_SIZE;

    component LCU is
        port (
            G      : in  std_logic_vector(3 downto 0);
            P      : in  std_logic_vector(3 downto 0);
            Cin    : in  std_logic;
            C      : out std_logic_vector(3 downto 1);
            Cout   : out std_logic;
            PGroup : out std_logic;
            GGroup : out std_logic
        );
    end component;

    signal block_c    : std_logic_vector(NUM_BLOCKS downto 0);
    signal block_p    : std_logic_vector(NUM_BLOCKS-1 downto 0);
    signal block_g    : std_logic_vector(NUM_BLOCKS-1 downto 0);
    signal s_int      : std_logic_vector(N-1 downto 0);

begin

    assert (N mod BLOCK_SIZE = 0) 
        report "CarryLookahead requires N to be a multiple of 4." 
        severity failure;

    block_c(0) <= Cin;

    -- Generate block-level propagate and generate signals using LCU instances
    gen_blocks: for i in 0 to NUM_BLOCKS - 1 generate
        signal g_bit, p_bit : std_logic_vector(3 downto 0);
        signal c_internal   : std_logic_vector(3 downto 1);
        signal c_full       : std_logic_vector(4 downto 0);
        signal local_cout   : std_logic;
    begin
        -- Bitwise generate and propagate for the 4 bits in block i
        gen_bits: for j in 0 to BLOCK_SIZE - 1 generate
            constant BIT_IDX : natural := i * BLOCK_SIZE + j;
        begin
            g_bit(j) <= A(BIT_IDX) and B(BIT_IDX);
            p_bit(j) <= A(BIT_IDX) xor B(BIT_IDX);
        end generate gen_bits;

        -- Instantiate LCU for this 4-bit block
        BLOCK_LCU : LCU
            port map (
                G      => g_bit,
                P      => p_bit,
                Cin    => block_c(i),
                C      => c_internal,
                Cout   => local_cout,
                PGroup => block_p(i),
                GGroup => block_g(i)
            );

        c_full(0)          <= block_c(i);
        c_full(3 downto 1) <= c_internal;
        c_full(4)          <= local_cout;

        -- Compute sum for this block
        gen_sum_bits: for j in 0 to BLOCK_SIZE - 1 generate
            constant BIT_IDX : natural := i * BLOCK_SIZE + j;
        begin
            s_int(BIT_IDX) <= p_bit(j) xor c_full(j);
        end generate gen_sum_bits;
    end generate gen_blocks;

    -- Top-level carry lookahead across the 16 blocks
    process(block_p, block_g, block_c(0))
        variable c_carry : std_logic_vector(NUM_BLOCKS downto 0);
    begin
        c_carry(0) := block_c(0);
        for i in 0 to NUM_BLOCKS - 1 loop
            c_carry(i+1) := block_g(i) or (block_p(i) and c_carry(i));
        end loop;
        
        for i in 1 to NUM_BLOCKS loop
            block_c(i) <= c_carry(i);
        end loop;
    end process;

    S    <= s_int;
    Cout <= block_c(NUM_BLOCKS);

    -- Signed overflow detection
    Ovfl <= (A(N-1) and B(N-1) and not s_int(N-1)) or 
            (not A(N-1) and not B(N-1) and s_int(N-1));

end architecture CarryLookahead;
