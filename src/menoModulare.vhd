library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Metadata Reader Unit (MdRU) per leggere k e s
-- ----------------------------------------------------
entity MdRU is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start_read : in std_logic; -- segnale dalla CU per iniziare a leggere
        i_base_addr : in std_logic_vector(15 downto 0);

        o_k : out unsigned(15 downto 0);
        o_s : out std_logic;
        o_read_done : out std_logic; -- segnale per la CU di fine lettura
        -- potrei considerare di mettere in output anche l'address finale di memoria giusto per non portarmi sempre dietro quel +3 o successivamente il +17

        -- segnali per l'utilizzo della memoria (in sola lettura)
        o_mem_addr : out std_logic_vector(15 downto 0); -- l'indirizzo di memoria dove scrivere
        o_mem_en : out std_logic; -- non metto _we dato che non devo mai scrivere
        i_mem_data : in std_logic_vector(7 downto 0); -- il dato in uscita dalla memoria
    );
end entity MdRU;
architecture Behavioral of MdRU is

    -- Qui devo fare una piccola macchiana a stati in grado di leggere s, k1 e k2
    type state_type is (IDLE, READ_K1, WAIT_K1, READ_K2, WAIT_K2, READ_S, WAIT_S, READ_DONE);
    signal current_state : state_type

    signal s_k1 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_k2 : std_logic_vector(7 downto 0) := (others => '0');
    signal s_k  : unsigned(15 downto 0) := to_unsigned(0, 16);
    signal s_s : std_logic := '0';

begin

    process (i_clk, i_rst) is

        -- per unire i segnali di k1 e k2 in k
        variable v_k : std_logic_vector(15 downto 0) := (others => '0');

    begin

        if i_rst = '1' then
            current_state <= IDLE;
            s_k1 <= (others => '0');
            s_k2 <= (others => '0');
            s_s <= '0';

        elsif rising_edge(i_clk) then

            case current_state is
                when IDLE =>
                    s_read_done <= '0';
                    -- aspetto che la CU mi dia il permesso di partire
                    if i_start_read = '1' then
                        current_state <= READ_K1;
                    end if;

                when READ_K1 =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 1);
                    current_state <= WAIT_K1;

                when WAIT_K1 =>
                    s_k1 <= i_mem_data;
                    current_state <= READ_K2;

                when READ_K2 =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 2);
                    current_state <= WAIT_K2;

                when WAIT_K2 =>
                    s_k2 <= i_mem_data;
                    current_state <= READ_S;

                when READ_S =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(unsigned(mem_init_addr) + 3);
                    current_state <= WAIT_S;

                when WAIT_S =>
                    s_s <= i_mem_data(0);
                    current_state <= READ_DONE;

                when READ_DONE =>

                    -- unisco i sengali di k1 e k2 in k
                    v_k(15 downto 8) := s_k1; 
                    v_k(7 downto 0)  := s_k2;
                    s_k <= unsigned(v_k);

                    current_state <= IDLE;

            end case;
        end if;
    end process;

    -- assegno i valori agl'output dai segnali
    o_k <= s_k;
    o_s <= s_s;
    -- e anche la "notifica" alla CU
    o_read_done <= s_read_done;

end architecture Behavioral;
























-- Coefficient Loader Module (CLM) per la lettura dei coefficienti
-- ----------------------------------------------------
entity CLM is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_read_start : in std_logic; -- segnale dalla CU di iniziare la lettura
        i_s : in std_logic; -- per capire se leggere i coefficienti di ordine 3 o 5
        i_base_addr : in std_logic_vector(15 downto 0); -- addres che il TB da al top_module

        -- questi non li faccio unificati perché poi bisogna multiplexare quando si connettono le porte nel top module
        o_cn2_3 : out signed(7 downto 0);
        o_cn1_3 : out signed(7 downto 0);
        o_cp1_3 : out signed(7 downto 0);
        o_cp2_3 : out signed(7 downto 0);
        o_cn3_5 : out signed(7 downto 0);
        o_cn2_5 : out signed(7 downto 0);
        o_cn1_5 : out signed(7 downto 0);
        o_cp1_5 : out signed(7 downto 0);
        o_cp2_5 : out signed(7 downto 0);
        o_cp3_5 : out signed(7 downto 0);

        o_read_done : out std_logic; -- segnale per la CU di fine lettura

        -- segnali per l'utilizzo della memoria (in sola lettura)
        o_mem_addr : out std_logic_vector(15 downto 0); -- l'indirizzo di memoria dove scrivere
        o_mem_en : out std_logic; -- non metto _we dato che non devo mai scrivere
        i_mem_data : in std_logic_vector(7 downto 0); -- il dato in uscita dalla memoria
    );
