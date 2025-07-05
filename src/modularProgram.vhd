library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modulo di Memory Control Unit (MCU)
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modulo di Arithmetic Logic Unit for order 3 (ALU3)
-- ----------------------------------------------------
entity ALU3 is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start_alu3 : in std_logic;

        i_cn2_3 : in signed(7 downto 0);
        i_cn1_3 : in signed(7 downto 0);
        i_cp1_3 : in signed(7 downto 0);
        i_cp2_3 : in signed(7 downto 0);

        i_prev2 : in signed(7 downto 0);
        i_prev1 : in signed(7 downto 0);
        i_next1 : in signed(7 downto 0);
        i_next2 : in signed(7 downto 0);

        o_done_alu3 : out std_logic;
        o_result_alu3 : out signed(7 downto 0)
    );
end entity ALU3;
architecture Behavioral of ALU3 is

    -- creo dei segnali di registro che vengono mappati solo a fine processo
    -- agli effettivi segnali di output
    signal s_result_alu3_reg : signed(7 downto 0);
    signal s_done_alu3_reg   : std_logic;

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
                tmp_n2 := resize(i_cn2_3, 16) * resize(i_prev2, 16);
                tmp_n1 := resize(i_cn1_3, 16) * resize(i_prev1, 16);
                tmp_p1 := resize(i_cp1_3, 16) * resize(i_next1, 16);
                tmp_p2 := resize(i_cp2_3, 16) * resize(i_next2, 16);
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
                    s_result_alu3_reg <= signed(resize(tmp_res, 8));
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modulo di Arithmetic Logic Unit for order 5 (ALU5)
-- ----------------------------------------------------
entity ALU5 is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start_alu5 : in std_logic;

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

        o_done_alu5 : out std_logic;
        o_result_alu5 : out signed(7 downto 0)
    );
end entity ALU5;
architecture Behavioral of ALU5 is

    -- creo dei segnali di registro che vengono mappati solo a fine processo
    -- agli effettivi segnali di output
    signal s_result_alu5_reg : signed(7 downto 0);
    signal s_done_alu5_reg   : std_logic;

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
                tmp_n3 := resize(i_cn3_5, 16) * resize(i_prev3, 16);
                tmp_n2 := resize(i_cn2_5, 16) * resize(i_prev2, 16);
                tmp_n1 := resize(i_cn1_5, 16) * resize(i_prev1, 16);
                tmp_p1 := resize(i_cp1_5, 16) * resize(i_next1, 16);
                tmp_p2 := resize(i_cp2_5, 16) * resize(i_next2, 16);
                tmp_p3 := resize(i_cp3_5, 16) * resize(i_next3, 16);
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
                    s_result_alu5_reg <= signed(resize(tmp_res, 8));
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



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    type coeffs_array_3 is array (0 to 3) of signed(7 downto 0);
    type coeffs_array_5 is array (0 to 5) of signed(7 downto 0);
    signal s_coeffs_3 : coeffs_array_3 := (others => to_signed(0,8));
    signal s_coeffs_5 : coeffs_array_5 := (others => to_signed(0,8));

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




library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modulo di Window Reader Unit (WRU)
-- ----------------------------------------------------
entity Window_Reader_Unit is
    port (
        i_clk             : in  std_logic;
        i_rst             : in  std_logic;
        i_start_wru       : in  std_logic;                  -- Avvia la lettura della finestra
        i_center_addr     : in  std_logic_vector(15 downto 0); -- L'indirizzo del valore centrale (W(i))
        i_filter_order_s  : in  std_logic;                  -- '0' per ordine 3, '1' per ordine 5

        -- Output dei dati della finestra
        o_prev3           : out signed(7 downto 0); -- Valido solo per ordine 5
        o_prev2           : out signed(7 downto 0);
        o_prev1           : out signed(7 downto 0);
        o_current_W       : out signed(7 downto 0);
        o_next1           : out signed(7 downto 0);
        o_next2           : out signed(7 downto 0);
        o_next3           : out signed(7 downto 0); -- Valido solo per ordine 5

        o_wru_done        : out std_logic;                  -- Segnale di completamento lettura finestra

        -- Interfaccia con MCU (WRU è il master, MCU è lo slave)
        o_mcu_start_req   : out std_logic;                  -- Richiesta di operazione a MCU
        i_mcu_done_ack    : in  std_logic;                  -- Done da MCU
        o_mcu_addr_req    : out std_logic_vector(15 downto 0); -- Indirizzo per MCU
        o_mcu_write_flag  : out std_logic;                  -- Sempre '0' per WRU (lettura)
        i_mcu_data_read   : in  std_logic_vector(7 downto 0) -- Dato letto da MCU
    );
end entity Window_Reader_Unit;
architecture Behavioral of Window_Reader_Unit is

    -- Stati della FSM interna
    type state_type is (
        IDLE,
        READ_PREV3, WAIT_PREV3, -- Solo per ordine 5
        READ_PREV2, WAIT_PREV2,
        READ_PREV1, WAIT_PREV1,
        READ_CURRENT_W, WAIT_CURRENT_W,
        READ_NEXT1, WAIT_NEXT1,
        READ_NEXT2, WAIT_NEXT2,
        READ_NEXT3, WAIT_NEXT3, -- Solo per ordine 5
        DONE_WRU_OP
    );
    signal current_state : state_type := IDLE;

    -- Registri interni per memorizzare i dati della finestra
    signal s_prev3_reg      : signed(7 downto 0) := (others => '0');
    signal s_prev2_reg      : signed(7 downto 0) := (others => '0');
    signal s_prev1_reg      : signed(7 downto 0) := (others => '0');
    signal s_current_W_reg  : signed(7 downto 0) := (others => '0');
    signal s_next1_reg      : signed(7 downto 0) := (others => '0');
    signal s_next2_reg      : signed(7 downto 0) := (others => '0');
    signal s_next3_reg      : signed(7 downto 0) := (others => '0');

    -- Segnali di controllo per MCU (output di WRU, input di MCU)
    signal s_mcu_start_req_int : std_logic := '0';
    signal s_mcu_addr_req_int  : std_logic_vector(15 downto 0) := (others => '0');
    signal s_wru_done_int      : std_logic := '0';

