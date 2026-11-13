-- PUNTAJE: contador BCD, registro de record y decodificador de dificultad.
LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;

ENTITY puntaje IS
    PORT (
        clk        : IN    STD_LOGIC;
        reset      : IN    STD_LOGIC;
        frame_tick : IN    STD_LOGIC;
        estado     : IN    estado_juego_t;
        puntos     : OUT   digitos_t;
        record_bcd : OUT   digitos_t;
        velocidad_salida : OUT INTEGER RANGE VELOCIDAD TO VELOCIDAD_MAX
    );
END ENTITY puntaje;

ARCHITECTURE rtl OF puntaje IS

    SIGNAL actual, mejor : digitos_t                := (OTHERS => 0);
    SIGNAL fase          : INTEGER RANGE 0 TO 5     := 0;

BEGIN

    PROCESS (clk) IS

        VARIABLE siguiente : digitos_t;
        VARIABLE acarreo   : BOOLEAN;
        VARIABLE mayor, igual : BOOLEAN;

    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (reset = '1') THEN
                actual <= (OTHERS => 0);
                mejor  <= (OTHERS => 0);

                fase   <= 0;
            ELSIF (estado = INICIO) THEN
                actual <= (OTHERS => 0);

                fase   <= 0;
            ELSIF (estado = JUGANDO AND frame_tick = '1') THEN
                IF (fase = 5) THEN
                    fase <= 0;
                    IF actual /= (9, 9, 9, 9, 9) THEN
                        siguiente := actual;
                        acarreo   := TRUE;

                        FOR i IN 0 TO 4 LOOP

                            IF (acarreo) THEN
                                IF (siguiente(i) = 9) THEN
                                    siguiente(i) := 0;
                                ELSE
                                    siguiente(i) := siguiente(i) + 1;
                                    acarreo      := FALSE;
                                END IF;
                            END IF;

                        END LOOP;

                        actual <= siguiente;

                        -- Comparador decimal desde el digito mas significativo.
                        mayor := FALSE;
                        igual := TRUE;
                        FOR i IN 4 DOWNTO 0 LOOP
                            IF igual THEN
                                IF siguiente(i) > mejor(i) THEN
                                    mayor := TRUE;
                                END IF;
                                IF siguiente(i) /= mejor(i) THEN
                                    igual := FALSE;
                                END IF;
                            END IF;
                        END LOOP;
                        IF mayor THEN
                            mejor <= siguiente;
                        END IF;
                    END IF;
                ELSE
                    fase <= fase + 1;
                END IF;
            END IF;
        END IF;

    END PROCESS;

    -- Decodificacion combinacional: velocidad cada 100 puntos.
    PROCESS (actual) IS
    BEGIN
        -- Las distancias aleatorias no dependen del puntaje.
        IF actual(4) /= 0 OR actual(3) /= 0 OR actual(2) >= 4 THEN
            velocidad_salida <= VELOCIDAD_MAX;
        ELSE
            velocidad_salida <= VELOCIDAD + actual(2);
        END IF;
    END PROCESS;

    puntos     <= actual;
    record_bcd <= mejor;

END ARCHITECTURE rtl;

