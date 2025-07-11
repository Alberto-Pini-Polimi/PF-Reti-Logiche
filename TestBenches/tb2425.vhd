-- TB EXAMPLE PFRL 2024-2025
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
 
entity tb2425 is
end tb2425;
 
architecture project_tb_arch of tb2425 is

    -- genero un segnale di clock
    constant CLOCK_PERIOD : time := 20 ns;

    -- creo i segnali per poter comunicare col modulo
    signal tb_clk : std_logic := '0';
    signal tb_rst, tb_start, tb_done : std_logic;
    signal tb_add : std_logic_vector(15 downto 0);
 
    -- e quelli per la memoria
    signal tb_o_mem_addr, exc_o_mem_addr, init_o_mem_addr : std_logic_vector(15 downto 0); -- tutti gli addr sono da 16 bit
    signal tb_o_mem_data, exc_o_mem_data, init_o_mem_data : std_logic_vector(7 downto 0);  -- tutti i data sono da 8 bit
    signal tb_i_mem_data : std_logic_vector(7 downto 0);
    signal tb_o_mem_we, tb_o_mem_en, exc_o_mem_we, exc_o_mem_en, init_o_mem_we, init_o_mem_en : std_logic; -- gli altri sono tutti segnali della memoria


    -- MEMORIA:
    -- dichiaro il tipo di ram_type che è un array di 65536 elementi di 1 byte (vettore di 8 bit)
    type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);
    -- creo il segnale RAM di tipo ram_type i cui 64KB sono tutti inizializzati a 0 
    signal RAM : ram_type := (OTHERS => "00000000");
 
 
    -- SCENARIO:
    -- definisco un tipo che rappresenta i metadati per il nostro modulo
    -- cioè un array di 17 interi 
    type scenario_config_type is array (0 to 16) of integer;
    constant SCENARIO_LENGTH : integer := 24; -- 24 è il numero K
    -- questa seconda costante contiene la rappresentazione unsigned di 16bit del numero 24
    constant SCENARIO_LENGTH_STL : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(SCENARIO_LENGTH, 16));
    -- definisco poi un altro tipo che è un array di 24 interi (serve per input e output del nostro modulo)
    type scenario_type is array (0 to SCENARIO_LENGTH-1) of integer; -- il tipo di array contenente gli input e gli output (per l'UUT)

    -- configuro i metadati del filtro
    signal scenario_config : scenario_config_type := ( -- istanzio l'array contente i metadati per il filtro
        to_integer(unsigned(SCENARIO_LENGTH_STL(15 downto 8))),   -- K1
        to_integer(unsigned(SCENARIO_LENGTH_STL(7 downto 0))),    -- K2
        0,                                                        -- S
        0, -1, 8, 0, -8, 1, 0, 1, -9, 45, 0, -45, 9, -1           -- C1-C14 immagazzino sia il filtro di ordine 3 che quello di ordine 5!!!
    );
    --configuro l'input e l'output atteso
    signal scenario_input : scenario_type := (32, -24, -35,   0, 46, -54, -39, -22, -53, -47,  12, 11,  11, 45, -30, -14, -35, -25, -19, -35, -41, -61, -24, -62);
    signal scenario_output : scenario_type :=(11,  43, -13, -54, 33,  53, -28,   8,  18, -38, -31,  7, -24, 23,  33,  -1,   7, -11,   5,  10,  15, -12,   3, -10);
    -- segnale per determinare chi conrolla la memoria
    signal memory_control : std_logic := '0';      -- quando è 1 la controlla il nostro modulo altrimenti è del tb
 
    -- definisce l'address che passerà al componente come i_add 
    constant SCENARIO_ADDRESS : integer := 1234;    -- This value may arbitrarily change
 
    -- definisce poi il componente che da testare (UUT) 
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

-- inizia il processo
begin
    -- definisco l'istanza della Unit Under Testing cioè il nostro modulo 
    UUT : project_reti_logiche -- componente che è stato definito nell'architettura del tb
    port map( -- mappo i segnali del tb al componente
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
 
    -- inverto il valore di tb_clk ad ogni mezzo periodo
    tb_clk <= not tb_clk after CLOCK_PERIOD/2; -- quindi ogni 10ns
 
    -- descrivo il funzionamento della memoria RAM:
    MEM : process (tb_clk)
    begin 
        if tb_clk'event and tb_clk = '1' then
            if tb_o_mem_en = '1' then -- se la memoria si attiva
                if tb_o_mem_we = '1' then -- e si attiva in modalità scrittura
                    -- scrivo tb_o_mem_data nell'indirizzo tb_o_mem_addr
                    -- dopo 1ns la memoria è all'interno della RAM
                    RAM(to_integer(unsigned(tb_o_mem_addr))) <= tb_o_mem_data after 1 ns;
                    -- dopo un altro ns aggiorno tb_i_mem_data co il valore che ho scritto in memoria
                    tb_i_mem_data <= tb_o_mem_data after 1 ns;
                else 
                    -- altrimenti devo effettuare una lettura che dura anch'essa 1ns
                    tb_i_mem_data <= RAM(to_integer(unsigned(tb_o_mem_addr))) after 1 ns;
                    -- notare che 1 ns è un ordine di grandezza minore del semiperiodo del clock
                    -- quindi potrei aspettarmi il risultato nello stesso clock in cui lo richiedo
                    -- idem per la scrittura (una volta che lancio il risultatato mi aspetto che finisca nello stesso clock)
                end if;
            end if;
        end if;
    end process;
 
 	-- il processo di swap della memoria server a definire chi 
 	-- controlla la memoria in un dato momento: o il tb o la UUT
    memory_signal_swapper : process ( -- GIGA SENSITIVITY LIST
        memory_control,   -- è il segnale che definisce chi usa la memoria
        init_o_mem_addr,  -- tutti gli init_o_mem_qualcosa sono segnali che definiscono  
        init_o_mem_data,  -- 
        init_o_mem_en,    --  
        init_o_mem_we,    -- 
        exc_o_mem_addr,   -- gli exc invece ...
        exc_o_mem_data, 
        exc_o_mem_en, 
        exc_o_mem_we
    )
    begin
        -- we swap the memory
        -- signals from the component to the testbench when needed.
 
        -- aggiorno i segnali tb quando la mem è controllata dal tb
        tb_o_mem_addr <= init_o_mem_addr;
        tb_o_mem_data <= init_o_mem_data;
        tb_o_mem_en   <= init_o_mem_en;
        tb_o_mem_we   <= init_o_mem_we;
 
        if memory_control = '1' then -- quando la memoria è controllata dal nostro modulo ...
            tb_o_mem_addr <= exc_o_mem_addr;
            tb_o_mem_data <= exc_o_mem_data;
            tb_o_mem_en   <= exc_o_mem_en;
            tb_o_mem_we   <= exc_o_mem_we;
        end if;
    end process;
 
   
    create_scenario : process
    begin
        wait for 50 ns;
 
        -- Signal initialization and reset of the component
        tb_start <= '0';
        tb_add <= (others=>'0');
        tb_rst <= '1'; -- mando il reset
 
        -- Wait some time for the component to reset...
        wait for 50 ns;
 
        tb_rst <= '0'; -- tolgo il reset
        memory_control <= '0';  -- Memory controlled by the testbench
 
 		-- aspetta fino alla caduta del clk per evitare di cominciare
 		-- col clock alto
        wait until falling_edge(tb_clk);
 
        -- inizializzo i segnali di init con i primi 17 byte di metadati
        for i in 0 to 16 loop
            init_o_mem_addr <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS+i, 16));
            init_o_mem_data <= std_logic_vector(to_unsigned(scenario_config(i),8));
            init_o_mem_en   <= '1';
            init_o_mem_we   <= '1';
            wait until rising_edge(tb_clk);
        end loop;
 
 		-- inizializzo 
        for i in 0 to SCENARIO_LENGTH-1 loop
            init_o_mem_addr <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS+17+i, 16));
            init_o_mem_data <= std_logic_vector(to_unsigned(scenario_input(i),8));
            init_o_mem_en   <= '1';
            init_o_mem_we   <= '1';
            wait until rising_edge(tb_clk);   
        end loop;
 
        wait until falling_edge(tb_clk);
 
 		-- il nostro modulo riprende il controllo della memoria
        memory_control <= '1';  -- Memory controlled by the component
 
 		-- ci regala tb_add
        tb_add <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS, 16));
 		
 		-- dice al nostro modulo di iniziare
        tb_start <= '1';
 
 		-- finché il nostro modulo non ha finito
        while tb_done /= '1' loop                
            wait until rising_edge(tb_clk); 
        end loop; -- al primo rising edge dopo che il nostro modulo finisce (done = 1)
 
        wait for 5 ns;
 
        tb_start <= '0';
 
        wait;
 
    end process;
 
    -- Process without sensitivity list designed to test the actual component.
    test_routine : process
    begin
 
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
 
        assert false report "Simulation Ended! TEST PASSATO (EXAMPLE)" severity failure;
    end process;
 
end architecture;
