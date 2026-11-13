-- VGA: contadores de barrido, paisaje y multiplexores/decodificadores de pixeles.
-- Unidades independientes: cada ENTITY mantiene sus registros y puertos.

LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;

ENTITY vga_timing IS
    PORT (
        clk        : IN    STD_LOGIC;
        x          : OUT   INTEGER RANGE 0 TO 799;
        y          : OUT   INTEGER RANGE 0 TO 524;
        hs         : OUT   STD_LOGIC;
        vs         : OUT   STD_LOGIC;
        visible    : OUT   STD_LOGIC;
        frame_tick : OUT   STD_LOGIC
    );
END ENTITY vga_timing;

ARCHITECTURE rtl OF vga_timing IS

    SIGNAL h : INTEGER RANGE 0 TO 799 := 0;
    SIGNAL v : INTEGER RANGE 0 TO 524 := 0;

BEGIN

    PROCESS (clk) IS
    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (h = 799) THEN
                h <= 0;
                IF (v = 524) THEN
                    v <= 0;
                ELSE
                    v <= v + 1;
                END IF;
            ELSE
                h <= h + 1;
            END IF;
        END IF;

    END PROCESS;

    x          <= h;
    y          <= v;
    hs         <= '0' WHEN h >= 656 AND h < 752 ELSE
                  '1';
    vs         <= '0' WHEN v >= 490 AND v < 492 ELSE
                  '1';
    visible    <= '1' WHEN h < 640 AND v < 480 ELSE
                  '0';
    frame_tick <= '1' WHEN h = 799 AND v = 524 ELSE
                  '0';

END ARCHITECTURE rtl;



LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;

ENTITY fondo IS
    PORT (
        clk        : IN    STD_LOGIC;
        reset      : IN    STD_LOGIC;
        frame_tick : IN    STD_LOGIC;
        x          : IN    INTEGER RANGE 0 TO 799;
        y          : IN    INTEGER RANGE 0 TO 524;
        gris       : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0);
        velocidad_actual : IN INTEGER RANGE VELOCIDAD TO VELOCIDAD_MAX := VELOCIDAD
    );
END ENTITY fondo;

ARCHITECTURE rtl OF fondo IS

    SIGNAL nube_offset   : INTEGER RANGE 0 TO 767 := 0;
    SIGNAL tierra_offset : INTEGER RANGE 0 TO 127 := 0;
    SIGNAL lento         : INTEGER RANGE 0 TO 2   := 0;
    -- Nube contorneada pixelada, 96x32: mas ancha que el dinosaurio.

    FUNCTION techo (
        x : INTEGER
    ) RETURN INTEGER IS
    BEGIN

        IF (x < 8) THEN
            RETURN 26;
        ELSIF (x < 20) THEN
            RETURN 20;
        ELSIF (x < 30) THEN
            RETURN 14;
        ELSIF (x < 38) THEN
            RETURN 8;
        ELSIF (x < 48) THEN
            RETURN 2;
        ELSIF (x < 60) THEN
            RETURN 0;
        ELSIF (x < 68) THEN
            RETURN 6;
        ELSIF (x < 78) THEN
            RETURN 12;
        ELSIF (x < 86) THEN
            RETURN 20;
        ELSE
            RETURN 26;
        END IF;

    END FUNCTION techo;

    FUNCTION nube (
        x,
        y : INTEGER
    ) RETURN BOOLEAN IS

        VARIABLE t : INTEGER;

    BEGIN

        IF (x < 0 OR x >= 96 OR y < 0 OR y >= 32) THEN
            RETURN FALSE;
        END IF;

        t := techo(x);
        RETURN y = 30 OR y = 31 OR y = t OR y = t + 1 OR
            (x > 0 AND y > t AND y < techo(x - 1)) OR
            (x < 95 AND y > t AND y < techo(x + 1));

    END FUNCTION nube;

