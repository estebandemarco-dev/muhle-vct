/* ========================================================================
   ACCIONES_RENOMBRAR_TABLAS
   ------------------------------------------------------------------------
   Gestiones -> Acciones en el modelo de datos (tablas, parametria, vista,
   columnas, constraints e indices) y en TODO el codigo SQL que los usa.

   Alcance (se detecta solo, no hay nombres fijos):
     - Tablas y vistas dbo.VCT_* con GESTION en el nombre (incluye las
       VCT_PRM_GESTIONES_*): VCT_GESTIONES -> VCT_ACCIONES, etc.
     - Columnas con GESTION en el nombre de cualquier tabla dbo.VCT_*:
       ID_GESTION -> ID_ACCION, ID_GESTION_PADRE -> ID_ACCION_PADRE, etc.
     - PK/FK/UQ/DF/CK e indices con GESTION en el nombre.
     - SP, funciones, vistas y triggers: se reescriben reemplazando SOLO
       esos nombres exactos (palabra completa). No se tocan:
         * variables y parametros (@ID_GESTION, @HTML_GESTIONES...),
         * nombres de SP/funciones (VCT_GESTION_CREAR sigue igual),
         * textos visibles ("Gestiones"), claves data-* ni valores 'GESTION'.
   Queda afuera: tablas que no empiezan con VCT_ (LK_*, plataforma Muhle).

   Uso:
     1. Correrlo asi como esta (@APLICAR = 0): NO cambia nada; muestra
        el plan completo, los objetos que se reescriben y los avisos.
        Leerlo; si hay nombres que no deben cambiar, agregarlos a
        @EXCLUIR y volver a correr.
     2. Cambiar @APLICAR = 1 y correr. Todo va en UNA transaccion: si algo
        falla, se deshace todo y dice que objeto fallo.
     El trigger de auditoria DDL (TR_VCT_AUDITORIA_DDL) se apaga durante la
     corrida para no mandar un mail por cada objeto, y se vuelve a prender.
   Despues: DUMP_OBJETOS + split_dump.py y commitear (cambian muchos objetos).
   Compat 100 y 140. Re-ejecutable: si ya no queda nada con GESTION, no hace nada.
   ======================================================================== */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\ACCIONES_RENOMBRAR_TABLAS.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @APLICAR BIT = 0;          /* 0 = solo mostrar el plan | 1 = aplicar */

/* Nombres (de tabla, vista o columna) que NO se renombran. Ej.:
   INSERT INTO @EXCLUIR VALUES ('VCT_SISTEMA_GESTION'), ('NORMA_GESTION'); */
DECLARE @EXCLUIR TABLE (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY);

/* ---------------------------------------------------------------- tablas de trabajo */
IF OBJECT_ID('tempdb..#RT_REN') IS NOT NULL DROP TABLE #RT_REN;
IF OBJECT_ID('tempdb..#RT_MAP') IS NOT NULL DROP TABLE #RT_MAP;
IF OBJECT_ID('tempdb..#RT_MOD') IS NOT NULL DROP TABLE #RT_MOD;
IF OBJECT_ID('tempdb..#RT_AVI') IS NOT NULL DROP TABLE #RT_AVI;
IF OBJECT_ID('tempdb..#RT_ROTOS') IS NOT NULL DROP TABLE #RT_ROTOS;

CREATE TABLE #RT_REN (N INT IDENTITY PRIMARY KEY, PASO INT, CLASE VARCHAR(20), TABLA SYSNAME COLLATE DATABASE_DEFAULT NULL,
                   VIEJO SYSNAME COLLATE DATABASE_DEFAULT, NUEVO SYSNAME COLLATE DATABASE_DEFAULT, OBJ_ID INT NULL);
