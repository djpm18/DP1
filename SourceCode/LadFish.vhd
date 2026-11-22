library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture LadFish of Adder is

	-- Declare generate and propagate signals
	signal p_bit : std_logic_vector(N-1 downto 0);
	signal g_bit : std_logic_vector(N-1 downto 0);

begin

	recur : if N > 1 generate
		signal p_bit_u : std_logic_vector(N-1 downto N/2);
		signal g_bit_u : std_logic_vector(N-1 downto N/2);
		signal p_bit_l : std_logic_vector(N/2-1 downto 0);
		signal g_bit_l : std_logic_vector(N/2-1 downto 0);
	begin
		p_bit_u <= p_bit(N-1 downto N/2);
		g_bit_u <= g_bit(N-1 downto N/2);
		p_bit_l <= p_bit(N/2-1 downto 0);
		g_bit_l <= g_bit(N/2-1 downto 0);

		upper : entity work.Adder(LadFish)
			generic map (
				N => N/2
			)
			port map (
				A    => A(N-1 downto N/2),
				B    => B(N-1 downto N/2),
				Cin  => '0',
				S    => open,
				Cout => open,
				Ovfl => open
			);

		lower : entity work.Adder(LadFish)
			generic map (
				N => N/2
			)
			port map (
				A    => A(N/2-1 downto 0),
				B    => B(N/2-1 downto 0),
				Cin  => Cin,
				S    => open,
				Cout => open,
				Ovfl => open
			);

		ladfish_merge : for i in N/2 to N-1 generate
			-- Carry lookahead / prefix merge:
			-- Gout = G_high + P_high * Glo
			-- Pout = P_high * Plo
			g_bit_u(i) <= g_bit_u(i) or (p_bit_u(i) and g_bit_l(N/2-1));
			p_bit_u(i) <= p_bit_u(i) and p_bit_l(N/2-1);
		end generate ladfish_merge;

	else generate

		S(0) <= (A(0) xor B(0)) xor Cin;
		-- If there is a generate or a propagate and a Cin, then we have a Cout
		Cout <= (A(0) and B(0)) or ((A(0) xor B(0)) and Cin);
		Ovfl <= '0';

	end generate recur;

end architecture LadFish;