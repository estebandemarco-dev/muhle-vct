/* ========================================================================
   CONFIG_ESTANDAR_V2
   ------------------------------------------------------------------------
   NO toca permisos. dbo.VCT_MAIN_CONFIGURACION:
   1) DIAGNOSTICO: lista los css/js que carga la pantalla (para ver que
      version pide cada uno).
   2) Fuerza las versiones: vct-datagrid.css 28, vct-datagrid.js 11,
      vct-config-parametria.css 8, vct-config-parametria.js 4. Si alguno no
      estaba en el SP, lo agrega.
   Antes de correrlo: subir a C:\inetpub\wwwroot\muhle-vct\
      css\vct-config-parametria.css, js\vct-config-parametria.js,
      css\vct-datagrid.css y js\vct-datagrid.js.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONFIGURACION')), @orig NVARCHAR(MAX),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000),
        @marca NVARCHAR(80), @nuevo NVARCHAR(10), @tag NVARCHAR(300), @ancla NVARCHAR(80);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONFIGURACION.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. diagnostico */
PRINT '--- css/js que carga hoy la pantalla ---';
SET @p = CHARINDEX(N'href="../css/', @d);
WHILE @p > 0
BEGIN
    SET @q = CHARINDEX(N'"', @d, @p + 6);
    PRINT '  ' + CONVERT(VARCHAR(200), SUBSTRING(@d, @p, @q - @p + 1));
    SET @p = CHARINDEX(N'href="../css/', @d, @q);
END;
SET @p = CHARINDEX(N'src="../js/', @d);
WHILE @p > 0
BEGIN
    SET @q = CHARINDEX(N'"', @d, @p + 5);
    PRINT '  ' + CONVERT(VARCHAR(200), SUBSTRING(@d, @p, @q - @p + 1));
    SET @p = CHARINDEX(N'src="../js/', @d, @q);
END;

/* 2. versiones (si falta el archivo, se agrega junto a vct-datagrid) */
SET @k = 1;
WHILE @k <= 4
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' WHEN 2 THEN N'vct-datagrid.js?v=' WHEN 3 THEN N'vct-config-parametria.css?v=' ELSE N'vct-config-parametria.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'28' WHEN 2 THEN N'11' WHEN 3 THEN N'8' ELSE N'4' END;
    SET @p = CHARINDEX(@marca, @d);
    IF @p = 0 AND @k IN (3, 4)
    BEGIN
        SET @ancla = CASE @k WHEN 3 THEN N'<link rel="stylesheet" href="../css/vct-datagrid.css' ELSE N'<script src="../js/vct-datagrid.js' END;
        SET @tag = CASE @k WHEN 3 THEN N'<link rel="stylesheet" href="../css/vct-config-parametria.css?v=8">' ELSE N'<script src="../js/vct-config-parametria.js?v=4"></script>' END;
        SET @i = CHARINDEX(@ancla, @d);
        IF @i > 0
        BEGIN
            /* se agrega DESPUES del tag ancla (dentro del mismo literal) */
            SET @q = CHARINDEX(CASE @k WHEN 3 THEN N'>' ELSE N'</script>' END, @d, @i);
            SET @q = @q + CASE @k WHEN 3 THEN 1 ELSE 9 END;
            SET @d = STUFF(@d, @q, 0, @tag);
            PRINT 'AGREGADO: ' + CONVERT(VARCHAR(200), @tag);
        END
        ELSE PRINT 'AVISO: no se encontro donde agregar ' + CONVERT(VARCHAR(80), @marca);
    END
    ELSE IF @p = 0 PRINT 'AVISO: no se encontro ' + CONVERT(VARCHAR(80), @marca);
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
PRINT 'Version: datagrid css 28 / js 11, config-parametria css 8 / js 4.';

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
    PRINT 'OK: VCT_MAIN_CONFIGURACION actualizado (version de css/js de Parametria).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONFIGURACION (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
