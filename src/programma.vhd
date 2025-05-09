library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;  -- Clock di sistema
        i_rst      : in  std_logic;  -- Reset asincrono
        i_start    : in  std_logic;  -- Segnale di avvio
        i_add      : in  std_logic_vector(15 downto 0); -- Indirizzo di partenza in memoria

        o_done     : out std_logic;  -- Segnale di completamento

        o_mem_addr : out std_logic_vector(15 downto 0); -- Indirizzo di memoria
        i_mem_data : in  std_logic_vector(7 downto 0);  -- Dato letto dalla memoria
        o_mem_data : out std_logic_vector(7 downto 0);  -- Dato da scrivere in memoria
        o_mem_we   : out std_logic;  -- Segnale di scrittura memoria
        o_mem_en   : out std_logic   -- Segnale di abilitazione memoria
    );
end entity project_reti_logiche;

architecture behavioral of project_reti_logiche is

    -- Definizione degli stati della FSM
    type state_type is (START, IDLE, 
        K1_STATE, K2_STATE, K_STATE, S_STATE, READ_COEFF, 
        FILTER_INIT, FILTER_INIT_2, FILTER_INIT_3, FILTER_INIT_4, 
        COMPUTE_ORDER_3, SHIFT_ORDER_3, READ_NEXT_2,
        COMPUTE_ORDER_5, SHIFT_ORDER_5, READ_NEXT_3, DONE, WAITING
    );
    signal current_state : state_type := START;
    signal state : state_type := WAITING;

    
    -- Segnali interni
    signal mem_w1_addr    : std_logic_vector(15 downto 0) := (others => '0'); -- Indirizzo del primo byte della sequenza da filtrare
    signal mem_init_addr  : std_logic_vector(15 downto 0) := (others => '0'); -- Indirizzo del primo byte dell'input

    signal k1, k2         : std_logic_vector(7 downto 0) := (others => '0');  -- Lunghezza sequenza e ordine filtro
    signal k              : unsigned(15 downto 0) := to_unsigned(0, 16);  -- Lunghezza sequenza e ordine filtro
    signal s              : std_logic := '0';
    signal data_counter   : integer := 0;  -- Contatore per lettura dati
    signal coeff_counter  : integer := 0;  -- Contatore per lettura coefficienti

    -- coefficienti di ordine 3
    signal c_n2_3 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_n1_3 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_p1_3 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_p2_3 : signed(7 downto 0)  := to_signed(0, 8);
    
    -- coefficienti di ordine 5
    signal c_n3_5 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_n2_5 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_n1_5 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_p1_5 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_p2_5 : signed(7 downto 0)  := to_signed(0, 8);
    signal c_p3_5 : signed(7 downto 0)  := to_signed(0, 8);
     
    
    signal prev3 : signed(7 downto 0)  := to_signed(0, 8);
    signal prev2 : signed(7 downto 0)  := to_signed(0, 8);
    signal prev1 : signed(7 downto 0)  := to_signed(0, 8);
    signal current_W : signed(7 downto 0)  := to_signed(0, 8);
    signal next1 : signed(7 downto 0)  := to_signed(0, 8);
    signal next2 : signed(7 downto 0)  := to_signed(0, 8);
    signal next3 : signed(7 downto 0)  := to_signed(0, 8);
    
    -- do we want the constants one byte long? or longer?
    constant n_3 : unsigned(7 downto 0) := to_unsigned(12, 8);
    constant n_5 : unsigned(7 downto 0) := to_unsigned(60, 8);