end entity CLM;
architecture Behavioral of CLM is

    -- Qui devo fare una piccola macchiana a stati in grado di leggere s, k1 e k2
    type state_type is (IDLE, ASK_FOR_COEFFS, READ_COEFFS, READ_DONE);
    signal current_state : state_type

    signal s_c_n2_3 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_n1_3 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_p1_3 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_p2_3 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_n3_5 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_n2_5 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_n1_5 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_p1_5 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_p2_5 : signed(7 downto 0) := to_signed(0, 8);
    signal s_c_p3_5 : signed(7 downto 0) := to_signed(0, 8);

    signal s_counter_3 : integer range 0 to 4 := 0;
    signal s_counter_5 : integer range 0 to 6 := 0;

    -- faccio anche i segnali per interfacciarsi con la CU
    signal s_read_done : std_logic := '0';
    signal s_base_addr : std_logic_vector(15 downto 0) := (others => '0');

    -- ora i segnali per la memoria
    signal s_mem_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal s_mem_en : std_logic := '0';

begin

    process (i_clk, i_rst) is
    begin

        if i_rst = '1' then
            current_state <= IDLE;
            s_counter_3 <= 0;
            s_counter_5 <= 0;
            s_c_n2_3 <= (others => '0');
            s_c_n1_3 <= (others => '0');
            s_c_p1_3 <= (others => '0');
            s_c_p2_3 <= (others => '0');
            s_c_n3_5 <= (others => '0');
            s_c_n2_5 <= (others => '0');
            s_c_n1_5 <= (others => '0');
            s_c_p1_5 <= (others => '0');
            s_c_p2_5 <= (others => '0');
            s_c_p3_5 <= (others => '0');
            s_base_addr <= (others => '0');
            s_read_done <= '0';

        elsif rising_edge(i_clk) then

            case current_state is
                when IDLE =>
                    s_read_done <= '0';
                    -- aspetto che la CU mi dia il permesso di partire
                    if i_read_start = '1' then
                        s_base_addr <= i_base_addr; -- mi salvo l'addres base sia mai cambiasse per qualche strano motivo
                        s_counter_3 <= 0; -- inizializzo bene i counter per sicurezza
                        s_counter_5 <= 0;
                        current_state <= ASK_FOR_COEFFS;
                    end if;

                -- Lettura coefficienti
                when ASK_FOR_COEFFS =>
                    -- qui determino l'addres di memoria target per la prossima lettura
                    if s_s = '0' then
                        -- Filtro ordine 3: coefficienti agli indirizzi 4, 5, 7, 8
                        case s_counter_3 is
                            when 0 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 4);   -- c_n2_3
                            when 1 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 5);   -- c_n1_3
                            when 2 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 7);   -- c_p1_3
                            when 3 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 8);   -- c_p2_3
                            when others => s_mem_addr <= (others => '0');
                        end case;
                    else
                        -- Filtro ordine 5: coefficienti agli indirizzi 10, 11, 12, 14, 15, 16
                        case s_counter_5 is
                            when 0 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 10);  -- c_n3_5
                            when 1 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 11);  -- c_n2_5
                            when 2 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 12);  -- c_n1_5
                            when 3 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 14);  -- c_p1_5
                            when 4 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 15);  -- c_p2_5
                            when 5 => s_mem_addr <= std_logic_vector(unsigned(s_base_addr) + 16);  -- c_p3_5
                            when others => s_mem_addr <= (others => '0');
                        end case;
                    end if;
                    -- ovviamente devo anche attivare la memoria
                    s_mem_en <= '1';
                    -- e poi posso passare allo stato di lettura
                    current_state <= READ_COEFFS;

                when READ_COEFFS =>

                    if s_s = '0' then
                        -- immagazzino il coefficiente letto
                        case s_counter_3 is
                            when 0 => s_c_n2_3 <= signed(i_mem_data);
                            when 1 => s_c_n1_3 <= signed(i_mem_data);
                            when 2 => s_c_p1_3 <= signed(i_mem_data);
                            when 3 => s_c_p2_3 <= signed(i_mem_data);
                        end case;
                        
                        -- al quarto coefficiente ho finito di leggerli tutti
                        if coeff_counter = 3 then
                            current_state <= CONFIG_DONE;
                        else
                            -- altrimenti continuo con l'iterazione
                            coeff_counter <= coeff_counter + 1;
                            current_state <= ASK_FOR_COEFFS;
                        end if;
                    else
                        case s_counter_3 is
                            when 0 => s_c_n3_5 <= signed(i_mem_data);
                            when 1 => s_c_n2_5 <= signed(i_mem_data);
                            when 2 => s_c_n1_5 <= signed(i_mem_data);
                            when 3 => s_c_p1_5 <= signed(i_mem_data);
                            when 4 => s_c_p2_5 <= signed(i_mem_data);
                            when 5 => s_c_p3_5 <= signed(i_mem_data);
                        end case;
                        
                        -- al sesto coefficiente ho finito la lettura
                        if coeff_counter = 5 then
                            current_state <= CONFIG_DONE;
                        else
                            coeff_counter <= coeff_counter + 1;
                            current_state <= ASK_FOR_COEFFS;
                        end if;
                    end if;
                    

                when READ_DONE =>
                    s_read_done <= '1';
                    current_state <= IDLE; -- appena la CU da il permesso di iniziare al ciclo dopo dovrebbe togliere subito questo permesso!! altrimenti si potrebbe creare un ciclo infinito

            end case;
        end if;

    end process;

    -- alla fine del processo mappo tutti i segnali alle porte di output
    if i_s = '0' then
        o_cn2_3 <= s_c_n2_3;
        o_cn1_3 <= s_c_n1_3;
        o_cp1_3 <= s_c_p1_3;
        o_cp2_3 <= s_c_p2_3;
    elsif i_s = '1' then
        o_cn3_5 <= s_c_n3_5;
        o_cn2_5 <= s_c_n2_5;
        o_cn1_5 <= s_c_n1_5;
        o_cp1_5 <= s_c_p1_5;
        o_cp2_5 <= s_c_p2_5;
        o_cp3_5 <= s_c_p3_5;
    end if;
    o_read_done <= s_read_done;
    o_mem_addr <= s_mem_addr;
    o_mem_en <= s_mem_en;

