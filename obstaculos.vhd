LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.juego_pkg.ALL;

ENTITY obstaculos IS
    PORT (
        clk        : IN    STD_LOGIC;
        reset      : IN    STD_LOGIC;
        frame_tick : IN    STD_LOGIC;
        activos    : OUT   STD_LOGIC_VECTOR(NUM_OBJ - 1 DOWNTO 0);
        xs         : OUT   posiciones_t;
        ys         : OUT   alturas_t;
        tipos      : OUT   tipos_t;
        alas       : OUT   STD_LOGIC;
        velocidad_actual : IN INTEGER RANGE VELOCIDAD TO VELOCIDAD_MAX := VELOCIDAD
    );
END ENTITY obstaculos;

ARCHITECTURE rtl OF obstaculos IS

    SIGNAL rng       : UNSIGNED(15 DOWNTO 0)                  := x"ACE1";
    SIGNAL a         : STD_LOGIC_VECTOR(NUM_OBJ - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL px        : posiciones_t                           := (OTHERS => 640);
    SIGNAL py        : alturas_t                              := (OTHERS => SUELO_Y - OBJ_H);
    SIGNAL tp        : tipos_t                                := (OTHERS => 0);
    SIGNAL distancia_restante : INTEGER RANGE 0 TO OBJ_W + GAP_MAX := 0;
    SIGNAL ultimo_gap : INTEGER RANGE 0 TO GAP_MAX := 0;
    SIGNAL anim      : INTEGER RANGE 0 TO 15                  := 0;

BEGIN

    -- LFSR libre: el instante de inicio humano cambia la secuencia.
    -- Pseudoaleatorio reproducible en simulacion, no ruido fisico.
    PROCESS (clk) IS
    BEGIN

        IF RISING_EDGE(clk) THEN
            rng <= rng(14 DOWNTO 0) & (rng(15) XOR rng(13) XOR rng(12) XOR rng(10));
        END IF;

    END PROCESS;

    PROCESS (clk) IS

        VARIABLE libre : INTEGER;
        VARIABLE tipo  : INTEGER;
        VARIABLE gap : INTEGER;
        VARIABLE base_gap, variacion : INTEGER;

    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (reset = '1') THEN
                a         <= (OTHERS => '0');
                px        <= (OTHERS => 640);
                py        <= (OTHERS => SUELO_Y - OBJ_H);
                tp        <= (OTHERS => 0);
                distancia_restante <= 0;
                ultimo_gap <= 0;
                anim      <= 0;
            ELSIF (frame_tick = '1') THEN
                IF (anim = 15) THEN
                    anim <= 0;
                ELSE
                    anim <= anim + 1;
                END IF;
                libre := -1;

                FOR i IN 0 TO NUM_OBJ - 1 LOOP

                    IF (a(i) = '1') THEN
                        IF (px(i) <= -OBJ_W + velocidad_actual) THEN
                            a(i) <= '0';
                        ELSE
                            px(i) <= px(i) - velocidad_actual;
                        END IF;
                    ELSIF (libre = -1) THEN
                        libre := i;
                    END IF;

                END LOOP;

                IF (distancia_restante <= velocidad_actual AND libre /= -1) THEN
                    tipo := TO_INTEGER(rng(2 DOWNTO 0)) MOD 3;
                    -- Distancias EN PIXELES, independientes de velocidad y puntaje.
                    -- Se mezclan cortas, medias y largas en toda la partida.
                    CASE TO_INTEGER(rng(15 DOWNTO 13)) IS
                        WHEN 0 => base_gap := GAP_LARGO;
                        WHEN 1 TO 3 => base_gap := GAP_MEDIO;
                        WHEN OTHERS => base_gap := GAP_MIN;
                    END CASE;
                    variacion := TO_INTEGER(rng(12 DOWNTO 9)) MOD 5;
                    gap := base_gap + variacion * 8;
                    IF gap = ultimo_gap THEN
                        variacion := (variacion + 1) MOD 5;
                        gap := base_gap + variacion * 8;
                    END IF;
                    ultimo_gap <= gap;
                    a(libre)  <= '1';
                    px(libre) <= 640;
                    tp(libre) <= tipo;
                    IF (tipo = 2 AND rng(9) = '1') THEN
                        py(libre) <= SUELO_Y - alto_sprite(tipo) - 70;
                    -- pajaro alto
                    ELSE
                        py(libre) <= SUELO_Y - alto_sprite(tipo);
                    -- pajaro bajo o terrestre
                    END IF;
                    distancia_restante <= OBJ_W + gap;
                ELSIF (distancia_restante > velocidad_actual) THEN
                    distancia_restante <= distancia_restante - velocidad_actual;
                END IF;
            END IF;
        END IF;

    END PROCESS;

    activos <= a;
    xs      <= px;
    ys      <= py;
    tipos   <= tp;
    alas    <= '1' WHEN anim < 8 ELSE
               '0';

END ARCHITECTURE rtl;


