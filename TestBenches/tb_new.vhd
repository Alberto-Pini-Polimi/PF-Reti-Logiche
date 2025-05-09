--Testbench created to:
-- -test the component under different input scenarios
-- -test that the result is truncated correctly
-- -test that the component works correctly even after recieving the reset signal mid-elaboration
-- -test both the 3rd order filter and 5th order filter
-- -ensure that the 3rd order filter works correctly even when the first and last coefficients aren't set to zero
-- -ensure that the component can start the conversion again without needing the the reset signal
--This is done by using the example data from ESEMPIO 3 and ESEMPIO 4, which are tested in succession
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
 
entity tb2425 is
end tb2425;
 
architecture project_tb_arch of tb2425 is

    constant CLOCK_PERIOD : time := 20 ns;

    -- Signals to be connected to the component
    signal tb_clk : std_logic := '0';
    signal tb_rst, tb_start, tb_done : std_logic;
    signal tb_add : std_logic_vector(15 downto 0);
 
    -- Signals for the memory
    signal tb_o_mem_addr, exc_o_mem_addr, init_o_mem_addr : std_logic_vector(15 downto 0);
    signal tb_o_mem_data, exc_o_mem_data, init_o_mem_data : std_logic_vector(7 downto 0);
    signal tb_i_mem_data : std_logic_vector(7 downto 0);
    signal tb_o_mem_we, tb_o_mem_en, exc_o_mem_we, exc_o_mem_en, init_o_mem_we, init_o_mem_en : std_logic;

    -- Memory
    type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);
    signal RAM : ram_type := (OTHERS => "00000000");
 
    -- Scenario 1
    type scenario_config_type is array (0 to 16) of integer;
    constant SCENARIO_LENGTH : integer := 32;
    constant SCENARIO_LENGTH_STL : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(SCENARIO_LENGTH, 16));
    type scenario_type is array (0 to SCENARIO_LENGTH-1) of integer;

    signal scenario_config : scenario_config_type := (to_integer(unsigned(SCENARIO_LENGTH_STL(15 downto 8))),   -- K1
                                                      to_integer(unsigned(SCENARIO_LENGTH_STL(7 downto 0))),    -- K2
                                                      128,                                                        -- S
                                                      -1, -1, 8, 0, -8, 1, 1, 1, -9, 45, 0, -45, 9, -1           -- C1-C14
                                                      );
    signal scenario_input : scenario_type := (-13, 127, 108, 64, 61, 109, 107, -82, 58, -1, -62, -16, -110, -101, 45, -70, 28, 100, 5, 73, 53, -67, -66, -45, -38, 66, 106, -112, 60, 39, 113, -110);
    signal scenario_output : scenario_type :=(-73, -73, 47, 28, -28, -42, 124, 22, -66, 85, -2, 22, 64, -106, -7, 27, -114, 26, 18, -44, 86, 68, -21, -6, -57, -100, 124, 27, -98, -33, 92, 70);
 
    signal memory_control : std_logic := '0';      -- A signal to decide when the memory is accessed
                                                   -- by the testbench or by the project
 
    constant SCENARIO_ADDRESS : integer := 227;    -- This value may arbitrarily change
 
 
    --Scenario 2
    constant SCENARIO_LENGTH2 : integer := 47;
    constant SCENARIO_LENGTH_STL2 : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(SCENARIO_LENGTH2, 16));
    type scenario_type2 is array (0 to SCENARIO_LENGTH2-1) of integer;
    signal scenario_config2 : scenario_config_type := (to_integer(unsigned(SCENARIO_LENGTH_STL2(15 downto 8))),   -- K1
                                                      to_integer(unsigned(SCENARIO_LENGTH_STL2(7 downto 0))),    -- K2
                                                      127,                                                        -- S
                                                      -1, -1, 8, 0, -8, 1, 1, 1, -9, 45, 0, -45, 9, -1           -- C1-C14
                                                      );
    signal scenario_input2 : scenario_type2 := (-115, 60, -102, 14, -112, 7, -68, -122, -96, 120, 8, -101, -108, 90, 93, -47, 67, -125, -90, 23, -88, -32, -87, 46, -102, -10, 83, -77, -66, -105, -62, 126, -10, 125, 54, 0, 84, -60, -78, 52, 14, -21, -17, -97, -66, -104, -68);
    signal scenario_output2 : scenario_type2 :=(-59, -5, 34, -1, 12, -53, 96, 35, -128, -73, 127, 78, -126, -128, 127, -12, 31, 127, -128, 14, 38, 2, -59, 10, 66, -128, 57, 95, -2, 28, -128, -6, 15, -68, 110, -48, 25, 127, -93, -60, 63, 0, 46, 25, -2, 14, -69);
    constant SCENARIO_ADDRESS2 : integer := 422;    -- This value may arbitrarily change
  
  
    component project_reti_logiche is
        port (
                i_clk : in std_logic;
                i_rst : in std_logic;
                i_start : in std_logic;
                i_add : in std_logic_vector(15 downto 0);
 
                o_done : out std_logic;
 
                o_mem_addr : out std_logic_vector(15 downto 0);
                i_mem_data : in  std_logic_vector(7 downto 0);
                o_mem_data : out std_logic_vector(7 downto 0);
                o_mem_we   : out std_logic;
                o_mem_en   : out std_logic
        );
    end component project_reti_logiche;
 
