/* ========================================================================
   ACCIONES_RENOMBRAR_SPS
   ------------------------------------------------------------------------
   Segunda parte de Gestiones -> Acciones (correr DESPUES de
   ACCIONES_RENOMBRAR_TABLAS.sql).
     1. SP y funciones dbo.VCT_* con GESTION en el nombre pasan a ACCION:
          VCT_GESTION_CREAR               -> VCT_ACCION_CREAR
          VCT_GESTION_CAMBIAR_ESTADO      -> VCT_ACCION_CAMBIAR_ESTADO
          VCT_GESTION_COMENTARIO_AGREGAR  -> VCT_ACCION_COMENTARIO_AGREGAR
          VCT_GESTION_PARTICIPANTE_AGREGAR-> VCT_ACCION_PARTICIPANTE_AGREGAR
        (se detectan solos). Se crea el nuevo con el texto revisado, se
        copian los permisos (GRANT) y se borra el viejo.
     2. Revision interna: en esos SP y en TODO el codigo que los llama o
        que todavia nombra tablas/columnas de gestiones, se reemplazan
        (palabra completa):
          - los nombres de SP viejos por los nuevos,
          - los nombres de tablas/vistas/columnas viejos (VCT_GESTIONES,
            ID_GESTION...) por los actuales (VCT_ACCIONES, ID_ACCION...).
        No se tocan variables/parametros (@ID_GESTION_OUT sigue igual, asi
        los EXEC con parametros por nombre no se rompen), ni textos
        visibles, ni valores 'GESTION'.
     3. Datos: columnas de texto que guardan el nombre de alguno de esos SP
        (ruteo, reglas, etc.) se actualizan al nombre nuevo
        (@ACTUALIZAR_DATOS = 1). Se excluyen tablas de log/auditoria.
   Fuera de alcance: objetos que no empiezan con VCT_ (FN_GET_OBLIGA_MINUTA_GESTION,
   HOME_ADD_MINUTA_GESTION son legacy de la plataforma): se listan.

   Uso: correrlo con @APLICAR = 0 (no cambia nada, muestra el plan), revisar
   y correrlo con @APLICAR = 1. Todo en UNA transaccion; si algo falla se
   deshace todo. Un objeto que ya no compilaba antes (apunta a una tabla
   borrada) se saltea y se informa. El trigger TR_VCT_AUDITORIA_DDL se
   apaga mientras corre. Despues: DUMP_OBJETOS + split_dump.py y commitear.
   Compat 100 y 140. Re-ejecutable.
   ======================================================================== */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\ACCIONES_RENOMBRAR_SPS.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @APLICAR BIT = 0;           /* 0 = solo mostrar el plan | 1 = aplicar */
DECLARE @ACTUALIZAR_DATOS BIT = 1;  /* 1 = actualizar nombres de SP guardados en tablas */

/* Nombres de SP/funcion que NO se renombran. Ej.: INSERT INTO @EXCLUIR VALUES ('VCT_GESTION_XXX'); */
DECLARE @EXCLUIR TABLE (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY);

IF OBJECT_ID('dbo.VCT_GESTIONES','U') IS NOT NULL
BEGIN
    RAISERROR('Todavia existe dbo.VCT_GESTIONES: correr antes ACCIONES_RENOMBRAR_TABLAS.sql con @APLICAR = 1.',16,1);
    RETURN;
END;

IF OBJECT_ID('tempdb..#RS_SPS') IS NOT NULL DROP TABLE #RS_SPS;
IF OBJECT_ID('tempdb..#RS_MAP') IS NOT NULL DROP TABLE #RS_MAP;
IF OBJECT_ID('tempdb..#RS_MOD') IS NOT NULL DROP TABLE #RS_MOD;
IF OBJECT_ID('tempdb..#RS_AVI') IS NOT NULL DROP TABLE #RS_AVI;
IF OBJECT_ID('tempdb..#RS_ROTOS') IS NOT NULL DROP TABLE #RS_ROTOS;
IF OBJECT_ID('tempdb..#RS_DAT') IS NOT NULL DROP TABLE #RS_DAT;
IF OBJECT_ID('tempdb..#RS_PERM') IS NOT NULL DROP TABLE #RS_PERM;

