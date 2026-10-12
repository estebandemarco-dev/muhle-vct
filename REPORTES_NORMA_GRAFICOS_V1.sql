/* ========================================================================
   REPORTES_NORMA_GRAFICOS_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica dbo.VCT_MAIN_REPORTES:
   1) Calificacion Consultores: "Aptitud" pasa a "Norma" (columna, filtro,
      buscador, KPI "Con Norma Activa" y grafico "Top 5 normas").
   2) Version: vct-reportes.css 30 (graficos de todos los reportes con la
      logica de Parte de Actividades, combos de filtro mas angostos) y
      vct-reportes.js 17 (servicio con icono en Calificacion).
   Antes de correrlo: subir css/vct-reportes.css y js/vct-reportes.js.
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_REPORTES')), @orig NVARCHAR(MAX),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0,
        @trg_on BIT = 0, @msg NVARCHAR(2000), @marca NVARCHAR(60), @nuevo NVARCHAR(10);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_REPORTES.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. Calificacion Consultores: "Aptitud" pasa a "Norma" (titulo de columna,
      filtro, buscador, KPI y grafico) */
DECLARE @R TABLE (ORD INT, VIEJO NVARCHAR(400), NUEVO NVARCHAR(400));
DECLARE @ro INT, @rv NVARCHAR(400), @rn NVARCHAR(400), @cnt INT = 0;
INSERT INTO @R VALUES
    (1, N'>Con Aptitud Activa<', N'>Con Norma Activa<'),
    (2, N'Top 5 aptitudes por cantidad', N'Top 5 normas por cantidad'),
    (3, N'Buscar consultor, aptitud o servicio...', N'Buscar consultor, norma o servicio...'),
    (4, N'aria-label="Aptitud" title="Aptitud"><option value="">Aptitud (todas)<', N'aria-label="Norma" title="Norma"><option value="">Norma (todas)<'),
    (5, N'<span>Aptitud</span>', N'<span>Norma</span>'),
    (6, N'data-label="Aptitud"', N'data-label="Norma"');
DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R ORDER BY ORD;
OPEN crp;
FETCH NEXT FROM crp INTO @ro, @rv, @rn;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF CHARINDEX(@rv, @d) > 0 BEGIN SET @d = REPLACE(@d, @rv, @rn); SET @cnt = @cnt + 1; END
    ELSE IF CHARINDEX(@rn, @d) = 0 PRINT 'AVISO: no se encontro el cambio ' + CONVERT(VARCHAR(5), @ro) + ' (se saltea).';
    FETCH NEXT FROM crp INTO @ro, @rv, @rn;
END;
CLOSE crp;
DEALLOCATE crp;
PRINT 'Paso 1: ' + CONVERT(VARCHAR(5), @cnt) + ' textos Aptitud -> Norma.';

/* 2. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-reportes.css?v=' ELSE N'vct-reportes.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'30' ELSE N'17' END;
    SET @p = CHARINDEX(@marca, @d);
    IF @p = 0 PRINT 'AVISO: no se encontro ' + CONVERT(VARCHAR(60), @marca);
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
PRINT 'Paso 2: version vct-reportes.css 30 / vct-reportes.js 17.';

IF @d = @orig BEGIN PRINT 'VCT_MAIN_REPORTES: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_REPORTES actualizado (Norma + graficos).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_REPORTES (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
