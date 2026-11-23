
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity Adder is
    Generic ( N : natural := 64 );
    Port (
        A, B : in std_logic_vector(N-1 downto 0);
        S : out std_logic_vector(N-1 downto 0);
        Cin : in std_logic;
        Cout, Ovfl : out std_logic
    );
End Entity Adder;


architecture LadFish of Adder is

    -- Declare generate and propagate signals
    signal p_bit : std_logic_vector(N-1 downto 0);
    signal g_bit : std_logic_vector(N-1 downto 0);

    -- Find how many levels are needed
    function log2ceil(n : positive) return natural is
        variable levels : natural := 0;
        variable size : natural := 1;
    begin
        while size < n loop
            size := size * 2;
            levels := levels + 1;
        end loop;
        return levels;
    end function;

begin

    -- Calculate generate and propagate signals
    p_bit <= A xor B;
    g_bit <= A and B;

    recur : if N > 1 generate

        constant LEVELS : natural := log2ceil(N);

        -- Store signals from each prefix level
        type prefix_array is array (natural range <>)
            of std_logic_vector(N-1 downto 0);

        signal p_tree : prefix_array(0 to LEVELS);
        signal g_tree : prefix_array(0 to LEVELS);

        signal carry : std_logic_vector(N downto 0);

    begin

        p_tree(0) <= p_bit;
        g_tree(0) <= g_bit;

        -- Combine generate and propagate signals
        ladfish_merge : for k in 0 to LEVELS-1 generate

            constant HALF_SIZE : natural := 2**k;
            constant GROUP_SIZE : natural := 2**(k+1);

        begin

            merge_bits : for i in 0 to N-1 generate

                -- Combine upper and lower groups
                upper_half : if (i mod GROUP_SIZE) >= HALF_SIZE generate

                    constant PARTNER : natural :=
                        (i / GROUP_SIZE) * GROUP_SIZE
                        + HALF_SIZE - 1;

                begin

                    -- Gout = G_high + P_high * Glo
                    -- Pout = P_high * Plo
                    g_tree(k+1)(i) <= g_tree(k)(i) or
                        (p_tree(k)(i) and g_tree(k)(PARTNER));

                    p_tree(k+1)(i) <= p_tree(k)(i) and
                        p_tree(k)(PARTNER);

                end generate upper_half;

                -- Keep signals that do not need merging
                lower_half : if (i mod GROUP_SIZE) < HALF_SIZE generate
                begin
                    g_tree(k+1)(i) <= g_tree(k)(i);
                    p_tree(k+1)(i) <= p_tree(k)(i);
                end generate lower_half;

            end generate merge_bits;

        end generate ladfish_merge;

        -- Calculate carries and sum
        carry(0) <= Cin;

        sum_bits : for i in 0 to N-1 generate
        begin
            carry(i+1) <= g_tree(LEVELS)(i) or
                (p_tree(LEVELS)(i) and Cin);

            S(i) <= p_bit(i) xor carry(i);
        end generate sum_bits;

        Cout <= carry(N);
        Ovfl <= carry(N-1) xor carry(N);

    else generate

        S(0) <= (A(0) xor B(0)) xor Cin;

        -- Calculate carry-out for the 1-bit case
        Cout <= (A(0) and B(0)) or
                ((A(0) xor B(0)) and Cin);

        -- Signed overflow for the 1-bit case
        Ovfl <= Cin xor
                ((A(0) and B(0)) or
                ((A(0) xor B(0)) and Cin));

    end generate recur;

end architecture LadFish;