end architecture Behavioral;























library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- a ciclo singolo 

-- Modulo di Arithmetic Logic Unit for order 3 (ALU3)
-- ----------------------------------------------------
entity ALU3 is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start_alu3 : in std_logic; -- segnale da CU per iniziare a calcolare

        -- coefficienti con i quali eseguire il calcolo
        i_cn2_3 : in signed(7 downto 0);
        i_cn1_3 : in signed(7 downto 0);
        i_cp1_3 : in signed(7 downto 0);
        i_cp2_3 : in signed(7 downto 0);

        -- dati di input
        i_prev2 : in signed(7 downto 0);
        i_prev1 : in signed(7 downto 0);
        i_next1 : in signed(7 downto 0);
        i_next2 : in signed(7 downto 0);

        o_done_alu3 : out std_logic; -- segnale per CU di fine calcolo
        o_result_alu3 : out signed(7 downto 0)
    );
end entity ALU3;
architecture Behavioral of ALU3 is

    signal s_result_alu3 : signed(7 downto 0);
    signal s_done_alu3   : std_logic;

begin

    process (i_clk, i_rst)

        variable tmp_p2 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_p1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n1 : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_n2 : signed(31 downto 0) := to_signed(0, 32);

        variable tmp_sum : signed(31 downto 0) := to_signed(0, 32);
        variable tmp_res : signed(31 downto 0) := to_signed(0, 32);

    begin

        if i_rst = '1' then
            s_result_alu3 <= (others => '0');
            s_done_alu3   <= '0';
            
        elsif rising_edge(i_clk) then
            -- Reset del segnale done ad ogni ciclo, a meno che non sia attivato di nuovo
            s_done_alu3 <= '0';

            -- Esegui i calcoli solo quando il segnale di start è attivo
            if i_start_alu3 = '1' then
        
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
                    s_result_alu3 <= "01111111";
                elsif tmp_res < to_signed(-128, 32) then
                    s_result_alu3 <= "10000000";
                else
                    s_result_alu3 <= signed(resize(tmp_res, 8));
                end if;

                -- lancio il segnale di fine
                s_done_alu3 <= '1';
            end if;
        end if;
    end process;

    -- assegnazione degli output dai registri
    o_result_alu3 <= s_result_alu3;
    o_done_alu3   <= s_done_alu3;
    
end architecture Behavioral;
















library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- praticamente identico ad ALU3

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
    signal s_result_alu5 : signed(7 downto 0);
    signal s_done_alu5   : std_logic;

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

        if i_rst = '1' then
            s_result_alu5 <= (others => '0');
            s_done_alu5   <= '0';
            
        elsif rising_edge(i_clk) then
            -- Reset del segnale done ad ogni ciclo, a meno che non sia attivato di nuovo
            s_done_alu5 <= '0';

            -- Esegui i calcoli solo quando il segnale di start è attivo
            if i_start_alu5 = '1' then
        
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
                    s_result_alu5 <= "01111111";
                elsif tmp_res < to_signed(-128, 32) then
                    s_result_alu5 <= "10000000";
                else
                    s_result_alu5 <= signed(resize(tmp_res, 8));
                end if;

                -- lancio il segnale di fine
                s_done_alu5 <= '1';
            end if;
        end if;
    end process;

    -- assegnazione degli output dai registri
    o_result_alu5 <= s_result_alu5;
    o_done_alu5   <= s_done_alu5;
    
