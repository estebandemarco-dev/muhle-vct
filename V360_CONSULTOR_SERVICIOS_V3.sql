/* ========================================================================
   V360_CONSULTOR_SERVICIOS_V3
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca SERVICIOS_V3). No depende de como este armado hoy el boton ni las
   opciones:
   1) Boton Nuevo de la pestana Servicios: se muestra solo si al consultor
      le falta alguno de los 3 servicios (Consultoria, Auditoria,
      Capacitacion). Se calcula @SRV_FALTAN antes de armar los paneles y se
      condiciona lo que va en "vct-360-box-actions" del panel servicios.
   2) Drawer de Servicio: justo antes de armar el <template> de opciones
      del campo Servicio, la lista se recalcula con los servicios que el
      consultor todavia NO tiene.
   3) Celda Servicio: icono y descripcion alineados (estilo en linea, por
      si el css quedo en cache).
   4) Version de la grilla: vct-datagrid.css?v=22 solo en VCT_MAIN_CONSULTORES_V360
      (tablas del Resumen con ancho flexible). La 360 de Clientes NO se toca.
   Antes de correrlo: subir css/vct-datagrid.css (v22). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @CALC NVARCHAR(MAX) = N'/* SERVICIOS_V3: al consultor le falta algun servicio? (boton Nuevo de Servicios) */
    DECLARE @SRV_FALTAN BIT = CASE WHEN EXISTS (
        SELECT 1 FROM dbo.VCT_PRM_SERVICIOS S2 WITH(NOLOCK)
        WHERE S2.CODIGO IN (''CONSULTORIA'',''AUDITORIA'',''CAPACITACION'')
          AND NOT EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CS2 WITH(NOLOCK)
                          WHERE CS2.ID_CONSULTOR = @ID_CONSULTOR AND CS2.ID_SERVICIO = S2.ID)) THEN 1 ELSE 0 END;

    ';

DECLARE @OPT NVARCHAR(MAX) = N'/* SERVICIOS_V3: opciones = solo los servicios que el consultor no tiene */
    SELECT {VAR}=ISNULL((
        SELECT ''<option value="'' + CONVERT(VARCHAR(30),S.ID) + ''">'' +
               REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),S.CODIGO),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') +
               ''</option>''
        FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CS3 WITH(NOLOCK)
                          WHERE CS3.ID_CONSULTOR = @ID_CONSULTOR AND CS3.ID_SERVICIO = S.ID)
        ORDER BY CASE S.CODIGO WHEN ''CONSULTORIA'' THEN 1 WHEN ''AUDITORIA'' THEN 2 WHEN ''CAPACITACION'' THEN 3 ELSE 4 END, S.ID
        FOR XML PATH(''''),TYPE
    ).value(''.'',''VARCHAR(MAX)''),'''');

    ';

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @s INT, @e INT, @t INT, @v INT, @c INT, @x INT,
        @var NVARCHAR(128), @seg NVARCHAR(MAX), @a NVARCHAR(200), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0, @msg NVARCHAR(2000);

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CONSULTORES_V360');

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

        IF @nom = N'VCT_MAIN_CONSULTORES_V360' AND CHARINDEX(N'SERVICIOS_V3', @d) > 0
            PRINT @nom + ': boton y opciones de Servicios ya estaban aplicados (SERVICIOS_V3).';
        ELSE IF @nom = N'VCT_MAIN_CONSULTORES_V360'
        BEGIN
            /* 1. boton Nuevo condicionado */
            SET @s = CHARINDEX(N'data-vct-panel="servicios"', @d);
            SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'data-vct-panel=', @d, @s + 20) ELSE 0 END;
            IF @e = 0 SET @e = LEN(@d);
            SET @a = N'class="vct-360-box-actions">''+';
            SET @t = CASE WHEN @s > 0 THEN CHARINDEX(@a, @d, @s) ELSE 0 END;
            SET @c = CASE WHEN @t > 0 THEN CHARINDEX(N'+''</div>', @d, @t) ELSE 0 END;
            /* ultimo SET @OUTPARAM2= antes del panel servicios */
            SET @x = CASE WHEN @s > 0 AND CHARINDEX(REVERSE(N'SET @OUTPARAM2='), REVERSE(LEFT(@d, @s))) > 0
                          THEN @s - CHARINDEX(REVERSE(N'SET @OUTPARAM2='), REVERSE(LEFT(@d, @s))) - LEN(N'SET @OUTPARAM2=') + 2 ELSE 0 END;
            IF @s = 0 OR @t = 0 OR @t > @e OR @c = 0 OR @c > @e OR @x <= 0 OR @x > @s
                PRINT 'AVISO: no se encontro el boton del panel Servicios (o SET @OUTPARAM2); no se modifico el boton.';
            ELSE
            BEGIN
                /* primero el CASE (mas adelante en el texto), despues el calculo antes de SET @OUTPARAM2 */
                SET @seg = SUBSTRING(@d, @t + LEN(@a), @c - (@t + LEN(@a)));
                SET @d = STUFF(@d, @t + LEN(@a), @c - (@t + LEN(@a)), N'CASE WHEN @SRV_FALTAN=1 THEN ' + @seg + N' ELSE '''' END');
                SET @d = STUFF(@d, @x, 0, @CALC);
                PRINT 'Paso 1: boton Nuevo de Servicios solo si faltan servicios (era: ' + LEFT(@seg, 80) + ').';
            END;

            /* 2. opciones del campo Servicio del drawer */
            SET @t = CHARINDEX(N'data-vct-field-options', @d);
            WHILE @t > 0 AND CHARINDEX(N'vctDrawerConsultorServicio', SUBSTRING(@d, @t, 300)) = 0
                SET @t = CHARINDEX(N'data-vct-field-options', @d, @t + 20);
            SET @v = CASE WHEN @t > 0 THEN CHARINDEX(N'ISNULL(@', @d, @t) ELSE 0 END;
            IF @t = 0 OR @v = 0 OR @v - @t > 500
                PRINT 'AVISO: no se encontro el template de opciones del drawer de Servicio; no se modificaron las opciones.';
            ELSE
            BEGIN
                SET @c = CHARINDEX(N',', @d, @v);
                SET @var = LTRIM(RTRIM(SUBSTRING(@d, @v + 7, @c - (@v + 7))));
                /* inicio de la sentencia que arma el template: ultimo "SET @" antes del template */
                SET @x = @t - CHARINDEX(REVERSE(N'SET @'), REVERSE(LEFT(@d, @t))) - LEN(N'SET @') + 2;
                IF @var NOT LIKE N'@%' OR @var LIKE N'%[^@A-Za-z0-9_]%' OR @x <= 0 OR @t - @x > 1500
                    PRINT 'AVISO: no se pudo identificar la variable de opciones (' + ISNULL(@var,'?') + '); no se modificaron las opciones.';
                ELSE
                BEGIN
                    SET @d = STUFF(@d, @x, 0, REPLACE(@OPT, N'{VAR}', @var));
                    PRINT 'Paso 2: opciones del drawer (' + @var + ') = solo servicios que faltan.';
                END;
            END;

            /* 3. icono + descripcion alineados */
            SET @a = N'<span class="vctdg-svc-item">';
            IF CHARINDEX(@a, @d) > 0
            BEGIN
                SET @d = REPLACE(@d, @a, N'<span class="vctdg-svc-item" style="display:inline-flex;align-items:center;gap:8px;">');
                PRINT 'Paso 3: icono y descripcion alineados.';
            END;
        END;

        /* 4. version */
        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'22' ELSE N'7' END;
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
