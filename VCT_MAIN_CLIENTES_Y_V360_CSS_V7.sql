/* ========================================================================
   VCT_MAIN_CLIENTES_Y_V360_CSS_V7
   ------------------------------------------------------------------------
   Modifica los SP EXISTENTES dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360
   (no crea nada). En cada uno toma la definicion vigente del servidor y solo
   cambia la version de los archivos de la grilla, para que el navegador
   cargue los nuevos:
     ../css/vct-datagrid.css?v=N  ->  ?v=7
     ../js/vct-datagrid.js?v=N    ->  ?v=5
   Antes de correrlo: subir css/vct-datagrid.css (v7) y js/vct-datagrid.js (v5) al servidor web.
   Para otra pantalla (Consultores, Empleados, la 360 de Consultor, etc.)
   agregar su SP en la lista de abajo y volver a correrlo.
   Re-ejecutable: los que ya estan en esa version no se tocan.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @SPS TABLE (NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (N'VCT_MAIN_CLIENTES'), (N'VCT_MAIN_CLIENTES_V360');

DECLARE @CSS_NEW NVARCHAR(10) = N'7', @JS_NEW NVARCHAR(10) = N'5';

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000);

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

DECLARE csp CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM @SPS;
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

        IF @d = @orig
            PRINT @nom + ': ya estaba en la version nueva (o no carga la grilla). Sin cambios.';
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
                    PRINT 'OK: ' + @nom + ' ahora carga vct-datagrid.css?v=' + @CSS_NEW + ' y vct-datagrid.js?v=' + @JS_NEW + '.';
                END TRY
                BEGIN CATCH
                    SET @msg = N'FALLO ' + @nom + N': ' + ERROR_MESSAGE() + N' (quedo como estaba).';
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
