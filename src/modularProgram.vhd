library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



-- Modulo di Memory Controller Unit (MCU)
-- ----------------------------------------------------
entity MCU is
    port (
        i_rst             : in  std_logic;  -- Reset asincrono
        i_clk             : in  std_logic;  -- Clock di sistema
        i_start_mcu       : in  std_logic;  -- Segnale di avvio operazione di memoria

        i_write_flag      : in  std_logic;                  -- Se '1' esegue scrittura, altrimenti lettura
        i_target_mem_addr : in  std_logic_vector(15 downto 0); -- Indirizzo di memoria (target)
        i_data_to_write   : in  std_logic_vector(7 downto 0);  -- Dato da scrivere (valido solo se i_write_flag = '1')
        o_data_read       : out std_logic_vector(7 downto 0);  -- Dato letto dalla memoria (valido se i_write_flag = '0' e o_done = '1')
        
        o_done            : out std_logic;                  -- Segnale di completamento operazione

        -- Porte di interfaccia con la RAM esterna
        -- le collego poi nel top_module con quelle del test bench
        o_mem_addr        : out std_logic_vector(15 downto 0); -- Indirizzo verso la RAM
        i_mem_data_bus    : in  std_logic_vector(7 downto 0);  -- Dato letto dalla RAM
        o_mem_data_bus    : out std_logic_vector(7 downto 0);  -- Dato da scrivere verso la RAM
        o_mem_we          : out std_logic;                  -- Write Enable (1 per scrittura, 0 per lettura)
        o_mem_en          : out std_logic                   -- Memory Enable (1 per abilitare RAM, 0 per disabilitare)
    );
end entity MCU;

architecture Behavioral of MCU is

    -- Stati della FSM interna al Memory Controller
    type state_type is (IDLE, MEM_ACCESS, DONE_MEM_OP);
    signal current_state : state_type := IDLE;

    -- Segnali interni di registro per le uscite del modulo e per catturare il dato letto
    signal s_done        : std_logic := '0';
    signal s_data_read   : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Segnali interni per pilotare le porte del bus di memoria (e registrarle)
    signal s_mem_addr_reg     : std_logic_vector(15 downto 0) := (others => '0');
    signal s_mem_data_bus_reg : std_logic_vector(7 downto 0)  := (others => '0');
    signal s_mem_we_reg       : std_logic := '0';
    signal s_mem_en_reg       : std_logic := '0';

begin

    process (i_clk, i_rst)
    begin

        if i_rst = '1' then
            -- Reset asincrono
            current_state      <= IDLE;
            s_done             <= '0';
            s_data_read        <= (others => '0');
            s_mem_addr_reg     <= (others => '0');
            s_mem_data_bus_reg <= (others => '0');
            s_mem_we_reg       <= '0';
            s_mem_en_reg       <= '0';

        elsif rising_edge(i_clk) then
            -- Default assignments per il prossimo ciclo, a meno che non vengano sovrascritti
            s_done       <= '0'; -- Resetta 'done' all'inizio del ciclo
            s_mem_we_reg <= '0'; -- Di default non scrivere
            s_mem_en_reg <= '0'; -- Di default disabilita la memoria

            case current_state is
                when IDLE =>
                    if i_start_mcu = '1' then
                        -- Una nuova operazione di memoria è richiesta
                        s_mem_addr_reg <= i_target_mem_addr; -- Prepara l'indirizzo

                        -- Capisco se devo leggere o scrivere
                        if i_write_flag = '1' then
                            -- Operazione di scrittura
                            s_mem_data_bus_reg <= i_data_to_write; -- Prepara il dato da scrivere
                            s_mem_we_reg       <= '1';              -- Abilita la scrittura
                        else
                            -- Operazione di lettura
                            s_mem_data_bus_reg <= (others => 'Z'); -- bus dati in alta impedenza per la lettura (solo per simulazione, la sintesi lo ignora)
                            s_mem_we_reg       <= '0';              -- Disabilita la scrittura
                        end if;
                        
                        s_mem_en_reg  <= '1';              -- Abilita il chip di memoria
                        current_state <= MEM_ACCESS;       -- Passa allo stato di accesso alla memoria
                    else
                        current_state <= IDLE; -- Rimani in IDLE
                    end if;

                when MEM_ACCESS =>

                    s_mem_en_reg <= '0'; -- Disabilita la memoria dopo il ciclo di accesso
                    s_mem_we_reg <= '0'; -- Disabilita il write enable

                    if i_write_flag = '0' then
                        -- Se era una lettura, cattura il dato dal bus
                        s_data_read <= i_mem_data_bus; 
                    end if;
                    -- Se invece ero in scrittura assumo sia andato tutto bene dato che non posso
                    -- essere certo che il dato sia stato scritto

                    s_done        <= '1';        -- Segnala che l'operazione è completa
                    current_state <= DONE_MEM_OP; -- Passa allo stato di completamento

                when DONE_MEM_OP =>
                    -- Qui attendiamo che la Control Unit esterna riconosca il segnale 'done'
                    -- disattivando 'i_start_mcu'.
                    if i_start_mcu = '0' then
                        current_state <= IDLE; -- Torna allo stato IDLE per la prossima operazione
                    else
                        current_state <= DONE_MEM_OP; -- Aspetta che la richiesta di start venga de-asserita
                    end if;

                when others =>
                    current_state <= IDLE; -- Stato di fallback, torna in IDLE
            end case;
        end if;
    end process;
    
    -- mappano i segnali di registro interni alle porte di output
    o_done         <= s_done;
    o_data_read    <= s_data_read;
    o_mem_addr     <= s_mem_addr_reg;
    o_mem_data_bus <= s_mem_data_bus_reg;
    o_mem_we       <= s_mem_we_reg;
    o_mem_en       <= s_mem_en_reg;
    
