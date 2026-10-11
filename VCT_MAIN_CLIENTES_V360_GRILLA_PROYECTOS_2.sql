/* ========================================================================
   VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS_2
   ------------------------------------------------------------------------
   NO toca permisos ni PrmActions (solo los muestra, para revisar).
   1) Diagnostico (solo lectura): que devuelve VCT_MAIN_GET_ACTIONS para
      'PROYECTOS' en cada perfil. El menu de 3 puntos aparece si el perfil
      tiene una accion de tipo VIEW o EDIT; el boton Nuevo, si tiene CREATE.
   2) dbo.VCT_MAIN_CLIENTES_V360 (grilla de proyectos): normas sin repetir
      (un proyecto con la misma norma en dos servicios la mostraba dos veces).
   3) Version de la grilla en dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360:
      vct-datagrid.css?v=9 y vct-datagrid.js?v=7.
   Antes de correrlo: subir css/vct-datagrid.css (v9) y js/vct-datagrid.js (v7).
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

/* ---------------- 1. Diagnostico (solo lectura) ---------------- */
PRINT '=== PrmActions de PROYECTOS (ActionType debe ser VIEW / EDIT / CREATE) ===';
SELECT PA.ActionID, PA.ActionType, PA.Title, PA.Icon, PA.StorageKey, PA.TargetGuid
FROM dbo.PrmActions PA
WHERE UPPER(PA.ActionID) LIKE 'PROYECTOS.%'
ORDER BY PA.ActionID;

PRINT '=== Lo que VCT_MAIN_GET_ACTIONS devuelve para PROYECTOS en cada perfil ===';
SELECT G.GroupId AS PERFIL, A.ACTION_ID, A.ACTION_TYPE, A.TITLE, A.ICON
FROM (SELECT DISTINCT GroupId FROM dbo.GroupsActions) G
CROSS APPLY dbo.VCT_MAIN_GET_ACTIONS(G.GroupId, 'PROYECTOS') A
ORDER BY G.GroupId, A.ACTION_ID;

/* ---------------- 2 y 3. Parche de los SP ---------------- */
DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000),
        @old1 NVARCHAR(200) = N'ORDER BY ISNULL(PN.PRINCIPAL,0) DESC, N.DESCRIPCION',
        @new1 NVARCHAR(200) = N'GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION',
        @old2 NVARCHAR(200) = N'(SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)',
        @new2 NVARCHAR(200) = N'(SELECT COUNT(DISTINCT PN.ID_NORMA) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)';

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

DECLARE csp CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM @SPS ORDER BY ORD;
OPEN csp;
FETCH NEXT FROM csp INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @d = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + QUOTENAME(@nom)));
    IF @d IS NULL
        PRINT 'No existe dbo.' + @nom + ' (se saltea).';
    ELSE
    BEGIN
        SET @orig = @d;

        IF @nom = N'VCT_MAIN_CLIENTES_V360'
        BEGIN
            IF CHARINDEX(N'GRILLA_PROY_V2', @d) = 0
                PRINT @nom + ': no tiene la grilla nueva (GRILLA_PROY_V2). Correr antes VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS.sql.';
            ELSE IF CHARINDEX(N'NORMAS_DISTINCT_V1', @d) > 0
                PRINT @nom + ': normas sin repetir ya aplicado.';
            ELSE
            BEGIN
                SET @d = REPLACE(@d, @old1, @new1);
                SET @d = REPLACE(@d, @old2, @new2);
                SET @d = REPLACE(@d, N'GRILLA_PROY_V2:', N'GRILLA_PROY_V2 (NORMAS_DISTINCT_V1):');
            END;
        END;

        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'9' ELSE N'7' END;
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

        IF @d = @orig
            PRINT @nom + ': sin cambios.';
        ELSE
        BEGIN
            SET @hecho = 0;
            SET @i = CHARINDEX(N'CREATE', @d);
            WHILE @i > 0 AND @hecho = 0
            BEGIN
                SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
                IF @rest LIKE N'PROC%' BEGIN SET @d = STUFF(@d, @i, 6, N'ALTER'); SET @hecho = 1; END
                ELSE SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
            END;
            IF @hecho = 0
                PRINT @nom + ': no se encontro CREATE PROCEDURE. Sin cambios.';
            ELSE
            BEGIN
                BEGIN TRY
                    EXEC sp_executesql @d;
                    PRINT 'OK: ' + @nom + ' actualizado.';
                END TRY
                BEGIN CATCH
                    SET @msg = N'FALLO ' + @nom + N' (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
                    PRINT @msg;
                END CATCH;
            END;
        END;
    END;
    FETCH NEXT FROM csp INTO @nom;
END;
CLOSE csp;
DEALLOCATE csp;

IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
GO
