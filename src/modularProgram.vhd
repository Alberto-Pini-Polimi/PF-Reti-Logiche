library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- Modulo di Reset
-- ----------------------------------------------------
entity Reset is
    port (
        rst : in STD_LOGIC;
        clk : in STD_LOGIC;
        ??
    );
end entity Reset;

architecture Behavioral of Reset is
begin
    ???
end architecture Behavioral;







-- Modulo di Memory Controller Unit (MCU)
-- ----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
entity ALU3 is
    port (
        i_clk : in STD_LOGIC;
        i_rst : in STD_LOGIC;
        i_start_alu3 : in STD_LOGIC;

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
            s_result_alu3_reg <= (others => '0');
            s_done_alu3_reg   <= '0';
            
        -- altrimenti
        elsif rising_edge(i_clk) then
            -- Reset del segnale done ad ogni ciclo, a meno che non sia attivato di nuovo
            s_done_alu3_reg <= '0';

            if i_start_alu3 = '1' then
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










































-- Modulo di Control Unit (CU)
-- ----------------------------------------------------
entity CU is
    port (
        rst : in STD_LOGIC;
        clk : in STD_LOGIC;
        
    );
end entity CU;

architecture Behavioral of CU is
begin
    macchina a stati
end architecture Behavioral;


