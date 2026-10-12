/* ========================================================================
   GRILLAS_V20
   ------------------------------------------------------------------------
   NO toca permisos. Solo cambia la version de la grilla
   (vct-datagrid.css?v=20, vct-datagrid.js?v=7) en:
   VCT_MAIN_CLIENTES, VCT_MAIN_CONSULTORES, VCT_MAIN_EMPLEADOS,
   VCT_MAIN_PROVEEDORES, VCT_MAIN_CLIENTES_V360 y VCT_MAIN_DASHBOARD.
   Toma css v20: nombre del consultor sin negrita en la grilla de
   Consultores (incluye lo de v18: badges y filtros).
   Antes de correrlo: subir css/vct-datagrid.css (v20).
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @R TABLE (ORD INT, SP SYSNAME, VIEJO NVARCHAR(1000), NUEVO NVARCHAR(1000));

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES'), (3, N'VCT_MAIN_CONSULTORES'),
                        (4, N'VCT_MAIN_EMPLEADOS'), (5, N'VCT_MAIN_PROVEEDORES'), (6, N'VCT_MAIN_DASHBOARD');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000),
        @rv NVARCHAR(1000), @rn NVARCHAR(1000), @ro INT;

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

        /* cambios puntuales de este SP */
        DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R WHERE SP = @nom ORDER BY ORD;
        OPEN crp;
        FETCH NEXT FROM crp INTO @ro, @rv, @rn;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @nom = N'VCT_MAIN_DASHBOARD' AND CHARINDEX(N'vct-datagrid.css', @d) > 0
                SET @rv = @rv;   /* ya carga la grilla */
            ELSE IF CHARINDEX(@rv, @d) > 0
                SET @d = REPLACE(@d, @rv, @rn);
            ELSE IF CHARINDEX(@rn, @d) = 0
                PRINT 'AVISO ' + @nom + ': no se encontro el texto del cambio ' + CONVERT(VARCHAR(5), @ro) + ' (se saltea).';
            FETCH NEXT FROM crp INTO @ro, @rv, @rn;
        END;
        CLOSE crp;
        DEALLOCATE crp;

        /* version de los archivos de la grilla */
        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'20' ELSE N'7' END;
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