begin

    process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            current_state <= IDLE;
            s_prev3_reg <= (others => '0');
            s_prev2_reg <= (others => '0');
            s_prev1_reg <= (others => '0');
            s_current_W_reg <= (others => '0');
            s_next1_reg <= (others => '0');
            s_next2_reg <= (others => '0');
            s_next3_reg <= (others => '0');
            s_mcu_start_req_int <= '0';
            s_mcu_addr_req_int <= (others => '0');
            s_wru_done_int <= '0';

        elsif rising_edge(i_clk) then
            -- Default assignments
            s_mcu_start_req_int <= '0';  -- Rilascia la richiesta MCU di default
            s_wru_done_int      <= '0';  -- Resetta il done di default

            case current_state is
                when IDLE =>
                    if i_start_wru = '1' then
                        -- A seconda dell'ordine del filtro, inizia a leggere dal punto giusto
                        if i_filter_order_s = '1' then -- Ordine 5
                            current_state <= READ_PREV3;
                        else -- Ordine 3
                            current_state <= READ_PREV2;
                        end if;
                    end if;

                -- FSM per la lettura sequenziale
                -- Ogni stato READ_X chiede a MCU, ogni stato WAIT_X attende la risposta

                when READ_PREV3 => -- Solo ordine 5
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) - 3);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_PREV3;
                when WAIT_PREV3 =>
                    if i_mcu_done_ack = '1' then
                        s_prev3_reg <= signed(i_mcu_data_read);
                        current_state <= READ_PREV2;
                    end if;

                when READ_PREV2 =>
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) - 2);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_PREV2;
                when WAIT_PREV2 =>
                    if i_mcu_done_ack = '1' then
                        s_prev2_reg <= signed(i_mcu_data_read);
                        current_state <= READ_PREV1;
                    end if;

                when READ_PREV1 =>
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) - 1);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_PREV1;
                when WAIT_PREV1 =>
                    if i_mcu_done_ack = '1' then
                        s_prev1_reg <= signed(i_mcu_data_read);
                        current_state <= READ_CURRENT_W;
                    end if;

                when READ_CURRENT_W =>
                    s_mcu_addr_req_int <= i_center_addr;
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_CURRENT_W;
                when WAIT_CURRENT_W =>
                    if i_mcu_done_ack = '1' then
                        s_current_W_reg <= signed(i_mcu_data_read);
                        current_state <= READ_NEXT1;
                    end if;

                when READ_NEXT1 =>
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) + 1);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_NEXT1;
                when WAIT_NEXT1 =>
                    if i_mcu_done_ack = '1' then
                        s_next1_reg <= signed(i_mcu_data_read);
                        current_state <= READ_NEXT2;
                    end if;

                when READ_NEXT2 =>
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) + 2);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_NEXT2;
                when WAIT_NEXT2 =>
                    if i_mcu_done_ack = '1' then
                        s_next2_reg <= signed(i_mcu_data_read);
                        if i_filter_order_s = '1' then -- Se è ordine 5, leggi anche next3
                            current_state <= READ_NEXT3;
                        else -- Se è ordine 3, hai finito
                            current_state <= DONE_WRU_OP;
                        end if;
                    end if;

                when READ_NEXT3 => -- Solo ordine 5
                    s_mcu_addr_req_int <= std_logic_vector(unsigned(i_center_addr) + 3);
                    s_mcu_start_req_int <= '1';
                    current_state <= WAIT_NEXT3;
                when WAIT_NEXT3 =>
                    if i_mcu_done_ack = '1' then
                        s_next3_reg <= signed(i_mcu_data_read);
                        current_state <= DONE_WRU_OP; -- Tutti i dati letti
                    end if;

                when DONE_WRU_OP =>
                    s_wru_done_int <= '1'; -- Segnala il completamento
                    if i_start_wru = '0' then -- Aspetta che la CU de-asserisca start
                        current_state <= IDLE;
                    end if;

                when others =>
                    current_state <= IDLE;
            end case;
        end if;
    end process;

    -- Assegnazione degli output dalle registrazioni interne
    o_prev3           <= s_prev3_reg;
    o_prev2           <= s_prev2_reg;
    o_prev1           <= s_prev1_reg;
    o_current_W       <= s_current_W_reg;
    o_next1           <= s_next1_reg;
    o_next2           <= s_next2_reg;
    o_next3           <= s_next3_reg;
    o_wru_done        <= s_wru_done_int;

    -- Connessione dell'interfaccia MCU
    o_mcu_start_req   <= s_mcu_start_req_int;
    o_mcu_addr_req    <= s_mcu_addr_req_int;
    o_mcu_write_flag  <= '0'; -- WRU esegue solo letture

end architecture Behavioral;