end architecture Behavioral;


-- Modulo di Arithmetic Logic Unit for order 3 (ALU3)
-- ----------------------------------------------------
entity ALU3 is
    port (
        i_clk : in STD_LOGIC;
        i_rst : in STD_LOGIC;
        i_start_alu3 : in STD_LOGIC;

        i_cn2_3 : in signed(7 downto 0);
        i_cn1_3 : in signed(7 downto 0);
        i_cp1_3 : in signed(7 downto 0);
        i_cp2_3 : in signed(7 downto 0);

        i_prev2 : in signed(7 downto 0);
        i_prev1 : in signed(7 downto 0);
        i_next1 : in signed(7 downto 0);
        i_next2 : in signed(7 downto 0);

        o_done_alu3 : out STD_LOGIC;
        o_result_alu3 : out signed(7 downto 0);
    );
end entity ALU3;

architecture Behavioral of ALU3 is

    -- creo dei segnali di registro che vengono mappati solo a fine processo
    -- agli effettivi segnali di output
    signal s_result_alu3_reg : signed(7 downto 0);
    signal s_done_alu3_reg   : STD_LOGIC;

begin

    process (i_clk, i_rst)

        --variable tmp_p3 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_p2 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_p1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n2 : signed(31 downto 0) := to_signed(0, 32);
        --variable tmp_n3 : signed(31 downto 0) := to_signed(0, 32);

        variable tmp_sum : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_res : signed(31 downto 0) := to_signed(0, 32);

    begin

        -- tocca fare il reset
        if i_rst = '1' then
            s_result_alu3_reg <= (others => '0');
            s_done_alu3_reg   <= '0';
            
        -- altrimenti
        elsif rising_edge(i_clk) then
            -- Reset del segnale done ad ogni ciclo, a meno che non sia attivato di nuovo
            s_done_alu3_reg <= '0';

            if i_start_alu3 = '1' then
                -- Esegui i calcoli solo quando il segnale di start è attivo
        
                -- moltiplicazioni
                tmp_n2 := resize(c_n2_3, 16) * resize(prev2, 16);
                tmp_n1 := resize(c_n1_3, 16) * resize(prev1, 16);
                tmp_p1 := resize(c_p1_3, 16) * resize(next1, 16);
                tmp_p2 := resize(c_p2_3, 16) * resize(next2, 16);
                -- somma
                tmp_sum := tmp_n2 + tmp_n1 + tmp_p1 + tmp_p2;
                --divisione
                tmp_res := shift_right (tmp_sum, 4) + shift_right (tmp_sum, 6) + shift_right (tmp_sum, 8) + shift_right (tmp_sum, 10);
                -- fix divisione
                if tmp_sum < to_signed(0, 32) then
                    tmp_res := tmp_res + 4;
                end if;

                -- saturo
                if tmp_res > to_signed(127, 32) then
                    s_result_alu3_reg <= "01111111";
                elsif tmp_res < to_signed(-128, 32) then
                    s_result_alu3_reg <= "10000000";
                else
                    s_result_alu3_reg <= std_logic_vector(resize(tmp_res, 8));
                end if;

                -- lancio il segnale di fine
                s_done_alu3_reg <= '1';
            end if;
        end if;
    end process;

    -- assegnazione degli output dai registri
    o_result_alu3 <= s_result_alu3_reg;
    o_done_alu3   <= s_done_alu3_reg;
    
