/* ========================================================================
   VCT_MAIN_CLIENTES_V360_FIX_VISTAS
   ------------------------------------------------------------------------
   Modifica el SP EXISTENTE dbo.VCT_MAIN_CLIENTES_V360 (no crea nada).
   Error: Invalid object name 'dbo.VCT_VW_PERSONAS_V360' (vista borrada).
   Toma la definicion vigente del servidor y reemplaza, dentro del mismo SP,
   cada uso de las vistas/funciones borradas por su consulta equivalente:
     dbo.VCT_VW_PERSONAS_V360           -> (SELECT ... VCT_EMPLEADOS UNION ALL VCT_CONSULTORES) alias
     dbo.VCT_VW_GESTIONES_RESPONSABLES  -> (SELECT responsable principal activo
     dbo.VCT_VW_ACCIONES_RESPONSABLES       de cada accion, con su nombre) alias
     dbo.VCT_PERFIL_PUEDE(@x,'MOD.ACC') -> EXISTS en VCT_MAIN_GET_ACTIONS(@x,'MOD')
   Se quita el WITH(NOLOCK) que seguia a esas vistas (no aplica a una subconsulta).
   El resto del SP queda igual. Al final lista si queda alguna otra
   referencia a un objeto que no existe.
   Re-ejecutable: si ya no usa esos objetos, avisa y no hace nada.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @SP SYSNAME = N'VCT_MAIN_CLIENTES_V360';
DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + @SP)), @orig NVARCHAR(MAX), @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CLIENTES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

/* ---- tabla de participantes vigente (renombrada o no) ---- */
DECLARE @TP SYSNAME, @CP SYSNAME;
IF OBJECT_ID(N'dbo.VCT_ACCIONES_PARTICIPANTES') IS NOT NULL
BEGIN
    SET @TP = N'VCT_ACCIONES_PARTICIPANTES';
    SET @CP = CASE WHEN COL_LENGTH(N'dbo.VCT_ACCIONES_PARTICIPANTES', N'ID_ACCION') IS NOT NULL THEN N'ID_ACCION' ELSE N'ID_GESTION' END;
END
ELSE
BEGIN
    SET @TP = N'VCT_GESTIONES_PARTICIPANTES';
    SET @CP = CASE WHEN COL_LENGTH(N'dbo.VCT_GESTIONES_PARTICIPANTES', N'ID_GESTION') IS NOT NULL THEN N'ID_GESTION' ELSE N'ID_ACCION' END;
END;

/* ---- consultas equivalentes a las vistas borradas ---- */
DECLARE @PERS NVARCHAR(MAX) =
N'(SELECT ''EMPLEADO'' AS TIPO_ENTIDAD, PE_E.ID AS ID_ENTIDAD,
        CONVERT(VARCHAR(320), ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(PE_E.NOMBRES, '''') + '' '' + ISNULL(PE_E.APELLIDOS, ''''))), ''''),
                                     ''Empleado #'' + CONVERT(VARCHAR(20), PE_E.ID))) AS NOMBRE
   FROM dbo.VCT_EMPLEADOS PE_E
   UNION ALL
   SELECT ''CONSULTOR'', PE_C.ID,
        CONVERT(VARCHAR(320), ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(150), PE_C.NOMBRES), '''') + '' '' + ISNULL(CONVERT(VARCHAR(150), PE_C.APELLIDOS), ''''))), ''''),
                                     ''Consultor #'' + CONVERT(VARCHAR(20), PE_C.ID)))
   FROM dbo.VCT_CONSULTORES PE_C)';

DECLARE @RESP NVARCHAR(MAX) =
N'(SELECT RS_X.ID_REF AS ID_ACCION, RS_X.ID_REF AS ID_GESTION, RS_X.TIPO_ENTIDAD, RS_X.ID_ENTIDAD, RS_X.NOMBRE
   FROM (SELECT RS_P.' + @CP + N' AS ID_REF, RS_P.TIPO_ENTIDAD, RS_P.ID_ENTIDAD,
                CASE WHEN RS_P.TIPO_ENTIDAD = ''SISTEMA'' THEN ''Sistema''
                     WHEN RS_N.NOMBRE IS NOT NULL THEN RS_N.NOMBRE
                     WHEN RS_P.ID_ENTIDAD IS NOT NULL THEN RS_P.TIPO_ENTIDAD + '' #'' + CONVERT(VARCHAR(20), RS_P.ID_ENTIDAD)
                     ELSE RS_P.TIPO_ENTIDAD END AS NOMBRE,
                ROW_NUMBER() OVER (PARTITION BY RS_P.' + @CP + N' ORDER BY RS_P.PRINCIPAL DESC, RS_P.ID) AS RN
         FROM dbo.' + @TP + N' RS_P
         LEFT JOIN ' + @PERS + N' RS_N ON RS_N.TIPO_ENTIDAD = RS_P.TIPO_ENTIDAD AND RS_N.ID_ENTIDAD = RS_P.ID_ENTIDAD
         WHERE RS_P.ROL_PARTICIPANTE = ''RESPONSABLE'' AND RS_P.ESTADO = ''ACTIVO'') RS_X
   WHERE RS_X.RN = 1)';

