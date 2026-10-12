/* ========================================================================
   VCT_MAIN_PROVEEDORES_SIN_NEGRITA
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_PROVEEDORES:
   en la grilla, la razon social va sin negrita (se quita el <strong> de la
   celda "Razon social"), igual que en Consultores y Empleados.
   No cambia css ni js. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_PROVEEDORES')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @seg NVARCHAR(MAX), @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0,
        @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_PROVEEDORES.', 16, 1); RETURN; END;
SET @orig = @d;

SET @s = CHARINDEX(N'data-label="Raz', @d);
SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</td>', @d, @s) ELSE 0 END;
IF @s = 0 OR @e = 0
BEGIN
    PRINT 'No se encontro la celda Razon social. No se hizo nada.';
    RETURN;
END;
SET @seg = SUBSTRING(@d, @s, @e - @s);
IF CHARINDEX(N'<strong>', @seg) = 0
BEGIN
    PRINT 'La razon social ya estaba sin negrita. No se hizo nada.';
    RETURN;
END;
SET @seg = REPLACE(REPLACE(@seg, N'<strong>', N'<span>'), N'</strong>', N'</span>');
SET @d = STUFF(@d, @s, @e - @s, @seg);
PRINT 'Paso 1: razon social sin negrita.';

IF @d = @orig BEGIN PRINT 'VCT_MAIN_PROVEEDORES: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_PROVEEDORES actualizado (razon social sin negrita).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_PROVEEDORES (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
