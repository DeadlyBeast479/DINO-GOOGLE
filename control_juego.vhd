-- CONTROL: FSM general y seleccion; FSM de salto; registro de colision.
LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;

ENTITY control_juego IS
    PORT (
        clk        : IN  STD_LOGIC;
        reset      : IN  STD_LOGIC;
        frame_tick : IN  STD_LOGIC;
        pulsos     : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
        choque     : IN  STD_LOGIC;
        estado     : OUT estado_juego_t;
        personaje  : OUT INTEGER RANGE 0 TO 2
    );
END ENTITY control_juego;

ARCHITECTURE rtl OF control_juego IS
    SIGNAL actual, proximo   : estado_juego_t := INICIO;
    SIGNAL elegido, eleccion : INTEGER RANGE 0 TO 2 := 0;
BEGIN
    -- Registro de estado (DFFs) y contador circular del personaje.
    registros : PROCESS (clk) IS
    BEGIN
        IF RISING_EDGE(clk) THEN
            IF reset = '1' THEN
                actual <= INICIO;
                elegido <= 0;
            ELSIF frame_tick = '1' THEN
                actual <= proximo;
                elegido <= eleccion;
            END IF;
        END IF;
    END PROCESS registros;

    -- Logica combinacional de proximo estado. Valores por defecto: sin latches.
    transiciones : PROCESS (actual, elegido, pulsos, choque) IS
    BEGIN
        proximo <= actual;
        eleccion <= elegido;
        CASE actual IS
            WHEN INICIO =>
                IF pulsos(1) = '1' AND pulsos(0) = '0' THEN
                    IF elegido = 0 THEN
                        eleccion <= 2;
                    ELSE
                        eleccion <= elegido - 1;
                    END IF;
                ELSIF pulsos(0) = '1' AND pulsos(1) = '0' THEN
                    IF elegido = 2 THEN
                        eleccion <= 0;
                    ELSE
                        eleccion <= elegido + 1;
                    END IF;
                END IF;
                IF pulsos(2) = '1' THEN
                    proximo <= JUGANDO;
                END IF;
            WHEN JUGANDO =>
                IF choque = '1' THEN
                    proximo <= FIN;
                END IF;
            WHEN FIN =>
                IF pulsos(2) = '1' THEN
                    proximo <= INICIO;
                END IF;
        END CASE;
    END PROCESS transiciones;

    estado <= actual;
    personaje <= elegido;
END ARCHITECTURE rtl;

LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;

ENTITY dino_fisica IS
    PORT (
        clk        : IN    STD_LOGIC;
        reset      : IN    STD_LOGIC;
        frame_tick : IN    STD_LOGIC;
        salto      : IN    STD_LOGIC;
        dino_y     : OUT   INTEGER RANGE 0 TO 416
    );
END ENTITY dino_fisica;

ARCHITECTURE rtl OF dino_fisica IS

    CONSTANT DINO_H : INTEGER := DINO_SIZE;

    TYPE salto_estado_t IS (SUELO, SUBIENDO, CIMA, CAYENDO);

    SIGNAL salto_estado   : salto_estado_t          := SUELO;
    SIGNAL pausa_cima     : INTEGER RANGE 0 TO 2    := 0;
    SIGNAL velocidad_y    : INTEGER RANGE -14 TO 18 := 0;
    SIGNAL salto_anterior : STD_LOGIC               := '0';
    SIGNAL pos_y          : INTEGER RANGE 0 TO 416  := SUELO_Y - DINO_SIZE;

BEGIN

    PROCESS (clk) IS
    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (reset = '1') THEN
                pos_y          <= SUELO_Y - DINO_SIZE;
                salto_estado   <= SUELO;
                pausa_cima     <= 0;
                velocidad_y    <= 0;
                salto_anterior <= '0';
            ELSIF (frame_tick = '1') THEN
                salto_anterior <= salto;

                CASE salto_estado IS

                    WHEN SUELO =>

                        pos_y       <= SUELO_Y - DINO_H;
                        velocidad_y <= 0;
                        IF (salto = '1' AND salto_anterior = '0') THEN
                            velocidad_y  <= -14;
                            salto_estado <= SUBIENDO;
                        END IF;

                    WHEN SUBIENDO =>

                        pos_y <= pos_y + velocidad_y;
                        IF (velocidad_y >= -1) THEN
                            velocidad_y  <= 0;
                            pausa_cima   <= 0;
                            salto_estado <= CIMA;
                        ELSE
                            velocidad_y <= velocidad_y + 1;
                        END IF;

                    WHEN CIMA =>

                        -- Tres fotogramas extra en la cima: aproximadamente 50 ms.
                        IF (pausa_cima = 2) THEN
                            pausa_cima   <= 0;
                            salto_estado <= CAYENDO;
                        ELSE
                            pausa_cima <= pausa_cima + 1;
                        END IF;

                    WHEN CAYENDO =>

                        IF (pos_y + velocidad_y >= SUELO_Y - DINO_H) THEN
                            pos_y        <= SUELO_Y - DINO_H;
                            velocidad_y  <= 0;
                            pausa_cima   <= 0;
                            salto_estado <= SUELO;
                        ELSE
                            pos_y <= pos_y + velocidad_y;
                            -- Gravedad +1 en caida, limitada a 18 pixeles/frame.
                            IF (velocidad_y < 18) THEN
                                velocidad_y <= velocidad_y + 1;
                            END IF;
                        END IF;

                END CASE;

            END IF;
        END IF;

    END PROCESS;

    dino_y <= pos_y;

END ARCHITECTURE rtl;

LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;

ENTITY colisiones IS
    PORT (
        clk        : IN    STD_LOGIC;
        reset      : IN    STD_LOGIC;
        frame_tick : IN    STD_LOGIC;
        contacto   : IN    STD_LOGIC;
        choque     : OUT   STD_LOGIC
    );
END ENTITY colisiones;

ARCHITECTURE rtl OF colisiones IS

    SIGNAL detectado : STD_LOGIC := '0';

BEGIN

    -- El renderizador comparte sus mascaras visibles. Se acumula el contacto
    -- durante el barrido y la FSM lo consume al terminar el fotograma.
    PROCESS (clk) IS
    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (reset = '1') THEN
                detectado <= '0';
            ELSIF (frame_tick = '1') THEN
                detectado <= '0';
            ELSIF (contacto = '1') THEN
                detectado <= '1';
            END IF;
        END IF;

    END PROCESS;

    choque <= detectado;

END ARCHITECTURE rtl;

