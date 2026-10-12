/* ========================================================================
   V360_CONSULTOR_SERVICIOS_V2
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360,
   pestana Servicios (marca SERVICIOS_V2):
   1) Grilla: Servicio con su icono fijo (Consultoria briefcase, Auditoria
      clipboard-check, Capacitacion users) + la descripcion; Observaciones;
      Desde. Sin menu de 3 puntos (no se edita ni elimina desde aca).
   2) Boton Agregar/Nuevo: solo si al consultor le falta alguno de los 3
      servicios.
   3) Drawer de alta: el desplegable de Servicio trae solo los servicios
      que el consultor todavia no tiene.
   4) Version de la grilla: vct-datagrid.css?v=21 (js v=7).
   Antes de correrlo: subir css/vct-datagrid.css (v21). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @GRID NVARCHAR(MAX) = N'/* SERVICIOS_V2: Servicio (icono + descripcion) | Observaciones | Desde; sin menu de fila */
    SELECT @HTML_SERVICIOS=ISNULL((
        SELECT
            ''<tr data-vct-row data-vct-id="'' + CONVERT(VARCHAR(30),CS.ID) + ''" data-vct-idservicio="'' + CONVERT(VARCHAR(30),CS.ID_SERVICIO) + ''">'' +
                ''<td data-label="Servicio" data-vct-sort-value="'' + REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),ISNULL(S.CODIGO,'''')),''"'',''&quot;''),''<'',''&lt;'') + ''">'' +
                    ''<span class="vctdg-svc-item"><span class="vctdg-svc is-on '' +
                        CASE S.CODIGO WHEN ''CONSULTORIA'' THEN ''is-co'' WHEN ''AUDITORIA'' THEN ''is-au'' WHEN ''CAPACITACION'' THEN ''is-ca'' ELSE ''is-co'' END +
                        ''"><span data-vct-icon="'' +
                        CASE S.CODIGO WHEN ''CONSULTORIA'' THEN ''briefcase'' WHEN ''AUDITORIA'' THEN ''clipboard-check'' WHEN ''CAPACITACION'' THEN ''users'' ELSE ''briefcase'' END +
                        ''"></span></span>'' +
                    ''<span class="vctdg-svc-text">'' +
                        REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),ISNULL(S.CODIGO,''Servicio '' + CONVERT(VARCHAR(30),CS.ID_SERVICIO))),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') +
                    ''</span></span>'' +
                ''</td>'' +
                ''<td data-label="Observaciones">'' + REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(CS.OBSERVACIONES,''''),''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</td>'' +
                ''<td class="vct-text-center" data-label="Desde">'' + CASE WHEN CS.FECHA_ALTA IS NULL THEN ''-'' ELSE CONVERT(VARCHAR(10),CS.FECHA_ALTA,103) END + ''</td>'' +
            ''</tr>''
        FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)
        LEFT JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = CS.ID_SERVICIO
        WHERE CS.ID_CONSULTOR = @ID_CONSULTOR
        ORDER BY CASE S.CODIGO WHEN ''CONSULTORIA'' THEN 1 WHEN ''AUDITORIA'' THEN 2 WHEN ''CAPACITACION'' THEN 3 ELSE 4 END, CS.ID
        FOR XML PATH(''''),TYPE
    ).value(''.'',''VARCHAR(MAX)''),'''');

    IF @HTML_SERVICIOS=''''
        SET @HTML_SERVICIOS=''<div class="vct-360-empty vct-360-fixed-empty">El consultor no tiene servicios cargados.</div>'';
    ELSE
        SET @HTML_SERVICIOS=
            ''<div data-vct-dg data-vct-dg-id="v360_con_servicios" data-vct-dg-title="Servicios del consultor" data-vct-dg-subtitle="Consultor: '' + REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') + ''" data-vct-dg-unit="servicio(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar servicio..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'' +
            ''<table>'' +
            ''<thead><tr>'' +
            ''<th data-vct-width="26%" data-vct-sort="servicio" data-vct-sortable="true"><span>Servicio</span></th>'' +
            ''<th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span></th>'' +
            ''<th class="vct-text-center" data-vct-width="12%" data-vct-sort="desde" data-vct-sortable="true" data-vct-sort-type="date"><span>Desde</span></th>'' +
            ''</tr></thead>'' +
            ''<tbody>'' + @HTML_SERVICIOS + ''</tbody>'' +
            ''</table>'' +
            ''</div>'';';