end architecture Behavioral;


-- Modulo di Arithmetic Logic Unit for order 5 (ALU5)
-- ----------------------------------------------------
entity ALU5 is
    port (
        i_clk : in STD_LOGIC;
        i_rst : in STD_LOGIC;
        i_start_alu5 : in STD_LOGIC;

        i_cn3_5 : in signed(7 downto 0);
        i_cn2_5 : in signed(7 downto 0);
        i_cn1_5 : in signed(7 downto 0);
        i_cp1_5 : in signed(7 downto 0);
        i_cp2_5 : in signed(7 downto 0);
        i_cp3_5 : in signed(7 downto 0);

        i_prev3 : in signed(7 downto 0);
        i_prev2 : in signed(7 downto 0);
        i_prev1 : in signed(7 downto 0);
        i_next1 : in signed(7 downto 0);
        i_next2 : in signed(7 downto 0);
        i_next3 : in signed(7 downto 0);

        o_done_alu5 : out STD_LOGIC;
        o_result_alu5 : out signed(7 downto 0);
    );
end entity ALU5;

architecture Behavioral of ALU5 is

    -- creo dei segnali di registro che vengono mappati solo a fine processo
    -- agli effettivi segnali di output
    signal s_result_alu5_reg : signed(7 downto 0);
    signal s_done_alu5_reg   : STD_LOGIC;

begin

    process (i_clk, i_rst)

        variable tmp_p3 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_p2 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_p1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n2 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n3 : signed(31 downto 0) := to_signed(0, 32);

        variable tmp_sum : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_res : signed(31 downto 0) := to_signed(0, 32);

    begin

        -- tocca fare il reset
        if i_rst = '1' then
            s_result_alu5_reg <= (others => '0');
            s_done_alu5_reg   <= '0';
            
        -- altrimenti
        elsif rising_edge(i_clk) then
            -- Reset del segnale done ad ogni ciclo, a meno che non sia attivato di nuovo
            s_done_alu5_reg <= '0';

            if i_start_alu5 = '1' then
                -- Esegui i calcoli solo quando il segnale di start è attivo
        
                -- moltiplicazioni
                tmp_n3 := resize(c_n3_5, 16) * resize(prev3, 16);
                tmp_n2 := resize(c_n2_3, 16) * resize(prev2, 16);
                tmp_n1 := resize(c_n1_3, 16) * resize(prev1, 16);
                tmp_p1 := resize(c_p1_3, 16) * resize(next1, 16);
                tmp_p2 := resize(c_p2_3, 16) * resize(next2, 16);
                tmp_p3 := resize(c_p3_5, 16) * resize(next3, 16);
                -- somma
                tmp_sum := tmp_n3 + tmp_n2 + tmp_n1 + tmp_p1 + tmp_p2 + tmp_p3;
                --divisione
                tmp_res := shift_right (tmp_sum, 6) + shift_right (tmp_sum, 10);
                -- fix divisione
                if tmp_sum < to_signed(0, 32) then
                    tmp_res := tmp_res + 2;
                end if;

                -- saturo
                if tmp_res > to_signed(127, 32) then
                    s_result_alu5_reg <= "01111111";
                elsif tmp_res < to_signed(-128, 32) then
                    s_result_alu5_reg <= "10000000";
                else
                    s_result_alu5_reg <= std_logic_vector(resize(tmp_res, 8));
                end if;

                -- lancio il segnale di fine
                s_done_alu5_reg <= '1';
            end if;
        end if;
    end process;

    -- assegnazione degli output dai registri
    o_result_alu5 <= s_result_alu5_reg;
    o_done_alu5   <= s_done_alu5_reg;
    
end architecture Behavioral;





