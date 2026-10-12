/* ========================================================================
   REPORTES_ESTANDAR_V2
   ------------------------------------------------------------------------
   NO toca permisos. Solo sube la version de los JS en dbo.VCT_MAIN_REPORTES:
     vct-datagrid.js -> 11, vct-reportes.js -> 16
   (la configuracion de columnas de cada reporte ahora la aplica
   vct-reportes.js, no depende de los encabezados del SP).
   Ademas informa cuantos encabezados quedaron marcados por la V1.
   Antes de correrlo: subir js/vct-datagrid.js y js/vct-reportes.js.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_REPORTES')), @orig NVARCHAR(MAX),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0,
        @trg_on BIT = 0, @msg NVARCHAR(2000), @marca NVARCHAR(60), @nuevo NVARCHAR(10);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_REPORTES.', 16, 1); RETURN; END;
SET @orig = @d;

PRINT 'Info V1: data-vct-detail=' + CONVERT(VARCHAR(10), (LEN(@d) - LEN(REPLACE(@d, N'data-vct-detail', N''))) / 15)
    + ', data-vct-sub-of=' + CONVERT(VARCHAR(10), (LEN(@d) - LEN(REPLACE(@d, N'data-vct-sub-of', N''))) / 15)
    + ', data-vct-person=' + CONVERT(VARCHAR(10), (LEN(@d) - LEN(REPLACE(@d, N'data-vct-person', N''))) / 15)
    + ' (si da 0, no importa: ahora lo aplica vct-reportes.js).';

SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.js?v=' ELSE N'vct-reportes.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'11' ELSE N'16' END;
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
PRINT 'Version: vct-datagrid.js 11 / vct-reportes.js 16.';

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
    PRINT 'OK: VCT_MAIN_REPORTES actualizado (version JS 11 / 16).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_REPORTES (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