CREATE TABLE #RT_MAP (N INT IDENTITY PRIMARY KEY, VIEJO SYSNAME COLLATE DATABASE_DEFAULT, NUEVO SYSNAME COLLATE DATABASE_DEFAULT);
CREATE TABLE #RT_MOD (OBJ_ID INT PRIMARY KEY, NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, TIPO VARCHAR(2), NIVEL INT DEFAULT 0, ORDEN INT DEFAULT 0,
                   QI BIT, AN BIT, DEF NVARCHAR(MAX), NUEVA NVARCHAR(MAX), REEMPLAZOS INT DEFAULT 0, RESIDUOS INT DEFAULT 0);
CREATE TABLE #RT_AVI (N INT IDENTITY, TXT NVARCHAR(2000));
CREATE TABLE #RT_ROTOS (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, ERROR NVARCHAR(2000));

/* ---------------------------------------------------------------- 1. tablas y vistas */
INSERT INTO #RT_REN (PASO, CLASE, TABLA, VIEJO, NUEVO, OBJ_ID)
SELECT 1, CASE O.type WHEN 'U' THEN 'TABLA' ELSE 'VISTA' END, NULL, O.name,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(O.name COLLATE Latin1_General_BIN,
           'GESTIONES','ACCIONES'),'Gestiones','Acciones'),'gestiones','acciones'),
           'GESTION','ACCION'),'Gestion','Accion'),'gestion','accion'),
       O.object_id
FROM sys.objects O
WHERE O.type IN ('U','V') AND O.schema_id = SCHEMA_ID('dbo') AND O.is_ms_shipped = 0
  AND O.name LIKE 'VCT[_]%'
  AND O.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%'
  AND NOT EXISTS (SELECT 1 FROM @EXCLUIR E WHERE E.NOMBRE = O.name);

/* ---------------------------------------------------------------- 2. columnas de tablas VCT_* */
INSERT INTO #RT_REN (PASO, CLASE, TABLA, VIEJO, NUEVO, OBJ_ID)
SELECT 2, 'COLUMNA', T.name, C.name,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(C.name COLLATE Latin1_General_BIN,
           'GESTIONES','ACCIONES'),'Gestiones','Acciones'),'gestiones','acciones'),
           'GESTION','ACCION'),'Gestion','Accion'),'gestion','accion'),
       T.object_id
FROM sys.columns C
JOIN sys.tables T ON T.object_id = C.object_id
WHERE T.schema_id = SCHEMA_ID('dbo') AND T.is_ms_shipped = 0
  AND T.name LIKE 'VCT[_]%'
  AND C.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%'
  AND NOT EXISTS (SELECT 1 FROM @EXCLUIR E WHERE E.NOMBRE = T.name OR E.NOMBRE = C.name);

/* La misma columna existe en una tabla fuera del alcance (LK_*, plataforma):
   como el codigo se reescribe por nombre, renombrarla romperia esas consultas. */
INSERT INTO #RT_AVI (TXT)
SELECT DISTINCT N'COLUMNA NO RENOMBRADA: ' + R.VIEJO + N' tambien existe en ' + T.name + N' (fuera de alcance). Revisar a mano.'
FROM #RT_REN R
JOIN sys.columns C ON C.name = R.VIEJO
JOIN sys.tables T ON T.object_id = C.object_id
WHERE R.CLASE = 'COLUMNA' AND T.name NOT LIKE 'VCT[_]%';

DELETE R FROM #RT_REN R
WHERE R.CLASE = 'COLUMNA'
  AND EXISTS (SELECT 1 FROM sys.columns C JOIN sys.tables T ON T.object_id = C.object_id
              WHERE C.name = R.VIEJO AND T.name NOT LIKE 'VCT[_]%');

/* ---------------------------------------------------------------- 3. constraints e indices */
INSERT INTO #RT_REN (PASO, CLASE, TABLA, VIEJO, NUEVO, OBJ_ID)
SELECT 3, 'CONSTRAINT', OBJECT_NAME(K.parent_object_id), K.name,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(K.name COLLATE Latin1_General_BIN,
           'GESTIONES','ACCIONES'),'Gestiones','Acciones'),'gestiones','acciones'),
           'GESTION','ACCION'),'Gestion','Accion'),'gestion','accion'),
       K.object_id
