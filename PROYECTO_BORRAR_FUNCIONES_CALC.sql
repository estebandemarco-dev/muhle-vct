/* ========================================================================
   PROYECTO_BORRAR_FUNCIONES_CALC (vistas y funciones de tabla)
   ------------------------------------------------------------------------
   Regla nueva: no se crean vistas ni funciones de tabla por cada cambio;
   la logica va dentro de los SP. Se borran todas las existentes (se
   rehace la operatoria desde el alta de proyecto):
     Funciones de tabla: VCT_PROYECTO_AVANCE, VCT_PROYECTO_LANZ_ESTADO,
       VCT_PROYECTO_MINUTAS, VCT_PROYECTO_PLAN_CALC,
       VCT_PROYECTO_VISITAS_CALC, VCT_PROYECTO_VISITAS_HORAS_CONS
     Vistas: VCT_VW_ACCIONES_RESPONSABLES (o VCT_VW_GESTIONES_RESPONSABLES
       si no se corrio el renombrado), VCT_VW_PROYECTOS_ACTORES,
       VCT_VW_PERSONAS_V360
   @APLICAR = 0: no borra nada; muestra que objetos las usan (esos van a
                 fallar al ejecutarse una vez borradas).
   @APLICAR = 1: las borra, todo en una transaccion. El trigger
                 TR_VCT_AUDITORIA_DDL se apaga mientras corre.
   Antes de borrar se guarda la definicion de cada una en el .txt de _diag
   (por si hace falta mirarla). Re-ejecutable: las que ya no existen se saltean.
   ======================================================================== */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\PROYECTO_BORRAR_FUNCIONES_CALC.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @APLICAR BIT = 0;   /* 0 = solo mostrar | 1 = borrar */

IF OBJECT_ID('tempdb..#BC_F') IS NOT NULL DROP TABLE #BC_F;
CREATE TABLE #BC_F (ORDEN INT, NOMBRE SYSNAME COLLATE DATABASE_DEFAULT, OBJ_ID INT NULL, TIPO NVARCHAR(60) NULL);

/* orden de borrado: primero las que usan a otras */
INSERT INTO #BC_F (ORDEN, NOMBRE) VALUES
 (1, 'VCT_VW_ACCIONES_RESPONSABLES'),
 (2, 'VCT_VW_GESTIONES_RESPONSABLES'),
 (3, 'VCT_VW_PROYECTOS_ACTORES'),
 (4, 'VCT_VW_PERSONAS_V360'),
 (5, 'VCT_PROYECTO_VISITAS_HORAS_CONS'),
 (6, 'VCT_PROYECTO_AVANCE'),
 (7, 'VCT_PROYECTO_LANZ_ESTADO'),
 (8, 'VCT_PROYECTO_MINUTAS'),
 (9, 'VCT_PROYECTO_PLAN_CALC'),
 (10, 'VCT_PROYECTO_VISITAS_CALC');

/* y cualquier otra vista de usuario que exista (regla: no usar vistas) */
INSERT INTO #BC_F (ORDEN, NOMBRE)
SELECT 100 + ROW_NUMBER() OVER (ORDER BY V.name), V.name
FROM sys.views V
WHERE V.is_ms_shipped = 0 AND V.schema_id = SCHEMA_ID('dbo')
  AND V.name NOT IN (SELECT NOMBRE FROM #BC_F);

UPDATE F SET OBJ_ID = O.object_id, TIPO = O.type_desc
FROM #BC_F F JOIN sys.objects O ON O.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(F.NOMBRE));

PRINT '=== Vistas y funciones a borrar ===';
SELECT ORDEN, NOMBRE, ISNULL(TIPO, '(ya no existe)') AS TIPO FROM #BC_F ORDER BY ORDEN;

PRINT '=== Objetos que las usan y que van a fallar (sin contar las de la lista) ===';
SELECT DISTINCT O.type_desc AS TIPO, O.name AS OBJETO, F.NOMBRE AS USA
FROM #BC_F F
JOIN sys.sql_modules M ON M.definition COLLATE Latin1_General_CI_AS LIKE N'%' + REPLACE(F.NOMBRE, '_', '[_]') + N'%'
JOIN sys.objects O ON O.object_id = M.object_id
WHERE F.OBJ_ID IS NOT NULL
  AND O.name NOT IN (SELECT NOMBRE FROM #BC_F)
ORDER BY O.name, F.NOMBRE;

PRINT '=== Definiciones (respaldo) ===';
DECLARE @nom SYSNAME, @def NVARCHAR(MAX), @i INT, @len INT;
DECLARE cdef CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM #BC_F WHERE OBJ_ID IS NOT NULL ORDER BY ORDEN;
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

IF NOT EXISTS (SELECT 1 FROM #BC_F WHERE OBJ_ID IS NOT NULL)
BEGIN
    PRINT 'Ninguna de las vistas/funciones existe. No se hizo nada.';
    RETURN;
END;

IF @APLICAR = 0
BEGIN
    PRINT '';
    PRINT 'MODO VISTA PREVIA: no se borro nada. Correr con @APLICAR = 1 para borrar.';
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

    DECLARE cdrop CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM #BC_F WHERE OBJ_ID IS NOT NULL ORDER BY ORDEN;
    OPEN cdrop;
    FETCH NEXT FROM cdrop INTO @nom;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paso = N'DROP ' + @nom;
        SET @sql = CASE WHEN OBJECTPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(@nom)), 'IsView') = 1
                        THEN N'DROP VIEW dbo.' ELSE N'DROP FUNCTION dbo.' END + QUOTENAME(@nom) + N';';
        EXEC sp_executesql @sql;
        PRINT 'Borrada: ' + @nom;
        FETCH NEXT FROM cdrop INTO @nom;
    END;
    CLOSE cdrop;
    DEALLOCATE cdrop;

    IF @trg_on = 1
        ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

    COMMIT TRANSACTION;
    PRINT 'OK: vistas y funciones de tabla borradas.';
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','cdrop') >= -1 BEGIN IF CURSOR_STATUS('local','cdrop') >= 0 CLOSE cdrop; DEALLOCATE cdrop; END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @err NVARCHAR(2000) = N'FALLO en [' + @paso + N']: ' + ERROR_MESSAGE() + N'. Se deshizo todo.';
    RAISERROR('%s',16,1,@err);
END CATCH;
GO
