-- Design Candidate - Multi-level look ahead (Carry-lookahead) Adder Architecture

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Carry look ahead unit (LCU)
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

-- Architecture to generate 4-bit LCU at bitwise level
architecture structural of LCU is
begin
    C(1) <= G(0) or (P(0) and Cin);
    C(2) <= G(1) or (P(1) and G(0)) or (P(1) and P(0) and Cin);
    C(3) <= G(2) or (P(2) and G(1)) or (P(2) and P(1) and G(0)) or (P(2) and P(1) and P(0) and Cin);
    Cout <= G(3) or (P(3) and G(2)) or (P(3) and P(2) and G(1)) or (P(3) and P(2) and P(1) and G(0)) or (P(3) and P(2) and P(1) and P(0) and Cin);

    PGroup <= P(3) and P(2) and P(1) and P(0);
    GGroup <= G(3) or (P(3) and G(2)) or (P(3) and P(2) and G(1)) or (P(3) and P(2) and P(1) and G(0));
end architecture structural;

-- Carry-lookahead architecture to instatiate the 3 levels needed
architecture CarryLookahead of Adder is

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

    signal g_int, p_int : std_logic_vector(3 downto 0);
    signal c_int        : std_logic_vector(3 downto 1);
    signal carry_chain  : std_logic_vector(4 downto 0);
    signal cout_int     : std_logic;
    
    -- Internal signal for overflow with the sum vector
    signal s_int        : std_logic_vector(N-1 downto 0);
    
    signal unused_pg_sig, unused_gg_sig : std_logic;

begin

    assert N = 4 report "CarryLookahead architecture configured for N=4 blocks." severity note;

	 -- Generating the group signals to go down into the 4 4-bit LCUs
    carry_chain(0)          <= Cin;
    carry_chain(3 downto 1) <= c_int;
    carry_chain(4)          <= cout_int;
    Cout                    <= cout_int;

    gen_gp: for i in 3 downto 0 generate
        g_int(i) <= A(i) and B(i);
        p_int(i) <= A(i) xor B(i);
    end generate gen_gp;

	 -- Instatiating the 4 4-bit LCUs to group the pairs of G/P signals
    CLU_INST : LCU
        port map (
            G      => g_int,
            P      => p_int,
            Cin    => Cin,
            C      => c_int,
            Cout   => cout_int,
            PGroup => unused_pg_sig,
            GGroup => unused_gg_sig
        );

    gen_sum: for i in 3 downto 0 generate
        s_int(i) <= p_int(i) xor carry_chain(i);
    end generate gen_sum;

    gen_zero_upper: if N > 4 generate
        zero_s: for i in N-1 downto 4 generate
            s_int(i) <= '0';
        end generate;
    end generate;

    -- Drive output port S from internal signal
    S <= s_int;

    -- Evaluate overflow using internal s_int instead of the output port S
    Ovfl <= (A(N-1) and B(N-1) and not s_int(N-1)) or (not A(N-1) and not B(N-1) and s_int(N-1));

end architecture CarryLookahead;