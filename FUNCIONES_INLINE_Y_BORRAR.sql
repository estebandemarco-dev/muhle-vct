/* ========================================================================
   FUNCIONES_INLINE_Y_BORRAR
   ------------------------------------------------------------------------
   Situacion (10/10): las funciones escalares se borraron a mano; queda solo
   VCT_MAIN_RENDER_ACTION (y la de tabla VCT_MAIN_GET_ACTIONS, la de permisos).
   Los SP que llamaban a VCT_HTML_ESC o VCT_PERFIL_PUEDE quedaron rotos.
   Este script los ARREGLA sobre su definicion vigente:
     dbo.VCT_HTML_ESC(x)                    -> REPLACE(...) de & < > "
     dbo.VCT_PERFIL_PUEDE(@IUNIDAD,'MOD.ACC') -> CASE WHEN EXISTS(SELECT 1 FROM
                         dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD,'MOD') WHERE ACTION_ID='MOD.ACC')
                         THEN 1 ELSE 0 END
   La fuente de permisos es VCT_MAIN_GET_ACTIONS: si una accion no esta en
   PrmActions, se lista para cargarla ahi (no se fuerza nada en el codigo).
   Si alguna de las funciones de la lista todavia existe, la borra al final
   (VCT_MAIN_RENDER_ACTION NO se toca).
   Los SP que usaban VCT_FMT_HORAS, VCT_CK_VALOR, VCT_PROYECTO_HORAS_USADAS_TXT
   o VCT_MIG_PROY_IMPORTE no se arreglan (se redisenan): se listan.
   @APLICAR = 0: no cambia nada; muestra que objetos y cuantas llamadas.
   @APLICAR = 1: aplica todo en UNA transaccion. Un objeto que no compila por
                 algo ajeno (tabla o funcion borrada) se saltea y se informa;
                 cualquier otro error deshace todo.
   El trigger TR_VCT_AUDITORIA_DDL se apaga mientras corre.
   ======================================================================== */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\FUNCIONES_INLINE_Y_BORRAR.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @APLICAR BIT = 0;   /* 0 = solo mostrar | 1 = aplicar */

IF OBJECT_ID('tempdb..#IN_FN') IS NOT NULL DROP TABLE #IN_FN;
IF OBJECT_ID('tempdb..#IN_MOD') IS NOT NULL DROP TABLE #IN_MOD;
IF OBJECT_ID('tempdb..#IN_ERR') IS NOT NULL DROP TABLE #IN_ERR;
IF OBJECT_ID('tempdb..#IN_ROTOS') IS NOT NULL DROP TABLE #IN_ROTOS;
CREATE TABLE #IN_FN (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY, NARGS INT, TPL NVARCHAR(MAX));
CREATE TABLE #IN_MOD (OBJ_ID INT PRIMARY KEY, NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, TIPO VARCHAR(2), QI BIT, AN BIT,
                   DEF NVARCHAR(MAX), NUEVA NVARCHAR(MAX), LLAMADAS INT DEFAULT 0, QUEDAN INT DEFAULT 0);
CREATE TABLE #IN_ERR (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, TXT NVARCHAR(1000));
CREATE TABLE #IN_ROTOS (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, ERROR NVARCHAR(2000));
IF OBJECT_ID('tempdb..#IN_PP') IS NOT NULL DROP TABLE #IN_PP;
CREATE TABLE #IN_PP (OBJETO SYSNAME COLLATE DATABASE_DEFAULT, ACCION NVARCHAR(400) COLLATE DATABASE_DEFAULT);
IF OBJECT_ID('tempdb..#IN_DROP') IS NOT NULL DROP TABLE #IN_DROP;
CREATE TABLE #IN_DROP (ORDEN INT, NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT INTO #IN_DROP (ORDEN, NOMBRE) VALUES
 (1,'VCT_USER_GET_ACTIONS'), (2,'VCT_USER_HAS_ACTION'), (3,'VCT_USER_CAN_SEE_SIDEBAR'),
 (4,'VCT_HTML_ESC'), (5,'VCT_PERFIL_PUEDE'),
 (7,'VCT_CK_VALOR'), (8,'VCT_FMT_HORAS'), (9,'VCT_PROYECTO_HORAS_USADAS_TXT'),
 (10,'VCT_MIG_PROY_IMPORTE'), (11,'FN_VCT_LIMPIA_TELEFONO');

