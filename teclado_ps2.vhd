-- PS/2: registros de desplazamiento, contador de bits y decodificador de teclas.
-- Unidades independientes: cada ENTITY mantiene sus registros y puertos.

LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;

ENTITY ps2_receptor IS
    PORT (
        clk       : IN  STD_LOGIC; -- 25 MHz
        ps2_clk   : IN  STD_LOGIC;
        ps2_dat   : IN  STD_LOGIC;
        dato      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        valido    : OUT STD_LOGIC;
        error_rx  : OUT STD_LOGIC
    );
END ENTITY ps2_receptor;

ARCHITECTURE rtl OF ps2_receptor IS
    SIGNAL reloj_meta, reloj_sync, datos_meta, datos_sync : STD_LOGIC := '1';
    SIGNAL filtro : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '1');
    SIGNAL reloj_filtrado, reloj_anterior : STD_LOGIC := '1';
    SIGNAL indice : INTEGER RANGE 0 TO 10 := 0;
    SIGNAL espera : INTEGER RANGE 0 TO 49999 := 0;
    SIGNAL bits : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL paridad, paridad_ok : STD_LOGIC := '0';
BEGIN
    PROCESS (clk) IS
    BEGIN
        IF RISING_EDGE(clk) THEN
            reloj_meta <= ps2_clk;
            reloj_sync <= reloj_meta;
            datos_meta <= ps2_dat;
            datos_sync <= datos_meta;
            filtro <= filtro(6 DOWNTO 0) & reloj_sync;
            IF filtro = "11111111" THEN
                reloj_filtrado <= '1';
            ELSIF filtro = "00000000" THEN
                reloj_filtrado <= '0';
            END IF;
            reloj_anterior <= reloj_filtrado;
            valido <= '0';
            error_rx <= '0';

            IF reloj_anterior = '1' AND reloj_filtrado = '0' THEN
                espera <= 0;
                CASE indice IS
                    WHEN 0 =>
                        IF datos_sync = '0' THEN
                            indice <= 1;
                            paridad <= '0';
                        END IF;
                    WHEN 1 TO 8 =>
                        bits(indice - 1) <= datos_sync;
                        paridad <= paridad XOR datos_sync;
                        indice <= indice + 1;
                    WHEN 9 =>
                        paridad_ok <= paridad XOR datos_sync; -- paridad impar
                        indice <= 10;
                    WHEN 10 =>
                        indice <= 0;
                        IF datos_sync = '1' AND paridad_ok = '1' THEN
                            dato <= bits;
                            valido <= '1';
                        ELSE
                            error_rx <= '1';
                        END IF;
                END CASE;
            ELSIF indice /= 0 THEN
                IF espera = 49999 THEN -- 2 ms sin flancos: trama incompleta
                    indice <= 0;
                    espera <= 0;
                    error_rx <= '1';
                ELSE
                    espera <= espera + 1;
                END IF;
            ELSE
                espera <= 0;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE rtl;


LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;

ENTITY entrada_teclado IS
    PORT (
        clk        : IN  STD_LOGIC;
        frame_tick : IN  STD_LOGIC;
        ps2_clk    : IN  STD_LOGIC;
        ps2_dat    : IN  STD_LOGIC;
        niveles    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        pulsos     : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        reset      : OUT STD_LOGIC
    );
END ENTITY entrada_teclado;

ARCHITECTURE rtl OF entrada_teclado IS
    SIGNAL dato : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL valido, error_rx : STD_LOGIC;
    SIGNAL extendido, soltar : STD_LOGIC := '0';
    SIGNAL teclas, pendientes : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enter_presionado, reset_enter : STD_LOGIC := '0';
    SIGNAL arranque : INTEGER RANGE 0 TO 1023 := 0;
    SIGNAL tiempo_prefijo : INTEGER RANGE 0 TO 249999 := 0;
BEGIN
    receptor : ENTITY work.ps2_receptor
        PORT MAP (
            clk      => clk,
            ps2_clk  => ps2_clk,
            ps2_dat  => ps2_dat,
            dato     => dato,
            valido   => valido,
            error_rx => error_rx
        );

    PROCESS (clk) IS
        VARIABLE tecla : INTEGER RANGE -1 TO 2;
    BEGIN
        IF RISING_EDGE(clk) THEN
            reset_enter <= '0';
            IF arranque < 1023 THEN
                arranque <= arranque + 1;
            END IF;

            -- Los eventos cortos se guardan hasta que la FSM consume frame_tick.
            IF frame_tick = '1' THEN
                pendientes <= (OTHERS => '0');
            END IF;

            IF error_rx = '1' THEN
                extendido <= '0';
                soltar <= '0';
                tiempo_prefijo <= 0;
            ELSIF valido = '1' THEN
                tiempo_prefijo <= 0;
                IF dato = X"E0" THEN
                    extendido <= '1';
                ELSIF dato = X"F0" THEN
                    soltar <= '1';
                ELSE
                    tecla := -1;
                    IF dato = X"29" AND extendido = '0' THEN
                        tecla := 2; -- espacio: reemplazo de B2
                    ELSIF dato = X"6B" AND extendido = '1' THEN
                        tecla := 1; -- izquierda: reemplazo de B1
                    ELSIF dato = X"74" AND extendido = '1' THEN
                        tecla := 0; -- derecha: reemplazo de B0
                    END IF;

                    IF tecla /= -1 THEN
                        IF soltar = '1' THEN
                            teclas(tecla) <= '0';
                        ELSIF teclas(tecla) = '0' THEN
                            teclas(tecla) <= '1';
                            pendientes(tecla) <= '1';
                        END IF;
                    END IF;

                    IF dato = X"5A" THEN -- Enter normal o Enter numerico E0 5A
                        IF soltar = '1' THEN
                            enter_presionado <= '0';
                        ELSIF enter_presionado = '0' THEN
                            enter_presionado <= '1';
                            reset_enter <= '1';
                            teclas <= (OTHERS => '0');
                            pendientes <= (OTHERS => '0');
                        END IF;
                    END IF;
                    extendido <= '0';
                    soltar <= '0';
                END IF;
            ELSIF extendido = '1' OR soltar = '1' THEN
                IF tiempo_prefijo = 249999 THEN -- 10 ms: prefijo abandonado
                    extendido <= '0';
                    soltar <= '0';
                    tiempo_prefijo <= 0;
                ELSE
                    tiempo_prefijo <= tiempo_prefijo + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    niveles <= teclas;
    pulsos <= pendientes WHEN frame_tick = '1' ELSE (OTHERS => '0');
    -- Arranque autonomo; despues solo Enter genera un pulso de reinicio.
    reset <= '1' WHEN arranque < 1023 ELSE reset_enter;
END ARCHITECTURE rtl;