CREATE TABLE #RS_SPS (OBJ_ID INT PRIMARY KEY, TIPO VARCHAR(2), VIEJO SYSNAME COLLATE DATABASE_DEFAULT, NUEVO SYSNAME COLLATE DATABASE_DEFAULT);
CREATE TABLE #RS_MAP (N INT IDENTITY PRIMARY KEY, CLASE VARCHAR(20), VIEJO SYSNAME COLLATE DATABASE_DEFAULT, NUEVO SYSNAME COLLATE DATABASE_DEFAULT);
CREATE TABLE #RS_MOD (OBJ_ID INT PRIMARY KEY, NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, NOMBRE_FINAL SYSNAME COLLATE DATABASE_DEFAULT,
                   TIPO VARCHAR(2), ES_RENOMBRADO BIT DEFAULT 0, NIVEL INT DEFAULT 0, ORDEN INT DEFAULT 0,
                   QI BIT, AN BIT, DEF NVARCHAR(MAX), NUEVA NVARCHAR(MAX), REEMPLAZOS INT DEFAULT 0);
CREATE TABLE #RS_AVI (N INT IDENTITY, TXT NVARCHAR(2000));
CREATE TABLE #RS_ROTOS (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, ERROR NVARCHAR(2000));
CREATE TABLE #RS_DAT (TABLA SYSNAME COLLATE DATABASE_DEFAULT, COLUMNA SYSNAME COLLATE DATABASE_DEFAULT, FILAS INT);
CREATE TABLE #RS_PERM (SP_NUEVO SYSNAME COLLATE DATABASE_DEFAULT, SENTENCIA NVARCHAR(1000));

/* ---------------------------------------------------------------- 1. SP / funciones a renombrar */
INSERT INTO #RS_SPS (OBJ_ID, TIPO, VIEJO, NUEVO)
SELECT O.object_id, O.type, O.name,
       REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(O.name COLLATE Latin1_General_BIN,
           'GESTIONES','ACCIONES'),'Gestiones','Acciones'),'gestiones','acciones'),
           'GESTION','ACCION'),'Gestion','Accion'),'gestion','accion')
FROM sys.objects O
WHERE O.type IN ('P','FN','IF','TF') AND O.schema_id = SCHEMA_ID('dbo') AND O.is_ms_shipped = 0
  AND O.name LIKE 'VCT[_]%'
  AND O.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%'
  AND NOT EXISTS (SELECT 1 FROM @EXCLUIR E WHERE E.NOMBRE = O.name);

INSERT INTO #RS_AVI (TXT)
SELECT N'CHOQUE: ya existe ' + NUEVO + N' (para ' + VIEJO + N').'
FROM #RS_SPS WHERE OBJECT_ID(N'dbo.' + QUOTENAME(NUEVO)) IS NOT NULL;

INSERT INTO #RS_AVI (TXT)
SELECT N'SIN CAMBIO (revisar mayusculas): ' + VIEJO FROM #RS_SPS WHERE VIEJO COLLATE Latin1_General_BIN = NUEVO COLLATE Latin1_General_BIN;
DELETE FROM #RS_SPS WHERE VIEJO COLLATE Latin1_General_BIN = NUEVO COLLATE Latin1_General_BIN;

/* permisos de los SP viejos, para repetirlos en los nuevos */
INSERT INTO #RS_PERM (SP_NUEVO, SENTENCIA)
SELECT S.NUEVO,
       DP.state_desc COLLATE DATABASE_DEFAULT + N' ' + DP.permission_name COLLATE DATABASE_DEFAULT
       + N' ON dbo.' + QUOTENAME(S.NUEVO) + N' TO ' + QUOTENAME(PR.name)
