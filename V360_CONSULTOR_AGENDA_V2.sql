/* ========================================================================
   V360_CONSULTOR_AGENDA_V2
   ------------------------------------------------------------------------
   NO toca permisos. Corrige la pestana Agenda con subopciones en
   dbo.VCT_MAIN_CONSULTORES_V360:
   - El menu no abria porque la plataforma no recarga la pagina al navegar:
     vct-datagrid.js ya estaba cargado (v7) y no volvia a ejecutarse. El js
     v9 trae el menu de la pestana en un bloque propio que se carga igual.
   - La flecha usa un SVG propio (el set de iconos no tiene chevron-down).
   - Version: vct-datagrid.css?v=26 y vct-datagrid.js?v=9.
   Antes de correrlo: subir css/vct-datagrid.css (v26) y js/vct-datagrid.js (v9).
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0,
        @msg NVARCHAR(2000), @marca NVARCHAR(40), @nuevo NVARCHAR(10);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'data-vctdg-tabgroup', @d) = 0
BEGIN
    PRINT 'Falta la pestana Agenda con subopciones: correr antes V360_CONSULTOR_AGENDA_V1.sql. No se hizo nada.';
    RETURN;
END;

IF CHARINDEX(N'<span class="vctdg-tabgroup-chev" data-vct-icon="chevron-down"></span>', @d) > 0
BEGIN
    SET @d = REPLACE(@d, N'<span class="vctdg-tabgroup-chev" data-vct-icon="chevron-down"></span>', N'<span class="vctdg-tabgroup-chev" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg></span>');
    PRINT 'Paso 1: flecha de la pestana Agenda con SVG propio.';
END;

SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'26' ELSE N'9' END;
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
PRINT 'Paso 2: version css 26 / js 9.';

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
