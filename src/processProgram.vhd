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

        o_mem_addr : out std_logic_vector(15 downto 0); -- Indirizzo di memoria target (su cui scrivere o da cui leggere)
        i_mem_data : in  std_logic_vector(7 downto 0);  -- Dato letto dalla memoria
        o_mem_data : out std_logic_vector(7 downto 0);  -- Dato da scrivere in memoria
        o_mem_we   : out std_logic;  -- Segnale di scrittura memoria
        o_mem_en   : out std_logic   -- Segnale di abilitazione memoria
    );
end entity project_reti_logiche;
architecture behavioral of project_reti_logiche is

    type state_type is (
        IDLE,  -- l'idle serve quando il modulo è "spento" 
        START, -- start è uno stato di passaggio che triggera l'esecuzione del calcolo
        READ_K1, -- stato per la lettura di K1 che interpella il processo della memoria
        READ_K2, -- idem e inoltre unifica K1 e K2 in K
        READ_S,
        DONE
    );
    signal s_state : state_type := IDLE;

    -- segnali per il cambio di stato
    signal s_next_state : std_logic := '0'; -- questo è un segnale che serve per permettere al process del cambio di stato di cambiare effettivamente stato => settarlo ad 1 alla fine delle operazioni logiche

    -- segnali per interagire col processo della memoria
    signal s_mem_process_en : std_logic := '0';
    signal s_mem_action : std_logic := '0';
    signal s_mem_target_addr : std_logic_vector(15 downto 0) := (others => '0'); -- indirizzo target della memoria
    signal s_mem_read_out : std_logic_vector(7 downto 0) := (others => '0'); -- segnale col dato letto dalla memoria
    signal s_mem_write_in : std_logic_vector(7 downto 0) := (others => '0'); -- segnale col dato scritto nella memoria
    signal s_mem_process_finish : std_logic := '0'; -- segnale di ack
    signal s_done_asking : std_logic := '0'; -- segnale interno per il processo (non usare)
    -- segnali per le uscite di memoria
    signal int_o_mem_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal int_o_mem_data : std_logic_vector(7 downto 0) := (others => '0');
    signal int_o_mem_we   : std_logic := '0';
    signal int_o_mem_en   : std_logic := '0';

    -- segnali per i metadati
    signal s_k1 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_k2 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_k : std_logic_vector(15 downto 0) := (others => '0'); -- assegnato in READ_K2
    signal s_s : std_logic := '0';

    -- segnale per il done
    signal s_done : std_logic := '0';

