library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity TB_Adder is
end entity TB_Adder;

architecture behaviour of TB_Adder is
    constant N              : positive := 64;
    constant TestVectorFile : string := "Adder00.tvs";
    constant PreStimTime    : time := 1 ns;
    constant PostStimTime   : time := 100 ns;
    constant StableTime     : time := 5 ns;

    signal A, B, S : std_logic_vector(N-1 downto 0);
    signal Cin, Cout, Ovfl : std_logic;
    signal ExpectedS : std_logic_vector(N-1 downto 0);
    signal ExpectedCout, ExpectedOvfl : std_logic;
    signal Status : std_logic_vector(1 downto 0);

    signal MeasurementIndex : natural := 0;
    signal FailureCount : natural := 0;
    signal TestDone : boolean := false;
    signal SumDelay, StatusDelay : time := 0 ns;
    signal WorstSumDelay, WorstStatusDelay : time := 0 ns;

    --Component lets configurations choose the adder architecture
    component Adder is
        generic (N : natural := 64);
        port (
            A, B : in std_logic_vector(N-1 downto 0);
            S : out std_logic_vector(N-1 downto 0);
            Cin : in std_logic;
            Cout, Ovfl : out std_logic
        );
    end component;

begin
    -- Status groups carry-out and signed overflow
    Status <= Cout & Ovfl;

    DUT : Adder
        generic map (N => N)
        port map (
            A => A, B => B, Cin => Cin,
            S => S, Cout => Cout, Ovfl => Ovfl
        );

    STIM : process
        file vectors : text;
        variable open_status : file_open_status;
        variable vector_line : line;
        variable file_line, first_char : natural := 0;
        variable good, passed : boolean;
        variable a_v, b_v, s_v : std_logic_vector(N-1 downto 0);
        variable cin_v, cout_v, ovfl_v : std_logic;
        variable measurement, failures : natural := 0;
        variable start_time : time;
        variable sum_delay_v, status_delay_v : time;
        variable worst_sum_v, worst_status_v : time := 0 ns;
        variable status_text : string(1 to 4);
    begin
        file_open(open_status, vectors, TestVectorFile, read_mode);
        assert open_status = open_ok
            report "Cannot open " & TestVectorFile & "; check the ModelSim working folder."
            severity failure;

        while not endfile(vectors) loop
            readline(vectors, vector_line);
            file_line := file_line + 1;

            -- Ignore blank lines and lines starting with --.
            first_char := 0;
            for i in vector_line.all'range loop
                if vector_line(i) /= ' ' and
                   vector_line(i) /= character'val(9) and
                   vector_line(i) /= character'val(13) then
                    first_char := i;
                    exit;
                end if;
            end loop;
            if first_char = 0 then
                next;
            end if;
            if vector_line(first_char) = '-' then
                if first_char < vector_line.all'high then
                    if vector_line(first_char to first_char + 1) = "--" then
                        next;
                    end if;
                end if;
            end if;

            -- Each line is: A B Cin S Cout Ovfl.
            hread(vector_line, a_v, good);
            assert good report "Invalid A at line " & natural'image(file_line) severity failure;
            hread(vector_line, b_v, good);
            assert good report "Invalid B at line " & natural'image(file_line) severity failure;
            read(vector_line, cin_v, good);
            assert good report "Invalid Cin at line " & natural'image(file_line) severity failure;
            hread(vector_line, s_v, good);
            assert good report "Invalid S at line " & natural'image(file_line) severity failure;
            read(vector_line, cout_v, good);
            assert good report "Invalid Cout at line " & natural'image(file_line) severity failure;
            read(vector_line, ovfl_v, good);
            assert good report "Invalid Ovfl at line " & natural'image(file_line) severity failure;

            -- Give unknown inputs before every measurement
            A <= (others => 'X');
            B <= (others => 'X');
            Cin <= 'X';
            wait for PreStimTime;

            measurement := measurement + 1;
            MeasurementIndex <= measurement;
            ExpectedS <= s_v;
            ExpectedCout <= cout_v;
            ExpectedOvfl <= ovfl_v;

            -- Start the timer at the same instant that we apply real inputs
            start_time := now;
            A <= a_v;
            B <= b_v;
            Cin <= cin_v;
            wait for PostStimTime;

            -- Check that outputs have stopped changing before reading them
            assert S'stable(StableTime) and Status'stable(StableTime)
                report "Outputs may not be stable at measurement " & natural'image(measurement)
                severity warning;

            -- LAST_EVENT is the time since the most recent change
            -- If an output changed during this measurement, find that change time
            -- If it never changed, its observed delay is zero
            sum_delay_v := 0 ns;
            if S'last_event <= now - start_time then
                sum_delay_v := now - S'last_event - start_time;
            end if;
            status_delay_v := 0 ns;
            if Status'last_event <= now - start_time then
                status_delay_v := now - Status'last_event - start_time;
            end if;

            SumDelay <= sum_delay_v;
            StatusDelay <= status_delay_v;
            if sum_delay_v > worst_sum_v then
                worst_sum_v := sum_delay_v;
            end if;
            if status_delay_v > worst_status_v then
                worst_status_v := status_delay_v;
            end if;
            WorstSumDelay <= worst_sum_v;
            WorstStatusDelay <= worst_status_v;

            passed := (S = s_v) and (Cout = cout_v) and (Ovfl = ovfl_v);
            status_text := "PASS";
            if not passed then
                status_text := "FAIL";
                failures := failures + 1;
                FailureCount <= failures;
            end if;

            -- Print one report line per vector
            report "Measurement " & natural'image(measurement) & " " & status_text &
                " A=" & to_hstring(a_v) & " B=" & to_hstring(b_v) &
                " Cin=" & std_logic'image(cin_v) &
                " expected(S,Cout,Ovfl)=" & to_hstring(s_v) & "," &
                std_logic'image(cout_v) & "," & std_logic'image(ovfl_v) &
                " actual(S,Cout,Ovfl)=" & to_hstring(S) & "," &
                std_logic'image(Cout) & "," & std_logic'image(Ovfl) &
                " SumDelay=" & time'image(sum_delay_v) &
                " StatusDelay=" & time'image(status_delay_v)
                severity note;
        end loop;

        file_close(vectors);
        assert measurement > 0 report "No test vectors were found." severity failure;
        report "Completed last test vector. Total=" & natural'image(measurement) &
            " Passed=" & natural'image(measurement - failures) &
            " Failed=" & natural'image(failures) &
            " WorstSumDelay=" & time'image(worst_sum_v) &
            " WorstStatusDelay=" & time'image(worst_status_v)
            severity note;
        TestDone <= true;
        wait for 0 ns;
        assert failures = 0 report "Adder verification failed." severity failure;
        wait;
    end process STIM;
end architecture behaviour;
--Configurations
-- Baseline Ripple Adder
configuration ConfigBaseline of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(Baseline);
        end for;
    end for;
end configuration ConfigBaseline;

-- Conditional Sum Adder
configuration ConfigCondSum of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(CondSum);
        end for;
    end for;
end configuration ConfigCondSum;

-- Carry Skip Adder
configuration ConfigCarrySkip of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(CarrySkip);
        end for;
    end for;
end configuration ConfigCarrySkip;

-- Carry Select Adder
configuration ConfigCarrySelect of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(CarrySelect);
        end for;
    end for;
end configuration ConfigCarrySelect;

-- Carry Lookahead Adder
configuration ConfigCarryLookahead of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(CarryLookahead);
        end for;
    end for;
end configuration ConfigCarryLookahead;

-- Block Carry Lookahead Adder
configuration ConfigBlockCarryLookahead of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(BlockCarryLookahead);
        end for;
    end for;
end configuration ConfigBlockCarryLookahead;

-- Ladner Fischer Adder
configuration ConfigLadFish of TB_Adder is
    for behaviour
        for DUT : Adder
            use entity work.Adder(LadFish);
        end for;
    end for;
end configuration ConfigLadFish;

