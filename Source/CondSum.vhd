
library ieee;
use ieee.std_logic_1164.all;

-- Recursive N-bit Conditional-Sum Adder
architecture CondSum of Adder is

    constant M : natural := N/2;

    signal Sum_internal : std_logic_vector(N-1 downto 0);
    signal Sum0, Sum1 : std_logic_vector(M-1 downto 0);
    signal Cout0, Cout1 : std_logic;
    signal CarrySel : std_logic;
    signal CarryOut : std_logic;

begin


    -- Base case: 2-bit adder
    base_case: if N = 2 generate

        Sum_internal(0) <= A(0) xor B(0) xor Cin;

        Cout0 <= (A(0) and B(0)) or
                 (Cin and (A(0) xor B(0)));

        Sum_internal(1) <= A(1) xor B(1) xor Cout0;

        CarryOut <= (A(1) and B(1)) or
                    (Cout0 and (A(1) xor B(1)));

    end generate;

    -- Recursive case
    recursive_case: if N > 2 generate

        -- Lower half
        LowerAdder: entity work.Adder(CondSum)
            generic map (N => M)
            port map (
                A => A(M-1 downto 0),
                B => B(M-1 downto 0),
                Cin => Cin,
                S => Sum_internal(M-1 downto 0),
                Cout => CarrySel,
                Ovfl => open
            );

        -- Upper half assuming carry = 0
        UpperAdder_0: entity work.Adder(CondSum)
            generic map (N => M)
            port map (
                A => A(N-1 downto M),
                B => B(N-1 downto M),
                Cin => '0',
                S => Sum0,
                Cout => Cout0,
                Ovfl => open
            );

        -- Upper half assuming carry = 1
        UpperAdder_1: entity work.Adder(CondSum)
            generic map (N => M)
            port map (
                A => A(N-1 downto M),
                B => B(N-1 downto M),
                Cin => '1',
                S => Sum1,
                Cout => Cout1,
                Ovfl => open
            );

        -- Select correct upper-half result
        Sum_internal(N-1 downto M) <=
            Sum0 when CarrySel = '0' else Sum1;

        CarryOut <= Cout0 when CarrySel = '0' else Cout1;

    end generate;

    -- Final outputs
    S <= Sum_internal;
    Cout <= CarryOut;

    -- Signed overflow
    Ovfl <= (A(N-1) and B(N-1) and not Sum_internal(N-1)) or
            (not A(N-1) and not B(N-1) and Sum_internal(N-1));

end architecture CondSum;
