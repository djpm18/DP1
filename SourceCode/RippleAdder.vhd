-- N-bit Ripple Adder

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

architecture Baseline of Adder is

	component FullAdder is
		port (
			A, B, Cin : in std_logic;
			S, Cout   : out std_logic
		);
	end component;

	signal c : std_logic_vector(N downto 0); -- Internal carry chain array

begin	

	c(0) <= Cin; -- Initial carry-in connected to start of the chain

	-- Loop to instatiate each adder
	GEN_ADDERS: for i in 0 to N-1 generate
		 FA_i : FullAdder
			 port map (
					A    => A(i),
					B    => B(i),
					Cin  => c(i),
					S    => S(i),
					Cout => c(i+1)
			 );
	end generate GEN_ADDERS;

	Cout <= c(N);
	Ovfl <= c(N) xor c(N-1);

end architecture Baseline;
