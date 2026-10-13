/* ========================================================================
   V360_CLIENTE_ESTADO_AVANCE_V1
   ------------------------------------------------------------------------
   NO toca permisos ni vistas. Resumen de la Vista 360 de Cliente,
   "Ultimos proyectos": la columna Estado se montaba sobre Avance.
   Causa: el modulo de Cliente tambien tiene la clase .vct-consultor360-module
   y tomaba los anchos de la tabla del Consultor (9 columnas). El arreglo
   esta en css/vct-datagrid.css v29 (anchos propios para Cliente).
   Este script solo sube la version del css en dbo.VCT_MAIN_CLIENTES_V360
   (vct-datagrid.css?v=NN -> v=29) para que el navegador tome el nuevo.
   Antes de correrlo: subir css/vct-datagrid.css (v29). Re-ejecutable.
   ======================================================================== */
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CLIENTES_V360')),
        @marca NVARCHAR(40) = N'vct-datagrid.css?v=', @nuevo NVARCHAR(10) = N'29',
        @p INT, @q INT, @cambios INT = 0, @antes NVARCHAR(200) = N'', @trg_on BIT = 0, @k INT;

IF @d IS NULL
BEGIN
    PRINT 'FALLO: no existe dbo.VCT_MAIN_CLIENTES_V360.';
    RETURN;
END;

/* reemplaza el numero de version en cada aparicion */
SET @p = CHARINDEX(@marca, @d);
IF @p = 0 PRINT 'AVISO: no se encontro "vct-datagrid.css?v=" en dbo.VCT_MAIN_CLIENTES_V360; no se modifica.';
WHILE @p > 0
BEGIN
    SET @q = @p + LEN(@marca);
    SET @k = @q;
    WHILE @k <= LEN(@d) AND SUBSTRING(@d, @k, 1) LIKE N'[0-9]' SET @k = @k + 1;
    SET @antes = @antes + CASE WHEN @antes = N'' THEN N'' ELSE N', ' END + N'v=' + SUBSTRING(@d, @q, @k - @q);
    IF SUBSTRING(@d, @q, @k - @q) <> @nuevo
    BEGIN
        SET @d = STUFF(@d, @q, @k - @q, @nuevo);
        SET @cambios = @cambios + 1;
    END;
    SET @p = CHARINDEX(@marca, @d, @q);
END;

IF @cambios = 0
BEGIN
    PRINT 'OK: dbo.VCT_MAIN_CLIENTES_V360 ya usaba vct-datagrid.css?v=29 (' + @antes + '). Nada para cambiar.';
    RETURN;
END;

/* CREATE -> ALTER */
SET @p = PATINDEX(N'%CREATE%PROC%', @d);
IF @p = 0
BEGIN
    PRINT 'FALLO: no se encontro CREATE PROCEDURE en la definicion.';
    RETURN;
END;
SET @d = STUFF(@d, @p, 6, N'ALTER');

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK: dbo.VCT_MAIN_CLIENTES_V360 ahora usa vct-datagrid.css?v=29 (antes: ' + @antes + ').';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
