/* ========================================================================
   VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS_4
   ------------------------------------------------------------------------
   NO toca permisos. Modifica SP existentes:
   1) dbo.VCT_MAIN_CLIENTES_V360: columna Servicios con ancho fijo de 96px
      (3 iconos) en "Ultimos proyectos" y en la pestana Proyectos.
   2) Version de la grilla en dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360:
      vct-datagrid.css?v=11 (js v=7 sin cambios).
   Antes de correrlo: subir css/vct-datagrid.css (v11). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000);

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
            /* Ultimos proyectos: 2da columna (Servicios) */
            SET @d = REPLACE(@d, N'<colgroup><col><col style="width:10%"><col style="width:17%">',
                                 N'<colgroup><col><col style="width:96px"><col style="width:17%">');
            /* Pestana Proyectos: encabezado de Servicios */
            SET @d = REPLACE(@d, N'<th class="vct-text-center" data-vct-width="12%"><span>Servicios</span></th>',
                                 N'<th class="vct-text-center" data-vct-width="96"><span>Servicios</span></th>');
        END;

        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'11' ELSE N'7' END;
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
