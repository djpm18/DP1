-- Hierarchical block carry-lookahead architecture for the shared Adder entity.
-- Compile after RippleAdder.vhd (Adder) and CarryLookahead.vhd (LCU).

library ieee;
use ieee.std_logic_1164.all;

architecture BlockCarryLookahead of Adder is
    constant BLOCK_SIZE : positive := 4;

    function group_count(width : positive; level : natural) return positive is
        variable count : positive := width;
    begin
        for i in 1 to level loop
            count := 1 + (count - 1) / BLOCK_SIZE;
        end loop;
        return count;
    end function group_count;

    function top_level(width : positive) return positive is
        variable level : positive := 1;
    begin
        while group_count(width, level) > 1 loop
            level := level + 1;
        end loop;
        return level;
    end function top_level;

    constant LEVEL_COUNT : positive := top_level(N);

    -- Level 0 represents individual bits. Higher levels summarize blocks of
    -- 4, 16, 64, ... bits. Only the groups present at each level are used.
    type level_signals is array (0 to LEVEL_COUNT) of std_logic_vector(N-1 downto 0);
    signal group_g, group_p, carry_in : level_signals;
    signal carry_out : std_logic;
begin
    gen_bits : for i in 0 to N-1 generate
        group_g(0)(i) <= A(i) and B(i);
        group_p(0)(i) <= A(i) xor B(i);
        S(i) <= group_p(0)(i) xor carry_in(0)(i);
    end generate gen_bits;

    carry_in(LEVEL_COUNT)(0) <= Cin;

    gen_levels : for level in 1 to LEVEL_COUNT generate
        constant CHILD_COUNT : positive := group_count(N, level - 1);
    begin
        gen_groups : for block_index in 0 to group_count(N, level) - 1 generate
            constant FIRST_CHILD : natural := BLOCK_SIZE * block_index;
            signal child_g, child_p : std_logic_vector(BLOCK_SIZE-1 downto 0);
            signal child_carry : std_logic_vector(BLOCK_SIZE-1 downto 1);
        begin
            gen_children : for slot in 0 to BLOCK_SIZE-1 generate
                constant CHILD_INDEX : natural := FIRST_CHILD + slot;
            begin
                gen_active : if CHILD_INDEX < CHILD_COUNT generate
                    child_g(slot) <= group_g(level - 1)(CHILD_INDEX);
                    child_p(slot) <= group_p(level - 1)(CHILD_INDEX);
                end generate gen_active;

                -- Unused positions pass the carry through in a short block.
                gen_padding : if CHILD_INDEX >= CHILD_COUNT generate
                    child_g(slot) <= '0';
                    child_p(slot) <= '1';
                end generate gen_padding;
            end generate gen_children;

            -- Group G/P travel up the tree independently of Cin. Each unit
            -- computes its children's carries in parallel from its own Cin.
            lookahead : entity work.LCU(structural)
                port map (
                    G      => child_g,
                    P      => child_p,
                    Cin    => carry_in(level)(block_index),
                    C      => child_carry,
                    Cout   => open,
                    PGroup => group_p(level)(block_index),
                    GGroup => group_g(level)(block_index)
                );

            carry_in(level - 1)(FIRST_CHILD) <= carry_in(level)(block_index);
            gen_carries : for slot in 1 to BLOCK_SIZE-1 generate
                gen_active : if FIRST_CHILD + slot < CHILD_COUNT generate
                    carry_in(level - 1)(FIRST_CHILD + slot) <= child_carry(slot);
                end generate gen_active;
            end generate gen_carries;
        end generate gen_groups;
    end generate gen_levels;

    carry_out <= group_g(LEVEL_COUNT)(0) or (group_p(LEVEL_COUNT)(0) and Cin);
    Cout <= carry_out;
    -- Signed overflow occurs when the carries into and out of the MSB differ.
    Ovfl <= carry_in(0)(N-1) xor carry_out;
end architecture BlockCarryLookahead;
