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

architecture FastRipple of Adder is

signal A_ext, B_ext, sum_ext : unsigned(N downto 0);

begin

-- Padding inputs A and B with '0' to account for overflow/Cout
	A_ext <= '0' & unsigned(A);
	B_ext <= '0' & unsigned(B); 	
	sum_ext <= A_ext + B_ext + ('0' & Cin); -- Sum now adding 65-bit unsigned numbers
	
	S <= std_logic_vector(sum_ext(N-1 downto 0));
	Cout <= std_logic(sum_ext(N)); -- Top bit is the Cout bit
	
	Ovfl <= (A(N-1) AND B(N-1) AND (NOT sum_ext(N-1))) OR ((NOT A(N-1)) AND (NOT B(N-1)) AND sum_ext(N-1));

end architecture FastRipple;