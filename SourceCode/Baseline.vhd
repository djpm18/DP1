-- 1-bit full adder

library ieee;
use ieee.std_logic_1164.all;

-- One bit full adder
	entity FullAdder is
		port (
			A, B, Cin : in std_logic;
			S, Cout : out std_logic
			);
	end entity;

architecture structural of FullAdder is

	signal g, p : std_logic; -- Generate/Propagate signals
	
begin
	-- Generate and Propagate logic
	g <= A AND B;
	p <= A XOR B;
	
	-- Constructing the baseline outputs
	S <= p XOR Cin;
	Cout <= g OR (p AND Cin);
	
end architecture structural;	
