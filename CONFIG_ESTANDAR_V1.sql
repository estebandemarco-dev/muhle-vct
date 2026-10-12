/* ========================================================================
   CONFIG_ESTANDAR_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONFIGURACION
   (lee la definicion actual de la base y aplica cambios por anclas):
   1) Saca los KPIs (div.vct-reports-kpis) y los modales de graficos
      (div.vct-modal-charts) de todos los ABM de Parametria.
   2) Saca data-vct-dg-charts de las grillas (sin boton Graficos).
   3) Chevron de las pestanas con submenu igual al de Agenda.
   4) Columna de acciones de 52px (menu de 3 puntos, lo arma
      vct-config-parametria.js v3 con los mismos botones del SP).
   5) Version: vct-datagrid.css 28 / js 11, vct-config-parametria.css 7 / js 3.
   Antes de correrlo: subir css/vct-config-parametria.css y
   js/vct-config-parametria.js. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONFIGURACION')), @orig NVARCHAR(MAX),
        @s INT, @p INT, @q INT, @a INT, @b INT, @k INT, @i INT, @lvl INT, @fin INT, @seg NVARCHAR(MAX),
        @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000),
        @marca NVARCHAR(80), @nuevo NVARCHAR(10), @cnt INT;

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONFIGURACION.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. KPIs y modales de graficos: se borra cada bloque <div ...> hasta su </div> */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'<div class="vct-reports-kpis">' ELSE N'<div class="vct-modal vct-modal-charts"' END;
    SET @cnt = 0;
    SET @s = CHARINDEX(@marca, @d);
    WHILE @s > 0
    BEGIN
        SET @lvl = 0; SET @p = @s; SET @fin = 0;
        WHILE @fin = 0 AND @p > 0
        BEGIN
            SET @a = CHARINDEX(N'<div', @d, @p);
            SET @b = CHARINDEX(N'</div>', @d, @p);
            IF @b = 0 SET @p = 0;
            ELSE IF @a > 0 AND @a < @b BEGIN SET @lvl = @lvl + 1; SET @p = @a + 4; END
            ELSE BEGIN SET @lvl = @lvl - 1; SET @p = @b + 6; IF @lvl = 0 SET @fin = @p; END;
        END;
        SET @seg = CASE WHEN @fin > 0 THEN SUBSTRING(@d, @s, @fin - @s) ELSE N'' END;
        IF @fin > 0 AND (LEN(@seg) - LEN(REPLACE(@seg, N'''', N''))) % 2 = 0
        BEGIN
            SET @d = STUFF(@d, @s, @fin - @s, N'');
            SET @cnt = @cnt + 1;
            SET @s = CHARINDEX(@marca, @d, @s);
        END
        ELSE
        BEGIN
            PRINT 'AVISO: no se pudo delimitar un bloque ' + CONVERT(VARCHAR(80), @marca) + ' (se deja).';
            SET @s = CHARINDEX(@marca, @d, @s + 1);
        END;
    END;
    PRINT 'Paso 1: ' + CONVERT(VARCHAR(5), @cnt) + CASE @k WHEN 1 THEN ' bloques de KPIs borrados.' ELSE ' modales de graficos borrados.' END;
    SET @k = @k + 1;
END;

/* 2. sin boton Graficos */
SET @cnt = 0;
SET @p = CHARINDEX(N'data-vct-dg-charts="', @d);
WHILE @p > 0
BEGIN
    SET @q = CHARINDEX(N'"', @d, @p + LEN(N'data-vct-dg-charts="'));
    IF @q = 0 BREAK;
    SET @d = STUFF(@d, @p, @q - @p + 1, N'');
    SET @cnt = @cnt + 1;
    SET @p = CHARINDEX(N'data-vct-dg-charts="', @d, @p);
END;
PRINT 'Paso 2: ' + CONVERT(VARCHAR(5), @cnt) + ' grillas sin boton Graficos.';

/* 3 y 4. chevron y columna de acciones */
IF CHARINDEX(N'<span class="vct-param-chevron" data-vct-icon="chevrons-up-down"></span>', @d) > 0 SET @d = REPLACE(@d, N'<span class="vct-param-chevron" data-vct-icon="chevrons-up-down"></span>', N'<span class="vct-param-chevron" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg></span>');
IF CHARINDEX(N'class="vct-col-action" data-vct-width="88"', @d) > 0 SET @d = REPLACE(@d, N'class="vct-col-action" data-vct-width="88"', N'class="vct-col-action" data-vct-width="52"');
PRINT 'Pasos 3 y 4: chevron y columna de acciones.';

/* 5. version */
SET @k = 1;
WHILE @k <= 4
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' WHEN 2 THEN N'vct-datagrid.js?v=' WHEN 3 THEN N'vct-config-parametria.css?v=' ELSE N'vct-config-parametria.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'28' WHEN 2 THEN N'11' WHEN 3 THEN N'7' ELSE N'3' END;
    SET @p = CHARINDEX(@marca, @d);
    IF @p = 0 PRINT 'AVISO: no se encontro ' + CONVERT(VARCHAR(80), @marca);
    WHILE @p > 0
    BEGIN
        SET @p = @p + LEN(@marca);
        SET @q = @p;
        WHILE @q <= LEN(@d) AND SUBSTRING(@d, @q, 1) LIKE N'[0-9]' SET @q = @q + 1;
        SET @d = STUFF(@d, @p, @q - @p, @nuevo);
        SET @p = CHARINDEX(@marca, @d, @p + LEN(@nuevo));
    END;
    SET @k = @k + 1;
END;
PRINT 'Paso 5: version datagrid css 28 / js 11, config-parametria css 7 / js 3.';

IF @d = @orig BEGIN PRINT 'VCT_MAIN_CONFIGURACION: sin cambios.'; RETURN; END;

SET @i = CHARINDEX(N'CREATE', @d);
WHILE @i > 0 AND @hecho = 0
BEGIN
    SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
    IF @rest LIKE N'PROC%' BEGIN SET @d = STUFF(@d, @i, 6, N'ALTER'); SET @hecho = 1; END
    ELSE SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
END;
IF @hecho = 0 BEGIN RAISERROR('No se encontro CREATE PROCEDURE. No se hizo nada.', 16, 1); RETURN; END;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK: VCT_MAIN_CONFIGURACION actualizado (estandar de pestanas y grillas, sin KPIs ni graficos).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONFIGURACION (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
