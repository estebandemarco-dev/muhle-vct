/* ========================================================================
   V360_CLIENTE_PROYECTOS_EQUIPO_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica SP existentes:
   1) dbo.VCT_MAIN_CLIENTES_V360, pestana Proyectos: agrega las columnas
      Analista y Consultor (circulo con iniciales, nombre en el tooltip,
      centradas), igual que "Ultimos proyectos".
   2) Version de la grilla vct-datagrid.css?v=17 en VCT_MAIN_CLIENTES_V360 y
      VCT_MAIN_DASHBOARD (rentabilidad sin verde; tipografia 12px y anillos
      centrados en el Inicio).
   Antes de correrlo: subir css/vct-datagrid.css (v17). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @DER_ANCHOR NVARCHAR(400) = N'REPLACE(ISNULL(P.ESTADO_CODIGO,''''),''"'','''') AS EstadoCod,',
        @DER_ADD    NVARCHAR(MAX) = N'
                REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(P.ANALISTA,''''))),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscAnalista,
                CASE WHEN CHARINDEX('' '', LTRIM(RTRIM(ISNULL(P.ANALISTA,'''')))) > 0
                     THEN UPPER(LEFT(LTRIM(P.ANALISTA),1) + LEFT(REVERSE(LEFT(REVERSE(RTRIM(P.ANALISTA)), CHARINDEX('' '', REVERSE(RTRIM(P.ANALISTA)) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(LTRIM(ISNULL(P.ANALISTA,'''')),2)) END AS IniAnalista,
                CASE WHEN P.CONSULTOR_ID IS NULL THEN ''''
                     ELSE REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(LTRIM(RTRIM(P.CONSULTOR_NOMBRE)),''''),''#''+CONVERT(VARCHAR(20),P.CONSULTOR_ID)),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') END AS EscConsultor,
                CASE WHEN CHARINDEX('' '', LTRIM(RTRIM(ISNULL(P.CONSULTOR_NOMBRE,'''')))) > 0
                     THEN UPPER(LEFT(LTRIM(P.CONSULTOR_NOMBRE),1) + LEFT(REVERSE(LEFT(REVERSE(RTRIM(P.CONSULTOR_NOMBRE)), CHARINDEX('' '', REVERSE(RTRIM(P.CONSULTOR_NOMBRE)) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(LTRIM(ISNULL(NULLIF(P.CONSULTOR_NOMBRE,''''),''C'')),2)) END AS IniConsultor,',
        @TD_ANCHOR  NVARCHAR(400) = N'''<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '' + EstadoClase + ''">'' + EscEstado + ''</span></td>'' +',
        @TD_ADD     NVARCHAR(MAX) = N'''<td class="vct-text-center" data-label="Analista">'' +
                    CASE WHEN EscAnalista IN ('''', ''-'') THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-a" title="'' + EscAnalista + ''">'' + IniAnalista + ''</span></span>'' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Consultor">'' +
                    CASE WHEN EscConsultor = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-c" title="'' + EscConsultor + ''">'' + IniConsultor + ''</span></span>'' END +
                ''</td>'' +
                ',
        @TH_ANCHOR  NVARCHAR(400) = N'''<th class="vct-text-center" data-vct-width="12%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span></th>''+',
        @TH_ADD     NVARCHAR(MAX) = N'''<th class="vct-text-center" data-vct-width="80"><span>Analista</span></th>''+''<th class="vct-text-center" data-vct-width="80"><span>Consultor</span></th>''+
            ';

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_DASHBOARD');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @g INT, @t INT, @p INT, @q INT, @k INT, @i INT,
        @marca NVARCHAR(40), @nuevo NVARCHAR(10), @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000);

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
            SET @g = CHARINDEX(N'GRILLA_PROY_V2', @d);
            SET @t = CHARINDEX(N'TOP_PROY_V2', @d);
            IF CHARINDEX(N'<span>Analista</span></th>', @d) > 0
                PRINT 'Pestana Proyectos: Analista y Consultor ya estaban agregados.';
            ELSE IF @g = 0 OR @t = 0 OR CHARINDEX(@DER_ANCHOR, @d) = 0 OR CHARINDEX(@TH_ANCHOR, @d) = 0
                PRINT 'AVISO: no se encontro la grilla de la pestana Proyectos (GRILLA_PROY_V2); no se modifico.';
            ELSE
            BEGIN
                /* columna td: primera ocurrencia dentro del bloque de la pestana */
                SET @p = CHARINDEX(@TD_ANCHOR, @d, @g);
                IF @p = 0 OR @p > @t
                    PRINT 'AVISO: no se encontro la celda de Estado en la pestana Proyectos; no se modifico.';
                ELSE
                BEGIN
                    SET @d = STUFF(@d, @p, 0, @TD_ADD);
                    SET @p = CHARINDEX(@DER_ANCHOR, @d);
                    SET @d = STUFF(@d, @p + LEN(@DER_ANCHOR), 0, @DER_ADD);
                    SET @p = CHARINDEX(@TH_ANCHOR, @d);
                    SET @d = STUFF(@d, @p, 0, @TH_ADD);
                    SET @d = REPLACE(@d, N'<th data-vct-width="24%" data-vct-sort="normas"', N'<th data-vct-width="18%" data-vct-sort="normas"');
                    PRINT 'Pestana Proyectos: columnas Analista y Consultor agregadas.';
                END;
            END;
        END;

        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'17' ELSE N'7' END;
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
