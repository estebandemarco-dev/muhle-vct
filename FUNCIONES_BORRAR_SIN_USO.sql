/* ========================================================================
   FUNCIONES_BORRAR_SIN_USO
   ------------------------------------------------------------------------
   Revisa las funciones escalares VCT y borra las que no usa nadie.
   "Usada" = la nombra algun SP / funcion / vista / trigger, o una columna
   calculada, un default o un check. Si una funcion solo la usa otra que
   tambien se borra, se borra tambien (se repite hasta que no cambia).
   Las que siguen en uso se listan con quien las usa y NO se tocan.
   Volver a correrlo cuando se borren o rehagan los SP de lanzamiento, plan,
   visitas, Dashboard y notificaciones: ahi quedan libres VCT_FMT_HORAS,
   VCT_CK_VALOR y VCT_PROYECTO_HORAS_USADAS_TXT.

   @APLICAR = 0: no borra nada; muestra el analisis y guarda las
                 definiciones en el .txt de _diag (respaldo).
   @APLICAR = 1: borra las que no se usan, en una transaccion.
   ======================================================================== */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\FUNCIONES_BORRAR_SIN_USO.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @APLICAR BIT = 0;   /* 0 = solo mostrar | 1 = borrar las que no se usan */

IF OBJECT_ID('tempdb..#SU_F') IS NOT NULL DROP TABLE #SU_F;
IF OBJECT_ID('tempdb..#SU_U') IS NOT NULL DROP TABLE #SU_U;
CREATE TABLE #SU_F (NOMBRE SYSNAME COLLATE DATABASE_DEFAULT PRIMARY KEY, OBJ_ID INT NULL, BORRAR BIT DEFAULT 0);
CREATE TABLE #SU_U (FUNCION SYSNAME COLLATE DATABASE_DEFAULT, USADA_POR NVARCHAR(300) COLLATE DATABASE_DEFAULT, USADA_POR_ID INT NULL);

INSERT INTO #SU_F (NOMBRE) VALUES
 ('FN_VCT_LIMPIA_TELEFONO'), ('VCT_CK_VALOR'), ('VCT_FMT_HORAS'), ('VCT_HTML_ESC'),
 ('VCT_MAIN_RENDER_ACTION'), ('VCT_MIG_PROY_IMPORTE'), ('VCT_PERFIL_PUEDE'),
 ('VCT_PROYECTO_HORAS_USADAS_TXT'), ('VCT_USER_CAN_SEE_SIDEBAR'), ('VCT_USER_GET_ACTIONS'),
 ('VCT_USER_HAS_ACTION');

UPDATE #SU_F SET OBJ_ID = OBJECT_ID(N'dbo.' + QUOTENAME(NOMBRE));

/* quien usa cada una: codigo */
INSERT INTO #SU_U (FUNCION, USADA_POR, USADA_POR_ID)
SELECT F.NOMBRE, O.type_desc COLLATE DATABASE_DEFAULT + N' ' + O.name, O.object_id
FROM #SU_F F
JOIN sys.sql_modules M ON M.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%'
JOIN sys.objects O ON O.object_id = M.object_id
WHERE F.OBJ_ID IS NOT NULL AND O.object_id <> F.OBJ_ID;

/* columnas calculadas, defaults y checks */
INSERT INTO #SU_U (FUNCION, USADA_POR, USADA_POR_ID)
SELECT F.NOMBRE, N'COLUMNA CALCULADA ' + OBJECT_NAME(C.object_id) + N'.' + C.name, NULL
FROM #SU_F F JOIN sys.computed_columns C ON C.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%'
WHERE F.OBJ_ID IS NOT NULL
UNION ALL
SELECT F.NOMBRE, N'DEFAULT ' + D.name, NULL
FROM #SU_F F JOIN sys.default_constraints D ON D.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%'
WHERE F.OBJ_ID IS NOT NULL
UNION ALL
SELECT F.NOMBRE, N'CHECK ' + K.name, NULL
FROM #SU_F F JOIN sys.check_constraints K ON K.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%'
WHERE F.OBJ_ID IS NOT NULL;