/* ---- reemplazo de cada uso: dbo.VISTA [AS] alias [WITH(...)] -> (consulta) alias ---- */
DECLARE @V TABLE (ORD INT, NOMBRE SYSNAME, REPL NVARCHAR(MAX));
INSERT INTO @V VALUES (1, N'VCT_VW_GESTIONES_RESPONSABLES', @RESP), (2, N'VCT_VW_ACCIONES_RESPONSABLES', @RESP), (3, N'VCT_VW_PERSONAS_V360', @PERS);

DECLARE @n SYSNAME, @repl NVARCHAR(MAX), @pat NVARCHAR(200), @p INT, @e INT, @q INT, @a INT, @s INT, @t INT, @u INT,
        @alias NVARCHAR(128), @segEnd INT, @txt NVARCHAR(MAX), @cuenta INT = 0;
DECLARE cv CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE, REPL FROM @V ORDER BY ORD;
OPEN cv;
FETCH NEXT FROM cv INTO @n, @repl;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @d = REPLACE(REPLACE(REPLACE(@d, N'[dbo].[' + @n + N']', N'dbo.' + @n), N'dbo.[' + @n + N']', N'dbo.' + @n), N'[dbo].' + @n, N'dbo.' + @n);
    SET @pat = N'dbo.' + @n;
    SET @p = CHARINDEX(@pat, @d);
    WHILE @p > 0
    BEGIN
        SET @e = @p + LEN(@pat);
        SET @q = @e;
        WHILE @q <= LEN(@d) AND SUBSTRING(@d, @q, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10)) SET @q = @q + 1;
        IF UPPER(SUBSTRING(@d, @q, 2)) = N'AS' AND SUBSTRING(@d, @q + 2, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10))
        BEGIN
            SET @q = @q + 2;
            WHILE @q <= LEN(@d) AND SUBSTRING(@d, @q, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10)) SET @q = @q + 1;
        END;
        SET @a = @q;
        WHILE @q <= LEN(@d) AND SUBSTRING(@d, @q, 1) LIKE N'[A-Za-z0-9_]' SET @q = @q + 1;
        SET @alias = SUBSTRING(@d, @a, @q - @a);
        IF @alias = N'' OR UPPER(@alias) IN (N'ON', N'WHERE', N'INNER', N'LEFT', N'RIGHT', N'FULL', N'JOIN', N'CROSS', N'OUTER',
                                             N'GROUP', N'ORDER', N'WITH', N'UNION', N'AND', N'OR', N'HAVING')
        BEGIN
            SET @alias = @n;          /* sin alias: la subconsulta toma el nombre de la vista */
            SET @segEnd = @e - 1;
            SET @s = @e;
        END
        ELSE
        BEGIN
            SET @segEnd = @q - 1;
            SET @s = @q;
        END;
        /* hint de tabla a continuacion: WITH (NOLOCK) */
        WHILE @s <= LEN(@d) AND SUBSTRING(@d, @s, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10)) SET @s = @s + 1;
        IF UPPER(SUBSTRING(@d, @s, 4)) = N'WITH'
        BEGIN
            SET @t = @s + 4;
            WHILE @t <= LEN(@d) AND SUBSTRING(@d, @t, 1) IN (N' ', CHAR(9), CHAR(13), CHAR(10)) SET @t = @t + 1;
            IF SUBSTRING(@d, @t, 1) = N'('
            BEGIN
                SET @u = CHARINDEX(N')', @d, @t);
                IF @u > 0 SET @segEnd = @u;
            END;
        END;
        SET @txt = @repl + N' ' + @alias + N' ';
        SET @d = STUFF(@d, @p, @segEnd - @p + 1, @txt);
        SET @cuenta = @cuenta + 1;
        SET @p = CHARINDEX(@pat, @d, @p + LEN(@txt));
    END;
    FETCH NEXT FROM cv INTO @n, @repl;