end architecture Behavioral;












-- Modulo per la lettura dei dati da memoria con lo stile della sliding window
-- l'input è il contatore interno alla CU e il base addres o l'addres di W_1
-- l'output sono semplicemente i 3 valori prima di current_W ed i 3 successivi
-- oltre che ovviamente un akn per la CU

-- Data Window Management Module (DMW)
-- ----------------------------------------------------
















-- Control Unit (CU)
-- ----------------------------------------------------
entity CU is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;

        -- sicuramente un botto di porte in più

    );
end entity CU;
architecture Behavioral of CU is

    -- FSM principale
    -- gestione di tutti i moduli con akn vari
    -- gestione di i_start e i_rst

begin

    process (i_clk, i_rst) is

    begin
    end process;

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
        i_add      : in std_logic_vector(15 downto 0);

        o_done     : out std_logic;

        -- Interfaccia verso la memoria esterna
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end entity project_reti_logiche;

architecture Structural of project_reti_logiche is

    -- nell'architettura bisogna definire segnali e componenti prima di connettere il tutto
    
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

    -- Componente ALU3 (Arithmetic Logic Unit per Ordine 3)
    component ALU3 is
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
    end component;

    -- Componente ALU5 (Arithmetic Logic Unit per Ordine 5)
    component ALU5 is
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
    end component;

    

    -- Componente CU (Control Unit)
    component CU is
        port (
            -- qui ci saranno un botto di porte
        );
    end component;

begin

    -- ora il modulo strutturale si occupa di istanziare e mappare le porte di tutti i moduli

    -- Istanziazione dell'ALU3
    ALU3_INST : ALU3
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start_alu3 => s_alu3_start,
        o_done_alu3  => s_alu3_done,
        i_cn2_3       => s_alu3_cn2_3,
        i_cn1_3       => s_alu3_cn1_3,
        i_cp1_3       => s_alu3_cp1_3,
        i_cp2_3       => s_alu3_cp2_3,
        i_prev2     => s_alu3_prev2,
        i_prev1     => s_alu3_prev1,
        i_next1     => s_alu3_next1,
        i_next2     => s_alu3_next2,
        o_result_alu3 => s_alu3_result
    );

    -- Istanziazione dell'ALU5
    ALU5_INST : ALU5
    port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_start_alu5     => s_alu5_start,
        o_done_alu5      => s_alu5_done,
        i_cn3_5       => s_alu5_cn3_5,
        i_cn2_5       => s_alu5_cn2_5,
        i_cn1_5       => s_alu5_cn1_5,
        i_cp1_5       => s_alu5_cp1_5,
        i_cp2_5       => s_alu5_cp2_5,
        i_cp3_5       => s_alu5_cp3_5,
        i_prev3     => s_alu5_prev3,
        i_prev2     => s_alu5_prev2,
        i_prev1     => s_alu5_prev1,
        i_next1     => s_alu5_next1,
        i_next2     => s_alu5_next2,
        i_next3     => s_alu5_next3,
        o_result_alu5    => s_alu5_result
    );

    -- Istanziazione della Control Unit (CU)
    CU_INST : CU
    port map (
        
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

    -- process (s_mcu_start_cu, s_mcu_start_wru, s_mcu_write_flag_cu,
    --          s_mcu_addr_cu, s_mcu_data_write_cu, s_mcu_addr_wru, s_mcu_write_flag_wru)
    -- begin
    --     o_mem_en   <= '0'; -- Inizialmente disabilitata
    --     o_mem_addr <= (others => '0');
    --     o_mem_we   <= '0'; -- Default a lettura
    --     o_mem_data <= (others => '0'); -- Default data da scrivere a 0

    --     if s_mcu_start_cu = '1' then
    --         o_mem_en   <= '1';
    --         o_mem_addr <= s_mcu_addr_cu;
    --         o_mem_we   <= s_mcu_write_flag_cu;
    --         o_mem_data <= s_mcu_data_write_cu;
    --     elsif s_mcu_start_wru = '1' then
    --         o_mem_en   <= '1';
    --         o_mem_addr <= s_mcu_addr_wru;
    --         o_mem_we   <= s_mcu_write_flag_wru; -- WRU imposta sempre a '0' per lettura
    --         -- o_mem_data rimane a (others => '0') perché WRU non scrive
    --     end if;
    -- end process;

     -- Collegamento del dato letto dalla memoria esterna
    -- Il dato letto dalla memoria esterna (i_mem_data) viene passato ai moduli interni
    --s_mem_data_read <= i_mem_data;


end architecture Structural;





