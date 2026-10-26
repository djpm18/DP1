library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity TBAdderCondSum is
end entity TBAdderCondSum;

architecture test of TBAdderCondSum is

    constant N              : positive := 64;
    constant TestVectorFile : string := "Adder00.tvs";
    constant PreStimTime    : time := 1 ns;
    -- Functional RTL settling allowance; this is not a measured FPGA delay.
    constant PostStimTime   : time := 10 ns;

    signal A, B, S                 : std_logic_vector(N-1 downto 0);
    signal Cin, Cout, Ovfl         : std_logic;
    signal ExpectedS              : std_logic_vector(N-1 downto 0);
    signal ExpectedCout, ExpectedOvfl : std_logic;
    signal MeasurementIndex       : natural := 0;
    signal FailureCount           : natural := 0;
    signal TestDone               : boolean := false;

begin

    DUT: entity work.Adder(CondSum)
        generic map (N => N)
        port map (
            A => A, B => B, Cin => Cin,
            S => S, Cout => Cout, Ovfl => Ovfl
        );

    STIM: process
        file vectors : text;
        variable open_status : file_open_status;
        variable vector_line : line;
        variable file_line, first_char : natural := 0;
        variable good, passed : boolean;
        variable a_v, b_v, s_v : std_logic_vector(N-1 downto 0);
        variable cin_v, cout_v, ovfl_v : std_logic;
        variable measurement, failures : natural := 0;
        variable status_text : string(1 to 4);
    begin
        file_open(open_status, vectors, TestVectorFile, read_mode);
        assert open_status = open_ok
            report "Cannot open " & TestVectorFile & "; run from Simulation."
            severity failure;

        while not endfile(vectors) loop
            readline(vectors, vector_line);
            file_line := file_line + 1;

            -- Ignore empty lines, whitespace, and full-line VHDL comments.
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

            -- The file fields are A B Cin S Cout Ovfl; vectors use hex for buses.
            hread(vector_line, a_v, good);
            assert good report "Invalid A at file line " & natural'image(file_line)
                severity failure;
            hread(vector_line, b_v, good);
            assert good report "Invalid B at file line " & natural'image(file_line)
                severity failure;
            read(vector_line, cin_v, good);
            assert good report "Invalid Cin at file line " & natural'image(file_line)
                severity failure;
            hread(vector_line, s_v, good);
            assert good report "Invalid S at file line " & natural'image(file_line)
                severity failure;
            read(vector_line, cout_v, good);
            assert good report "Invalid Cout at file line " & natural'image(file_line)
                severity failure;
            read(vector_line, ovfl_v, good);
            assert good report "Invalid Ovfl at file line " & natural'image(file_line)
                severity failure;

            assert not is_x(a_v) and not is_x(b_v) and not is_x(s_v) and
                   (cin_v = '0' or cin_v = '1') and
                   (cout_v = '0' or cout_v = '1') and
                   (ovfl_v = '0' or ovfl_v = '1')
                report "Non-binary vector at file line " & natural'image(file_line)
                severity failure;

            measurement := measurement + 1;
            MeasurementIndex <= measurement;

            -- Remove the preceding vector's known state before each measurement.
            A <= (others => 'X');
            B <= (others => 'X');
            Cin <= 'X';
            wait for PreStimTime;

            A <= a_v;
            B <= b_v;
            Cin <= cin_v;
            ExpectedS <= s_v;
            ExpectedCout <= cout_v;
            ExpectedOvfl <= ovfl_v;
            wait for PostStimTime;

            passed := S = s_v and Cout = cout_v and Ovfl = ovfl_v;
            status_text := "PASS";
            if not passed then
                status_text := "FAIL";
                failures := failures + 1;
                FailureCount <= failures;
            end if;

            -- One transcript line contains the index, inputs and all comparisons.
            report "Measurement " & natural'image(measurement) & " " & status_text &
                " A=" & to_hstring(a_v) & " B=" & to_hstring(b_v) &
                " Cin=" & std_logic'image(cin_v) &
                " expected(S,Cout,Ovfl)=" & to_hstring(s_v) & "," &
                    std_logic'image(cout_v) & "," & std_logic'image(ovfl_v) &
                " actual(S,Cout,Ovfl)=" & to_hstring(S) & "," &
                    std_logic'image(Cout) & "," & std_logic'image(Ovfl)
                severity note;
        end loop;

        file_close(vectors);
        assert measurement > 0 report "No test vectors were found." severity failure;
        report "Completed last test vector. Measurements=" &
            natural'image(measurement) & " Passed=" &
            natural'image(measurement - failures) & " Failed=" &
            natural'image(failures)
            severity note;

        TestDone <= true;
        wait for 0 ns; -- Commit the final counters before reporting overall failure.
        assert failures = 0 report "Adder verification failed." severity failure;
        wait; -- No clock: run -all returns when the circuit becomes quiescent.
    end process STIM;

end architecture test;