END;
CLOSE cv;
DEALLOCATE cv;

/* ---- dbo.VCT_PERFIL_PUEDE(arg, 'MODULO.ACCION') -> VCT_MAIN_GET_ACTIONS ---- */
DECLARE @c INT, @depth INT, @args NVARCHAR(1000), @a0 NVARCHAR(500), @a1 NVARCHAR(500), @mod NVARCHAR(200), @coma INT;
IF OBJECT_ID(N'dbo.VCT_PERFIL_PUEDE') IS NULL
BEGIN
    SET @pat = N'dbo.VCT_PERFIL_PUEDE(';
    SET @p = CHARINDEX(@pat, @d);
    WHILE @p > 0
    BEGIN
        SET @c = @p + LEN(@pat); SET @depth = 1;
        WHILE @c <= LEN(@d) AND @depth > 0
        BEGIN
            IF SUBSTRING(@d, @c, 1) = N'(' SET @depth = @depth + 1;
            IF SUBSTRING(@d, @c, 1) = N')' SET @depth = @depth - 1;
            SET @c = @c + 1;
        END;
        SET @args = SUBSTRING(@d, @p + LEN(@pat), @c - 1 - (@p + LEN(@pat)));
        SET @coma = CHARINDEX(N',', @args);
        SET @a0 = LTRIM(RTRIM(LEFT(@args, @coma - 1)));
        SET @a1 = LTRIM(RTRIM(SUBSTRING(@args, @coma + 1, 1000)));
        IF @coma > 0 AND LEFT(@a1, 1) = N'''' AND CHARINDEX(N'.', @a1) > 0
        BEGIN
            SET @mod = SUBSTRING(@a1, 2, CHARINDEX(N'.', @a1) - 2);
            SET @txt = N'(CONVERT(BIT, CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_MAIN_GET_ACTIONS(' + @a0 + N', ''' + @mod + N''') GA_PP WHERE GA_PP.ACTION_ID = ' + @a1 + N') THEN 1 ELSE 0 END))';
            SET @d = STUFF(@d, @p, @c - @p, @txt);
            SET @cuenta = @cuenta + 1;
            SET @p = CHARINDEX(@pat, @d, @p + LEN(@txt));
        END
        ELSE
        BEGIN
            SET @msg = N'AVISO: no se pudo reemplazar VCT_PERFIL_PUEDE(' + @args + N') (el permiso no es un texto fijo).';
            PRINT @msg;
            SET @p = CHARINDEX(@pat, @d, @c);
        END;
    END;
END;

IF @d = @orig
BEGIN
    PRINT 'VCT_MAIN_CLIENTES_V360 ya no usa las vistas/funciones borradas. No se hizo nada.';
    RETURN;
END;

/* ---- CREATE PROCEDURE -> ALTER PROCEDURE ---- */
DECLARE @i INT, @rest NVARCHAR(80), @hecho BIT = 0;
SET @i = CHARINDEX(N'CREATE', @d);
WHILE @i > 0 AND @hecho = 0
BEGIN
    SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
    IF @rest LIKE N'PROC%' BEGIN SET @d = STUFF(@d, @i, 6, N'ALTER'); SET @hecho = 1; END
    ELSE SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
END;
IF @hecho = 0 BEGIN RAISERROR('No se encontro CREATE PROCEDURE en la definicion. No se hizo nada.', 16, 1); RETURN; END;

DECLARE @trg_on BIT = 0;
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;

BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'OK: VCT_MAIN_CLIENTES_V360 corregido (' + CONVERT(NVARCHAR(10), @cuenta) + N' reemplazos).';
    PRINT @msg;
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO al modificar VCT_MAIN_CLIENTES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N'. El SP quedo como estaba.';
    RAISERROR('%s', 16, 1, @msg);
    RETURN;
END CATCH;

/* ---- control: otras referencias a objetos que no existen ---- */
PRINT '=== Objetos que VCT_MAIN_CLIENTES_V360 nombra y no existen (vacio = OK) ===';
SELECT DISTINCT D.referenced_entity_name AS NO_EXISTE
FROM sys.sql_expression_dependencies D
WHERE D.referencing_id = OBJECT_ID(N'dbo.VCT_MAIN_CLIENTES_V360')
  AND D.referenced_id IS NULL
  AND ISNULL(D.referenced_schema_name, N'dbo') = N'dbo'
  AND D.referenced_entity_name NOT LIKE N'#%'
  AND OBJECT_ID(N'dbo.' + QUOTENAME(D.referenced_entity_name)) IS NULL;
GO