/* borrar = nadie la usa, salvo funciones que tambien se borran (iterativo) */
DECLARE @cambio INT = 1;
WHILE @cambio > 0
BEGIN
    UPDATE F SET BORRAR = 1
    FROM #SU_F F
    WHERE F.OBJ_ID IS NOT NULL AND F.BORRAR = 0
      AND NOT EXISTS (SELECT 1 FROM #SU_U U
                      WHERE U.FUNCION = F.NOMBRE
                        AND (U.USADA_POR_ID IS NULL
                             OR NOT EXISTS (SELECT 1 FROM #SU_F F2 WHERE F2.OBJ_ID = U.USADA_POR_ID AND F2.BORRAR = 1)));
    SET @cambio = @@ROWCOUNT;
END;

PRINT '=== Resultado ===';
SELECT F.NOMBRE,
       CASE WHEN F.OBJ_ID IS NULL THEN 'YA NO EXISTE' WHEN F.BORRAR = 1 THEN 'SIN USO - SE BORRA' ELSE 'EN USO - QUEDA' END AS ESTADO,
       ISNULL(STUFF((SELECT N', ' + U.USADA_POR FROM #SU_U U WHERE U.FUNCION = F.NOMBRE ORDER BY U.USADA_POR FOR XML PATH('')), 1, 2, ''), '') AS USADA_POR
FROM #SU_F F
ORDER BY F.BORRAR DESC, F.NOMBRE;

PRINT '=== Definiciones de las que se borran (respaldo) ===';
DECLARE @nom SYSNAME, @def NVARCHAR(MAX), @i INT, @len INT;
DECLARE cdef CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM #SU_F WHERE BORRAR = 1 ORDER BY NOMBRE;
OPEN cdef;
FETCH NEXT FROM cdef INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + QUOTENAME(@nom)));
    PRINT '-------------------- ' + @nom + ' --------------------';
    SET @i = 1; SET @len = LEN(@def);
    WHILE @i <= @len
    BEGIN
        PRINT SUBSTRING(@def, @i, 4000);
        SET @i = @i + 4000;
    END;
    FETCH NEXT FROM cdef INTO @nom;
END;
CLOSE cdef;
DEALLOCATE cdef;

IF NOT EXISTS (SELECT 1 FROM #SU_F WHERE BORRAR = 1)
BEGIN
    PRINT 'No hay funciones sin uso. No se hizo nada.';
    RETURN;
END;

IF @APLICAR = 0
BEGIN
    PRINT '';
    PRINT 'MODO VISTA PREVIA: no se borro nada. Correr con @APLICAR = 1 para borrar las marcadas SIN USO.';
    RETURN;
END;

DECLARE @trg_on BIT = 0, @sql NVARCHAR(400), @paso NVARCHAR(200) = N'';
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0)
    SET @trg_on = 1;

BEGIN TRY
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    IF @trg_on = 1
        DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    /* primero las que usan a otras de la lista */
    DECLARE cdrop CURSOR LOCAL FAST_FORWARD FOR
        SELECT F.NOMBRE FROM #SU_F F WHERE F.BORRAR = 1
        ORDER BY (SELECT COUNT(*) FROM #SU_U U WHERE U.FUNCION = F.NOMBRE) ASC, F.NOMBRE;
    OPEN cdrop;
    FETCH NEXT FROM cdrop INTO @nom;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = N'DROP ' + @nom;
        SET @sql = N'DROP FUNCTION dbo.' + QUOTENAME(@nom) + N';';
        EXEC sp_executesql @sql;
        PRINT 'Borrada: ' + @nom;
        FETCH NEXT FROM cdrop INTO @nom;
    END;
    CLOSE cdrop;
    DEALLOCATE cdrop;

    IF @trg_on = 1
        ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    COMMIT TRANSACTION;
    PRINT 'OK: funciones sin uso borradas.';
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','cdrop') >= -1 BEGIN IF CURSOR_STATUS('local','cdrop') >= 0 CLOSE cdrop; DEALLOCATE cdrop; END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @err NVARCHAR(2000) = N'FALLO en [' + @paso + N']: ' + ERROR_MESSAGE() + N'. Se deshizo todo.';
    RAISERROR('%s',16,1,@err);
END CATCH;
GO