FROM sys.objects K
WHERE K.type IN ('PK','UQ','F','D','C') AND K.schema_id = SCHEMA_ID('dbo')
  AND K.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%'
  AND OBJECT_NAME(K.parent_object_id) LIKE 'VCT[_]%';

INSERT INTO #RT_REN (PASO, CLASE, TABLA, VIEJO, NUEVO, OBJ_ID)
SELECT 4, 'INDICE', O.name, I.name,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(I.name COLLATE Latin1_General_BIN,
           'GESTIONES','ACCIONES'),'Gestiones','Acciones'),'gestiones','acciones'),
           'GESTION','ACCION'),'Gestion','Accion'),'gestion','accion'),
       O.object_id
FROM sys.indexes I
JOIN sys.objects O ON O.object_id = I.object_id
WHERE I.is_primary_key = 0 AND I.is_unique_constraint = 0 AND I.name IS NOT NULL
  AND O.type IN ('U','V') AND O.schema_id = SCHEMA_ID('dbo') AND O.name LIKE 'VCT[_]%'
  AND I.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%';

/* nombres que no cambian (mayusculas raras) */
INSERT INTO #RT_AVI (TXT)
SELECT N'SIN CAMBIO (revisar mayusculas): ' + CLASE + N' ' + ISNULL(TABLA + N'.', N'') + VIEJO
FROM #RT_REN WHERE VIEJO COLLATE Latin1_General_BIN = NUEVO COLLATE Latin1_General_BIN;
DELETE FROM #RT_REN WHERE VIEJO COLLATE Latin1_General_BIN = NUEVO COLLATE Latin1_General_BIN;

/* choques: el nombre nuevo ya existe */
INSERT INTO #RT_AVI (TXT)
SELECT N'CHOQUE: ya existe un objeto llamado ' + R.NUEVO + N' (para ' + R.VIEJO + N').'
FROM #RT_REN R
WHERE R.CLASE IN ('TABLA','VISTA','CONSTRAINT') AND OBJECT_ID(N'dbo.' + QUOTENAME(R.NUEVO)) IS NOT NULL;

INSERT INTO #RT_AVI (TXT)
SELECT N'CHOQUE: la tabla ' + R.TABLA + N' ya tiene una columna ' + R.NUEVO + N'.'
FROM #RT_REN R
WHERE R.CLASE = 'COLUMNA' AND COL_LENGTH(N'dbo.' + QUOTENAME(R.TABLA), R.NUEVO) IS NOT NULL;