begin
    UUT : project_reti_logiche
    port map(
                i_clk   => tb_clk,
                i_rst   => tb_rst,
                i_start => tb_start,
                i_add   => tb_add,
 
                o_done => tb_done,
 
                o_mem_addr => exc_o_mem_addr,
                i_mem_data => tb_i_mem_data,
                o_mem_data => exc_o_mem_data,
                o_mem_we   => exc_o_mem_we,
                o_mem_en   => exc_o_mem_en
    );
 
    -- Clock generation
    tb_clk <= not tb_clk after CLOCK_PERIOD/2;
 
    -- Process related to the memory
    MEM : process (tb_clk)
    begin
        if tb_clk'event and tb_clk = '1' then
            if tb_o_mem_en = '1' then
                if tb_o_mem_we = '1' then
                    RAM(to_integer(unsigned(tb_o_mem_addr))) <= tb_o_mem_data after 1 ns;
                    tb_i_mem_data <= tb_o_mem_data after 1 ns;
                else
                    tb_i_mem_data <= RAM(to_integer(unsigned(tb_o_mem_addr))) after 1 ns;
                end if;
            end if;
        end if;
    end process;
 
    memory_signal_swapper : process(memory_control, init_o_mem_addr, init_o_mem_data,
                                    init_o_mem_en,  init_o_mem_we,   exc_o_mem_addr,
                                    exc_o_mem_data, exc_o_mem_en, exc_o_mem_we)
    begin
        -- This is necessary for the testbench to work: we swap the memory
        -- signals from the component to the testbench when needed.
 
        tb_o_mem_addr <= init_o_mem_addr;
        tb_o_mem_data <= init_o_mem_data;
        tb_o_mem_en   <= init_o_mem_en;
        tb_o_mem_we   <= init_o_mem_we;
 
        if memory_control = '1' then
            tb_o_mem_addr <= exc_o_mem_addr;
            tb_o_mem_data <= exc_o_mem_data;
            tb_o_mem_en   <= exc_o_mem_en;
            tb_o_mem_we   <= exc_o_mem_we;
        end if;
    end process;
 
    -- This process provides the correct scenario on the signal controlled by the TB
    create_scenario : process
    begin
        wait for 50 ns;
 
        -- Signal initialization and reset of the component
        tb_start <= '0';
        tb_add <= (others=>'0');
        tb_rst <= '1';
 
        -- Wait some time for the component to reset...
        wait for 50 ns;
 
        tb_rst <= '0';
        --Start the first run
        memory_control <= '0';  -- Memory controlled by the testbench
 
        wait until falling_edge(tb_clk); -- Skew the testbench transitions with respect to the clock
 
 
        for i in 0 to 16 loop
            init_o_mem_addr<= std_logic_vector(to_unsigned(SCENARIO_ADDRESS+i, 16));
            init_o_mem_data<= std_logic_vector(to_unsigned(scenario_config(i),8));
            init_o_mem_en  <= '1';
            init_o_mem_we  <= '1';
            wait until rising_edge(tb_clk);   
        end loop;
 
        for i in 0 to SCENARIO_LENGTH-1 loop
            init_o_mem_addr<= std_logic_vector(to_unsigned(SCENARIO_ADDRESS+17+i, 16));
            init_o_mem_data<= std_logic_vector(to_unsigned(scenario_input(i),8));
            init_o_mem_en  <= '1';
            init_o_mem_we  <= '1';
            wait until rising_edge(tb_clk);   
        end loop;
 
        wait until falling_edge(tb_clk);
 
        memory_control <= '1';  -- Memory controlled by the component
 
        tb_add <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS, 16));
 
        tb_start <= '1';
 
        --Wait for some time, then reset the component mid elaboration
        for i in 0 to 15 loop
          wait until rising_edge(tb_clk);   
        end loop;
        tb_rst <= '1';
        -- Wait some time for the component to reset...
        wait for 50 ns;
        tb_rst <= '0';
        
        --Continue with the elaboration
        while tb_done /= '1' loop                
            wait until rising_edge(tb_clk);
        end loop;
 
        wait for 5 ns;
 
        tb_start <= '0';
        
        
        --Start the second run
        memory_control <= '0';  -- Memory controlled by the testbench

        wait until falling_edge(tb_clk); -- Skew the testbench transitions with respect to the clock


        for i in 0 to 16 loop
            init_o_mem_addr<= std_logic_vector(to_unsigned(SCENARIO_ADDRESS2+i, 16));
            init_o_mem_data<= std_logic_vector(to_unsigned(scenario_config2(i),8));
            init_o_mem_en  <= '1';
            init_o_mem_we  <= '1';
            wait until rising_edge(tb_clk);   
        end loop;

        for i in 0 to SCENARIO_LENGTH2-1 loop
            init_o_mem_addr<= std_logic_vector(to_unsigned(SCENARIO_ADDRESS2+17+i, 16));
            init_o_mem_data<= std_logic_vector(to_unsigned(scenario_input2(i),8));
            init_o_mem_en  <= '1';
            init_o_mem_we  <= '1';
            wait until rising_edge(tb_clk);   
        end loop;

        wait until falling_edge(tb_clk);

        memory_control <= '1';  -- Memory controlled by the component

        tb_add <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS2, 16));

        tb_start <= '1';

        while tb_done /= '1' loop                
            wait until rising_edge(tb_clk);
        end loop;

        wait for 5 ns;

        tb_start <= '0';

        wait;

    end process;
 
    -- Process without sensitivity list designed to test the actual component.
    test_routine : process
    begin
    
        --Test the first scenario
        wait until tb_rst = '1';
        wait for 25 ns;
        assert tb_done = '0' report "TEST FALLITO o_done !=0 during reset" severity failure;
        wait until tb_rst = '0';
 
        wait until falling_edge(tb_clk);
        assert tb_done = '0' report "TEST FALLITO o_done !=0 after reset before start" severity failure;
 
        wait until rising_edge(tb_start);
 
        while tb_done /= '1' loop                
            wait until rising_edge(tb_clk);
        end loop;
 
        assert tb_o_mem_en = '0' or tb_o_mem_we = '0' report "TEST FALLITO o_mem_en !=0 memory should not be written after done." severity failure;
 
        for i in 0 to SCENARIO_LENGTH-1 loop
            assert RAM(SCENARIO_ADDRESS+17+SCENARIO_LENGTH+i) = std_logic_vector(to_unsigned(scenario_output(i),8)) report "TEST FALLITO @ OFFSET=" & integer'image(17+SCENARIO_LENGTH+i) & " expected= " & integer'image(scenario_output(i)) & " actual=" & integer'image(to_integer(unsigned(RAM(SCENARIO_ADDRESS+17+SCENARIO_LENGTH+i)))) severity failure;
        end loop;
 
        wait until falling_edge(tb_start);
        assert tb_done = '1' report "TEST FALLITO o_done == 0 before start goes to zero" severity failure;
        wait until falling_edge(tb_done);
        
        
        --Test the second scenario
        while tb_done /= '1' loop                
            wait until rising_edge(tb_clk);
        end loop;
 
        assert tb_o_mem_en = '0' or tb_o_mem_we = '0' report "TEST FALLITO o_mem_en !=0 memory should not be written after done." severity failure;
 
        for i in 0 to SCENARIO_LENGTH2-1 loop
            assert RAM(SCENARIO_ADDRESS2+17+SCENARIO_LENGTH2+i) = std_logic_vector(to_unsigned(scenario_output2(i),8)) report "TEST FALLITO @ OFFSET=" & integer'image(17+SCENARIO_LENGTH2+i) & " expected= " & integer'image(scenario_output2(i)) & " actual=" & integer'image(to_integer(unsigned(RAM(SCENARIO_ADDRESS2+17+SCENARIO_LENGTH2+i)))) severity failure;
        end loop;
 
        wait until falling_edge(tb_start);
        assert tb_done = '1' report "TEST FALLITO o_done == 0 before start goes to zero" severity failure;
        wait until falling_edge(tb_done);        
 
        assert false report "Simulation Ended! TEST PASSATO (EXAMPLE)" severity failure;
    end process;
 
end architecture;

