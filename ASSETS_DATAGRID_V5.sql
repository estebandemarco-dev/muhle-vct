/* ========================================================================
   ASSETS_DATAGRID_V5
   ------------------------------------------------------------------------
   Sube la version (cache) del motor de grillas en TODOS los SP que lo cargan:
     ../css/vct-datagrid.css?v=N  ->  ?v=5
     ../js/vct-datagrid.js?v=N    ->  ?v=4
   Acompana a los archivos nuevos css/vct-datagrid.css (v5) y
   js/vct-datagrid.js (v4): toolbar estandar (buscador primero, filtros y
   botones del alto de "Nuevo", combos suaves, "Registros por pagina" hacia
   abajo) y tipografia de la tabla.
   ORDEN: 1) subir los dos archivos al servidor web; 2) correr este script.
   @APLICAR = 0: solo lista los SP que cambiarian.
   @APLICAR = 1: aplica el ALTER de cada SP (uno por uno; si alguno falla
                 se informa y se sigue con el resto).
   Re-ejecutable: los que ya estan en la version nueva no se tocan.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @APLICAR BIT = 0;   /* 0 = solo mostrar | 1 = aplicar */

DECLARE @CSS_NEW VARCHAR(10) = '5', @JS_NEW VARCHAR(10) = '4';

IF OBJECT_ID('tempdb..#DG5_SP') IS NOT NULL DROP TABLE #DG5_SP;
CREATE TABLE #DG5_SP (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY, DEF NVARCHAR(MAX), NUEVA NVARCHAR(MAX), ESTADO VARCHAR(200) NULL);

INSERT INTO #DG5_SP (NOMBRE, DEF)
SELECT O.name, M.definition
FROM sys.sql_modules M
INNER JOIN sys.objects O ON O.object_id = M.object_id
WHERE O.type = 'P'
  AND (M.definition LIKE N'%vct-datagrid.css?v=%' OR M.definition LIKE N'%vct-datagrid.js?v=%');

/* reemplaza el numero de version que sigue a cada marca */
DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @marca NVARCHAR(40), @nuevo VARCHAR(10), @p INT, @q INT, @k INT;
DECLARE cdg CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM #DG5_SP;
OPEN cdg;
FETCH NEXT FROM cdg INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @d = DEF FROM #DG5_SP WHERE NOMBRE = @nom;
    SET @k = 1;
    WHILE @k <= 2
    BEGIN
        SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
        SET @nuevo = CASE @k WHEN 1 THEN @CSS_NEW ELSE @JS_NEW END;
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
    UPDATE #DG5_SP SET NUEVA = @d WHERE NOMBRE = @nom;
    FETCH NEXT FROM cdg INTO @nom;
END;
CLOSE cdg;
DEALLOCATE cdg;

UPDATE #DG5_SP SET ESTADO = 'ya estaba en la version nueva' WHERE NUEVA = DEF;

/* CREATE -> ALTER: el primer CREATE seguido (solo con espacios) de PROC */
DECLARE @i INT, @rest NVARCHAR(80), @hecho BIT;
DECLARE cca CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM #DG5_SP WHERE ESTADO IS NULL;
OPEN cca;
FETCH NEXT FROM cca INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @d = NUEVA FROM #DG5_SP WHERE NOMBRE = @nom;
    SET @hecho = 0;
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
    IF @hecho = 1 UPDATE #DG5_SP SET NUEVA = @d WHERE NOMBRE = @nom;
    ELSE UPDATE #DG5_SP SET ESTADO = 'NO SE ENCONTRO CREATE PROCEDURE (revisar a mano)' WHERE NOMBRE = @nom;
    FETCH NEXT FROM cca INTO @nom;
END;
CLOSE cca;
DEALLOCATE cca;

PRINT '=== SP que cargan vct-datagrid ===';
SELECT NOMBRE, ISNULL(ESTADO, CASE WHEN @APLICAR = 1 THEN 'se actualiza' ELSE 'cambiaria' END) AS ESTADO
FROM #DG5_SP ORDER BY NOMBRE;

IF @APLICAR = 0
BEGIN
    PRINT 'MODO VISTA PREVIA: no se cambio nada. Correr con @APLICAR = 1 para aplicar.';
    RETURN;
END;

DECLARE @trg_on BIT = 0, @sql NVARCHAR(MAX), @ok INT = 0, @err INT = 0, @msg NVARCHAR(2000);
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;
IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

DECLARE cap CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE, NUEVA FROM #DG5_SP WHERE ESTADO IS NULL ORDER BY NOMBRE;
OPEN cap;
FETCH NEXT FROM cap INTO @nom, @sql;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sp_executesql @sql;
        SET @ok = @ok + 1;
        PRINT 'OK: ' + @nom;
    END TRY
    BEGIN CATCH
        SET @err = @err + 1;
        SET @msg = N'FALLO ' + @nom + N': ' + ERROR_MESSAGE();
        PRINT @msg;
    END CATCH;
    FETCH NEXT FROM cap INTO @nom, @sql;
END;
CLOSE cap;
DEALLOCATE cap;

IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

SET @msg = N'Listo: ' + CONVERT(NVARCHAR(10), @ok) + N' SP actualizados, ' + CONVERT(NVARCHAR(10), @err) + N' con error.';
PRINT @msg;
GO