-- Modulo di Config Reader Unit (CRU) per la lettura di s, k e dei coefficienti
-- ----------------------------------------------------
entity CRU is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_base_addr : in std_logic_vector(15 downto 0);
        
        -- Output dei parametri letti
        o_k : out std_logic_vector(15 downto 0);
        o_s : out std_logic;
        o_cn3 : out signed(7 downto 0);
        o_cn2 : out signed(7 downto 0);
        o_cn1 : out signed(7 downto 0);
        o_cp1 : out signed(7 downto 0);
        o_cp2 : out signed(7 downto 0);
        o_cp3 : out signed(7 downto 0);
        o_w1_addr : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        
        -- Interfaccia con MCU
        o_start_mcu : out std_logic;
        i_done_mcu : in std_logic;
        o_mcu_addr : out std_logic_vector(15 downto 0);
        o_mcu_write_flag : out std_logic;
        i_mcu_data : in std_logic_vector(7 downto 0);
        o_mcu_data : out std_logic_vector(7 downto 0)
    );
end entity CRU;
architecture Behavioral of CRU is

    type state_type is (
        IDLE, 
        READ_K1, WAIT_K1,
        READ_K2, WAIT_K2,
        READ_S, WAIT_S,
        READ_COEFFS, WAIT_COEFFS,
        CONFIG_DONE
    );
    signal current_state : state_type := IDLE;

    -- Registri interni
    signal s_k1 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_k2 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_s : std_logic := '0';
    -- coefficienti di ordine 3 e 5
    signal s_c_n3 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_c_n2 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_c_n1 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_c_p1 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_c_p2 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_c_p3 : signed(7 downto 0)  := to_signed(0, 8);
    signal s_w1_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal s_base_addr : std_logic_vector(15 downto 0) := (others => '0');
    -- Contatore per lettura coefficienti
    -- si usa questo esgnale per iterare leggendo tutti i coefficienti a seconda dell'ordine
    signal coeff_counter : integer range 0 to 6 := 0;
    -- Segnali di controllo MCU
    signal s_start_mcu : std_logic := '0';
    signal s_mcu_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal s_done : std_logic := '0';