/* palabras sueltas: reemplazarlas en el codigo tambien cambiaria valores de texto */
INSERT INTO #RT_AVI (TXT)
SELECT DISTINCT N'OJO: se renombra el nombre suelto ' + VIEJO + N' (sin "_"); un texto ''' + VIEJO + N''' en el codigo tambien cambiaria.'
FROM #RT_REN WHERE CLASE IN ('TABLA','VISTA','COLUMNA') AND CHARINDEX('_', VIEJO) = 0;

/* ---------------------------------------------------------------- 4. mapa de reemplazo para el codigo */
INSERT INTO #RT_MAP (VIEJO, NUEVO)
SELECT X.VIEJO, MIN(X.NUEVO)
FROM (SELECT VIEJO, NUEVO FROM #RT_REN) X
GROUP BY X.VIEJO
ORDER BY LEN(X.VIEJO) DESC;

/* ---------------------------------------------------------------- 5. codigo a reescribir */
INSERT INTO #RT_MOD (OBJ_ID, NOMBRE, TIPO, QI, AN, DEF)
SELECT O.object_id, O.name, O.type, M.uses_quoted_identifier, M.uses_ansi_nulls, M.definition
FROM sys.sql_modules M
JOIN sys.objects O ON O.object_id = M.object_id
WHERE O.type IN ('P','FN','IF','TF','V','TR') AND O.is_ms_shipped = 0
  AND M.definition IS NOT NULL
  AND M.definition COLLATE Latin1_General_CI_AS LIKE '%GESTION%';

DECLARE @oid INT, @txt NVARCHAR(MAX), @old SYSNAME, @new SYSNAME, @p INT, @lo INT, @cnt INT,
        @c1 NCHAR(1), @c2 NCHAR(1), @i INT, @nmap INT, @res INT, @q INT;
SELECT @nmap = COUNT(*) FROM #RT_MAP;

DECLARE cm CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #RT_MOD;
OPEN cm;
FETCH NEXT FROM cm INTO @oid;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @txt = DEF FROM #RT_MOD WHERE OBJ_ID = @oid;
    SET @cnt = 0;
    SET @i = 1;
    WHILE @i <= @nmap
    BEGIN
        SELECT @old = VIEJO, @new = NUEVO FROM #RT_MAP WHERE N = @i;
        SET @lo = LEN(@old);
        SET @p = CHARINDEX(@old COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS);
        WHILE @p > 0
        BEGIN
            SET @c1 = CASE WHEN @p > 1 THEN SUBSTRING(@txt, @p - 1, 1) ELSE N' ' END;
            SET @c2 = SUBSTRING(@txt, @p + @lo, 1);
            IF @c1 COLLATE Latin1_General_CI_AS LIKE N'[A-Za-z0-9_@#$]'
               OR @c2 COLLATE Latin1_General_CI_AS LIKE N'[A-Za-z0-9_$]'
                SET @p = CHARINDEX(@old COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS, @p + 1);
            ELSE
            BEGIN
                SET @txt = STUFF(@txt, @p, @lo, @new);
                SET @cnt = @cnt + 1;
                SET @p = CHARINDEX(@old COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS, @p + LEN(@new));
            END;
        END;
        SET @i = @i + 1;
    END;

    /* residuos: GESTION que queda fuera de variables/parametros (comentarios, textos, nombres de SP) */
    SET @res = 0;
    SET @p = CHARINDEX(N'GESTION' COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS);
    WHILE @p > 0
    BEGIN
        SET @q = @p;
        WHILE @q > 1 AND SUBSTRING(@txt, @q - 1, 1) COLLATE Latin1_General_CI_AS LIKE N'[A-Za-z0-9_]'
            SET @q = @q - 1;
        IF NOT (@q > 1 AND SUBSTRING(@txt, @q - 1, 1) = N'@')
            SET @res = @res + 1;
        SET @p = CHARINDEX(N'GESTION' COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS, @p + 7);
    END;

    UPDATE #RT_MOD SET NUEVA = @txt, REEMPLAZOS = @cnt, RESIDUOS = @res WHERE OBJ_ID = @oid;
    FETCH NEXT FROM cm INTO @oid;
END;
CLOSE cm;
DEALLOCATE cm;

DELETE FROM #RT_MOD WHERE REEMPLAZOS = 0;

/* orden de compilacion: vistas (por dependencia), funciones de tabla, escalares, SP, triggers */
UPDATE #RT_MOD SET ORDEN = CASE TIPO WHEN 'V' THEN 1 WHEN 'IF' THEN 2 WHEN 'TF' THEN 2 WHEN 'FN' THEN 3 WHEN 'P' THEN 4 ELSE 5 END;
DECLARE @k INT = 0;
WHILE @k < 10
BEGIN
    UPDATE M SET NIVEL = X.NV
    FROM #RT_MOD M
    JOIN (SELECT D.referencing_id, MAX(R.NIVEL) + 1 AS NV
          FROM sys.sql_expression_dependencies D
          JOIN #RT_MOD R ON R.OBJ_ID = D.referenced_id AND R.OBJ_ID <> D.referencing_id
          GROUP BY D.referencing_id) X ON X.referencing_id = M.OBJ_ID
    WHERE M.NIVEL < X.NV;
    IF @@ROWCOUNT = 0 BREAK;
    SET @k = @k + 1;
END;

/* ---------------------------------------------------------------- 6. plan */
PRINT '==================== PLAN ====================';
SELECT CLASE, TABLA, VIEJO, NUEVO FROM #RT_REN ORDER BY PASO, TABLA, VIEJO;
SELECT ORDEN, NIVEL, TIPO, NOMBRE, REEMPLAZOS, RESIDUOS FROM #RT_MOD ORDER BY ORDEN, NIVEL, NOMBRE;

PRINT '--- Objetos con GESTION en el nombre que NO se renombran (fuera de alcance o no son tablas):';
SELECT O.type_desc, O.name FROM sys.objects O
WHERE O.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%' AND O.is_ms_shipped = 0
  AND O.type IN ('U','V','P','FN','IF','TF','TR')
  AND NOT EXISTS (SELECT 1 FROM #RT_REN R WHERE R.OBJ_ID = O.object_id AND R.CLASE IN ('TABLA','VISTA'))
ORDER BY O.type_desc, O.name;

PRINT '--- Objetos a reescribir que YA estaban rotos (nombran tablas dbo que no existen). Se saltean y se informan:';
SELECT DISTINCT M.NOMBRE, D.referenced_entity_name AS TABLA_INEXISTENTE
FROM #RT_MOD M
JOIN sys.sql_expression_dependencies D ON D.referencing_id = M.OBJ_ID
WHERE D.referenced_id IS NULL AND D.referenced_database_name IS NULL AND D.referenced_server_name IS NULL
  AND D.referenced_schema_name = 'dbo'
  AND OBJECT_ID(N'dbo.' + QUOTENAME(D.referenced_entity_name)) IS NULL
ORDER BY M.NOMBRE;

PRINT '--- Datos de configuracion que mencionan tablas VCT_*GESTION* (no se cambian; revisar):';
DECLARE @scan NVARCHAR(MAX) = N'';
SELECT @scan = @scan + N'BEGIN TRY IF EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(T.name) + N' WITH(NOLOCK) WHERE ' + QUOTENAME(C.name)
             + N' LIKE ''%VCT[_]%GESTION%'') PRINT ''  ' + T.name + N'.' + C.name + N'''; END TRY BEGIN CATCH END CATCH;' + NCHAR(10)
