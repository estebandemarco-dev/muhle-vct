/* ========================================================================
   CONFIG_ACCIONES_V1
   ------------------------------------------------------------------------
   NO toca permisos ni nombres internos (ids, entidades, formularios).
   Solo textos visibles de dbo.VCT_MAIN_CONFIGURACION:
     - pestana "Gestiones" -> "Acciones" (el breadcrumb toma este texto);
     - "... de gestion" -> "... de accion" en titulos, subtitulos, titulos de
       grilla/exportacion y titulos de los formularios (Nuevo / Editar);
     - "esta gestion" -> "esta accion" (ayuda del campo Estado final).
   Los iconos de las pestanas no se tocan. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONFIGURACION')), @orig NVARCHAR(MAX),
        @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000), @n INT,
        @gest NVARCHAR(20) = N'gesti' + NCHAR(243) + N'n', @acc NVARCHAR(20) = N'acci' + NCHAR(243) + N'n';

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONFIGURACION.', 16, 1); RETURN; END;
SET @orig = @d;

/* pestana */
IF CHARINDEX(N'> Gestiones<span class="vct-param-chevron"', @d) > 0
BEGIN
    SET @d = REPLACE(@d, N'> Gestiones<span class="vct-param-chevron"', N'> Acciones<span class="vct-param-chevron"');
    PRINT 'Pestana Gestiones -> Acciones.';
END
ELSE PRINT 'Pestana: ya aplicada o no encontrada.';

/* textos */
SET @n = (LEN(@d) - LEN(REPLACE(@d, N' de ' + @gest, N''))) / LEN(N' de ' + @gest);
SET @d = REPLACE(@d, N' de ' + @gest, N' de ' + @acc);
SET @d = REPLACE(@d, N'esta ' + @gest, N'esta ' + @acc);
PRINT 'Textos "de gestion" cambiados: ' + CONVERT(VARCHAR(10), @n);

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
    PRINT 'OK: VCT_MAIN_CONFIGURACION actualizado (Gestiones -> Acciones).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONFIGURACION (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
