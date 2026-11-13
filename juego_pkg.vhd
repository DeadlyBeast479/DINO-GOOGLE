LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;

PACKAGE juego_pkg IS

    TYPE estado_juego_t IS (INICIO, JUGANDO, FIN);

    -- Indice 0 = unidades, indice 4 = decenas de millar.

    TYPE digitos_t IS ARRAY(0 TO 4) OF INTEGER RANGE 0 TO 9;

    CONSTANT ANCHO     : INTEGER := 640;
    CONSTANT SUELO_Y   : INTEGER := 409;
    CONSTANT DINO_X    : INTEGER := 100;
    CONSTANT DINO_SIZE : INTEGER := 48;
    CONSTANT OBJ_W     : INTEGER := 64;
    CONSTANT OBJ_H     : INTEGER := 48;
    CONSTANT VELOCIDAD : INTEGER := 4;
    CONSTANT VELOCIDAD_MAX : INTEGER := 8;
    CONSTANT GAP_MIN : INTEGER := 208;
    -- espacio vacio entre cajas de 64 px
    CONSTANT GAP_MAX : INTEGER := 368;
    CONSTANT GAP_MEDIO : INTEGER := 272;
    CONSTANT GAP_LARGO : INTEGER := 336;
    CONSTANT GAP_VARIACION : INTEGER := 32;
    CONSTANT NUM_OBJ : INTEGER := 3;

    TYPE posiciones_t IS ARRAY(0 TO NUM_OBJ - 1) OF INTEGER RANGE -64 TO 640;

    TYPE tipos_t IS ARRAY(0 TO NUM_OBJ - 1) OF INTEGER RANGE 0 TO 2;

    TYPE alturas_t IS ARRAY(0 TO NUM_OBJ - 1) OF INTEGER RANGE 0 TO 479;

    FUNCTION ancho_sprite (
        tipo : INTEGER
    ) RETURN INTEGER;


    FUNCTION alto_sprite (
        tipo : INTEGER
    ) RETURN INTEGER;

END PACKAGE juego_pkg;

PACKAGE BODY juego_pkg IS



    FUNCTION ancho_sprite (
        tipo : INTEGER
    ) RETURN INTEGER IS
    BEGIN

        IF (tipo = 2) THEN
            RETURN 32;
        ELSIF (tipo >= 3) THEN
            RETURN 48;
        ELSE
            RETURN 64;
        END IF;

    END FUNCTION ancho_sprite;

    FUNCTION alto_sprite (
        tipo : INTEGER
    ) RETURN INTEGER IS
    BEGIN

        IF (tipo = 2) THEN
            RETURN 24;
        ELSIF (tipo >= 3) THEN
            RETURN 48;
        ELSE
            RETURN 48;
        END IF;

    END FUNCTION alto_sprite;

END PACKAGE BODY juego_pkg;



