-- Design candidate: Carry-Select Adder

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture CarrySelect of Adder is

    -- Four 16-bit blocks for a 64-bit adder
    constant BLOCK_SIZE : natural := 16;
    constant NUM_BLOCKS : natural := N / BLOCK_SIZE;

    -- Internal signals for computed sums and carries for both Cin=0 and Cin=1 paths
    signal s_path0, s_path1       : std_logic_vector(N-1 downto 0);
    signal cout_path0, cout_path1 : std_logic_vector(NUM_BLOCKS-1 downto 0);
    
    -- Actual carry chain vector passing between blocks
    signal block_carry            : std_logic_vector(NUM_BLOCKS downto 0);
    
    -- Internal signal for final sum and overflow evaluation
    signal s_int                  : std_logic_vector(N-1 downto 0);

begin

    -- Connect initial external carry-in (C0)
    block_carry(0) <= Cin;

    -- Generate blocks
    gen_csla_blocks: for i in 0 to NUM_BLOCKS - 1 generate
        
        -- Index ranges for the current block
        constant LOW_IDX  : natural := i * BLOCK_SIZE;
        constant HIGH_IDX : natural := (i + 1) * BLOCK_SIZE - 1;

        signal a_block, b_block : std_logic_vector(BLOCK_SIZE-1 downto 0);
        signal sum0_block, sum1_block : std_logic_vector(BLOCK_SIZE-1 downto 0);
        signal c0_block, c1_block     : std_logic;

    begin
        a_block <= A(HIGH_IDX downto LOW_IDX);
        b_block <= B(HIGH_IDX downto LOW_IDX);

        -- Block assuming Cin = '0'
        process(a_block, b_block)
            variable sum_v : unsigned(BLOCK_SIZE downto 0);
        begin
            sum_v := ('0' & unsigned(a_block)) + ('0' & unsigned(b_block));
            sum0_block <= std_logic_vector(sum_v(BLOCK_SIZE-1 downto 0));
            c0_block   <= std_logic(sum_v(BLOCK_SIZE));
        end process;

		  -- Block assuming Cin = '1'
        process(a_block, b_block)
            variable sum_v : unsigned(BLOCK_SIZE downto 0);
        begin
            sum_v := ('0' & unsigned(a_block)) + ('0' & unsigned(b_block)) + 1;
            sum1_block <= std_logic_vector(sum_v(BLOCK_SIZE-1 downto 0));
            c1_block   <= std_logic(sum_v(BLOCK_SIZE));
        end process;

        -- Store block results into global vectors
        s_path0(HIGH_IDX downto LOW_IDX)    <= sum0_block;
        s_path1(HIGH_IDX downto LOW_IDX)    <= sum1_block;
        cout_path0(i)                       <= c0_block;
        cout_path1(i)                       <= c1_block;

		  -- MUX to select correct Cout for next block based on current Cin
        block_carry(i+1) <= c0_block when block_carry(i) = '0' else c1_block;

		  -- MUX to select correct sum bits
        process(block_carry(i), sum0_block, sum1_block)
        begin
            if block_carry(i) = '0' then
                s_int(HIGH_IDX downto LOW_IDX) <= sum0_block;
            else
                s_int(HIGH_IDX downto LOW_IDX) <= sum1_block;
            end if;
        end process;

    end generate gen_csla_blocks;

    -- Final Outputs
    S    <= s_int;
    Cout <= block_carry(NUM_BLOCKS);

    -- Signed Overflow detection
    Ovfl <= (A(N-1) and B(N-1) and not s_int(N-1)) or (not A(N-1) and not B(N-1) and s_int(N-1));

end architecture CarrySelect;