BEGIN

    PROCESS (clk) IS
    BEGIN

        IF RISING_EDGE(clk) THEN
            IF (reset = '1') THEN
                nube_offset   <= 0;
                tierra_offset <= 0;
                lento         <= 0;
            ELSIF (frame_tick = '1') THEN
                tierra_offset <= (tierra_offset + velocidad_actual) MOD 128;
                IF (lento = 2) THEN
                    lento <= 0;
                    IF (nube_offset = 767) THEN
                        nube_offset <= 0;
                    ELSE
                        nube_offset <= nube_offset + 1;
                    END IF;
                ELSE
                    lento <= lento + 1;
                END IF;
            END IF;
        END IF;

    END PROCESS;

    PROCESS (x, y, nube_offset, tierra_offset) IS

        VARIABLE cx, tx : INTEGER;

    BEGIN

        gris <= x"F";
 
        cx := (x + nube_offset) MOD 768;

        IF (nube(cx - 100, y - 225) OR nube(cx - 360, y - 180) OR nube(cx - 610, y - 250)) THEN
            gris <= x"C";
        END IF;

        tx := (x + tierra_offset) MOD 128;

        IF (y = SUELO_Y OR
            (y = SUELO_Y + 7 AND tx >= 10 AND tx < 18) OR
            (y = SUELO_Y + 12 AND tx >= 49 AND tx < 53) OR
            (y = SUELO_Y + 5 AND tx >= 84 AND tx < 89) OR
            (y = SUELO_Y + 15 AND tx >= 109 AND tx < 115)) THEN
            gris <= x"6";
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;



LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;
USE work.personajes_pkg.ALL;
USE work.obstaculos_pkg.ALL;

ENTITY renderizador IS
    PORT (
        x          : IN    INTEGER RANGE 0 TO 799;
        y          : IN    INTEGER RANGE 0 TO 524;
        visible    : IN    STD_LOGIC;
        fondo_gris : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
        dino_y     : IN    INTEGER RANGE 0 TO 416;
        activos    : IN    STD_LOGIC_VECTOR(NUM_OBJ - 1 DOWNTO 0);
        xs         : IN    posiciones_t;
        ys         : IN    alturas_t;
        tipos      : IN    tipos_t;
        personaje  : IN    INTEGER RANGE 0 TO 2;
        alas       : IN    STD_LOGIC;
        gris       : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0);
        contacto   : OUT   STD_LOGIC
    );
END ENTITY renderizador;

ARCHITECTURE rtl OF renderizador IS

BEGIN

    PROCESS (x, y, visible, fondo_gris, dino_y, activos, xs, ys, tipos, alas, personaje) IS

        VARIABLE id                    : INTEGER;
        VARIABLE w                     : INTEGER;
        VARIABLE h                     : INTEGER;
        VARIABLE pixel_dino, pixel_obj : BOOLEAN;

    BEGIN

        gris       <= x"0";
        contacto   <= '0';
        pixel_dino := FALSE;
        pixel_obj  := FALSE;

        IF (visible = '1') THEN
            gris <= fondo_gris;

            FOR i IN 0 TO NUM_OBJ - 1 LOOP

                CASE tipos(i) IS

                    WHEN 0 =>

                        id := 0;

                    WHEN 1 =>

                        id := 1;

                    WHEN 2 =>

                        IF (alas = '1') THEN
                            id := 2;
                        ELSE
                            id := 3;
                        END IF;

                    WHEN OTHERS =>

                        id := 0;

                END CASE;

                w := ancho_sprite(tipos(i));
                h := alto_sprite(tipos(i));
                IF (activos(i) = '1' AND x >= xs(i) AND x < xs(i) + w AND
                    y >= ys(i) AND y < ys(i) + h) THEN
                    IF (obj_display_pixel(id, x - xs(i), y - ys(i)) = '1') THEN
                        gris      <= x"4";
                        pixel_obj := TRUE;
                    END IF;
                END IF;

            END LOOP;

            IF (x >= DINO_X AND x < DINO_X + DINO_SIZE AND y >= dino_y AND y < dino_y + DINO_SIZE) THEN
                IF (personaje_pixel(personaje, x - DINO_X, y - dino_y) = '1') THEN
                    gris       <= x"4";
                    pixel_dino := TRUE;
                END IF;
            END IF;
        END IF;

        IF (pixel_dino AND pixel_obj) THEN
            contacto <= '1';
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;



LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;
USE work.personajes_pkg.ALL;
USE work.fuente_pkg.ALL;

ENTITY interfaz_juego IS
    PORT (
        x         : IN    INTEGER RANGE 0 TO 799;
        y         : IN    INTEGER RANGE 0 TO 524;
        estado    : IN    estado_juego_t;
        personaje : IN    INTEGER RANGE 0 TO 2;
        base      : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
        gris      : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY interfaz_juego;

ARCHITECTURE rtl OF interfaz_juego IS

BEGIN

    PROCESS (x, y, estado, personaje, base) IS

        VARIABLE tinta, panel : BOOLEAN;
        VARIABLE ox           : INTEGER;

    BEGIN

        gris  <= base;
        tinta := FALSE;
        panel := FALSE;

        IF (x < 640 AND y < 480) THEN
            IF (estado = INICIO) THEN
                panel := x >= 145 AND x < 495 AND y >= 80 AND y < 306;
                tinta := texto_pixel("ELIGE TU DINO", x - 242, y - 100);
                tinta := tinta OR texto_pixel("IZQ/DER CAMBIAR", x - 236, y - 270);
                tinta := tinta OR texto_pixel("ESPACIO INICIAR", x - 230, y - 290);

                FOR i IN 0 TO 2 LOOP

                    ox := 190 + i * 106;
                    IF (x >= ox AND x < ox + 48 AND y >= 170 AND y < 218) THEN
                        IF (personaje_pixel(i, x - ox, y - 170) = '1') THEN
                            tinta := TRUE;
                        END IF;
                    END IF;
                    IF (personaje = i AND x >= ox - 4 AND x < ox + 52 AND y >= 226 AND y < 230) THEN
                        tinta := TRUE;
                    END IF;

                END LOOP;

                CASE personaje IS

                    WHEN 0 =>

                        tinta := tinta OR texto_pixel("T-REX", x - 290, y - 245);

                    WHEN 1 =>

                        tinta := tinta OR texto_pixel("TRICERATOPS", x - 254, y - 245);

                    WHEN 2 =>

                        tinta := tinta OR texto_pixel("ESTEGOSAURIO", x - 248, y - 245);

                END CASE;

            ELSIF (estado = FIN) THEN
                panel := x >= 200 AND x < 440 AND y >= 100 AND y < 175;
                tinta := texto_pixel("FIN DEL JUEGO", x - 242, y - 115) OR texto_pixel("ESPACIO VOLVER", x - 236, y - 150);
            END IF;
            IF (panel) THEN
                gris <= x"F";
            END IF;
            IF (tinta) THEN
                gris <= x"4";
            END IF;
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;



LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;
USE work.fuente_pkg.ALL;

ENTITY hud IS
    PORT (
        x          : IN    INTEGER RANGE 0 TO 799;
        y          : IN    INTEGER RANGE 0 TO 524;
        puntos     : IN    digitos_t;
        record_bcd : IN    digitos_t;
        base       : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
        gris       : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY hud;

ARCHITECTURE rtl OF hud IS

BEGIN

    PROCESS (x, y, puntos, record_bcd, base) IS

        VARIABLE tinta : BOOLEAN;

    BEGIN

        gris <= base;

        IF (x >= 396 AND x < 620 AND y >= 18 AND y < 44) THEN
            gris  <= x"F";
            tinta := texto_pixel("HI", x - 404, y - 24);

            FOR i IN 0 TO 4 LOOP

                tinta := tinta OR digito_pixel(record_bcd(4 - i), x - (440 + 12 * i), y - 24)
                         OR digito_pixel(puntos(4 - i), x - (548 + 12 * i), y - 24);

            END LOOP;

            IF (tinta) THEN
                gris <= x"4";
            END IF;
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;


