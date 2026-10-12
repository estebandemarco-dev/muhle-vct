/* ========================================================================
   V360_CONSULTOR_ORDEN_PESTANAS
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360:
   orden de pestanas = Resumen, Proyectos, Acciones, Servicios, Normas,
   Agenda, Domicilios, Telefonos, Emails, Documentos, Notas.
   (mueve "Servicios" despues de "Acciones"; el resto ya estaba en ese orden)
   No cambia css ni js. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @g INT, @btn NVARCHAR(1000), @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0,
        @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

SET @s = CHARINDEX(N'<button type="button" data-vct-tab="servicios">', @d);
SET @g = CHARINDEX(N'<button type="button" data-vct-tab="gestiones">', @d);
IF @s = 0 OR @g = 0
BEGIN
    PRINT 'No se encontraron las pestanas Servicios / Acciones. No se hizo nada.';
    RETURN;
END;
IF @s > @g
BEGIN
    PRINT 'Servicios ya esta despues de Acciones. No se hizo nada.';
    RETURN;
END;

/* sacar Servicios (con el salto de linea y la sangria que le siguen) */
SET @e = CHARINDEX(N'</button>', @d, @s) + LEN(N'</button>');
SET @btn = SUBSTRING(@d, @s, @e - @s);
WHILE @e <= LEN(@d) AND SUBSTRING(@d, @e, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10)) SET @e = @e + 1;
SET @d = STUFF(@d, @s, @e - @s, N'');

/* ponerlo despues de Acciones */
SET @g = CHARINDEX(N'<button type="button" data-vct-tab="gestiones">', @d);
SET @e = CHARINDEX(N'</button>', @d, @g) + LEN(N'</button>');
SET @d = STUFF(@d, @e, 0, NCHAR(13) + NCHAR(10) + N'            ' + @btn);
PRINT 'Paso 1: Servicios despues de Acciones.';

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
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 actualizado (orden de pestanas).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONSULTORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
