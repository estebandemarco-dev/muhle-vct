/* ========================================================================
   V360_CONSULTOR_PROYECTOS_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca GRILLA_PROY_CON_V1), pestana Proyectos con la misma logica que la
   360 de Clientes y Cliente como primera columna:
     Cliente | Proyecto (codigo, nombre, referencia y rol) | Servicios (3 iconos)
     | Normas (lista, hasta 3 y "+N mas") | Analista | Consultor (iniciales con
     tooltip) | Estado (badge unificado) | Avance | menu de 3 puntos
   Filtro por estado; menu con las acciones de VCT_MAIN_GET_ACTIONS(@IUNIDAD,
   'PROYECTOS') (Ver / Editar proyecto). Sin Inicio ni Fin.
   Version de la grilla: vct-datagrid.css?v=23 (js v=7).
   Antes de correrlo: subir css/vct-datagrid.css (v23). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @GRID NVARCHAR(MAX) = N'/* GRILLA_PROY_CON_V1: pestana Proyectos = Cliente | Proyecto | Servicios | Normas | Analista | Consultor | Estado | Avance | menu */
    IF OBJECT_ID(''tempdb..#CPACCG'') IS NOT NULL DROP TABLE #CPACCG;
    SELECT A.ID_PRM, A.ACTION_ID, A.ACTION_TYPE,
           ISNULL(NULLIF(A.TITLE,''''), CASE A.ACTION_TYPE WHEN ''VIEW'' THEN ''Ver proyecto'' ELSE ''Editar proyecto'' END) AS TITLE,
           ISNULL(NULLIF(A.ICON,''''), CASE A.ACTION_TYPE WHEN ''VIEW'' THEN ''scan-eye'' ELSE ''edit'' END) AS ICON,
           A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID, A.SORT_ORDER
    INTO #CPACCG
    FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, ''PROYECTOS'') A
    WHERE A.ACTION_TYPE IN (''VIEW'',''EDIT'');

    DECLARE @CG_MENU_OK BIT = CASE WHEN EXISTS (SELECT 1 FROM #CPACCG) THEN 1 ELSE 0 END;
    DECLARE @CG_SRV_CO VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CONSULTORIA''), ''Consultoria''),
            @CG_SRV_AU VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''AUDITORIA''), ''Auditoria''),
            @CG_SRV_CA VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CAPACITACION''), ''Capacitacion'');

    SELECT @HTML_PROYECTOS = ISNULL((
        SELECT
            ''<tr data-vct-row data-vct-filter-estado="'' + EstadoCod + ''" data-vct-search="'' + REPLACE(REPLACE(REPLACE(RawServicios,''&'',''&amp;''),''"'',''&quot;''),''<'',''&lt;'') + '' '' + EscNormas + ''">'' +
                ''<td data-label="Cliente">'' + EscCliente + ''</td>'' +
                ''<td data-label="Proyecto" data-vct-sort-value="'' + EscCodigo + ''"><span class="vct-360-project-name">('' + EscCodigo + '') '' + EscNombre + ''</span>'' +
                    CASE WHEN EscReferencia <> '''' THEN ''<span class="vct-360-project-ref">'' + EscReferencia + ''</span>'' ELSE '''' END +
                    CASE WHEN EscRelacion <> '''' THEN ''<span class="vct-360-project-ref">Rol: '' + EscRelacion + ''</span>'' ELSE '''' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Servicios" data-vct-export-value="'' + REPLACE(REPLACE(REPLACE(RawServicios,''&'',''&amp;''),''"'',''&quot;''),''<'',''&lt;'') + ''"><span class="vctdg-svc-set">'' +
                    ''<span class="vctdg-svc is-co'' + CASE WHEN HasCo = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCo + CASE WHEN HasCo = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="briefcase"></span></span>'' +
                    ''<span class="vctdg-svc is-au'' + CASE WHEN HasAu = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvAu + CASE WHEN HasAu = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="clipboard-check"></span></span>'' +
                    ''<span class="vctdg-svc is-ca'' + CASE WHEN HasCa = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCa + CASE WHEN HasCa = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="users"></span></span>'' +
                ''</span></td>'' +
                ''<td data-label="Normas" data-vct-export-value="'' + EscNormas + ''"><span class="vctdg-list">'' +
                    CASE WHEN NormasTop = '''' THEN ''-'' ELSE NormasTop END +
                    CASE WHEN NormasCount > 3 THEN ''<span class="vctdg-li is-more" title="'' + EscNormas + ''">+'' + CONVERT(VARCHAR(10), NormasCount - 3) + '' m&aacute;s</span>'' ELSE '''' END +
                ''</span></td>'' +
                ''<td class="vct-text-center" data-label="Analista" data-vct-export-value="'' + EscAnalista + ''">'' +
                    CASE WHEN EscAnalista = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-a" title="'' + EscAnalista + ''">'' + IniAnalista + ''</span></span>'' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Consultor" data-vct-export-value="'' + EscConsultor + ''">'' +
                    CASE WHEN EscConsultor = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-c" title="'' + EscConsultor + ''">'' + IniConsultor + ''</span></span>'' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '' + EstadoClase + ''">'' + EscEstado + ''</span></td>'' +
                ''<td data-label="Avance" data-vct-sort-value="'' + AvanceTxt + ''"><span class="vctdg-progress"><span class="vctdg-progress-bar"><i style="width:'' + AvanceBarTxt + ''%"></i></span><b>'' + AvanceTxt + ''%</b></span></td>'' +
                ''<td class="vct-table-action-cell" data-label="" data-vct-export-ignore="true">'' +
                    CASE WHEN @CG_MENU_OK = 1 THEN
                        ''<button type="button" class="vct-row-menu-trigger" data-vctdg-rowmenu aria-label="Acciones" title="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'' +
                        ''<div class="vctdg-rowmenu-items" hidden>'' + MenuItems + ''</div>''
                    ELSE '''' END +
                ''</td>'' +
            ''</tr>''
        FROM
        (
            SELECT
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.CLIENTE_NOMBRE,''''),''Sin cliente''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscCliente,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.CODIGO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.NOMBRE,''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.REFERENCIA,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscReferencia,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.RELACION,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscRelacion,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.ESTADO,''''),''Sin estado''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscEstado,
                REPLACE(ISNULL(P.ESTADO_CODIGO,''''),''"'','''') AS EstadoCod,
                CASE P.ESTADO_CODIGO
                    WHEN ''ENCURSO'' THEN ''is-progress'' WHEN ''CONFIRMADO'' THEN ''is-planned'' WHEN ''PAUSADO'' THEN ''is-paused''
                    WHEN ''TERMINADO'' THEN ''is-done'' WHEN ''CANCELADO'' THEN ''is-cancel'' WHEN ''BORRADOR'' THEN ''is-draft''
                    ELSE ''is-neutral'' END AS EstadoClase,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(AN.NOMBRE,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscAnalista,
                CASE WHEN CHARINDEX('' '', ISNULL(AN.NOMBRE,'''')) > 0
                     THEN UPPER(LEFT(AN.NOMBRE,1) + LEFT(REVERSE(LEFT(REVERSE(AN.NOMBRE), CHARINDEX('' '', REVERSE(AN.NOMBRE) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(ISNULL(AN.NOMBRE,''''),2)) END AS IniAnalista,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CO.NOMBRE,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscConsultor,
                CASE WHEN CHARINDEX('' '', ISNULL(CO.NOMBRE,'''')) > 0
                     THEN UPPER(LEFT(CO.NOMBRE,1) + LEFT(REVERSE(LEFT(REVERSE(CO.NOMBRE), CHARINDEX('' '', REVERSE(CO.NOMBRE) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(ISNULL(CO.NOMBRE,''''),2)) END AS IniConsultor,
                CONVERT(VARCHAR(10), ISNULL(P.PORCENTAJE_AVANCE,0)) AS AvanceTxt,
                CONVERT(VARCHAR(10), CASE WHEN ISNULL(P.PORCENTAJE_AVANCE,0) < 0 THEN 0 WHEN ISNULL(P.PORCENTAJE_AVANCE,0) > 100 THEN 100 ELSE ISNULL(P.PORCENTAJE_AVANCE,0) END) AS AvanceBarTxt,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CONSULTORIA'') THEN 1 ELSE 0 END AS HasCo,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''AUDITORIA'') THEN 1 ELSE 0 END AS HasAu,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CAPACITACION'') THEN 1 ELSE 0 END AS HasCa,
                REPLACE(REPLACE(@CG_SRV_CO,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCo,
                REPLACE(REPLACE(@CG_SRV_AU,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvAu,
                REPLACE(REPLACE(@CG_SRV_CA,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCa,
                ISNULL(STUFF((
                    SELECT '', '' + S.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO
                    WHERE PS.ID_PROYECTO = P.ID
                    ORDER BY S.ID
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), '''') AS RawServicios,
                ISNULL(REPLACE(REPLACE(REPLACE(STUFF((
                    SELECT '', '' + N.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), ''&'', ''&amp;''), ''"'', ''&quot;''), ''<'', ''&lt;''), '''') AS EscNormas,
                ISNULL((
                    SELECT TOP 3 ''<span class="vctdg-li">'' + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</span>''
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS NormasTop,
                (SELECT COUNT(DISTINCT PN.ID_NORMA) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                 WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA'') AS NormasCount,
                ISNULL((
                    SELECT dbo.VCT_MAIN_RENDER_ACTION(A.ACTION_ID, A.TITLE, A.ICON, A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID,
                                                      CONVERT(VARCHAR(20), P.ID), ''vctdg-menu-item'', A.TITLE)
                    FROM #CPACCG A
                    ORDER BY CASE A.ACTION_TYPE WHEN ''VIEW'' THEN 0 ELSE 1 END, A.SORT_ORDER, A.ID_PRM
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS MenuItems,
                P.FECHA_INICIO AS SortFecha,
                P.ID AS SortID
            FROM #PROYECTOS360 P
            OUTER APPLY
            (
                SELECT TOP 1 LTRIM(RTRIM(ISNULL(E.NOMBRES,'''') + '' '' + ISNULL(E.APELLIDOS,''''))) AS NOMBRE
                FROM dbo.VCT_PROYECTOS_EQUIPO EQ WITH(NOLOCK)
                INNER JOIN dbo.VCT_PRM_PROYECTOS_ROLES ROL WITH(NOLOCK) ON ROL.ID = EQ.ID_ROL
                INNER JOIN dbo.VCT_EMPLEADOS E WITH(NOLOCK) ON E.ID = EQ.ID_EMPLEADO
                WHERE EQ.ID_PROYECTO = P.ID AND EQ.TIPO_MIEMBRO = ''EMPLEADO'' AND ROL.CODIGO = ''ANALISTA''
                  AND ISNULL(NULLIF(UPPER(LTRIM(RTRIM(EQ.ESTADO))),''''),''ACTIVO'') <> ''INACTIVO''
                ORDER BY EQ.PRINCIPAL DESC, EQ.ID
            ) AN
            OUTER APPLY
            (
                SELECT TOP 1 LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(150),C.NOMBRES),'''') + '' '' + ISNULL(CONVERT(VARCHAR(150),C.APELLIDOS),''''))) AS NOMBRE
                FROM
                (
                    SELECT EQ.ID_CONSULTOR, 1 AS FUENTE, CASE WHEN ISNULL(EQ.PRINCIPAL,0) = 1 THEN 0 ELSE 1 END AS ORDEN_INTERNO, EQ.ID AS ID_ORDEN
                    FROM dbo.VCT_PROYECTOS_EQUIPO EQ WITH(NOLOCK)
                    WHERE EQ.ID_PROYECTO = P.ID AND EQ.TIPO_MIEMBRO = ''CONSULTOR'' AND EQ.ID_CONSULTOR IS NOT NULL
                      AND ISNULL(NULLIF(UPPER(LTRIM(RTRIM(EQ.ESTADO))),''''),''ACTIVO'') <> ''INACTIVO''
                    UNION ALL
                    SELECT VC.ID_CONSULTOR, 2, CASE WHEN ISNULL(VC.LIDER,0) = 1 THEN 0 ELSE 1 END, VC.ID
                    FROM dbo.VCT_PROYECTOS_VISITAS V WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC WITH(NOLOCK) ON VC.ID_VISITA = V.ID
                    WHERE V.ID_PROYECTO = P.ID AND VC.ID_CONSULTOR IS NOT NULL
                ) Q
                INNER JOIN dbo.VCT_CONSULTORES C WITH(NOLOCK) ON C.ID = Q.ID_CONSULTOR
                ORDER BY Q.FUENTE, Q.ORDEN_INTERNO, Q.ID_ORDEN
            ) CO
        ) X
        ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END, SortFecha DESC, SortID DESC
        FOR XML PATH(''''), TYPE
    ).value(''.'',''VARCHAR(MAX)''),'''');

    IF @HTML_PROYECTOS = ''''
        SET @HTML_PROYECTOS = ''<div class="vct-360-empty vct-360-fixed-empty">El consultor no posee proyectos relacionados.</div>'';
    ELSE
        SET @HTML_PROYECTOS =
            ''<div data-vct-dg data-vct-dg-id="v360_con_proyectos" data-vct-dg-title="Proyectos del consultor" data-vct-dg-subtitle="Consultor: ''+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'')+''" data-vct-dg-unit="proyecto(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar cliente, proyecto, servicio, norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+
            ''<div data-vct-dg-slot="filters"><select data-vct-dg-filter="estado" aria-label="Estado"><option value="">Todos los estados</option>''+
                ISNULL((SELECT ''<option value="''+REPLACE(E.CODIGO,''"'','''')+''">''+REPLACE(REPLACE(E.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;'')+''</option>''
                        FROM dbo.VCT_PRM_PROYECTOS_ESTADOS E WITH(NOLOCK)
                        WHERE EXISTS (SELECT 1 FROM #PROYECTOS360 P WHERE P.ESTADO_CODIGO = E.CODIGO)
                        ORDER BY E.ID
                        FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''),'''')+
            ''</select></div>''+
            ''<table>''+
            ''<thead><tr>''+
                ''<th data-vct-width="14%" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente</span></th>''+
                ''<th data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span></th>''+
                ''<th class="vct-text-center" data-vct-width="96"><span>Servicios</span></th>''+
                ''<th data-vct-width="15%" data-vct-sort="normas" data-vct-sortable="true"><span>Normas</span></th>''+
                ''<th class="vct-text-center" data-vct-width="80"><span>Analista</span></th>''+
                ''<th class="vct-text-center" data-vct-width="80"><span>Consultor</span></th>''+
                ''<th class="vct-text-center" data-vct-width="112" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span></th>''+
                ''<th data-vct-width="12%" data-vct-sort="avance" data-vct-sortable="true" data-vct-sort-type="number"><span>Avance</span></th>''+
                ''<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>''+
            ''</tr></thead>''+
            ''<tbody>''+@HTML_PROYECTOS+''</tbody>''+
            ''</table>''+
            ''</div>'';

    ';

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10), @p INT, @q INT, @k INT,
        @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'GRILLA_PROY_CON_V1', @d) > 0
    PRINT 'La pestana Proyectos ya estaba aplicada (GRILLA_PROY_CON_V1). Solo se revisa la version.';
ELSE
BEGIN
    SET @s = CHARINDEX(N'SELECT @HTML_PROYECTOS=ISNULL((', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'/* CONSULTOR_TOP_V1', @d, @s) ELSE 0 END;
    IF @e = 0 AND @s > 0 SET @e = CHARINDEX(N'SELECT @HTML_PROYECTOS_TOP=ISNULL((', @d, @s);
    IF @s = 0 OR @e = 0 OR CHARINDEX(N'v360_con_proyectos', SUBSTRING(@d, @s, @e - @s)) = 0
        PRINT 'AVISO: no se encontro la grilla de la pestana Proyectos; no se modifico.';
    ELSE
    BEGIN
        SET @d = STUFF(@d, @s, @e - @s, @GRID);
        PRINT 'Paso 1: grilla de la pestana Proyectos reemplazada.';
    END;
END;

SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'23' ELSE N'7' END;
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
