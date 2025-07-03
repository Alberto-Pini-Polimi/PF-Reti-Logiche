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







-- Modulo di Memory Unit (MU)
-- ----------------------------------------------------
entity MU is
    port (
        rst : in STD_LOGIC;
        clk : in STD_LOGIC;
        ??
    );
end entity MU;

architecture Behavioral of MU is
begin
    
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


