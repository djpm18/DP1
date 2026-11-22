library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity Adder is
    Generic ( N : natural := 64 );
    Port ( A, B : in std_logic_vector(N-1 downto 0);
           S : out std_logic_vector(N-1 downto 0);
           Cin : in std_logic;
           Cout, Ovfl : out std_logic );
End Entity Adder;

architecture BrentKung of Adder is

    signal g0, p0 : std_logic_vector(N-1 downto 0);
    signal Cout_Int : std_logic;

    -- Number of levels in Brent-Kung tree
    function log2(N : natural) return natural is
        variable temp : natural := N;
        variable result : natural := 0;
    begin
        while temp > 1 loop
            temp := temp / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

    constant treeLevels : natural := log2(N);

begin

    -- First stage - pre-processing - bit-level PG logic
    GEN_PreProcess : for i in 0 to N-1 generate
        g0(i) <= A(i) AND B(i);
        p0(i) <= A(i) XOR B(i);
    end generate GEN_PreProcess;


    -- Second stage - upper carry generation stage
    process(g0, p0, Cin)

        variable gGroup : std_logic_vector(N-1 downto 0);
        variable pGroup : std_logic_vector(N-1 downto 0);
        variable groupDistance : natural;

        variable carry_msb : std_logic;
        variable carry_out : std_logic;

        variable sum_result : std_logic_vector(N-1 downto 0);

    begin

        -- Initialize the prefix signals
        for i in 0 to N-1 loop
            gGroup(i) := g0(i);
            pGroup(i) := p0(i);
        end loop;


        -- Upper sweep - Generating the group Generate/Propagate signals (Black Cell)
        for treeLevel in 0 to treeLevels-1 loop

            groupDistance := 2**treeLevel;

            for i in 0 to N-1 loop

                if ((i+1) mod (2*groupDistance)) = 0 then

                    -- Black cell: Group Generate
                    gGroup(i) :=
                        gGroup(i) OR
                        (pGroup(i) AND gGroup(i-groupDistance));

                    -- Black cell: Group Propagate
                    pGroup(i) :=
                        pGroup(i) AND pGroup(i-groupDistance);

                end if;

            end loop;

        end loop;


        -- Downwards sweep - Prefix Carry Calculations (Grey Cell)
        for treeLevel in treeLevels-2 downto 0 loop

            groupDistance := 2**treeLevel;

            for i in 0 to N-1 loop

                if (((i+1) mod (2*groupDistance)) = groupDistance)
                    AND ((i+1) > (2*groupDistance)) then

                    -- Grey cell: Group Generate
                    gGroup(i) :=
                        gGroup(i) OR
                        (pGroup(i) AND gGroup(i-groupDistance));

                end if;

            end loop;

        end loop;


        -- Final stage - sum/carry calculation (S, Cout, Ovfl)

        -- Carry into the first bit
        sum_result(0) := p0(0) XOR Cin;

        -- Calculate remaining sum bits
        for i in 1 to N-1 loop

            sum_result(i) :=
                p0(i) XOR
                (gGroup(i-1) OR (pGroup(i-1) AND Cin));

        end loop;


        -- Carry out and Overflow

        -- Carry entering the most significant bit
        carry_msb :=
            gGroup(N-2) OR
            (pGroup(N-2) AND Cin);

        -- Final carry out
        carry_out :=
            gGroup(N-1) OR
            (pGroup(N-1) AND Cin);

        Cout_Int <= carry_out;

        -- Signed overflow detection
        Ovfl <= carry_msb XOR carry_out;

        -- Assign final outputs
        S <= sum_result;

    end process;


    -- Output Connection
    Cout <= Cout_Int;

end architecture BrentKung;
