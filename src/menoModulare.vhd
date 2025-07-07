library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Metadata Reader Unit (MdRU) per leggere k e s
-- ----------------------------------------------------
entity MdRU is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_mem_data : in std_logic_vector(7 downto 0);
        i_start_read : in std_logic; -- segnale dalla CU per iniziare a leggere
        i_base_addr : in std_logic_vector(15 downto 0);

        o_k : out unsigned(15 downto 0);
        o_s : out std_logic;
        o_read_done : out std_logic; -- segnale per la CU di fine lettura
        -- potrei considerare di mettere in output anche l'address finale di memoria giusto per non portarmi sempre dietro quel +3 o successivamente il +17

        -- segnali per l'utilizzo della memoria (in sola lettura)
        o_mem_addr : out std_logic_vector(15 downto 0); -- l'indirizzo di memoria dove scrivere
        o_mem_en : out std_logic; -- non metto _we dato che non devo mai scrivere
        o_mem_data : in std_logic_vector(7 downto 0); -- il dato da scrivere in memoria
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























-- Un altro modulo per i coefficienti

-- tipo Coefficient Loader Module (CLM)
-- ----------------------------------------------------
























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
















-- la CU in questo caso diventa il anche il top_module e si occuperà anche di collegare tutti i moduli soprastanti

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
    -- collegare tra di loro tutti i moduli sopra

begin

    process (i_clk, i_rst) is

    begin
    end process;

end architecture Behavioral;













