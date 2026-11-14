LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE work.juego_pkg.ALL;

ENTITY vga_dinosaurio_con_objetos IS
    PORT (
        CLK_50 : IN    STD_LOGIC;
        PS2_KBCLK : IN STD_LOGIC;
        PS2_KBDAT : IN STD_LOGIC;
        VGA_HS : OUT   STD_LOGIC;
        VGA_VS : OUT   STD_LOGIC;
        VGA_R  : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0);
        VGA_G  : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0);
        VGA_B  : OUT   STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY vga_dinosaurio_con_objetos;

-- Entidad principal: conecta modulos; anadir PS/2 en la entrada de salto.

ARCHITECTURE rtl OF vga_dinosaurio_con_objetos IS

    SIGNAL cuadro_personaje : INTEGER RANGE 0 TO 3;
    SIGNAL velocidad_actual : INTEGER RANGE VELOCIDAD TO VELOCIDAD_MAX;
    SIGNAL estado             : estado_juego_t;
    SIGNAL personaje          : INTEGER RANGE 0 TO 2;
    SIGNAL niveles, pulsos    : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL menu               : STD_LOGIC := '0';
    SIGNAL reset_partida      : STD_LOGIC := '0';
    SIGNAL tick_juego         : STD_LOGIC := '0';
    SIGNAL choque             : STD_LOGIC := '0';
    SIGNAL contacto           : STD_LOGIC := '0';
    SIGNAL salto_listo        : STD_LOGIC := '0';
    SIGNAL puntos, record_bcd : digitos_t;
    SIGNAL gris_interfaz      : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL gris_final         : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL hs_raw, vs_raw     : STD_LOGIC;
    SIGNAL clk_25             : STD_LOGIC := '0';
    SIGNAL h_count            : INTEGER RANGE 0 TO 799;
    SIGNAL v_count            : INTEGER RANGE 0 TO 524;
    SIGNAL visible            : STD_LOGIC;
    SIGNAL frame_tick         : STD_LOGIC;
    SIGNAL reset              : STD_LOGIC;
    SIGNAL salto              : STD_LOGIC;
    SIGNAL alas               : STD_LOGIC;
    SIGNAL dino_y             : INTEGER RANGE 0 TO 416;
    SIGNAL activos            : STD_LOGIC_VECTOR(NUM_OBJ - 1 DOWNTO 0);
    SIGNAL xs                 : posiciones_t;
    SIGNAL ys                 : alturas_t;
    SIGNAL tipos              : tipos_t;
    SIGNAL fondo_gris, gris   : STD_LOGIC_VECTOR(3 DOWNTO 0);

BEGIN

    PROCESS (CLK_50) IS
    BEGIN

        IF RISING_EDGE(CLK_50) THEN
            clk_25 <= NOT clk_25;
        END IF;

    END PROCESS;

    timing : ENTITY work.vga_timing
        PORT MAP (
            clk        => clk_25,
            x          => h_count,
            y          => v_count,
            hs         => hs_raw,
            vs         => vs_raw,
            visible    => visible,
            frame_tick => frame_tick
        );

    entradas : ENTITY work.entrada_teclado
        PORT MAP (
            clk        => clk_25,
            frame_tick => frame_tick,
            ps2_clk    => PS2_KBCLK,
            ps2_dat    => PS2_KBDAT,
            niveles    => niveles,
            pulsos     => pulsos,
            reset      => reset
        );

    control : ENTITY work.control_juego
        PORT MAP (
            clk        => clk_25,
            reset      => reset,
            frame_tick => frame_tick,
            pulsos     => pulsos,
            choque     => choque,
            estado     => estado,
            personaje  => personaje
        );

    impactos : ENTITY work.colisiones
        PORT MAP (
            clk        => clk_25,
            reset      => reset_partida,
            frame_tick => frame_tick,
            contacto   => contacto,
            choque     => choque
        );

    menu          <= '1' WHEN estado = INICIO ELSE
                     '0';
    reset_partida <= reset OR menu;
    tick_juego    <= frame_tick WHEN estado = JUGANDO AND choque = '0' ELSE
                     '0';
    -- Espacio usado para iniciar debe soltarse antes del primer salto.
    PROCESS (clk_25) IS
    BEGIN

        IF RISING_EDGE(clk_25) THEN
            IF (reset = '1' OR estado /= JUGANDO) THEN
                salto_listo <= '0';
            ELSIF (niveles(2) = '0') THEN
                salto_listo <= '1';
            END IF;
        END IF;

    END PROCESS;

    salto <= (niveles(2) OR pulsos(2)) AND salto_listo;

    dino : ENTITY work.dino_fisica
        PORT MAP (
            clk        => clk_25,
            reset      => reset_partida,
            frame_tick => tick_juego,
            salto      => salto,
            dino_y     => dino_y
        );

    objetos : ENTITY work.obstaculos
        PORT MAP (
            clk        => clk_25,
            reset      => reset_partida,
            frame_tick => tick_juego,
            activos    => activos,
            xs         => xs,
            ys         => ys,
            tipos      => tipos,
            alas       => alas,
            velocidad_actual => velocidad_actual
        );

    paisaje : ENTITY work.fondo
        PORT MAP (
            clk        => clk_25,
            reset      => reset_partida,
            frame_tick => tick_juego,
            x          => h_count,
            y          => v_count,
            gris       => fondo_gris,
            velocidad_actual => velocidad_actual
        );

    animacion : ENTITY work.animacion_personaje
        PORT MAP (
            clk        => clk_25,
            reset      => reset_partida,
            frame_tick => tick_juego,
            dino_y     => dino_y,
            velocidad_actual => velocidad_actual,
            cuadro     => cuadro_personaje
        );

    pixels : ENTITY work.renderizador
        PORT MAP (
            x          => h_count,
            y          => v_count,
            visible    => visible,
            fondo_gris => fondo_gris,
            dino_y     => dino_y,
            activos    => activos,
            xs         => xs,
            ys         => ys,
            tipos      => tipos,
            personaje  => personaje,
            alas       => alas,
            gris       => gris,
            contacto   => contacto,
            cuadro     => cuadro_personaje
        );

    interfaz : ENTITY work.interfaz_juego
        PORT MAP (
            x         => h_count,
            y         => v_count,
            estado    => estado,
            personaje => personaje,
            base      => gris,
            gris      => gris_interfaz
        );

    contador : ENTITY work.puntaje
        PORT MAP (
            clk        => clk_25,
            reset      => reset,
            frame_tick => tick_juego,
            estado     => estado,
            puntos     => puntos,
            record_bcd => record_bcd,
            velocidad_salida => velocidad_actual
        );

    marcador : ENTITY work.hud
        PORT MAP (
            x          => h_count,
            y          => v_count,
            puntos     => puntos,
            record_bcd => record_bcd,
            base       => gris_interfaz,
            gris       => gris_final
        );

    -- Registrar color y sincronismos juntos evita transitorios entre pixeles.
    PROCESS (clk_25) IS
    BEGIN

        IF RISING_EDGE(clk_25) THEN
            VGA_R  <= gris_final;
            VGA_G  <= gris_final;
            VGA_B  <= gris_final;
            VGA_HS <= hs_raw;
            VGA_VS <= vs_raw;
        END IF;

    END PROCESS;

END ARCHITECTURE rtl;


