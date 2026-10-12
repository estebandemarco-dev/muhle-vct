/* ========================================================================
   CONFIG_EMAIL_V2
   ------------------------------------------------------------------------
   NO toca permisos. Solo sube la version de vct-config-parametria.js a 5
   en dbo.VCT_MAIN_CONFIGURACION (menu de 3 puntos tambien en la grilla de
   Templates de email, aun al volver del editor).
   Antes de correrlo: subir js/vct-config-parametria.js.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONFIGURACION')), @orig NVARCHAR(MAX),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0,
        @trg_on BIT = 0, @msg NVARCHAR(2000), @marca NVARCHAR(60), @nuevo NVARCHAR(10);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONFIGURACION.', 16, 1); RETURN; END;
SET @orig = @d;

SET @k = 1;
WHILE @k <= 1
BEGIN
    SET @marca = N'vct-config-parametria.js?v=';
    SET @nuevo = N'5';
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
PRINT 'Version: vct-config-parametria.js 5.';

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
    PRINT 'OK: VCT_MAIN_CONFIGURACION actualizado (vct-config-parametria.js 5).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONFIGURACION (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
