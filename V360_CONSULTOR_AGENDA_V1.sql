/* ========================================================================
   V360_CONSULTOR_AGENDA_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca vctdg-tabgroup), opcion A elegida:
   1) La pestana "Dias mensuales" se quita de la barra y "Agenda" pasa a su
      lugar (despues de Normas) como pestana con flecha y menu:
        Agenda v  ->  Calendario | Dias mensuales (cantidad)
      Las subvistas futuras se agregan en ese mismo menu.
   2) Encabezados: "Agenda > Calendario" y "Agenda > Dias mensuales (N)".
      Dias mensuales conserva su grilla, su boton Nuevo y su drawer.
   3) Version: vct-datagrid.css?v=25 y vct-datagrid.js?v=8 (el menu de la
      pestana lo maneja vct-datagrid.js v8).
   Antes de correrlo: subir css/vct-datagrid.css (v25) y js/vct-datagrid.js (v8).
   Re-ejecutable. Si algo no se encuentra, no aplica nada y avisa.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0,
        @msg NVARCHAR(2000), @marca NVARCHAR(40), @nuevo NVARCHAR(10), @falta NVARCHAR(400) = N'';

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'data-vctdg-tabgroup', @d) > 0
    PRINT 'La pestana Agenda con subopciones ya estaba aplicada. Solo se revisa la version.';
ELSE
BEGIN
    IF CHARINDEX(N'<button type="button" data-vct-tab="dias">', @d) = 0 SET @falta = @falta + N' [pestana dias]';
    IF CHARINDEX(N'<button type="button" data-vct-tab="agenda">', @d) = 0 SET @falta = @falta + N' [pestana agenda]';
    IF CHARINDEX(N'<button type="button" data-vct-tab="normas">', @d) = 0 SET @falta = @falta + N' [pestana normas]';
    IF CHARINDEX(N'data-vct-panel="dias"', @d) = 0 SET @falta = @falta + N' [panel dias]';
    IF CHARINDEX(N'data-vct-panel="agenda"', @d) = 0 SET @falta = @falta + N' [panel agenda]';
    IF @falta <> N''
    BEGIN
        SET @msg = N'No se encontro:' + @falta + N'. No se aplico nada.';
        PRINT @msg;
        RETURN;
    END;

    /* 1a. quitar las pestanas dias y agenda de la barra */
    SET @s = CHARINDEX(N'<button type="button" data-vct-tab="dias">', @d);
    SET @e = CHARINDEX(N'</button>', @d, @s) + LEN(N'</button>');
    SET @d = STUFF(@d, @s, @e - @s, N'');
    SET @s = CHARINDEX(N'<button type="button" data-vct-tab="agenda">', @d);
    SET @e = CHARINDEX(N'</button>', @d, @s) + LEN(N'</button>');
    SET @d = STUFF(@d, @s, @e - @s, N'');

    /* 1b. Agenda con menu, despues de Normas */
    SET @s = CHARINDEX(N'<button type="button" data-vct-tab="normas">', @d);
    SET @e = CHARINDEX(N'</button>', @d, @s) + LEN(N'</button>');
    SET @d = STUFF(@d, @e, 0, NCHAR(13) + NCHAR(10) + N'            ' + N'<button type="button" class="vctdg-tabgroup" data-vctdg-tabgroup data-vctdg-tabs="agenda,dias" aria-haspopup="menu"><span data-vct-icon="calendar"></span><span>Agenda</span><span class="vctdg-tabgroup-chev" data-vct-icon="chevron-down"></span></button>
            <div class="vctdg-tabgroup-items" hidden>
                <button type="button" data-vctdg-subtab="agenda"><span data-vct-icon="calendar"></span><span>Calendario</span></button>
                <button type="button" data-vctdg-subtab="dias"><span data-vct-icon="calendar-days"></span><span>D&iacute;as mensuales</span><small>''+CONVERT(VARCHAR(10),@HistoricoCount)+''</small></button>
            </div>');
    PRINT 'Paso 1: Agenda con subopciones en lugar de Dias mensuales.';

    /* 2. encabezados de los paneles */
    SET @p = CHARINDEX(N'data-vct-panel="dias"', @d);
    SET @s = CHARINDEX(N'data-vct-icon="calendar-days"></span>', @d, @p);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</h3>', @d, @s) ELSE 0 END;
    IF @s > 0 AND @e > 0 AND @e - @s < 300
    BEGIN
        SET @s = @s + LEN(N'data-vct-icon="calendar-days"></span>');
        SET @d = STUFF(@d, @s, @e - @s, N'Agenda <span class="vctdg-crumb">&rsaquo; <b>D&iacute;as mensuales</b> (''+CONVERT(VARCHAR(10),@HistoricoCount)+'')</span>');
    END
    ELSE PRINT 'AVISO: no se cambio el encabezado de Dias mensuales.';

    SET @p = CHARINDEX(N'data-vct-panel="agenda"', @d);
    SET @s = CHARINDEX(N'data-vct-icon="calendar"></span>', @d, @p);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</h3>', @d, @s) ELSE 0 END;
    IF @s > 0 AND @e > 0 AND @e - @s < 300
    BEGIN
        SET @s = @s + LEN(N'data-vct-icon="calendar"></span>');
        SET @d = STUFF(@d, @s, @e - @s, N'Agenda <span class="vctdg-crumb">&rsaquo; <b>Calendario</b></span>');
    END
    ELSE PRINT 'AVISO: no se cambio el encabezado de Agenda.';
    PRINT 'Paso 2: encabezados Agenda > Calendario / Agenda > Dias mensuales.';
END;

/* 3. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'25' ELSE N'8' END;
    SET @p = CHARINDEX(@marca, @d);
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

IF @d = @orig BEGIN PRINT 'VCT_MAIN_CONSULTORES_V360: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 actualizado (Agenda con subopciones).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONSULTORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