DECLARE @BTN NVARCHAR(MAX) = N'
    /* SERVICIOS_V2: Agregar solo si le falta alguno de los servicios */
    IF NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_SERVICIOS S2 WITH(NOLOCK)
                   WHERE S2.CODIGO IN (''CONSULTORIA'',''AUDITORIA'',''CAPACITACION'')
                     AND NOT EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CS2 WITH(NOLOCK)
                                     WHERE CS2.ID_CONSULTOR = @ID_CONSULTOR AND CS2.ID_SERVICIO = S2.ID))
        SET @BTN_ADD_SERV = '''';
';

DECLARE @FALTAN NVARCHAR(400) = N'NOT EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CS3 WITH(NOLOCK) WHERE CS3.ID_CONSULTOR = @ID_CONSULTOR AND CS3.ID_SERVICIO = S.ID) ';

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @p INT, @e INT, @f INT, @o INT, @a NVARCHAR(200), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'SERVICIOS_V2', @d) > 0
    PRINT 'La pestana Servicios ya estaba aplicada (SERVICIOS_V2). Solo se revisa la version.';
ELSE
BEGIN
    /* 1. grilla */
    SET @s = CHARINDEX(N'SELECT @HTML_SERVICIOS=ISNULL((', @d);
    SET @p = CASE WHEN @s > 0 THEN CHARINDEX(N'data-vct-dg-id="v360_con_servicios"', @d, @s) ELSE 0 END;
    SET @e = CASE WHEN @p > 0 THEN CHARINDEX(N'''</div>'';', @d, @p) ELSE 0 END;
    IF @s = 0 OR @p = 0 OR @e = 0 OR @p - @s > 12000 OR CHARINDEX(N'IF @HTML_SERVICIOS=', SUBSTRING(@d, @s, @e - @s)) = 0
        PRINT 'AVISO: no se encontro la grilla de Servicios; no se modifico.';
    ELSE
    BEGIN
        SET @d = STUFF(@d, @s, @e + LEN(N'''</div>'';') - @s, @GRID);
        PRINT 'Paso 1: grilla de Servicios con icono + descripcion y sin menu de fila.';
    END;

    /* 2. boton Agregar */
    SET @a = N'@OUTHTML=@BTN_ADD_SERV OUTPUT;';
    SET @s = CHARINDEX(@a, @d);
    IF @s = 0
        PRINT 'AVISO: no se encontro el boton Agregar de Servicios; no se modifico.';
    ELSE
    BEGIN
        SET @e = CHARINDEX(N'END;', @d, @s);   /* cierre del IF @CAN_EDIT=1 BEGIN ... END; */
        IF @e = 0 OR @e - @s > 200
            SET @e = @s + LEN(@a);
        ELSE
            SET @e = @e + LEN(N'END;');
        SET @d = STUFF(@d, @e, 0, @BTN);
        PRINT 'Paso 2: boton Agregar solo si faltan servicios.';
    END;

    /* 3. opciones del drawer: solo los que no tiene */
    SET @s = CHARINDEX(N'SELECT @HTML_SERV_OPTIONS=ISNULL((', @d);
    SET @f = CASE WHEN @s > 0 THEN CHARINDEX(N'FROM dbo.VCT_PRM_SERVICIOS S', @d, @s) ELSE 0 END;
    SET @o = CASE WHEN @f > 0 THEN CHARINDEX(N'ORDER BY', @d, @f) ELSE 0 END;
    IF @s = 0 OR @f = 0 OR @o = 0 OR @o - @s > 2000
        PRINT 'AVISO: no se encontraron las opciones del drawer de Servicio; no se modifico.';
    ELSE
    BEGIN
        IF CHARINDEX(N'WHERE', SUBSTRING(@d, @f, @o - @f)) > 0
            SET @d = STUFF(@d, @o, 0, N'AND ' + @FALTAN);
        ELSE
            SET @d = STUFF(@d, @o, 0, N'WHERE ' + @FALTAN);
        PRINT 'Paso 3: el desplegable trae solo los servicios que faltan.';
    END;
END;

/* 4. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'21' ELSE N'7' END;
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

IF @d = @orig BEGIN PRINT 'VCT_MAIN_CONSULTORES_V360: sin cambios.'; RETURN; END;

SET @i = CHARINDEX(N'CREATE', @d);
WHILE @i > 0 AND @hecho = 0
BEGIN
    SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
    IF @rest LIKE N'PROC%' BEGIN SET @d = STUFF(@d, @i, 6, N'ALTER'); SET @hecho = 1; END
    ELSE SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
END;
IF @hecho = 0 BEGIN RAISERROR('No se encontro CREATE PROCEDURE. No se hizo nada.', 16, 1); RETURN; END;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 actualizado.';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONSULTORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