/* plantillas: {{A0}}..{{An}} = argumentos de la llamada */
INSERT INTO #IN_FN (NOMBRE, NARGS, TPL) VALUES ('VCT_HTML_ESC', 1, N'(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CONVERT(VARCHAR(MAX),{{A0}}),''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;''))');
INSERT INTO #IN_FN (NOMBRE, NARGS, TPL) VALUES ('VCT_PERFIL_PUEDE', 2, N'(CONVERT(BIT,CASE WHEN EXISTS(SELECT 1 FROM dbo.VCT_MAIN_GET_ACTIONS({{A0}}, {{MOD}}) GA_PP WHERE GA_PP.ACTION_ID = {{A1}}) THEN 1 ELSE 0 END))');

INSERT INTO #IN_MOD (OBJ_ID, NOMBRE, TIPO, QI, AN, DEF)
SELECT O.object_id, O.name, O.type, M.uses_quoted_identifier, M.uses_ansi_nulls, M.definition
FROM sys.sql_modules M
JOIN sys.objects O ON O.object_id = M.object_id
WHERE O.type IN ('P','FN','IF','TF','V','TR') AND O.is_ms_shipped = 0 AND M.definition IS NOT NULL
  AND O.name NOT IN (SELECT NOMBRE FROM #IN_FN)
  AND EXISTS (SELECT 1 FROM #IN_FN F WHERE M.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%');

/* ---------------------------------------------------------------- reemplazo de llamadas */
DECLARE @oid INT, @t NVARCHAR(MAX), @fn SYSNAME, @na INT, @tpl NVARCHAR(MAX), @rep NVARCHAR(MAX),
        @start INT, @p INT, @s INT, @q INT, @i INT, @tl INT, @depth INT, @inq BIT, @cur INT, @fin INT,
        @c NCHAR(1), @k INT, @cnt INT, @nom SYSNAME, @mod NVARCHAR(400);
DECLARE @ARGS TABLE (K INT PRIMARY KEY, TXT NVARCHAR(MAX));

DECLARE cm CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #IN_MOD;
OPEN cm;
FETCH NEXT FROM cm INTO @oid;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @t = DEF, @nom = NOMBRE FROM #IN_MOD WHERE OBJ_ID = @oid;
    SET @cnt = 0;

    DECLARE cf CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE, NARGS, TPL FROM #IN_FN;
    OPEN cf;
    FETCH NEXT FROM cf INTO @fn, @na, @tpl;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @start = 1;
        WHILE 1 = 1
        BEGIN
            SET @p = CHARINDEX(@fn COLLATE Latin1_General_CI_AS, @t COLLATE Latin1_General_CI_AS, @start);
            IF @p = 0 BREAK;

            /* tiene que venir con esquema: dbo.X / [dbo].X / [dbo].[X] */
            IF @p > 4 AND SUBSTRING(@t, @p - 4, 4) COLLATE Latin1_General_CI_AS = N'dbo.' SET @s = @p - 4;
            ELSE IF @p > 7 AND SUBSTRING(@t, @p - 7, 7) COLLATE Latin1_General_CI_AS = N'[dbo].[' SET @s = @p - 7;
            ELSE IF @p > 6 AND SUBSTRING(@t, @p - 6, 6) COLLATE Latin1_General_CI_AS = N'[dbo].' SET @s = @p - 6;
            ELSE
            BEGIN
                SET @start = @p + 1;
                CONTINUE;
            END;

            SET @q = @p + LEN(@fn);
            IF SUBSTRING(@t, @q, 1) = N']' SET @q = @q + 1;
            WHILE SUBSTRING(@t, @q, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13)) SET @q = @q + 1;
            IF SUBSTRING(@t, @q, 1) <> N'('
            BEGIN
                SET @start = @p + 1;
                CONTINUE;
            END;

            /* argumentos: separar por comas de primer nivel, respetando parentesis y strings */
            DELETE FROM @ARGS;
            SET @k = 0; SET @i = @q; SET @depth = 0; SET @inq = 0; SET @cur = @q + 1; SET @fin = 0;
            SET @tl = LEN(@t);
            WHILE @i <= @tl
            BEGIN
                SET @c = SUBSTRING(@t, @i, 1);
                IF @inq = 1
                BEGIN
                    IF @c = N''''
                    BEGIN
                        IF SUBSTRING(@t, @i + 1, 1) = N'''' SET @i = @i + 1;
                        ELSE SET @inq = 0;
                    END;
                END
                ELSE IF @c = N'''' SET @inq = 1;
                ELSE IF @c = N'(' SET @depth = @depth + 1;
                ELSE IF @c = N')'
                BEGIN
                    SET @depth = @depth - 1;
                    IF @depth = 0
                    BEGIN
                        INSERT INTO @ARGS VALUES (@k, SUBSTRING(@t, @cur, @i - @cur));
                        SET @k = @k + 1;
                        SET @fin = @i;
                        BREAK;
                    END;
                END
                ELSE IF @c = N',' AND @depth = 1
                BEGIN
                    INSERT INTO @ARGS VALUES (@k, SUBSTRING(@t, @cur, @i - @cur));
                    SET @k = @k + 1;
                    SET @cur = @i + 1;
                END;
                SET @i = @i + 1;
            END;

            IF @fin = 0 OR @k <> @na
            BEGIN
                INSERT INTO #IN_ERR VALUES (@nom, N'No se pudo leer una llamada a ' + @fn + N' (argumentos: ' + CONVERT(NVARCHAR(10), @k) + N').');
                SET @start = @p + 1;
                CONTINUE;
            END;

            /* acciones que se consultaban con VCT_PERFIL_PUEDE (para verificar que esten en PrmActions) */
            IF @fn = 'VCT_PERFIL_PUEDE'
                INSERT INTO #IN_PP (OBJETO, ACCION)
                SELECT @nom, LTRIM(RTRIM(TXT)) FROM @ARGS WHERE K = 1;

            SET @rep = @tpl;
            SELECT @rep = REPLACE(@rep, N'{{A' + CONVERT(NVARCHAR(10), K) + N'}}', LTRIM(RTRIM(TXT))) FROM @ARGS ORDER BY K;

            /* modulo para VCT_MAIN_GET_ACTIONS: se toma del texto de la accion ('PROYECTOS.CREATE' -> 'PROYECTOS')
               al armar el codigo; en el SP queda el literal, sin LIKE ni calculos */
            IF @fn = 'VCT_PERFIL_PUEDE'
            BEGIN
                SELECT @mod = LTRIM(RTRIM(TXT)) FROM @ARGS WHERE K = 1;
                IF @mod LIKE N'''%.%'''
                    SET @mod = N'''' + SUBSTRING(@mod, 2, CHARINDEX(N'.', @mod) - 2) + N'''';
                ELSE
                    SET @mod = N'NULL /* accion no literal: revisar */';
                SET @rep = REPLACE(@rep, N'{{MOD}}', @mod);
            END;

            SET @t = STUFF(@t, @s, @fin - @s + 1, @rep);
            SET @cnt = @cnt + 1;
            SET @start = @s;   /* vuelve a mirar desde aca: puede haber llamadas anidadas en los argumentos */
        END;
        FETCH NEXT FROM cf INTO @fn, @na, @tpl;
    END;
    CLOSE cf;
    DEALLOCATE cf;

    UPDATE #IN_MOD SET NUEVA = @t, LLAMADAS = @cnt,
           QUEDAN = (SELECT COUNT(*) FROM #IN_FN F WHERE @t COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%')
    WHERE OBJ_ID = @oid;
    FETCH NEXT FROM cm INTO @oid;
END;
CLOSE cm;
DEALLOCATE cm;

/* ---------------------------------------------------------------- plan */
PRINT '=== Objetos que se reescriben (LLAMADAS reemplazadas; QUEDAN = funciones que siguen nombradas, p.ej. en comentarios) ===';
SELECT TIPO, NOMBRE, LLAMADAS, QUEDAN FROM #IN_MOD ORDER BY NOMBRE;
/* acciones de VCT_PERFIL_PUEDE: tienen que ser literales 'MOD.ACC' y estar en PrmActions */
INSERT INTO #IN_ERR (NOMBRE, TXT)
SELECT OBJETO, N'VCT_PERFIL_PUEDE con accion no literal: ' + ACCION + N' (revisar a mano).'
FROM #IN_PP WHERE ACCION NOT LIKE N'''%.%''';
PRINT '=== Acciones que se consultaban con VCT_PERFIL_PUEDE (las que FALTAN hay que cargarlas en PrmActions; hasta entonces el perfil no tiene ese permiso) ===';
SELECT P.OBJETO, P.ACCION,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.PrmActions PA WHERE UPPER(PA.ActionID) COLLATE DATABASE_DEFAULT = UPPER(REPLACE(P.ACCION, N'''', N'')))
            THEN 'OK (en PrmActions)' ELSE 'FALTA EN PrmActions' END AS ESTADO
FROM #IN_PP P ORDER BY P.ACCION, P.OBJETO;

IF EXISTS (SELECT 1 FROM #IN_ERR)
BEGIN
    PRINT '--- AVISOS:';
    SELECT NOMBRE, TXT FROM #IN_ERR;
END;

PRINT '=== Funciones que se borran ===';
SELECT D.NOMBRE, CASE WHEN OBJECT_ID(N'dbo.' + QUOTENAME(D.NOMBRE)) IS NULL THEN 'ya no existe' ELSE 'se borra' END AS ESTADO
FROM #IN_DROP D ORDER BY D.ORDEN;

PRINT '=== SP que van a quedar llamando a una funcion borrada (se rediseñan; fallan hasta rehacerlos) ===';
SELECT DISTINCT O.type_desc, O.name AS OBJETO, D.NOMBRE AS FUNCION
FROM #IN_DROP D
JOIN sys.sql_modules M ON M.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(D.NOMBRE, '_', '[_]') + N'%'
JOIN sys.objects O ON O.object_id = M.object_id
WHERE D.NOMBRE NOT IN (SELECT NOMBRE FROM #IN_FN)
  AND O.name NOT IN (SELECT NOMBRE FROM #IN_DROP)
ORDER BY O.name;

IF @APLICAR = 0
BEGIN
    PRINT '';
    PRINT 'MODO VISTA PREVIA: no se cambio nada. Correr con @APLICAR = 1.';
    RETURN;
END;

IF EXISTS (SELECT 1 FROM #IN_ERR)
BEGIN
    RAISERROR('Hay llamadas que no se pudieron leer (ver AVISOS). No se aplico nada.',16,1);
    RETURN;
END;

/* ---------------------------------------------------------------- aplicar */
DECLARE @emsg NVARCHAR(2000), @paso NVARCHAR(400) = N'', @sql NVARCHAR(MAX), @qi BIT, @an BIT,
        @pos INT, @rest NVARCHAR(80), @trg_on BIT = 0;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;

BEGIN TRY
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION;

    IF @trg_on = 1
        DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    DECLARE cx CURSOR LOCAL FAST_FORWARD FOR SELECT OBJ_ID FROM #IN_MOD WHERE LLAMADAS > 0 ORDER BY NOMBRE;
    OPEN cx;
    FETCH NEXT FROM cx INTO @oid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @t = NUEVA, @qi = QI, @an = AN, @paso = N'ALTER ' + NOMBRE FROM #IN_MOD WHERE OBJ_ID = @oid;

        SET @pos = 0;
        WHILE 1 = 1
        BEGIN
            SET @pos = CHARINDEX(N'CREATE' COLLATE Latin1_General_CI_AS, @t COLLATE Latin1_General_CI_AS, @pos + 1);
            IF @pos = 0 BREAK;
            IF @pos > 1 AND SUBSTRING(@t, @pos - 1, 1) COLLATE Latin1_General_CI_AS LIKE N'[A-Za-z0-9_@#]' CONTINUE;
            SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@t, @pos + 6, 60), NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' '));
            IF @rest COLLATE Latin1_General_CI_AS LIKE N'OR ALTER%' BREAK;
            IF @rest COLLATE Latin1_General_CI_AS LIKE N'PROC%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'FUNCTION%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'VIEW%'
               OR @rest COLLATE Latin1_General_CI_AS LIKE N'TRIGGER%'
            BEGIN
                SET @t = STUFF(@t, @pos, 6, N'ALTER');
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
            EXEC sp_executesql @sql, N'@d NVARCHAR(MAX)', @d = @t;
        END TRY
        BEGIN CATCH
            SET @emsg = ERROR_MESSAGE();
            /* "Invalid object name" de algo que no existe = ya estaba roto: se saltea.
               Cualquier otro error (sintaxis, columnas) es del reemplazo: se deshace todo. */
            IF XACT_STATE() = -1 OR ERROR_NUMBER() NOT IN (208, 4121)
                RAISERROR('%s',16,1,@emsg);
            ROLLBACK TRANSACTION SP_MOD;
            INSERT INTO #IN_ROTOS (NOMBRE, ERROR) SELECT NOMBRE, @emsg FROM #IN_MOD WHERE OBJ_ID = @oid;
        END CATCH;

        FETCH NEXT FROM cx INTO @oid;
    END;
    CLOSE cx;
    DEALLOCATE cx;

    /* borrar las funciones */
    DECLARE cd CURSOR LOCAL FAST_FORWARD FOR
        SELECT NOMBRE FROM #IN_DROP
        WHERE OBJECT_ID(N'dbo.' + QUOTENAME(NOMBRE)) IS NOT NULL
          AND OBJECTPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(NOMBRE)), 'IsScalarFunction') = 1
        ORDER BY ORDEN;
    OPEN cd;
    FETCH NEXT FROM cd INTO @fn;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = N'DROP ' + @fn;
        SET @sql = N'DROP FUNCTION dbo.' + QUOTENAME(@fn) + N';';
        EXEC sp_executesql @sql;
        FETCH NEXT FROM cd INTO @fn;
    END;
    CLOSE cd;
    DEALLOCATE cd;

    IF @trg_on = 1
        ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    COMMIT TRANSACTION;

    PRINT '';
    PRINT 'OK: SP arreglados (VCT_HTML_ESC y VCT_PERFIL_PUEDE reemplazadas por codigo directo / VCT_MAIN_GET_ACTIONS).';
    SELECT (SELECT COUNT(*) FROM #IN_MOD WHERE LLAMADAS > 0) - (SELECT COUNT(*) FROM #IN_ROTOS) AS OBJETOS_REESCRITOS,
           (SELECT SUM(LLAMADAS) FROM #IN_MOD) AS LLAMADAS_REEMPLAZADAS;
    IF EXISTS (SELECT 1 FROM #IN_ROTOS)
    BEGIN
        PRINT '--- SALTEADOS (ya no compilaban; siguen llamando a las funciones borradas):';
        SELECT NOMBRE, ERROR FROM #IN_ROTOS ORDER BY NOMBRE;
    END;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','cx') >= -1 BEGIN IF CURSOR_STATUS('local','cx') >= 0 CLOSE cx; DEALLOCATE cx; END;
    IF CURSOR_STATUS('local','cd') >= -1 BEGIN IF CURSOR_STATUS('local','cd') >= 0 CLOSE cd; DEALLOCATE cd; END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @err NVARCHAR(2000) = N'FALLO en [' + ISNULL(@paso, N'?') + N']: ' + ERROR_MESSAGE()
                                + N' (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'). Se deshizo todo; la base quedo como estaba.';
    RAISERROR('%s',16,1,@err);
END CATCH;
GO