library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modulo Control Unit (CU)
-- ------------------------------------------------
-- orchestra tutte le interazioni tra i moduli
entity CU is
    port (
        i_clk       : in  std_logic;  -- Clock di sistema
        i_rst       : in  std_logic;  -- Reset asincrono
        i_start     : in  std_logic;  -- Segnale di avvio dal Top Module
        i_base_addr : in  std_logic_vector(15 downto 0); -- Indirizzo di partenza in memoria (dal Top Module)

        o_done     : out std_logic;  -- Segnale di completamento per il Top Module

        -- Interfaccia con MCU (CU è il master)
        o_mcu_start       : out std_logic;
        i_mcu_done        : in  std_logic;
        o_mcu_addr        : out std_logic_vector(15 downto 0);
        o_mcu_write_flag  : out std_logic;
        o_mcu_data_write  : out std_logic_vector(7 downto 0); -- Dato da scrivere a MCU
        i_mcu_data_read   : in  std_logic_vector(7 downto 0);  -- Dato letto da MCU

        -- Interfaccia con ALU3
        o_alu3_start      : out std_logic;
        i_alu3_done       : in  std_logic;
        o_alu3_cn2_3      : out signed(7 downto 0);
        o_alu3_cn1_3      : out signed(7 downto 0);
        o_alu3_cp1_3      : out signed(7 downto 0);
        o_alu3_cp2_3      : out signed(7 downto 0);
        o_alu3_prev2      : out signed(7 downto 0);
        o_alu3_prev1      : out signed(7 downto 0);
        o_alu3_next1      : out signed(7 downto 0);
        o_alu3_next2      : out signed(7 downto 0);
        i_alu3_result     : in  signed(7 downto 0);

        -- Interfaccia con ALU5
        o_alu5_start      : out std_logic;
        i_alu5_done       : in  std_logic;
        o_alu5_cn3_5      : out signed(7 downto 0);
        o_alu5_cn2_5      : out signed(7 downto 0);
        o_alu5_cn1_5      : out signed(7 downto 0);
        o_alu5_cp1_5      : out signed(7 downto 0);
        o_alu5_cp2_5      : out signed(7 downto 0);
        o_alu5_cp3_5      : out signed(7 downto 0);
        o_alu5_prev3      : out signed(7 downto 0);
        o_alu5_prev2      : out signed(7 downto 0);
        o_alu5_prev1      : out signed(7 downto 0);
        o_alu5_next1      : out signed(7 downto 0);
        o_alu5_next2      : out signed(7 downto 0);
        o_alu5_next3      : out signed(7 downto 0);
        i_alu5_result     : in  signed(7 downto 0);

        -- Interfaccia con CRU
        o_cru_start       : out std_logic;
        i_cru_done        : in  std_logic;
        i_cru_k           : in  std_logic_vector(15 downto 0);
        i_cru_s           : in  std_logic;
        i_cru_cn2_3       : in  signed(7 downto 0);
        i_cru_cn1_3       : in  signed(7 downto 0);
        i_cru_cp1_3       : in  signed(7 downto 0);
        i_cru_cp2_3       : in  signed(7 downto 0);
        i_cru_cn3_5       : in  signed(7 downto 0);
        i_cru_cn2_5       : in  signed(7 downto 0);
        i_cru_cn1_5       : in  signed(7 downto 0);
        i_cru_cp1_5       : in  signed(7 downto 0);
        i_cru_cp2_5       : in  signed(7 downto 0);
        i_cru_cp3_5       : in  signed(7 downto 0);
        i_cru_w1_addr     : in  std_logic_vector(15 downto 0);

        -- NUOVA INTERFACCIA con WRU
        o_wru_start       : out std_logic;
        i_wru_done        : in  std_logic;
        o_wru_center_addr : out std_logic_vector(15 downto 0);
        o_wru_filter_order_s : out std_logic;
        i_wru_prev3       : in  signed(7 downto 0);
        i_wru_prev2       : in  signed(7 downto 0);
        i_wru_prev1       : in  signed(7 downto 0);
        i_wru_current_W   : in  signed(7 downto 0);
        i_wru_next1       : in  signed(7 downto 0);
        i_wru_next2       : in  signed(7 downto 0);
        i_wru_next3       : in  signed(7 downto 0)
    );
end entity CU;

architecture Behavioral of CU is

    -- Definizione degli stati della FSM principale
    type main_state_type is (
        IDLE,
        CONFIG_READ, WAIT_CONFIG,
        START_WINDOW_READ, WAIT_WINDOW_READ,
        COMPUTE_FILTER, WAIT_ALU_DONE,
        WRITE_RESULT, WAIT_WRITE_RESULT,
        CHECK_LOOP_END,
        DONE_OPERATION
    );
    signal current_main_state : main_state_type := IDLE;

    -- Segnali di controllo per i moduli (registrati per stabilità)
    signal s_mcu_start_reg       : std_logic := '0';
    signal s_mcu_addr_reg        : std_logic_vector(15 downto 0) := (others => '0');
    signal s_mcu_write_flag_reg  : std_logic := '0';
    signal s_mcu_data_write_reg  : std_logic_vector(7 downto 0) := (others => '0');

    signal s_alu3_start_reg      : std_logic := '0';
    signal s_alu5_start_reg      : std_logic := '0';

    signal s_cru_start_reg       : std_logic := '0';

    signal s_wru_start_reg       : std_logic := '0';
    signal s_wru_center_addr_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal s_wru_filter_order_s_reg : std_logic := '0';

    -- Registri per i parametri letti da CRU (copie locali)
    signal s_k_val           : unsigned(15 downto 0) := (others => '0');
    signal s_s_val           : std_logic := '0';
    signal s_w1_addr_val     : std_logic_vector(15 downto 0) := (others => '0');

    -- Registri per i coefficienti (copie locali da CRU)
    signal s_c_n2_3_val : signed(7 downto 0)  := (others => '0');
    signal s_c_n1_3_val : signed(7 downto 0)  := (others => '0');
    signal s_c_p1_3_val : signed(7 downto 0)  := (others => '0');
    signal s_c_p2_3_val : signed(7 downto 0)  := (others => '0');
    
    signal s_c_n3_5_val : signed(7 downto 0)  := (others => '0');
    signal s_c_n2_5_val : signed(7 downto 0)  := (others => '0');
    signal s_c_n1_5_val : signed(7 downto 0)  := (others => '0');
    signal s_c_p1_5_val : signed(7 downto 0)  := (others => '0');
    signal s_c_p2_5_val : signed(7 downto 0)  := (others => '0');
    signal s_c_p3_5_val : signed(7 downto 0)  := (others => '0');
     
    -- Registri per i valori della finestra del filtro (copie locali da WRU)
    signal s_prev3_val : signed(7 downto 0)      := (others => '0');
    signal s_prev2_val : signed(7 downto 0)      := (others => '0');
    signal s_prev1_val : signed(7 downto 0)      := (others => '0');
    signal s_current_W_val : signed(7 downto 0)  := (others => '0');
    signal s_next1_val : signed(7 downto 0)      := (others => '0');
    signal s_next2_val : signed(7 downto 0)      := (others => '0');
    signal s_next3_val : signed(7 downto 0)      := (others => '0');
    
    -- Contatore per iterare sui dati W
    signal s_data_counter : integer := 0;  

    -- Segnale di output finale
    signal s_done_output : std_logic := '0';

