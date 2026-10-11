/* ========================================================================
   VCT_MAIN_CLIENTES_DATAGRID_V6
   ------------------------------------------------------------------------
   Modifica el SP EXISTENTE dbo.VCT_MAIN_CLIENTES (no crea nada).
   Toma la definicion vigente del servidor y solo cambia la version de los
   dos archivos de la grilla, para que el navegador cargue los nuevos:
     ../css/vct-datagrid.css?v=N  ->  ?v=6
     ../js/vct-datagrid.js?v=N    ->  ?v=4
   Antes de correrlo: subir css/vct-datagrid.css y js/vct-datagrid.js al
   servidor web. Re-ejecutable: si ya esta en v5/v4 avisa y no hace nada.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_CLIENTES')),
        @marca NVARCHAR(40), @nuevo NVARCHAR(10), @p INT, @q INT, @k INT, @i INT,
        @rest NVARCHAR(80), @hecho BIT = 0, @orig NVARCHAR(MAX), @trg_on BIT = 0, @msg NVARCHAR(2000);

IF @d IS NULL
BEGIN
    RAISERROR('No existe dbo.VCT_MAIN_CLIENTES.', 16, 1);
    RETURN;
END;
SET @orig = @d;

/* version de cada archivo */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'6' ELSE N'4' END;
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

IF @d = @orig
BEGIN
    PRINT 'VCT_MAIN_CLIENTES ya carga vct-datagrid.css?v=6 y vct-datagrid.js?v=4 (o no los carga). No se hizo nada.';
    RETURN;
END;

/* CREATE PROCEDURE -> ALTER PROCEDURE */
SET @i = CHARINDEX(N'CREATE', @d);
WHILE @i > 0 AND @hecho = 0
BEGIN
    SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
    IF @rest LIKE N'PROC%'
    BEGIN
        SET @d = STUFF(@d, @i, 6, N'ALTER');
        SET @hecho = 1;
    END
    ELSE
        SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
END;
IF @hecho = 0
BEGIN
    RAISERROR('No se encontro CREATE PROCEDURE en la definicion. No se hizo nada.', 16, 1);
    RETURN;
END;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;

BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK: VCT_MAIN_CLIENTES ahora carga vct-datagrid.css?v=6 y vct-datagrid.js?v=4.';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO al modificar VCT_MAIN_CLIENTES: ' + ERROR_MESSAGE() + N'. El SP quedo como estaba.';
    RAISERROR('%s', 16, 1, @msg);
END CATCH;
GO
