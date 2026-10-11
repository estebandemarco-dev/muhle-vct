/* ========================================================================
   VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS_5
   ------------------------------------------------------------------------
   NO toca permisos. Modifica SP existentes:
   1) dbo.VCT_MAIN_CLIENTES_V360 - "Ultimos proyectos": Analista y Consultor
      solo con el circulo de iniciales (nombre completo en el tooltip, cursor
      de mano), centrados y mas angostos; el analista "-" se muestra como vacio.
   2) Version de la grilla en dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360:
      vct-datagrid.css?v=12 (escala tipografica general) y js v=7.
   Antes de correrlo: subir css/vct-datagrid.css (v12). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @R TABLE (ORD INT, VIEJO NVARCHAR(1000), NUEVO NVARCHAR(1000));
INSERT INTO @R VALUES
 (1, N'ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-a">'' + IniAnalista + ''</span><span class="vctdg-person-name" title="'' + EscAnalista + ''">'' + EscAnalista + ''</span></span>'' END +', N'ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-a" title="'' + EscAnalista + ''">'' + IniAnalista + ''</span></span>'' END +'),
 (2, N'ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-c">'' + IniConsultor + ''</span><span class="vctdg-person-name" title="'' + EscConsultor + ''">'' + EscConsultor + ''</span></span>'' END +', N'ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-c" title="'' + EscConsultor + ''">'' + IniConsultor + ''</span></span>'' END +'),
 (3, N'CASE WHEN EscAnalista = '''' THEN ''<span class="vctdg-none">-</span>''', N'CASE WHEN EscAnalista IN ('''', ''-'') THEN ''<span class="vctdg-none">-</span>'''),
 (4, N'''<td data-label="Analista">'' +', N'''<td class="vct-text-center" data-label="Analista">'' +'),
 (5, N'''<td data-label="Consultor">'' +', N'''<td class="vct-text-center" data-label="Consultor">'' +'),
 (6, N'<th>Analista</th><th>Consultor</th>', N'<th class="vct-text-center">Analista</th><th class="vct-text-center">Consultor</th>'),
 (7, N'<colgroup><col><col style="width:96px"><col style="width:17%"><col style="width:14%"><col style="width:14%"><col style="width:11%"><col style="width:11%"><col style="width:44px"></colgroup>', N'<colgroup><col><col style="width:96px"><col style="width:22%"><col style="width:76px"><col style="width:80px"><col style="width:112px"><col style="width:14%"><col style="width:44px"></colgroup>');

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES');

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

        IF @nom = N'VCT_MAIN_CLIENTES_V360'
        BEGIN
            IF CHARINDEX(N'TOP_PROY_V2', @d) = 0
                PRINT @nom + ': falta "Ultimos proyectos" nuevo (TOP_PROY_V2). Correr antes VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS_3.sql.';
            ELSE
            BEGIN
                DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R ORDER BY ORD;
                OPEN crp;
                FETCH NEXT FROM crp INTO @ro, @rv, @rn;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF CHARINDEX(@rv, @d) > 0
                        SET @d = REPLACE(@d, @rv, @rn);
                    ELSE IF CHARINDEX(@rn, @d) = 0
                        PRINT 'AVISO: no se encontro el texto del cambio ' + CONVERT(VARCHAR(5), @ro) + ' (se saltea).';
                    FETCH NEXT FROM crp INTO @ro, @rv, @rn;
                END;
                CLOSE crp;
                DEALLOCATE crp;
            END;
        END;

        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'12' ELSE N'7' END;
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