begin
    
    process (i_clk, i_rst)
    begin
        if i_rst = '1' then
            current_main_state <= IDLE;
            s_done_output <= '0';
            s_mcu_start_reg <= '0';
            s_alu3_start_reg <= '0';
            s_alu5_start_reg <= '0';
            s_cru_start_reg <= '0';
            s_wru_start_reg <= '0';
            s_data_counter <= 0;
            -- Reset di tutti i registri interni che mantengono stato
            s_k_val <= (others => '0');
            s_s_val <= '0';
            s_w1_addr_val <= (others => '0');
            s_c_n2_3_val <= (others => '0'); s_c_n1_3_val <= (others => '0'); s_c_p1_3_val <= (others => '0'); s_c_p2_3_val <= (others => '0');
            s_c_n3_5_val <= (others => '0'); s_c_n2_5_val <= (others => '0'); s_c_n1_5_val <= (others => '0'); s_c_p1_5_val <= (others => '0'); s_c_p2_5_val <= (others => '0'); s_c_p3_5_val <= (others => '0');
            s_prev3_val <= (others => '0'); s_prev2_val <= (others => '0'); s_prev1_val <= (others => '0'); s_current_W_val <= (others => '0');
            s_next1_val <= (others => '0'); s_next2_val <= (others => '0'); s_next3_val <= (others => '0');

        elsif rising_edge(i_clk) then
            -- Default assignments per il prossimo ciclo
            s_done_output <= '0';
            s_mcu_start_reg <= '0';
            s_alu3_start_reg <= '0';
            s_alu5_start_reg <= '0';
            s_cru_start_reg <= '0';
            s_wru_start_reg <= '0'; -- Resetta la richiesta a WRU
            s_mcu_write_flag_reg <= '0'; -- Default a lettura per MCU
            s_mcu_data_write_reg <= (others => '0'); -- Default data to write

            case current_main_state is
                when IDLE =>
                    if i_start = '1' then
                        s_cru_start_reg <= '1'; -- Avvia la lettura della configurazione
                        current_main_state <= WAIT_CONFIG;
                    end if;

                when WAIT_CONFIG =>
                    s_cru_start_reg <= '0'; -- Rilascia la richiesta a CRU
                    if i_cru_done = '1' then
                        -- Copia i parametri letti da CRU nei registri locali del CU
                        s_k_val <= unsigned(i_cru_k);
                        s_s_val <= i_cru_s;
                        s_w1_addr_val <= i_cru_w1_addr;
                        s_c_n2_3_val <= i_cru_cn2_3; s_c_n1_3_val <= i_cru_cn1_3; s_c_p1_3_val <= i_cru_cp1_3; s_c_p2_3_val <= i_cru_cp2_3;
                        s_c_n3_5_val <= i_cru_cn3_5; s_c_n2_5_val <= i_cru_cn2_5; s_c_n1_5_val <= i_cru_cn1_5; s_c_p1_5_val <= i_cru_cp1_5; s_c_p2_5_val <= i_cru_cp2_5; s_c_p3_5_val <= i_cru_cp3_5;
                        
                        s_data_counter <= 0; -- Resetta il contatore dati per l'inizio del filtro
                        current_main_state <= START_WINDOW_READ; -- Inizia la lettura della prima finestra
                    end if;

                when START_WINDOW_READ =>
                    -- Avvia la lettura della finestra da WRU
                    s_wru_start_reg <= '1';
                    s_wru_center_addr_reg <= std_logic_vector(unsigned(s_w1_addr_val) + to_unsigned(s_data_counter, 16)); -- Indirizzo del corrente W
                    s_wru_filter_order_s_reg <= s_s_val;
                    current_main_state <= WAIT_WINDOW_READ;

                when WAIT_WINDOW_READ =>
                    s_wru_start_reg <= '0'; -- Rilascia la richiesta a WRU
                    if i_wru_done = '1' then
                        -- Copia i dati della finestra letti da WRU nei registri locali del CU
                        s_prev3_val <= i_wru_prev3;
                        s_prev2_val <= i_wru_prev2;
                        s_prev1_val <= i_wru_prev1;
                        s_current_W_val <= i_wru_current_W;
                        s_next1_val <= i_wru_next1;
                        s_next2_val <= i_wru_next2;
                        s_next3_val <= i_wru_next3;
                        
                        current_main_state <= COMPUTE_FILTER; -- Passa al calcolo del filtro
                    end if;
                
                when COMPUTE_FILTER =>
                    -- Seleziona l'ALU e avvia il calcolo, passando i dati della finestra e i coefficienti
                    if s_s_val = '0' then -- Ordine 3
                        s_alu3_start_reg <= '1';
                        o_alu3_cn2_3 <= s_c_n2_3_val; o_alu3_cn1_3 <= s_c_n1_3_val;
                        o_alu3_cp1_3 <= s_c_p1_3_val; o_alu3_cp2_3 <= s_c_p2_3_val;
                        o_alu3_prev2 <= s_prev2_val; o_alu3_prev1 <= s_prev1_val;
                        o_alu3_next1 <= s_next1_val; o_alu3_next2 <= s_next2_val;
                    else -- Ordine 5
                        s_alu5_start_reg <= '1';
                        o_alu5_cn3_5 <= s_c_n3_5_val; o_alu5_cn2_5 <= s_c_n2_5_val; o_alu5_cn1_5 <= s_c_n1_5_val;
                        o_alu5_cp1_5 <= s_c_p1_5_val; o_alu5_cp2_5 <= s_c_p2_5_val; o_alu5_cp3_5 <= s_c_p3_5_val;
                        o_alu5_prev3 <= s_prev3_val; o_alu5_prev2 <= s_prev2_val; o_alu5_prev1 <= s_prev1_val;
                        o_alu5_next1 <= s_next1_val; o_alu5_next2 <= s_next2_val; o_alu5_next3 <= s_next3_val;
                    end if;
                    current_main_state <= WAIT_ALU_DONE; -- Aspetta il done della ALU

                when WAIT_ALU_DONE =>
                    -- Aspetta il completamento dell'ALU
                    if (s_s_val = '0' and i_alu3_done = '1') or (s_s_val = '1' and i_alu5_done = '1') then
                        current_main_state <= WRITE_RESULT; -- L'ALU ha finito, scrivi il risultato
                    end if;

                when WRITE_RESULT =>
                    -- Scrivi il risultato del filtro in memoria tramite MCU
                    s_mcu_write_flag_reg <= '1'; -- Scrittura
                    s_mcu_addr_reg <= std_logic_vector(unsigned(s_w1_addr_val) + s_k_val + to_unsigned(s_data_counter, 16));
                    if s_s_val = '0' then
                        s_mcu_data_write_reg <= std_logic_vector(i_alu3_result);
                    else
                        s_mcu_data_write_reg <= std_logic_vector(i_alu5_result);
                    end if;
                    s_mcu_start_reg <= '1'; -- Avvia la scrittura MCU
                    current_main_state <= WAIT_WRITE_RESULT;

                when WAIT_WRITE_RESULT =>
                    s_mcu_start_reg <= '0'; -- Rilascia la richiesta MCU
                    if i_mcu_done = '1' then
                        s_data_counter <= s_data_counter + 1; -- Incrementa il contatore dei dati processati
                        current_main_state <= CHECK_LOOP_END; -- Controlla se il loop è finito
                    end if;

                when CHECK_LOOP_END =>
                    if s_data_counter = to_integer(s_k_val) then -- Se tutti i dati sono stati processati
                        current_main_state <= DONE_OPERATION;
                    else
                        current_main_state <= START_WINDOW_READ; -- Altrimenti, leggi la prossima finestra
                    end if;

                when DONE_OPERATION =>
                    s_done_output <= '1'; -- Segnale di completamento per il Top Module
                    if i_start = '0' then -- Aspetta che il Top Module de-asserisca start
                        current_main_state <= IDLE;
                    end if;

                when others =>
                    current_main_state <= IDLE; -- Stato di fallback
            end case;
        end if;
    end process;

    -- Assegnazione delle uscite del Control Unit
    o_done <= s_done_output;

    o_mcu_start <= s_mcu_start_reg;
    o_mcu_addr <= s_mcu_addr_reg;
    o_mcu_write_flag <= s_mcu_write_flag_reg;
    o_mcu_data_write <= s_mcu_data_write_reg;
    --i_mcu_data_read <= i_mcu_data_read; -- Pass-through per il dato letto da MCU verso il CU

    o_alu3_start <= s_alu3_start_reg;
    o_alu3_cn2_3 <= s_c_n2_3_val; o_alu3_cn1_3 <= s_c_n1_3_val;
    o_alu3_cp1_3 <= s_c_p1_3_val; o_alu3_cp2_3 <= s_c_p2_3_val;
    o_alu3_prev2 <= s_prev2_val; o_alu3_prev1 <= s_prev1_val;
    o_alu3_next1 <= s_next1_val; o_alu3_next2 <= s_next2_val;

    o_alu5_start <= s_alu5_start_reg;
    o_alu5_cn3_5 <= s_c_n3_5_val; o_alu5_cn2_5 <= s_c_n2_5_val; o_alu5_cn1_5 <= s_c_n1_5_val;
    o_alu5_cp1_5 <= s_c_p1_5_val; o_alu5_cp2_5 <= s_c_p2_5_val; o_alu5_cp3_5 <= s_c_p3_5_val;
    o_alu5_prev3 <= s_prev3_val; o_alu5_prev2 <= s_prev2_val; o_alu5_prev1 <= s_prev1_val;
    o_alu5_next1 <= s_next1_val; o_alu5_next2 <= s_next2_val; o_alu5_next3 <= s_next3_val;

    o_cru_start <= s_cru_start_reg;

    -- Connessione delle uscite WRU
    o_wru_start <= s_wru_start_reg;
    o_wru_center_addr <= s_wru_center_addr_reg;
    o_wru_filter_order_s <= s_wru_filter_order_s_reg;

