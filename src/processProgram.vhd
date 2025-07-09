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

    type state_type is (
        IDLE,  -- l'idle serve quando il modulo è "spento" 
        START, -- start è uno stato di passaggio che triggera l'esecuzione del calcolo
        DONE
    );
    signal s_state : state_type := IDLE;

    -- segnali 
    signal s_next_state : std_logic := '0'; -- questo è un segnale che serve per permettere al process del cambio di stato di cambiare effettivamente stato => settarlo ad 1 alla fine delle operazioni logiche

    -- segnali per usare il processo della memoria
    signal s_mem_process_en : std_logic := '0';
    signal s_mem_action : std_logic := '0';
    signal s_mem_read_out : std_logic_vector(7 downto 0) := (others => '0'); -- segnale col dato letto dalla memoria
    signal s_mem_write_in : std_logic_vector(7 downto 0) := (others => '0'); -- segnale col dato letto dalla memoria
    signal s_mem_process_finish : std_logic := '0'; -- segnale di ack


begin
    
    -- processo per il reset
    reset_prcess : process (i_rst) is
    begin
        if i_rst = '1' then
            s_state <= IDLE; -- se il TB dice di resettare metto lo stato della FSM a IDLE
        end if;
    end process;

    -- cambio stati
    change_state_process : process (i_clk) is
    begin
        -- se il clock sale e la logica mi ha permesso di passare al prossimo stato
        if rising_edge(i_clk) and s_next_state = '1' then 
            -- allora cambio lo stato della FSM
            case s_state is

                when IDLE =>
                    -- passo da idle a start solo se il TB mi da il permesso
                    if i_start = '1' then
                        s_state <= START;
                    end if;
                
                when START =>
                    s_state <= DONE;
            end case;
        end if;
    end process;

    -- processo della logica
    logic_process : process (i_clk) is
    begin

        if rising_edge(i_clk) then
            case s_state is
                when IDLE =>
                    o_done <= '0';
                    o_mem_en <= '0';
                    o_mem_we <= '0';
                when START =>

            end case;
        end if;

    end process;


    -- processo per la lettura della memoria (dura 2 clock e quindi serve un segnale di ack)
    memory_process : process (s_mem_process_en, s_mem_action) is
    begin
        if rising_edge(s_mem_process_en) then
            case s_mem_action is
                when '0' => -- per leggere
                when '1' => -- per scrivere
                -- una volta che ho finito una di queste due operazioni mando il sengale di ack
                s_mem_process_finish <= '1'; -- così che la logica principale possa continuare
            end case;
        end if;
    end process;


end architecture behavioral;