FROM #RS_SPS S
JOIN sys.database_permissions DP ON DP.major_id = S.OBJ_ID AND DP.class = 1
JOIN sys.database_principals PR ON PR.principal_id = DP.grantee_principal_id
WHERE DP.state_desc IN ('GRANT','DENY');

/* ---------------------------------------------------------------- 2. mapa de reemplazo */
/* 2a. nombres de SP */
INSERT INTO #RS_MAP (CLASE, VIEJO, NUEVO) SELECT 'SP', VIEJO, NUEVO FROM #RS_SPS;

/* 2b. tablas/vistas ya renombradas: nombre viejo (GESTION) que ya no existe -> nombre actual */
INSERT INTO #RS_MAP (CLASE, VIEJO, NUEVO)
SELECT DISTINCT 'TABLA', X.VIEJO, X.NUEVO
FROM (
    SELECT O.name AS NUEVO,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(O.name COLLATE Latin1_General_BIN,
               'ACCIONES','GESTIONES'),'Acciones','Gestiones'),'acciones','gestiones'),
               'ACCION','GESTION'),'Accion','Gestion'),'accion','gestion') AS VIEJO
    FROM sys.objects O
    WHERE O.type IN ('U','V') AND O.schema_id = SCHEMA_ID('dbo') AND O.name LIKE 'VCT[_]%'
      AND O.name COLLATE Latin1_General_CI_AS LIKE '%ACCION%'
) X
WHERE X.VIEJO COLLATE Latin1_General_BIN <> X.NUEVO COLLATE Latin1_General_BIN
  AND CHARINDEX('_', X.VIEJO) > 0
  AND OBJECT_ID(N'dbo.' + QUOTENAME(X.VIEJO)) IS NULL
  AND NOT EXISTS (SELECT 1 FROM #RS_MAP M WHERE M.VIEJO = X.VIEJO);

/* 2c. columnas ya renombradas en tablas VCT_*: nombre viejo que ya no existe en ninguna tabla */
INSERT INTO #RS_MAP (CLASE, VIEJO, NUEVO)
SELECT DISTINCT 'COLUMNA', X.VIEJO, X.NUEVO
FROM (
    SELECT C.name AS NUEVO,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(C.name COLLATE Latin1_General_BIN,
               'ACCIONES','GESTIONES'),'Acciones','Gestiones'),'acciones','gestiones'),
               'ACCION','GESTION'),'Accion','Gestion'),'accion','gestion') AS VIEJO
    FROM sys.columns C
    JOIN sys.tables T ON T.object_id = C.object_id
    WHERE T.schema_id = SCHEMA_ID('dbo') AND T.name LIKE 'VCT[_]%'
      AND C.name COLLATE Latin1_General_CI_AS LIKE '%ACCION%'
) X
WHERE X.VIEJO COLLATE Latin1_General_BIN <> X.NUEVO COLLATE Latin1_General_BIN
  AND CHARINDEX('_', X.VIEJO) > 0      /* nunca reemplazar la palabra suelta GESTION */
  AND NOT EXISTS (SELECT 1 FROM sys.columns C2 WHERE C2.name = X.VIEJO)
  AND NOT EXISTS (SELECT 1 FROM #RS_MAP M WHERE M.VIEJO = X.VIEJO);

/* ---------------------------------------------------------------- 3. codigo a revisar */
INSERT INTO #RS_MOD (OBJ_ID, NOMBRE, NOMBRE_FINAL, TIPO, ES_RENOMBRADO, QI, AN, DEF)
SELECT O.object_id, O.name, ISNULL(S.NUEVO, O.name), O.type, CASE WHEN S.OBJ_ID IS NULL THEN 0 ELSE 1 END,
       M.uses_quoted_identifier, M.uses_ansi_nulls, M.definition
FROM sys.sql_modules M
JOIN sys.objects O ON O.object_id = M.object_id
LEFT JOIN #RS_SPS S ON S.OBJ_ID = O.object_id
WHERE O.type IN ('P','FN','IF','TF','V','TR') AND O.is_ms_shipped = 0
  AND M.definition IS NOT NULL
  AND (S.OBJ_ID IS NOT NULL OR M.definition COLLATE Latin1_General_CI_AS LIKE '%GESTION%');

DECLARE @oid INT, @txt NVARCHAR(MAX), @old SYSNAME, @new SYSNAME, @p INT, @lo INT, @cnt INT,
        @c1 NCHAR(1), @c2 NCHAR(1), @i INT, @nmap INT;
SELECT @nmap = MAX(N) FROM #RS_MAP;

DECLARE cm CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #RS_MOD;
OPEN cm;
FETCH NEXT FROM cm INTO @oid;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @txt = DEF FROM #RS_MOD WHERE OBJ_ID = @oid;
    SET @cnt = 0;
    SET @i = 1;
    WHILE @i <= ISNULL(@nmap, 0)
    BEGIN
        SELECT @old = VIEJO, @new = NUEVO FROM #RS_MAP WHERE N = @i;
        IF @@ROWCOUNT = 1
        BEGIN
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
        END;
        SET @i = @i + 1;
    END;
    UPDATE #RS_MOD SET NUEVA = @txt, REEMPLAZOS = @cnt WHERE OBJ_ID = @oid;
    FETCH NEXT FROM cm INTO @oid;
END;
CLOSE cm;
DEALLOCATE cm;

/* los renombrados se recrean siempre; el resto solo si cambio algo */
DELETE FROM #RS_MOD WHERE REEMPLAZOS = 0 AND ES_RENOMBRADO = 0;

INSERT INTO #RS_AVI (TXT)
SELECT N'OJO: en ' + NOMBRE + N' no se encontro su propio nombre para cambiarlo en el CREATE; revisar.'
FROM #RS_MOD M
WHERE M.ES_RENOMBRADO = 1
  AND CHARINDEX(M.NOMBRE_FINAL COLLATE Latin1_General_CI_AS, M.NUEVA COLLATE Latin1_General_CI_AS) = 0;

/* orden: SP/funciones renombrados primero (se crean), despues vistas, funciones, SP y triggers que cambian */
UPDATE #RS_MOD SET ORDEN = CASE WHEN ES_RENOMBRADO = 1 THEN 0
                             ELSE CASE TIPO WHEN 'V' THEN 1 WHEN 'IF' THEN 2 WHEN 'TF' THEN 2 WHEN 'FN' THEN 3 WHEN 'P' THEN 4 ELSE 5 END END;
DECLARE @k INT = 0;
WHILE @k < 10
BEGIN
    UPDATE M SET NIVEL = X.NV
    FROM #RS_MOD M
    JOIN (SELECT D.referencing_id, MAX(R.NIVEL) + 1 AS NV
          FROM sys.sql_expression_dependencies D
          JOIN #RS_MOD R ON R.OBJ_ID = D.referenced_id AND R.OBJ_ID <> D.referencing_id
          GROUP BY D.referencing_id) X ON X.referencing_id = M.OBJ_ID
    WHERE M.NIVEL < X.NV;
    IF @@ROWCOUNT = 0 BREAK;
    SET @k = @k + 1;
END;

/* ---------------------------------------------------------------- 4. datos que guardan nombres de SP */
DECLARE @scan NVARCHAR(MAX) = N'';
SELECT @scan = @scan
     + N'BEGIN TRY INSERT INTO #RS_DAT SELECT ''' + T.name + N''',''' + C.name + N''',COUNT(*) FROM dbo.' + QUOTENAME(T.name) + N' WITH(NOLOCK) WHERE '
     + QUOTENAME(C.name) + N' COLLATE Latin1_General_CI_AS LIKE ''%VCT[_]GESTION[_]%'' HAVING COUNT(*) > 0; END TRY BEGIN CATCH END CATCH;' + NCHAR(10)
FROM sys.columns C
JOIN sys.tables T ON T.object_id = C.object_id
JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE T.is_ms_shipped = 0 AND TY.name IN ('varchar','nvarchar','char','nchar')
  AND (C.max_length = -1 OR C.max_length >= 20)
  AND T.name NOT LIKE '%LOG%' AND T.name NOT LIKE '%AUDIT%' AND T.name NOT LIKE 'LK[_]%'
  AND C.is_computed = 0;
IF EXISTS (SELECT 1 FROM #RS_SPS)
    EXEC sp_executesql @scan;

/* ---------------------------------------------------------------- 5. plan */
PRINT '==================== PLAN ====================';
PRINT '--- SP / funciones que se renombran:';
SELECT TIPO, VIEJO, NUEVO FROM #RS_SPS ORDER BY VIEJO;
PRINT '--- Nombres que se reemplazan dentro del codigo:';
SELECT CLASE, VIEJO, NUEVO FROM #RS_MAP ORDER BY CLASE, VIEJO;
PRINT '--- Objetos que se recrean o reescriben:';
SELECT ORDEN, NIVEL, TIPO, NOMBRE, NOMBRE_FINAL, REEMPLAZOS FROM #RS_MOD ORDER BY ORDEN, NIVEL, NOMBRE;
PRINT '--- Permisos que se copian:';
SELECT SENTENCIA FROM #RS_PERM;
PRINT '--- Datos que guardan nombres VCT_GESTION_* (se actualizan si @ACTUALIZAR_DATOS = 1):';
SELECT TABLA, COLUMNA, FILAS FROM #RS_DAT ORDER BY TABLA, COLUMNA;

PRINT '--- Objetos con GESTION en el nombre que quedan como estan (fuera de alcance):';
SELECT O.type_desc, O.name FROM sys.objects O
WHERE O.name COLLATE Latin1_General_CI_AS LIKE '%GESTION%' AND O.is_ms_shipped = 0
  AND O.type IN ('U','V','P','FN','IF','TF','TR')
  AND NOT EXISTS (SELECT 1 FROM #RS_SPS S WHERE S.OBJ_ID = O.object_id)
ORDER BY O.type_desc, O.name;

PRINT '--- Objetos que ya estaban rotos (nombran tablas dbo que no existen): se saltean si fallan:';
SELECT DISTINCT M.NOMBRE, D.referenced_entity_name AS TABLA_INEXISTENTE
FROM #RS_MOD M
JOIN sys.sql_expression_dependencies D ON D.referencing_id = M.OBJ_ID
WHERE D.referenced_id IS NULL AND D.referenced_database_name IS NULL AND D.referenced_server_name IS NULL
  AND D.referenced_schema_name = 'dbo'
  AND OBJECT_ID(N'dbo.' + QUOTENAME(D.referenced_entity_name)) IS NULL
  AND NOT EXISTS (SELECT 1 FROM #RS_MAP P WHERE P.VIEJO = D.referenced_entity_name)
ORDER BY M.NOMBRE;

IF EXISTS (SELECT 1 FROM #RS_AVI)
BEGIN
    PRINT '--- AVISOS:';
    SELECT TXT AS AVISO FROM #RS_AVI ORDER BY N;
END;

IF NOT EXISTS (SELECT 1 FROM #RS_SPS) AND NOT EXISTS (SELECT 1 FROM #RS_MOD)
BEGIN
    PRINT 'No queda nada para renombrar ni revisar. No se hizo nada.';
    RETURN;
END;

IF @APLICAR = 0
BEGIN
    PRINT '';
    PRINT 'MODO VISTA PREVIA: no se cambio nada. Revisar el plan y correr con @APLICAR = 1.';
    RETURN;
END;

IF EXISTS (SELECT 1 FROM #RS_AVI WHERE TXT LIKE N'CHOQUE%')
BEGIN
    RAISERROR('Hay choques de nombres (ver AVISOS). No se aplico nada.',16,1);
    RETURN;
END;

/* ---------------------------------------------------------------- 6. aplicar */
DECLARE @emsg NVARCHAR(2000), @paso NVARCHAR(400) = N'', @sql NVARCHAR(MAX), @qi BIT, @an BIT,
        @pos INT, @rest NVARCHAR(80), @esren BIT, @trg_on BIT = 0, @tabla SYSNAME, @col SYSNAME;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;

BEGIN TRY
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION;

    IF @trg_on = 1
        DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    /* 6a. crear los nuevos (CREATE) y reescribir el resto (ALTER) */
    DECLARE cx CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #RS_MOD ORDER BY ORDEN, NIVEL, NOMBRE;
    OPEN cx;
    FETCH NEXT FROM cx INTO @oid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @txt = NUEVA, @qi = QI, @an = AN, @esren = ES_RENOMBRADO,
               @paso = CASE WHEN ES_RENOMBRADO = 1 THEN N'CREATE ' + NOMBRE_FINAL ELSE N'ALTER ' + NOMBRE END
        FROM #RS_MOD WHERE OBJ_ID = @oid;

        /* los renombrados quedan como CREATE (objeto nuevo); el resto pasa a ALTER */
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
                IF @esren = 0
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
            /* un SP renombrado tiene que crearse si o si; un objeto que no se renombra y falla por algo
               ajeno a este cambio (ya estaba roto) se saltea */
            IF XACT_STATE() = -1 OR @esren = 1
               OR EXISTS (SELECT 1 FROM #RS_MAP P
                          WHERE CHARINDEX(P.VIEJO COLLATE Latin1_General_CI_AS, @emsg COLLATE Latin1_General_CI_AS) > 0
                             OR CHARINDEX(P.NUEVO COLLATE Latin1_General_CI_AS, @emsg COLLATE Latin1_General_CI_AS) > 0)
                RAISERROR('%s',16,1,@emsg);
            ROLLBACK TRANSACTION SP_MOD;
            INSERT INTO #RS_ROTOS (NOMBRE, ERROR) SELECT NOMBRE, @emsg FROM #RS_MOD WHERE OBJ_ID = @oid;
        END CATCH;

        FETCH NEXT FROM cx INTO @oid;
    END;
    CLOSE cx;
    DEALLOCATE cx;

    /* 6b. permisos en los nuevos */
    DECLARE cp CURSOR LOCAL FAST_FORWARD FOR SELECT SENTENCIA FROM #RS_PERM;
    OPEN cp;
    FETCH NEXT FROM cp INTO @sql;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = @sql;
        EXEC sp_executesql @sql;
        FETCH NEXT FROM cp INTO @sql;
    END;
    CLOSE cp;
    DEALLOCATE cp;

    /* 6c. borrar los viejos */
    DECLARE cd CURSOR LOCAL FAST_FORWARD FOR SELECT TIPO, VIEJO FROM #RS_SPS;
    OPEN cd;
    FETCH NEXT FROM cd INTO @rest, @old;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = N'DROP ' + @old;
        SET @sql = CASE WHEN @rest = 'P' THEN N'DROP PROCEDURE dbo.' ELSE N'DROP FUNCTION dbo.' END + QUOTENAME(@old);
        EXEC sp_executesql @sql;
        FETCH NEXT FROM cd INTO @rest, @old;
    END;
    CLOSE cd;
    DEALLOCATE cd;

    /* 6d. datos que guardan el nombre de los SP */
    IF @ACTUALIZAR_DATOS = 1
    BEGIN
        DECLARE cdat CURSOR LOCAL FAST_FORWARD FOR SELECT TABLA, COLUMNA FROM #RS_DAT;
        OPEN cdat;
        FETCH NEXT FROM cdat INTO @tabla, @col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE cs CURSOR LOCAL FAST_FORWARD FOR SELECT VIEJO, NUEVO FROM #RS_SPS ORDER BY LEN(VIEJO) DESC;
            OPEN cs;
            FETCH NEXT FROM cs INTO @old, @new;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @paso = N'UPDATE ' + @tabla + N'.' + @col + N' (' + @old + N')';
                SET @sql = N'UPDATE dbo.' + QUOTENAME(@tabla) + N' SET ' + QUOTENAME(@col) + N' = REPLACE(' + QUOTENAME(@col) + N', @o, @n)'
                         + N' WHERE ' + QUOTENAME(@col) + N' COLLATE Latin1_General_CI_AS LIKE N''%'' + @o + N''%'';';
                EXEC sp_executesql @sql, N'@o NVARCHAR(128), @n NVARCHAR(128)', @o = @old, @n = @new;
                FETCH NEXT FROM cs INTO @old, @new;
            END;
            CLOSE cs;
            DEALLOCATE cs;
            FETCH NEXT FROM cdat INTO @tabla, @col;
        END;
        CLOSE cdat;
        DEALLOCATE cdat;
    END;

    IF @trg_on = 1
        ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    COMMIT TRANSACTION;

    PRINT '';
    PRINT 'OK: SP de gestiones renombrados a acciones y codigo revisado.';
    SELECT VIEJO AS SP_BORRADO, NUEVO AS SP_NUEVO FROM #RS_SPS ORDER BY NUEVO;
    SELECT (SELECT COUNT(*) FROM #RS_MOD) - (SELECT COUNT(*) FROM #RS_ROTOS) AS OBJETOS_CREADOS_O_REESCRITOS;

    IF EXISTS (SELECT 1 FROM #RS_ROTOS)
    BEGIN
        PRINT '--- SALTEADOS: ya no compilaban antes de este script (arreglarlos o borrarlos):';
        SELECT NOMBRE, ERROR FROM #RS_ROTOS ORDER BY NOMBRE;
    END;

    PRINT '--- Codigo que todavia nombra algo viejo (revisar a mano):';
    SELECT DISTINCT O.type_desc, O.name, P.VIEJO
    FROM #RS_MAP P
    JOIN sys.sql_modules M ON M.definition COLLATE Latin1_General_CI_AS LIKE N'%[^A-Za-z0-9_@]' + REPLACE(P.VIEJO, '_', '[_]') + N'[^A-Za-z0-9_]%'
    JOIN sys.objects O ON O.object_id = M.object_id
    ORDER BY O.name;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','cx') >= -1 BEGIN IF CURSOR_STATUS('local','cx') >= 0 CLOSE cx; DEALLOCATE cx; END;
    IF CURSOR_STATUS('local','cp') >= -1 BEGIN IF CURSOR_STATUS('local','cp') >= 0 CLOSE cp; DEALLOCATE cp; END;
    IF CURSOR_STATUS('local','cd') >= -1 BEGIN IF CURSOR_STATUS('local','cd') >= 0 CLOSE cd; DEALLOCATE cd; END;
    IF CURSOR_STATUS('local','cs') >= -1 BEGIN IF CURSOR_STATUS('local','cs') >= 0 CLOSE cs; DEALLOCATE cs; END;
    IF CURSOR_STATUS('local','cdat') >= -1 BEGIN IF CURSOR_STATUS('local','cdat') >= 0 CLOSE cdat; DEALLOCATE cdat; END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @err NVARCHAR(2000) = N'FALLO en [' + ISNULL(@paso, N'?') + N']: ' + ERROR_MESSAGE()
                                + N' (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'). Se deshizo todo; la base quedo como estaba.';
    RAISERROR('%s',16,1,@err);
END CATCH;
GO