end architecture Behavioral;









library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Top Module con stessa interfaccia del modulo monolitico originale
-- ----------------------------------------------------
entity project_reti_logiche is
    port (
        i_clk      : in std_logic;
        i_rst      : in std_logic;
        i_start    : in std_logic;
        i_add      : in std_logic_vector(15 downto 0); -- Rinominato per chiarezza, prima era 'base_address'

        o_done     : out std_logic;

        -- Interfaccia verso la MEMORIA ESTERNA (che prima era gestita dalla tua MCU interna)
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic; -- Write Enable (se '1' è scrittura, se '0' è lettura)
        o_mem_en   : out std_logic  -- Memory Enable (attiva la comunicazione con la memoria)
    );
end entity project_reti_logiche;

architecture Structural of project_reti_logiche is

    -- Segnali interni per le interconnessioni tra i moduli
    
    signal s_mcu_start_cu      : std_logic; -- Sarà mappato a o_mem_en
    signal s_mcu_addr_cu       : std_logic_vector(15 downto 0); -- Sarà mappato a o_mem_addr
    signal s_mcu_write_flag_cu : std_logic; -- Sarà mappato a o_mem_we
    signal s_mcu_data_write_cu : std_logic_vector(7 downto 0); -- Sarà mappato a o_mem_data

    signal s_mcu_start_wru     : std_logic; -- Sarà mappato a o_mem_en
    signal s_mcu_addr_wru      : std_logic_vector(15 downto 0); -- Sarà mappato a o_mem_addr
    signal s_mcu_write_flag_wru: std_logic; -- Sarà mappato a o_mem_we (sempre '0' per WRU)

    -- Il segnale 'done' della memoria (prima 's_mcu_done_from_mcu') sarà l'ACK dalla memoria esterna
    signal s_mem_done_ack      : std_logic;
    signal s_mem_data_read     : std_logic_vector(7 downto 0); -- Data letto dalla memoria esterna


    -- Segnali CRU
    signal s_cru_start         : std_logic;
    signal s_cru_done          : std_logic;
    signal s_cru_k             : std_logic_vector(15 downto 0);
    signal s_cru_s             : std_logic;
    signal s_cru_cn2_3         : signed(7 downto 0);
    signal s_cru_cn1_3         : signed(7 downto 0);
    signal s_cru_cp1_3         : signed(7 downto 0);
    signal s_cru_cp2_3         : signed(7 downto 0);
    signal s_cru_cn3_5         : signed(7 downto 0);
    signal s_cru_cn2_5         : signed(7 downto 0);
    signal s_cru_cn1_5         : signed(7 downto 0);
    signal s_cru_cp1_5         : signed(7 downto 0);
    signal s_cru_cp2_5         : signed(7 downto 0);
    signal s_cru_cp3_5         : signed(7 downto 0);
    signal s_cru_w1_addr       : std_logic_vector(15 downto 0);

    -- Segnali ALU3
    signal s_alu3_start        : std_logic;
    signal s_alu3_done         : std_logic;
    signal s_alu3_cn2_3        : signed(7 downto 0);
    signal s_alu3_cn1_3        : signed(7 downto 0);
    signal s_alu3_cp1_3        : signed(7 downto 0);
    signal s_alu3_cp2_3        : signed(7 downto 0);
    signal s_alu3_prev2        : signed(7 downto 0);
    signal s_alu3_prev1        : signed(7 downto 0);
    signal s_alu3_next1        : signed(7 downto 0);
    signal s_alu3_next2        : signed(7 downto 0);
    signal s_alu3_result       : signed(7 downto 0);

    -- Segnali ALU5
    signal s_alu5_start        : std_logic;
    signal s_alu5_done         : std_logic;
    signal s_alu5_cn3_5        : signed(7 downto 0);
    signal s_alu5_cn2_5        : signed(7 downto 0);
    signal s_alu5_cn1_5        : signed(7 downto 0);
    signal s_alu5_cp1_5        : signed(7 downto 0);
    signal s_alu5_cp2_5        : signed(7 downto 0);
    signal s_alu5_cp3_5        : signed(7 downto 0);
    signal s_alu5_prev3        : signed(7 downto 0);
    signal s_alu5_prev2        : signed(7 downto 0);
    signal s_alu5_prev1        : signed(7 downto 0);
    signal s_alu5_next1        : signed(7 downto 0);
    signal s_alu5_next2        : signed(7 downto 0);
    signal s_alu5_next3        : signed(7 downto 0);
    signal s_alu5_result       : signed(7 downto 0);

    -- Segnali WRU
    signal s_wru_start_cu      : std_logic;
    signal s_wru_done          : std_logic;
    signal s_wru_center_addr_cu : std_logic_vector(15 downto 0);
    signal s_wru_filter_order_s_cu : std_logic;
    signal s_wru_prev3_out     : signed(7 downto 0);
    signal s_wru_prev2_out     : signed(7 downto 0);
    signal s_wru_prev1_out     : signed(7 downto 0);
    signal s_wru_current_W_out : signed(7 downto 0);
    signal s_wru_next1_out     : signed(7 downto 0);
    signal s_wru_next2_out     : signed(7 downto 0);
    signal s_wru_next3_out     : signed(7 downto 0);

    -- Componente CRU (Configuration Reader Unit)
    component CRU is
        port (
            i_clk       : in  std_logic;
            i_rst       : in  std_logic;
            i_start     : in  std_logic;
            o_done      : out std_logic;
            o_k         : out std_logic_vector(15 downto 0);    -- Lunghezza della sequenza W
            o_s         : out std_logic;                      -- Ordine del filtro ('0' per 3, '1' per 5)
            o_cn2_3     : out signed(7 downto 0);
            o_cn1_3     : out signed(7 downto 0);
            o_cp1_3     : out signed(7 downto 0);
            o_cp2_3     : out signed(7 downto 0);
            o_cn3_5     : out signed(7 downto 0);
            o_cn2_5     : out signed(7 downto 0);
            o_cn1_5     : out signed(7 downto 0);
            o_cp1_5     : out signed(7 downto 0);
            o_cp2_5     : out signed(7 downto 0);
            o_cp3_5     : out signed(7 downto 0);
            o_w1_addr   : out std_logic_vector(15 downto 0)   -- Indirizzo di partenza per la sequenza W
        );
    end component;

    -- Componente ALU3 (Arithmetic Logic Unit per Ordine 3)
    component ALU3 is
        port (
            i_clk       : in  std_logic;
            i_rst       : in  std_logic;
            i_start     : in  std_logic;
            o_done      : out std_logic;
            i_cn2       : in  signed(7 downto 0);
            i_cn1       : in  signed(7 downto 0);
            i_cp1       : in  signed(7 downto 0);
            i_cp2       : in  signed(7 downto 0);
            i_prev2     : in  signed(7 downto 0);
            i_prev1     : in  signed(7 downto 0);
            i_next1     : in  signed(7 downto 0);
            i_next2     : in  signed(7 downto 0);
            o_result    : out signed(7 downto 0)
        );
    end component;

    -- Componente ALU5 (Arithmetic Logic Unit per Ordine 5)
    component ALU5 is
        port (
            i_clk       : in  std_logic;
            i_rst       : in  std_logic;
            i_start     : in  std_logic;
            o_done      : out std_logic;
            i_cn3       : in  signed(7 downto 0);
            i_cn2       : in  signed(7 downto 0);
            i_cn1       : in  signed(7 downto 0);
            i_cp1       : in  signed(7 downto 0);
            i_cp2       : in  signed(7 downto 0);
            i_cp3       : in  signed(7 downto 0);
            i_prev3     : in  signed(7 downto 0);
            i_prev2     : in  signed(7 downto 0);
            i_prev1     : in  signed(7 downto 0);
            i_next1     : in  signed(7 downto 0);
            i_next2     : in  signed(7 downto 0);
            i_next3     : in  signed(7 downto 0);
            o_result    : out signed(7 downto 0)
        );
    end component;

    -- Componente Window_Reader_Unit (WRU)
    component Window_Reader_Unit is
        port (
            i_clk             : in  std_logic;
            i_rst             : in  std_logic;
            i_start_wru       : in  std_logic;                  -- Avvia la lettura della finestra
            i_center_addr     : in  std_logic_vector(15 downto 0); -- L'indirizzo del valore centrale (W(i))
            i_filter_order_s  : in  std_logic;                  -- '0' per ordine 3, '1' per ordine 5

            -- Output dei dati della finestra
            o_prev3           : out signed(7 downto 0);
            o_prev2           : out signed(7 downto 0);
            o_prev1           : out signed(7 downto 0);
            o_current_W       : out signed(7 downto 0);
            o_next1           : out signed(7 downto 0);
            o_next2           : out signed(7 downto 0);
            o_next3           : out signed(7 downto 0);

            o_wru_done        : out std_logic;                  -- Segnale di completamento lettura finestra

            -- Interfaccia con MCU (WRU è il master, MCU è lo slave)
            o_mcu_start_req   : out std_logic;
            i_mcu_done_ack    : in  std_logic;
            o_mcu_addr_req    : out std_logic_vector(15 downto 0);
            o_mcu_write_flag  : out std_logic;
            i_mcu_data_read   : in  std_logic_vector(7 downto 0)
        );
    end component;

    -- Componente CU (Control Unit)
    component CU is
        port (
            i_clk      : in  std_logic;
            i_rst      : in  std_logic;
            i_start    : in  std_logic;
            i_base_addr : in  std_logic_vector(15 downto 0);

            o_done     : out std_logic;

            -- Interfaccia con MCU (CU è il master, WRU è lo slave per le letture della finestra)
            o_mcu_start       : out std_logic;
            i_mcu_done        : in  std_logic;
            o_mcu_addr        : out std_logic_vector(15 downto 0);
            o_mcu_write_flag  : out std_logic;
            o_mcu_data_write  : out std_logic_vector(7 downto 0);
            i_mcu_data_read   : in  std_logic_vector(7 downto 0);

            -- Interfaccia con ALU3
            o_alu3_start      : out std_logic;
            i_alu3_done       : in  std_logic;
            o_alu3_cn2_3      : out signed(7 downto 0);
            o_alu3_cn1_3      : out signed(7 downto 0);
            o_alu3_cp1_3      : out signed(7 downto 0);
            o_alu3_cp2_3      : out signed(7 downto 0);
            o_alu3_prev2      : out signed(7 downto 0);
            o_alu3_prev1      : out signed(7 downto 0);
            o_alu3_next1      : out signed(7 downto 0);
            o_alu3_next2      : out signed(7 downto 0);
            i_alu3_result     : in  signed(7 downto 0);

            -- Interfaccia con ALU5
            o_alu5_start      : out std_logic;
            i_alu5_done       : in  std_logic;
            o_alu5_cn3_5      : out signed(7 downto 0);
            o_alu5_cn2_5      : out signed(7 downto 0);
            o_alu5_cn1_5      : out signed(7 downto 0);
            o_alu5_cp1_5      : out signed(7 downto 0);
            o_alu5_cp2_5      : out signed(7 downto 0);
            o_alu5_cp3_5      : out signed(7 downto 0);
            o_alu5_prev3      : out signed(7 downto 0);
            o_alu5_prev2      : out signed(7 downto 0);
            o_alu5_prev1      : out signed(7 downto 0);
            o_alu5_next1      : out signed(7 downto 0);
            o_alu5_next2      : out signed(7 downto 0);
            o_alu5_next3      : out signed(7 downto 0);
            i_alu5_result     : in  signed(7 downto 0);

            -- Interfaccia con CRU
            o_cru_start       : out std_logic;
            i_cru_done        : in  std_logic;
            i_cru_k           : in  std_logic_vector(15 downto 0);
            i_cru_s           : in  std_logic;
            i_cru_cn2_3       : in  signed(7 downto 0);
            i_cru_cn1_3       : in  signed(7 downto 0);
            i_cru_cp1_3       : in  signed(7 downto 0);
            i_cru_cp2_3       : in  signed(7 downto 0);
            i_cru_cn3_5       : in  signed(7 downto 0);
            i_cru_cn2_5       : in  signed(7 downto 0);
            i_cru_cn1_5       : in  signed(7 downto 0);
            i_cru_cp1_5       : in  signed(7 downto 0);
            i_cru_cp2_5       : in  signed(7 downto 0);
            i_cru_cp3_5       : in  signed(7 downto 0);
            i_cru_w1_addr     : in  std_logic_vector(15 downto 0);

            -- Interfaccia con WRU
            o_wru_start       : out std_logic;
            i_wru_done        : in  std_logic;
            o_wru_center_addr : out std_logic_vector(15 downto 0);
            o_wru_filter_order_s : out std_logic;
            i_wru_prev3       : in  signed(7 downto 0);
            i_wru_prev2       : in  signed(7 downto 0);
            i_wru_prev1       : in  signed(7 downto 0);
            i_wru_current_W   : in  signed(7 downto 0);
            i_wru_next1       : in  signed(7 downto 0);
            i_wru_next2       : in  signed(7 downto 0);
            i_wru_next3       : in  signed(7 downto 0)
        );
    end component;



