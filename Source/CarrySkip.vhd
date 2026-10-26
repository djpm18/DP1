-- N-bit carry-skip adder using four-bit ripple blocks.

library ieee;
use ieee.std_logic_1164.all;

architecture CarrySkip of Adder is

    constant BLOCK_SIZE : positive := 4;
    constant NUM_BLOCKS : natural := (N + BLOCK_SIZE - 1) / BLOCK_SIZE;

    signal block_carry : std_logic_vector(NUM_BLOCKS downto 0);
    signal s_int       : std_logic_vector(N-1 downto 0);

begin

    assert N > 0
        report "CarrySkip requires N >= 1."
        severity failure;

    block_carry(0) <= Cin;

    gen_blocks: for i in 0 to NUM_BLOCKS - 1 generate
        signal ripple_carry    : std_logic_vector(BLOCK_SIZE downto 0);
        signal propagate_chain : std_logic_vector(BLOCK_SIZE downto 0);
    begin
        ripple_carry(0)    <= block_carry(i);
        propagate_chain(0) <= '1';

        gen_bits: for j in 0 to BLOCK_SIZE - 1 generate
            constant BIT_INDEX : natural := i * BLOCK_SIZE + j;
        begin
            active_bit: if BIT_INDEX < N generate
                signal p, g : std_logic;
            begin
                p <= A(BIT_INDEX) xor B(BIT_INDEX);
                g <= A(BIT_INDEX) and B(BIT_INDEX);

                s_int(BIT_INDEX) <= p xor ripple_carry(j);
                ripple_carry(j+1) <= g or (p and ripple_carry(j));
                propagate_chain(j+1) <= propagate_chain(j) and p;
            end generate active_bit;

            -- Pass through unused positions in a short final block.
            padding_bit: if BIT_INDEX >= N generate
                ripple_carry(j+1) <= ripple_carry(j);
                propagate_chain(j+1) <= propagate_chain(j);
            end generate padding_bit;
        end generate gen_bits;

        -- When every active bit propagates, bypass the block's ripple carry.
        block_carry(i+1) <= block_carry(i)
            when propagate_chain(BLOCK_SIZE) = '1'
            else ripple_carry(BLOCK_SIZE);
    end generate gen_blocks;

    S    <= s_int;
    Cout <= block_carry(NUM_BLOCKS);

    -- Signed overflow: equal operand signs and a different result sign.
    Ovfl <= (A(N-1) and B(N-1) and not s_int(N-1)) or
            (not A(N-1) and not B(N-1) and s_int(N-1));

end architecture CarrySkip;