begin
    
    -- cambio stati
    change_state_process : process (i_clk, i_rst) is
    begin
        if i_rst = '1' then -- reset asincrono
            s_state <= IDLE;
            s_next_state <= '0';
            s_mem_process_en <= '0';
            -- Reset di tutti i segnali di stato qui per un reset affidabile
            s_mem_action <= '0';
            s_mem_target_addr <= (others => '0');
            s_mem_read_out <= (others => '0');
            s_mem_write_in <= (others => '0');
            s_mem_process_finish <= '0';
            s_done_asking <= '0';
            s_k1 <= (others => '0');
            s_k2 <= (others => '0');
            s_k <= (others => '0');
            s_s <= '0';
            s_done <= '0';
            int_o_mem_addr <= (others => '0');
            int_o_mem_data <= (others => '0');
            int_o_mem_we <= '0';
            int_o_mem_en <= '0';

        elsif rising_edge(i_clk) then
            -- Se la logica mi ha permesso di passare al prossimo stato
            if s_next_state = '1' then
                -- allora cambio lo stato della FSM
                case s_state is
                    when IDLE =>
                        -- passo da idle a start solo se il TB mi da il permesso
                        if i_start = '1' then
                            s_state <= START;
                        end if; -- altrimenti appunto rimango in idle
                    
                    when START =>
                        s_state <= READ_K1;

                    when READ_K1 =>
                        s_state <= READ_K2;

                    when READ_K2 =>
                        s_state <= READ_S;

                    when READ_S =>
                        s_state <= DONE;

                    when DONE =>
                        s_state <= IDLE;

                    when others =>
                        s_state <= IDLE;
                end case;

                -- Reset del segnale di passaggio DOPO che è stato usato per la transizione
                s_next_state <= '0';

            end if;
        end if;
    end process;

    -- processo della logica
    logic_process : process (i_clk) is
    begin
        if rising_edge(i_clk) then
            s_mem_process_en <= '0';
            -- Anche s_mem_action dovrebbe avere un default se non è sempre impostato
            -- s_mem_action <= '0'; 

            case s_state is
                when IDLE =>
                    s_done <= '0';
                    -- se sono in idle passerò al prossimo stato solo se i_start = 1 (chek nell'altro processo)
                    s_next_state <= '1';

                when START =>
                    -- se sono in questo stato vuol dire che il TB mi ha appena detto di partire col calcolo
                    -- questo è solo uno stato di passaggio che trigghera READ_K1
                    s_next_state <= '1';

                when READ_K1 =>
                    -- ora devo interpellare il processo della memoria per leggere K1
                    s_mem_process_en <= '1'; -- accendo il process
                    s_mem_action <= '0'; -- gli dico che voglio leggere
                    s_mem_target_addr <= std_logic_vector(unsigned(i_add)); -- leggo il byte all'addres base
                    
                    -- ora, sempre in questo stato controllo se la lettura ha finito
                    if s_mem_process_finish = '1' then
                        -- a questo punto 
                        s_k1 <= s_mem_read_out; -- salvo il dato letto
                        -- e posso andare al prossimo stato
                        s_next_state <= '1';
                    end if;

                when READ_K2 =>
                    s_mem_process_en <= '1'; -- accendo il process
                    s_mem_action <= '0'; -- gli dico che voglio leggere
                    s_mem_target_addr <= std_logic_vector(unsigned(i_add) + 1); -- leggo il byte all'addres base + 1
                    
                    if s_mem_process_finish = '1' then
                        s_k2 <= s_mem_read_out; -- salvo il dato letto
                        s_next_state <= '1';

                        -- inoltre faccio gli assegnamenti per costruire K
                        s_k(15 downto 8) <= s_k1;
                        s_k(7 downto 0) <= s_mem_read_out; -- K2 appena letto

                    end if;

                when READ_S =>
                    -- identico a READ_K1
                    s_mem_process_en <= '1'; -- accendo il process
                    s_mem_action <= '0'; -- gli dico che voglio leggere
                    s_mem_target_addr <= std_logic_vector(unsigned(i_add) + 2); -- leggo il byte all'addres base + 2
                    
                    -- ora, sempre in questo stato controllo se la lettura ha finito
                    if s_mem_process_finish = '1' then
                        -- a questo punto 
                        s_s <= s_mem_read_out(0); -- salvo il primo bit del dato letto
                        -- e posso andare al prossimo stato
                        s_next_state <= '1';
                    end if;
                
                when DONE =>
                    s_done <= '1'; -- Segnala il completamento
                    s_next_state <= '1'; -- Per tornare a IDLE

                    -- Reset dei segnali di metadati qui, quando l'operazione è finita
                    s_k1 <= (others => '0');
                    s_k2 <= (others => '0');
                    s_k <= (others => '0');
                    s_s <= '0';

            end case;
        end if;

    end process;


    -- processo per la gestione della memoria (dura 2 clock e quindi serve un segnale di ack)
    memory_process : process (i_clk) is
    begin
        if rising_edge(i_clk) then -- Aggiunto rising_edge(i_clk) per sincronizzazione
            -- Reset output di memoria se s_mem_process_en è '0'
            if s_mem_process_en = '0' then
                int_o_mem_en <= '0';
                int_o_mem_we <= '0';
                -- s_done_asking e s_mem_process_finish dovrebbero essere resettati qui
                s_done_asking <= '0';
                s_mem_process_finish <= '0';
            else -- s_mem_process_en = '1'
                if s_done_asking = '0' then -- Primo ciclo: invia la richiesta
                    case s_mem_action is
                        when '0' => -- Leggi
                            int_o_mem_addr <= s_mem_target_addr;
                            int_o_mem_en <= '1';
                            int_o_mem_we <= '0';
                            s_mem_process_finish <= '0';
                        when '1' => -- Scrivi
                            int_o_mem_addr <= s_mem_target_addr;
                            int_o_mem_data <= s_mem_write_in;
                            int_o_mem_en <= '1';
                            int_o_mem_we <= '1';
                            s_mem_process_finish <= '0';
                        when others =>
                            int_o_mem_en <= '0'; int_o_mem_we <= '0'; s_mem_process_finish <= '1';
                    end case;
                    s_done_asking <= '1'; -- Richiesta inviata

                else -- s_done_asking = '1' - Secondo ciclo: ricevi dato o conferma
                    case s_mem_action is
                        when '0' => -- Leggi
                            s_mem_read_out <= i_mem_data; -- Latch del dato letto
                            s_mem_process_finish <= '1';
                        when '1' => -- Scrivi
                            s_mem_process_finish <= '1';
                        when others =>
                            s_mem_process_finish <= '1';
                    end case;
                    -- s_done_asking verrà resettato dal blocco s_mem_process_en = '0' nel ciclo successivo,
                    -- quando la FSM disabilita il processo di memoria.
                end if;
            end if;
        end if;
    end process;

    -- Faccio tutti gli assegnamenti segnale --> output (assegnazioni concorrenti)
    o_done     <= s_done;
    o_mem_addr <= int_o_mem_addr;
    o_mem_data <= int_o_mem_data;
    o_mem_we   <= int_o_mem_we;
    o_mem_en   <= int_o_mem_en;

end architecture behavioral;