begin

    -- Istanziazione dei Moduli
    -- -------------------------

    -- Istanziazione della Configuration Reader Unit (CRU)
    CRU_INST : CRU
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start     => s_cru_start,
        o_done      => s_cru_done,
        o_k         => s_cru_k,
        o_s         => s_cru_s,
        o_cn2_3     => s_cru_cn2_3,
        o_cn1_3     => s_cru_cn1_3,
        o_cp1_3     => s_cru_cp1_3,
        o_cp2_3     => s_cru_cp2_3,
        o_cn3_5     => s_cru_cn3_5,
        o_cn2_5     => s_cru_cn2_5,
        o_cn1_5     => s_cru_cn1_5,
        o_cp1_5     => s_cru_cp1_5,
        o_cp2_5     => s_cru_cp2_5,
        o_cp3_5     => s_cru_cp3_5,
        o_w1_addr   => s_cru_w1_addr
    );

    -- Istanziazione della Window Reader Unit (WRU)
    WRU_INST : Window_Reader_Unit
    port map (
        i_clk             => i_clk,
        i_rst             => i_rst,
        i_start_wru       => s_wru_start_cu,
        i_center_addr     => s_wru_center_addr_cu,
        i_filter_order_s  => s_wru_filter_order_s_cu,
        o_prev3           => s_wru_prev3_out,
        o_prev2           => s_wru_prev2_out,
        o_prev1           => s_wru_prev1_out,
        o_current_W       => s_wru_current_W_out,
        o_next1           => s_wru_next1_out,
        o_next2           => s_wru_next2_out,
        o_next3           => s_wru_next3_out,
        o_wru_done        => s_wru_done,
        o_mcu_start_req   => s_mcu_start_wru,
        i_mcu_done_ack    => s_mem_done_ack,
        o_mcu_addr_req    => s_mcu_addr_wru,
        o_mcu_write_flag  => s_mcu_write_flag_wru,
        i_mcu_data_read   => s_mem_data_read
    );

    -- Istanziazione dell'ALU3
    ALU3_INST : ALU3
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start     => s_alu3_start,
        o_done      => s_alu3_done,
        i_cn2       => s_alu3_cn2_3,
        i_cn1       => s_alu3_cn1_3,
        i_cp1       => s_alu3_cp1_3,
        i_cp2       => s_alu3_cp2_3,
        i_prev2     => s_alu3_prev2,
        i_prev1     => s_alu3_prev1,
        i_next1     => s_alu3_next1,
        i_next2     => s_alu3_next2,
        o_result    => s_alu3_result
    );

    -- Istanziazione dell'ALU5
    ALU5_INST : ALU5
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start     => s_alu5_start,
        o_done      => s_alu5_done,
        i_cn3       => s_alu5_cn3_5,
        i_cn2       => s_alu5_cn2_5,
        i_cn1       => s_alu5_cn1_5,
        i_cp1       => s_alu5_cp1_5,
        i_cp2       => s_alu5_cp2_5,
        i_cp3       => s_alu5_cp3_5,
        i_prev3     => s_alu5_prev3,
        i_prev2     => s_alu5_prev2,
        i_prev1     => s_alu5_prev1,
        i_next1     => s_alu5_next1,
        i_next2     => s_alu5_next2,
        i_next3     => s_alu5_next3,
        o_result    => s_alu5_result
    );

    -- Istanziazione della Control Unit (CU)
    CU_INST : CU
    port map (
        i_clk      => i_clk,
        i_rst      => i_rst,
        i_start    => i_start,      -- Start esterno al CU
        i_base_addr => i_add, -- Indirizzo base esterno al CU
        o_done     => o_done,      -- Done del CU all'esterno

        -- Connessioni MCU (CU come master, i suoi segnali andranno al multiplexer)
        o_mcu_start       => s_mcu_start_cu,
        i_mcu_done        => s_mem_done_ack,     -- Done da memoria esterna
        o_mcu_addr        => s_mcu_addr_cu,
        o_mcu_write_flag  => s_mcu_write_flag_cu,
        o_mcu_data_write  => s_mcu_data_write_cu,
        i_mcu_data_read   => s_mem_data_read,    -- Data letto da memoria esterna

        -- Connessioni ALU3
        o_alu3_start      => s_alu3_start,
        i_alu3_done       => s_alu3_done,
        o_alu3_cn2_3      => s_alu3_cn2_3,
        o_alu3_cn1_3      => s_alu3_cn1_3,
        o_alu3_cp1_3      => s_alu3_cp1_3,
        o_alu3_cp2_3      => s_alu3_cp2_3,
        o_alu3_prev2      => s_alu3_prev2,
        o_alu3_prev1      => s_alu3_prev1,
        o_alu3_next1      => s_alu3_next1,
        o_alu3_next2      => s_alu3_next2,
        i_alu3_result     => s_alu3_result,

        -- Connessioni ALU5
        o_alu5_start      => s_alu5_start,
        i_alu5_done       => s_alu5_done,
        o_alu5_cn3_5      => s_alu5_cn3_5,
        o_alu5_cn2_5      => s_alu5_cn2_5,
        o_alu5_cn1_5      => s_alu5_cn1_5,
        o_alu5_cp1_5      => s_alu5_cp1_5,
        o_alu5_cp2_5      => s_alu5_cp2_5,
        o_alu5_cp3_5      => s_alu5_cp3_5,
        o_alu5_prev3      => s_alu5_prev3,
        o_alu5_prev2      => s_alu5_prev2,
        o_alu5_prev1      => s_alu5_prev1,
        o_alu5_next1      => s_alu5_next1,
        o_alu5_next2      => s_alu5_next2,
        o_alu5_next3      => s_alu5_next3,
        i_alu5_result     => s_alu5_result,

        -- Connessioni CRU
        o_cru_start       => s_cru_start,
        i_cru_done        => s_cru_done,
        i_cru_k           => s_cru_k,
        i_cru_s           => s_cru_s,
        i_cru_cn2_3       => s_cru_cn2_3,
        i_cru_cn1_3       => s_cru_cn1_3,
        i_cru_cp1_3       => s_cru_cp1_3,
        i_cru_cp2_3       => s_cru_cp2_3,
        i_cru_cn3_5       => s_cru_cn3_5,
        i_cru_cn2_5       => s_cru_cn2_5,
        i_cru_cn1_5       => s_cru_cn1_5,
        i_cru_cp1_5       => s_cru_cp1_5,
        i_cru_cp2_5       => s_cru_cp2_5,
        i_cru_cp3_5       => s_cru_cp3_5,
        i_cru_w1_addr     => s_cru_w1_addr,

        -- Connessioni WRU
        o_wru_start       => s_wru_start_cu,
        i_wru_done        => s_wru_done,
        o_wru_center_addr => s_wru_center_addr_cu,
        o_wru_filter_order_s => s_wru_filter_order_s_cu,
        i_wru_prev3       => s_wru_prev3_out,
        i_wru_prev2       => s_wru_prev2_out,
        i_wru_prev1       => s_wru_prev1_out,
        i_wru_current_W   => s_wru_current_W_out,
        i_wru_next1       => s_wru_next1_out,
        i_wru_next2       => s_wru_next2_out,
        i_wru_next3       => s_wru_next3_out
    );


    -- Logica per il Multiplexer della MCU
    -- La MCU è uno slave. CU e WRU possono essere master della MCU.
    -- Dobbiamo prioritizzare o permettere una coesistenza (es. non si accavallano mai le richieste).
    -- Assumiamo che CU e WRU non richiedano la MCU contemporaneamente.
    -- Se la CU sta scrivendo (write_flag = '1'), ha la priorità per indirizzo e dati da scrivere.
    -- Se la WRU sta leggendo (write_flag = '0'), ha la priorità per indirizzo.

    -- Priorità: Se la CU sta scrivendo, i suoi segnali hanno la priorità.
    -- Altrimenti, se la WRU sta richiedendo, i suoi segnali hanno la priorità.
    -- Se nessuno dei due sta richiedendo, i segnali sono a 0 (o valori di default).

    process (s_mcu_start_cu, s_mcu_start_wru, s_mcu_write_flag_cu,
             s_mcu_addr_cu, s_mcu_data_write_cu, s_mcu_addr_wru, s_mcu_write_flag_wru)
    begin
        o_mem_en   <= '0'; -- Inizialmente disabilitata
        o_mem_addr <= (others => '0');
        o_mem_we   <= '0'; -- Default a lettura
        o_mem_data <= (others => '0'); -- Default data da scrivere a 0

        if s_mcu_start_cu = '1' then
            o_mem_en   <= '1';
            o_mem_addr <= s_mcu_addr_cu;
            o_mem_we   <= s_mcu_write_flag_cu;
            o_mem_data <= s_mcu_data_write_cu;
        elsif s_mcu_start_wru = '1' then
            o_mem_en   <= '1';
            o_mem_addr <= s_mcu_addr_wru;
            o_mem_we   <= s_mcu_write_flag_wru; -- WRU imposta sempre a '0' per lettura
            -- o_mem_data rimane a (others => '0') perché WRU non scrive
        end if;
    end process;

     -- Collegamento del dato letto dalla memoria esterna
    -- Il dato letto dalla memoria esterna (i_mem_data) viene passato ai moduli interni
    s_mem_data_read <= i_mem_data;


end architecture Structural;