FROM sys.columns C
JOIN sys.tables T ON T.object_id = C.object_id
JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE T.is_ms_shipped = 0 AND TY.name IN ('varchar','nvarchar') AND (C.max_length = -1 OR C.max_length >= 200)
  AND T.name NOT IN ('VCT_BUFFER');
EXEC sp_executesql @scan;

DECLARE @hay_choque BIT = CASE WHEN EXISTS (SELECT 1 FROM #RT_AVI WHERE TXT LIKE N'CHOQUE%') THEN 1 ELSE 0 END;
IF EXISTS (SELECT 1 FROM #RT_AVI)
BEGIN
    PRINT '--- AVISOS:';
    SELECT TXT AS AVISO FROM #RT_AVI ORDER BY N;
END;

IF NOT EXISTS (SELECT 1 FROM #RT_REN)
BEGIN
    PRINT 'No queda nada con GESTION para renombrar. No se hizo nada.';
    RETURN;
END;

IF @APLICAR = 0
BEGIN
    PRINT '';
    PRINT 'MODO VISTA PREVIA: no se cambio nada. Revisar el plan y correr con @APLICAR = 1.';
    RETURN;
END;

IF @hay_choque = 1
BEGIN
    RAISERROR('Hay choques de nombres (ver AVISOS). No se aplico nada.',16,1);
    RETURN;
END;

/* ---------------------------------------------------------------- 7. aplicar */
DECLARE @emsg NVARCHAR(2000), @paso NVARCHAR(400) = N'', @sql NVARCHAR(MAX), @tabla SYSNAME, @clase VARCHAR(20), @n INT,
        @trg_on BIT = 0, @qi BIT, @an BIT, @pos INT, @rest NVARCHAR(80);

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;

BEGIN TRY
    SET XACT_ABORT OFF;   /* para poder saltear un objeto que ya estaba roto sin perder la transaccion */
    BEGIN TRANSACTION;

    IF @trg_on = 1
        DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    /* 7a. tablas y vistas */
    DECLARE cr CURSOR LOCAL FAST_FORWARD FOR SELECT N FROM #RT_REN ORDER BY PASO, N;
    OPEN cr;
    FETCH NEXT FROM cr INTO @n;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @clase = CLASE, @tabla = TABLA, @old = VIEJO, @new = NUEVO FROM #RT_REN WHERE N = @n;

        /* la tabla de una columna/indice puede haber sido renombrada en el paso 1 */
        IF @tabla IS NOT NULL
            SELECT @tabla = ISNULL((SELECT R.NUEVO FROM #RT_REN R WHERE R.CLASE IN ('TABLA','VISTA') AND R.VIEJO = @tabla), @tabla);

        SET @paso = @clase + N' ' + ISNULL(@tabla + N'.', N'') + @old + N' -> ' + @new;

        IF @clase IN ('TABLA','VISTA')
        BEGIN
            SET @sql = N'dbo.' + QUOTENAME(@old);
            EXEC sp_rename @sql, @new;
        END
        ELSE IF @clase = 'COLUMNA'
        BEGIN
            SET @sql = N'dbo.' + QUOTENAME(@tabla) + N'.' + QUOTENAME(@old);
            EXEC sp_rename @sql, @new, 'COLUMN';
        END
        ELSE IF @clase = 'CONSTRAINT'
        BEGIN
            SET @sql = N'dbo.' + QUOTENAME(@old);
            EXEC sp_rename @sql, @new, 'OBJECT';
        END
        ELSE IF @clase = 'INDICE'
        BEGIN
            SET @sql = N'dbo.' + QUOTENAME(@tabla) + N'.' + QUOTENAME(@old);
            EXEC sp_rename @sql, @new, 'INDEX';
        END;

        FETCH NEXT FROM cr INTO @n;
    END;
    CLOSE cr;
    DEALLOCATE cr;

    /* 7b. codigo: CREATE -> ALTER y compilar con las opciones originales */
    DECLARE cx CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #RT_MOD ORDER BY ORDEN, NIVEL, NOMBRE;
    OPEN cx;
    FETCH NEXT FROM cx INTO @oid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @txt = NUEVA, @qi = QI, @an = AN, @paso = N'ALTER ' + NOMBRE FROM #RT_MOD WHERE OBJ_ID = @oid;

        SET @pos = 0;
        WHILE 1 = 1
        BEGIN
            SET @pos = CHARINDEX(N'CREATE' COLLATE Latin1_General_CI_AS, @txt COLLATE Latin1_General_CI_AS, @pos + 1);
            IF @pos = 0 BREAK;
            IF @pos > 1 AND SUBSTRING(@txt, @pos - 1, 1) COLLATE Latin1_General_CI_AS LIKE N'[A-Za-z0-9_@#]' CONTINUE;
            SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@txt, @pos + 6, 60), NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' '));
            IF @rest COLLATE Latin1_General_CI_AS LIKE N'OR ALTER%' BREAK;
            IF @rest COLLATE Latin1_General_CI_AS LIKE N'PROC%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'FUNCTION%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'VIEW%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'TRIGGER%'
            BEGIN
                SET @txt = STUFF(@txt, @pos, 6, N'ALTER');
                BREAK;
            END;
        END;
        IF @pos = 0
            RAISERROR('No se encontro el CREATE del objeto.',16,1);

        SET @sql = N'SET QUOTED_IDENTIFIER ' + CASE WHEN @qi = 1 THEN N'ON' ELSE N'OFF' END
                 + N'; SET ANSI_NULLS ' + CASE WHEN @an = 1 THEN N'ON' ELSE N'OFF' END
                 + N'; EXEC sp_executesql @d;';
        SAVE TRANSACTION SP_MOD;
        BEGIN TRY
            EXEC sp_executesql @sql, N'@d NVARCHAR(MAX)', @d = @txt;
        END TRY
        BEGIN CATCH
            SET @emsg = ERROR_MESSAGE();
            /* Si el error nombra algo de lo que se renombra, es un problema real: se aborta todo.
               Si no (ej. el objeto ya apuntaba a una tabla borrada), se saltea y se informa. */
            IF XACT_STATE() = -1
               OR EXISTS (SELECT 1 FROM #RT_REN R
                          WHERE CHARINDEX(R.VIEJO COLLATE Latin1_General_CI_AS, @emsg COLLATE Latin1_General_CI_AS) > 0
                             OR CHARINDEX(R.NUEVO COLLATE Latin1_General_CI_AS, @emsg COLLATE Latin1_General_CI_AS) > 0)
                RAISERROR('%s',16,1,@emsg);
            ROLLBACK TRANSACTION SP_MOD;
            INSERT INTO #RT_ROTOS (NOMBRE, ERROR) SELECT NOMBRE, @emsg FROM #RT_MOD WHERE OBJ_ID = @oid;
        END CATCH;

        FETCH NEXT FROM cx INTO @oid;
    END;
    CLOSE cx;
    DEALLOCATE cx;

    /* 7c. vistas que no se reescribieron pero leen tablas renombradas (SELECT *): refrescar metadata */
    DECLARE cv CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT V.name
        FROM sys.sql_expression_dependencies D
        JOIN sys.views V ON V.object_id = D.referencing_id
        JOIN #RT_REN R ON R.OBJ_ID = D.referenced_id AND R.CLASE IN ('TABLA','VISTA')
        WHERE NOT EXISTS (SELECT 1 FROM #RT_MOD M WHERE M.OBJ_ID = V.object_id);
    OPEN cv;
    FETCH NEXT FROM cv INTO @new;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = N'sp_refreshview ' + @new;
        SET @sql = N'dbo.' + QUOTENAME(@new);
        EXEC sp_refreshview @sql;
        FETCH NEXT FROM cv INTO @new;
    END;
    CLOSE cv;
    DEALLOCATE cv;

    IF @trg_on = 1
        ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    COMMIT TRANSACTION;

    PRINT '';
    PRINT 'OK: Gestiones -> Acciones aplicado.';
    SELECT CLASE, COUNT(*) AS RENOMBRADOS FROM #RT_REN GROUP BY CLASE;
    SELECT (SELECT COUNT(*) FROM #RT_MOD) - (SELECT COUNT(*) FROM #RT_ROTOS) AS OBJETOS_REESCRITOS;

    IF EXISTS (SELECT 1 FROM #RT_ROTOS)
    BEGIN
        PRINT '--- SALTEADOS: ya no compilaban antes de este script (quedan con los nombres viejos; arreglarlos o borrarlos):';
        SELECT NOMBRE, ERROR FROM #RT_ROTOS ORDER BY NOMBRE;
    END;

    PRINT '--- Objetos que todavia nombran tablas viejas (revisar a mano):';
    SELECT O.type_desc, O.name, R.VIEJO
    FROM #RT_REN R
    JOIN sys.sql_modules M ON M.definition COLLATE Latin1_General_CI_AS LIKE N'%[^A-Za-z0-9_@]' + R.VIEJO + N'[^A-Za-z0-9_]%'
    JOIN sys.objects O ON O.object_id = M.object_id
    WHERE R.CLASE IN ('TABLA','VISTA')
    ORDER BY O.name;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','cr') >= -1 BEGIN IF CURSOR_STATUS('local','cr') >= 0 CLOSE cr; DEALLOCATE cr; END;
    IF CURSOR_STATUS('local','cx') >= -1 BEGIN IF CURSOR_STATUS('local','cx') >= 0 CLOSE cx; DEALLOCATE cx; END;
    IF CURSOR_STATUS('local','cv') >= -1 BEGIN IF CURSOR_STATUS('local','cv') >= 0 CLOSE cv; DEALLOCATE cv; END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @err NVARCHAR(2000) = N'FALLO en [' + ISNULL(@paso, N'?') + N']: ' + ERROR_MESSAGE()
                                + N' (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'). Se deshizo todo; la base quedo como estaba.';
    RAISERROR('%s',16,1,@err);
END CATCH;
GO