begin

    process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            -- Reset asincrono
            current_state <= IDLE;
            s_k1 <= (others => '0');
            s_k2 <= (others => '0');
            s_s <= '0';
            s_c_n3 <= (others => '0');
            s_c_n2 <= (others => '0');
            s_c_n1 <= (others => '0');
            s_c_p1 <= (others => '0');
            s_c_p2 <= (others => '0');
            s_c_p3 <= (others => '0');
            s_w1_addr <= (others => '0');
            s_base_addr <= (others => '0');
            coeff_counter <= 0;
            s_start_mcu <= '0';
            s_mcu_addr <= (others => '0');
            s_done <= '0';
            
        elsif rising_edge(i_clk) then
            
            case current_state is
                
                when IDLE =>
                    s_done <= '0';
                    s_start_mcu <= '0';
                    
                    if i_start = '1' then
                        s_base_addr <= i_base_addr;
                        s_w1_addr <= std_logic_vector(unsigned(i_base_addr) + 17);
                        current_state <= READ_K1;
                    end if;
                
                -- Lettura K1
                when READ_K1 =>
                    s_mcu_addr <= s_base_addr;  -- Indirizzo K1
                    s_start_mcu <= '1';
                    current_state <= WAIT_K1;
                
                when WAIT_K1 =>
                    s_start_mcu <= '0';
                    if i_done_mcu = '1' then -- bisognerà poi collegare tutti questi segnali!
                        s_k1 <= i_mcu_data;
                        current_state <= READ_K2;
                    end if;
                
                -- Lettura K2
                when READ_K2 =>
                    s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 1);
                    s_start_mcu <= '1';
                    current_state <= WAIT_K2;
                
                when WAIT_K2 =>
                    s_start_mcu <= '0';
                    if i_done_mcu = '1' then
                        s_k2 <= i_mcu_data;
                        current_state <= READ_S;
                    end if;
                
                -- Lettura S
                when READ_S =>
                    s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 2);
                    s_start_mcu <= '1';
                    current_state <= WAIT_S;
                
                when WAIT_S =>
                    s_start_mcu <= '0';
                    if i_done_mcu = '1' then
                        s_s <= i_mcu_data(0);
                        coeff_counter <= 0;
                        current_state <= READ_COEFFS;
                    end if;
                
                -- Lettura coefficienti
                when READ_COEFFS =>
                    -- Determina l'indirizzo del coefficiente da leggere
                    if s_s = '0' then
                        -- Filtro ordine 3: coefficienti agli indirizzi 4, 5, 7, 8
                        case coeff_counter is
                            when 0 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 4);   -- c_n2_3
                            when 1 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 5);   -- c_n1_3
                            when 2 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 7);   -- c_p1_3
                            when 3 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 8);   -- c_p2_3
                            when others => s_mcu_addr <= (others => '0');
                        end case;
                    else
                        -- Filtro ordine 5: coefficienti agli indirizzi 10, 11, 12, 14, 15, 16
                        case coeff_counter is
                            when 0 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 10);  -- c_n3_5
                            when 1 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 11);  -- c_n2_5
                            when 2 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 12);  -- c_n1_5
                            when 3 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 14);  -- c_p1_5
                            when 4 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 15);  -- c_p2_5
                            when 5 => s_mcu_addr <= std_logic_vector(unsigned(s_base_addr) + 16);  -- c_p3_5
                            when others => s_mcu_addr <= (others => '0');
                        end case;
                    end if;
                    
                    s_start_mcu <= '1';
                    current_state <= WAIT_COEFFS;
                
                when WAIT_COEFFS =>
                    s_start_mcu <= '0';
                    if i_done_mcu = '1' then
                        -- Memorizza il coefficiente letto
                        if s_s = '0' then
                            -- Filtro ordine 3
                            s_coeffs_3(coeff_counter) <= signed(i_mcu_data);
                            
                            -- al quarto coefficiente ho finito di leggerli tutti
                            if coeff_counter = 3 then
                                current_state <= CONFIG_DONE;
                            else
                                coeff_counter <= coeff_counter + 1;
                                current_state <= READ_COEFFS;
                            end if;
                        else
                            -- Filtro ordine 5
                            s_coeffs_5(coeff_counter) <= signed(i_mcu_data);
                            
                            -- al sesto coefficiente ho finito la lettura
                            if coeff_counter = 5 then
                                current_state <= CONFIG_DONE;
                            else
                                coeff_counter <= coeff_counter + 1;
                                current_state <= READ_COEFFS;
                            end if;
                        end if;
                    end if;
                
                when CONFIG_DONE =>
                    s_done <= '1';
                    s_start_mcu <= '0';
                    
                    -- Aspetta che il segnale i_start venga de-asserito
                    if i_start = '0' then
                        current_state <= IDLE;
                    end if;
                
                when others =>
                    current_state <= IDLE;
            
            end case;
        end if;
    end process;

    -- Assegnazione delle uscite
    o_k(15 downto 8) <= s_k1;
    o_k(7 downto 0) <= s_k2;
    o_s <= s_s;
    o_cn3 <= s_c_n3;
    o_cn2 <= s_c_n2;
    o_cn1 <= s_c_n1;
    o_cp1 <= s_c_p1;
    o_cp2 <= s_c_p2;
    o_cp3 <= s_c_p3;
    o_w1_addr <= s_w1_addr;
    o_done <= s_done;
    
    -- Interfaccia MCU
    o_start_mcu <= s_start_mcu;
    o_mcu_addr <= s_mcu_addr;
    o_mcu_write_flag <= '0';  -- Sempre in lettura
    o_mcu_data <= (others => '0');  -- Non usato in lettura

end architecture Behavioral;






































-- Modulo di Control Unit (CU)
-- ----------------------------------------------------
entity CU is
    port (
        rst : in STD_LOGIC;
        clk : in STD_LOGIC;

        ...
        
    );
end entity CU;

architecture Behavioral of CU is

    -- Segnali di controllo per i moduli
    signal start_mcu, done_mcu : std_logic;
    signal start_alu3, done_alu3 : std_logic;
    signal start_alu5, done_alu5 : std_logic;

    -- Registri per i dati
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
     
    -- valori temporanei da dare in pasto alle ALU
    signal prev3 : signed(7 downto 0)      := to_signed(0, 8);
    signal prev2 : signed(7 downto 0)      := to_signed(0, 8);
    signal prev1 : signed(7 downto 0)      := to_signed(0, 8);
    signal current_W : signed(7 downto 0)  := to_signed(0, 8);
    signal next1 : signed(7 downto 0)      := to_signed(0, 8);
    signal next2 : signed(7 downto 0)      := to_signed(0, 8);
    signal next3 : signed(7 downto 0)      := to_signed(0, 8);


begin
    
    process (clk, rst)

        ...

    begin
        
        ...

    end process;


end architecture Behavioral;



-- Top Module con stessa interfaccia del modulo iniziale
-- ----------------------------------------------------

entity top_module is
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
end entity top_module;

--devo istanziare gli altri moduli e connettere le porte tra di loro

architecture Behavioral of top_module is

begin
    
end architecture Behavioral;