begin

    process (i_clk, i_rst) is

    variable tmp_k : std_logic_vector(15 downto 0) := (others => '0');
    variable tmp_s : std_logic := '0';
    --variable tmp_coeff_counter : integer := 0;
    
    --MODIFIED TO SIGNED 
    variable tmp_p3 : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_p2 : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_p1 : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_n1 : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_n2 : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_n3 : signed(31 downto 0) := to_signed(0, 32);

    variable tmp_sum : signed(31 downto 0) := to_signed(0, 32);
    variable tmp_res : signed(31 downto 0) := to_signed(0, 32);
    
    begin
    
        

        if i_rst = '1' then -- Reset asincrono 
            current_state <= START;
            o_done <= '0';
            o_mem_en <= '1'; -- next clock time, we want to read data from memory, don''t we need to set en to 1 rn?
            
            o_mem_we <= '0';
            o_mem_addr <= (others => '0');
            o_mem_data <= (others => '0');
           -- mem_addr <= (others => '0');
            data_counter <= 0;
            coeff_counter <= 0;
            k1 <= (others => '0');
            k2 <= (others => '0');
            s <= '0';
            

        elsif rising_edge(i_clk) then
        
            if state = DONE then
                if i_start = '0' then
                    o_done <= '0';
                    o_mem_en <= '0';
                    o_mem_we <= '0';
                    state <= IDLE;           
                 end if;
            end if;
        
            if i_start = '1' then
                case state is


                    ---------------------------- FASE DI LETTURA METADATI -----------------------------------
                    when WAITING =>
                        state <= current_state; 


                    when START => -- stato di attesa segnale start, lettura indirizzo mem iniz

                        mem_w1_addr <= std_logic_vector(unsigned(i_add) + 17);
            
                        o_done <= '0';
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        o_mem_addr <= i_add;
                        mem_init_addr <= i_add;
                        o_mem_data <= (others => '0');
                        state <= WAITING;
                        current_state <= K1_STATE;

                    when K1_STATE =>

                        o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 1);
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        k1 <= i_mem_data;
                        state <= WAITING;

                        current_state <= K2_STATE;

                    when K2_STATE =>

                        o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 2);
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        k2 <= i_mem_data;
                        state <= WAITING;

                        current_state <= K_STATE;
                        
                    when K_STATE =>
                        tmp_k(15 downto 8) := k1; 
                        tmp_k(7 downto 0) := k2;
                        k <= unsigned(tmp_k);
                        current_state <= S_STATE;
                        o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 2);
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        state <= WAITING;

                    when S_STATE =>

                        o_done <= '0';
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        s <= i_mem_data(0);
                        tmp_s := i_mem_data(0);
                        state <= WAITING;

                        -- chiedo alla mem il prossimo valore per gli stati di lettura dei coefficienti
                        if tmp_s = '0' then -- sto usando il filtro di ordine 3
                            o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 4); --leggo il primo coeff del filtro di ordine 3
                        elsif tmp_s = '1' then -- sono nel filtro di ordine 5
                            o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 10); --leggo il primo coeff del filtro di ordine 5
                        end if;
                        
                        
                        coeff_counter <= 0;
                        current_state <= READ_COEFF;

                    -- leggo i coefficienti basandomi sul segnale s e su un
                    -- un coeff_counter che si ricorda a che coefficiente sono
                    -- arrivato nella lettura
                    when READ_COEFF => 

                        o_done <= '0';
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        state <= WAITING;

                        if s = '0' then -- filtro ordine 3

                            case coeff_counter is

                                when 0 =>
                                    c_n2_3 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 5);

                                when 1 =>
                                    c_n1_3 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 7);

                                when 2 =>
                                    c_p1_3 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 8);

                                when 3 =>
                                    c_p2_3 <= signed(i_mem_data);
                                    o_mem_addr <= mem_w1_addr;
                                    current_state <= FILTER_INIT;
                                when others => 
                                    current_state <= DONE;
                           end case;

                        else -- filtro di ordine 5

                            case coeff_counter is

                                when 0 =>
                                    c_n3_5 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 11);

                                when 1 =>
                                    c_n2_5 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 12);

                                when 2 =>
                                    c_n1_5 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 14);

                                when 3 =>
                                    c_p1_5 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 15);

                                when 4 =>
                                    c_p2_5 <= signed(i_mem_data);
                                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 16);

                                when 5 =>
                                    c_p3_5 <= signed(i_mem_data);
                                    o_mem_addr <= mem_w1_addr;
                                    current_state <= FILTER_INIT;
                                when others  => 
                                    current_state <= DONE;
                            end case;
                        end if;
                                    
                        coeff_counter <= coeff_counter + 1; -- se non va usare tmp_coeff_counter come variabile momentanea


                    ----------------------- FASE DI INIZIALIZZAZIONE DEI PRIMI VALORI -----------------------------------


                    when FILTER_INIT =>

                        o_done <= '0';
                        o_mem_en <= '1';
                        o_mem_we <= '0';
                        state <= WAITING;

                        prev3 <= resize(to_signed(0, 8), 8);
                        prev2 <= resize(to_signed(0, 8), 8);
                        prev1 <= resize(to_signed(0, 8), 8);
                        current_W <= signed(i_mem_data); -- memorizzo quello che ho chiesto a fine READ_COEFF
                        next1 <= resize(to_signed(0, 8), 8);
                        next2 <= resize(to_signed(0, 8), 8);
                        next3 <= resize(to_signed(0, 8), 8);

                        o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + 1); -- chiedo il successivo (next1)

                        current_state <= FILTER_INIT_2;

                    when FILTER_INIT_2 =>
                        state <= WAITING;

                        o_done <= '0';
                        o_mem_en <= '1';
                        o_mem_we <= '0';

                        next1 <= signed(i_mem_data); -- memorizzo quello che ho chiesto prima (next1)
                        o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + 2); -- chiedo il successivo (nex2)

                        current_state <= FILTER_INIT_3;

                    when FILTER_INIT_3 =>
                        state <= WAITING;

                        o_done <= '0';
                        o_mem_we <= '0';

                        next2 <= signed(i_mem_data); -- memorizzo next2 che ho chiesto prima in FILTER_INIT_2

                        if s = '0' then
                            o_mem_en <= '0';
                            current_state <= COMPUTE_ORDER_3; -- se sono in ordine 3 posso iniziare la computazione
                        else
                            o_mem_en <= '1';
                            o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + 3); -- altrimenti chiedo il successivo (next3)
                            current_state <= FILTER_INIT_4;
                        end if;
                        
                    when FILTER_INIT_4 => 
                        state <= WAITING;

                        o_done <= '0';
                        o_mem_en <= '0';
                        o_mem_we <= '0';

                        next3 <= signed(i_mem_data); -- memorizzo next3

                        current_state <= COMPUTE_ORDER_5; -- inizio la computazione di ordine 5


                    --------------------------------------------------------------------------------------


                    when COMPUTE_ORDER_3 =>
                        state <= WAITING;

                        o_done <= '0';

               ----set resize value to 16 instead of 32 bc [Synth 8-690] width mismatch in assignment; target has 32 bits, source has 64 bits 
         
                        tmp_n2 := resize(c_n2_3, 16) * resize(prev2, 16); -- se non si può o per plagio defence, we can use std logic vector 31 down to 8 = 0 e others = x
                        tmp_n1 := resize(c_n1_3, 16) * resize(prev1, 16);
                        tmp_p1 := resize(c_p1_3, 16) * resize(next1, 16);
                        tmp_p2 := resize(c_p2_3, 16) * resize(next2, 16);

                        tmp_sum := tmp_n2 + tmp_n1 + tmp_p1 + tmp_p2;
                        tmp_res := shift_right (tmp_sum, 4) + shift_right (tmp_sum, 6) + shift_right (tmp_sum, 8) + shift_right (tmp_sum, 10);
                        if tmp_sum < to_signed(0, 32) then
                           tmp_res := tmp_res + 4;
                        end if;

                        -- saturo
                        if tmp_res > to_signed(127, 32) then
                            o_mem_data <= "01111111";
                        elsif tmp_res < to_signed(-128, 32) then
                            o_mem_data <= "10000000";
                        else
                            o_mem_data <= std_logic_vector(resize(tmp_res, 8));
                        end if;

                        o_mem_en <= '1';
                        o_mem_we <= '1';

                        o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + k + to_unsigned(data_counter, 16));

                        if data_counter = k - 1 then 
                            o_done <= '0';
                            current_state <= DONE; -- ci penso su
                        else 
                            o_done <= '0';
                            current_state <= SHIFT_ORDER_3;
                        end if;

                        data_counter <= data_counter + 1; --vedi sopra

                    when SHIFT_ORDER_3 => 
                        state <= WAITING;

                        o_done <= '0';

                        -- shifto tutto in dietro
                        prev2 <= prev1;
                        prev1 <= current_W;
                        current_W <= next1;
                        next1 <= next2;
                        -- next2 devo chiederlo

                        o_mem_en <= '1';
                        o_mem_we <= '0';

                        if data_counter > k - 3 then -- se sono alla fine 
                            next2 <= to_signed(0, 8); -- next2 è 0
                            o_mem_en <= '0';
                            current_state <= COMPUTE_ORDER_3; -- in questo modo quello 0 viene shiftato in next1
                        else 
                            o_mem_en <= '1';    -- se non sono alla fine degli input (W) allora chiedo next2...
                            o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr)+ 2 + to_unsigned(data_counter, 16));
                            current_state <= READ_NEXT_2; -- e poi vado nello stato in cui viene letto 
                        end if;

                    when READ_NEXT_2 =>
                        state <= WAITING;

                        o_done <= '0';
                        o_mem_en <= '0';
                        o_mem_we <= '0';
                        next2 <= signed(i_mem_data); -- memorizzo next2 (W successivo)
                        current_state <= COMPUTE_ORDER_3; -- e continuo con la computazione

                    -- avrò poi il corrispettivo per l'ordine 5:

                    when COMPUTE_ORDER_5 => 
                        state <= WAITING;
                        
                        o_done <= '0';

                        tmp_n3 := resize(c_n3_5, 16) * resize(prev3, 16);
                        tmp_n2 := resize(c_n2_5, 16) * resize(prev2, 16); -- se non si può o per plagio defence, we can use std logic vector 31 down to 8 = 0 e others = x
                        tmp_n1 := resize(c_n1_5, 16) * resize(prev1, 16);
                        tmp_p1 := resize(c_p1_5, 16) * resize(next1, 16);
                        tmp_p2 := resize(c_p2_5, 16) * resize(next2, 16);
                        tmp_p3 := resize(c_p3_5, 16) * resize(next3, 16);

                        tmp_sum := tmp_n3 + tmp_n2 + tmp_n1 + tmp_p1 + tmp_p2 + tmp_p3;
                        tmp_res := shift_right (tmp_sum, 6) + shift_right (tmp_sum, 10);
                        if tmp_sum < to_signed(0, 32) then
                           tmp_res := tmp_res + 2;
                        end if;

                        -- saturo il risultato a -128 o +127
                        if tmp_res > to_signed(127, 32) then
                            o_mem_data <= "01111111";
                        elsif tmp_res < to_signed(-128, 32) then
                            o_mem_data <= "10000000";
                        else
                            o_mem_data <= std_logic_vector(resize(tmp_res, 8));
                        end if;

                        -- setuppo la memoria per scrivere il risultato
                        o_mem_en <= '1';
                        o_mem_we <= '1';
                        -- l'address su cui lo scrivo è addr_w1 + k + data_counter
                        o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + k + to_unsigned(data_counter, 16));

                        if data_counter = k - 1 then 
                            o_done <= '0';
                            current_state <= DONE; -- ci penso su dato che dopo dovrà gestire anche i prossimi calcoli
                        else 
                            o_done <= '0';
                            current_state <= SHIFT_ORDER_5;
                        end if;

                        data_counter <= data_counter + 1; --vedi sopra

                    when SHIFT_ORDER_5 =>
                        state <= WAITING;

                        o_done <= '0';

                        -- shifto tutto in dietro
                        prev3 <= prev2;
                        prev2 <= prev1;
                        prev1 <= current_W;
                        current_W <= next1;
                        next1 <= next2;
                        next2 <= next3;
                        -- next3 devo chiederlo

                        o_mem_en <= '1';
                        o_mem_we <= '0';

                        if data_counter > k - 4 then -- se sono alla fine 
                            next3 <= to_signed(0, 8); -- next3 è 0
                            o_mem_en <= '0';
                            current_state <= COMPUTE_ORDER_5; -- in questo modo quello 0 viene shiftato in next2 e next1
                        else 
                            o_mem_en <= '1';    -- se non sono alla fine degli input (W) allora chiedo next3...
                            o_mem_addr <= std_logic_vector(unsigned(mem_w1_addr) + 3 + to_unsigned(data_counter, 16)); -- chiedo next3
                            current_state <= READ_NEXT_3; -- e poi vado nello stato in cui viene letto 
                        end if;

                    when READ_NEXT_3 =>
                        state <= WAITING;

                        o_done <= '0';
                        o_mem_en <= '0';
                        o_mem_we <= '0';
                        next3 <= signed(i_mem_data); -- memorizzo next3 (W successivo)
                        current_state <= COMPUTE_ORDER_5; -- e continuo con la computazione

                    --------------------------------------------------------------------------------------



                    when DONE =>
                        -- Stato finale, attesa del reset
                        
                        
                        o_mem_en <= '0';
                        o_mem_we <= '0';
                        o_done <= '1';   
                       
                        

                    when others =>
                        -- Stato di errore, reset alla condizione iniziale
                        o_mem_en <= '0';
                        o_mem_we <= '0';
                        o_done <= '0';
                       current_state <= START;
            
                end case;
            end if;
        end if;
    end process;

    -- Uscita indirizzo memoria
    --o_mem_addr <= std_logic_vector(mem_addr);

end architecture behavioral;
