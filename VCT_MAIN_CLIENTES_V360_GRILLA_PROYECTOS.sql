/* ========================================================================
   VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS
   ------------------------------------------------------------------------
   Modifica SP EXISTENTES (no crea nada nuevo en la base):
   1) Permisos: solo informa (no modifica PrmActions ni GroupsActions).
   2) dbo.VCT_MAIN_CLIENTES_V360, pestana Proyectos (marca GRILLA_PROY_V2):
      Proyecto (codigo, nombre, referencia) | Servicios (3 iconos fijos del
      alta: Consultoria / Auditoria / Capacitacion) | Normas (2 + "+N") |
      Estado | Avance | menu de 3 puntos (Ver / Editar proyecto segun permisos).
      Filtro por estado y boton Nuevo (PROYECTOS.CREATE) en el toolbar.
   3) Version de la grilla en dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360:
      vct-datagrid.css?v=8 y vct-datagrid.js?v=6.
   Antes de correrlo: subir css/vct-datagrid.css (v8) y js/vct-datagrid.js (v6).
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @GUID_PROY360 VARCHAR(40) = '330B876D-4E57-4E2E-BFC3-D7B998D09725', @msg NVARCHAR(2000), @sql NVARCHAR(MAX);

/* ---------------- 1. Permisos (solo lectura) ---------------- */
IF OBJECT_ID('tempdb..#GP_A') IS NOT NULL DROP TABLE #GP_A;
CREATE TABLE #GP_A (ACTION_ID VARCHAR(100), ACTION_TYPE VARCHAR(20), TITLE VARCHAR(200), ICON VARCHAR(50), DESTINO BIT);
INSERT INTO #GP_A VALUES ('PROYECTOS.VIEW','VIEW','Ver proyecto','scan-eye',1),
                         ('PROYECTOS.EDIT','EDIT','Editar proyecto','edit',1),
                         ('PROYECTOS.CREATE','CREATE','Nuevo proyecto','folder',0);

PRINT '=== Permisos de proyectos por perfil (GroupsActions) - si falta alguno, asignarlo desde Configuracion ===';
SELECT G.ACTION_ID,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.Actions A WHERE A.Id = G.ACTION_ID) THEN 'SI' ELSE 'NO (falta en Actions)' END AS EN_ACTIONS,
       ISNULL(STUFF((SELECT ', ' + GA.GroupId FROM dbo.GroupsActions GA WHERE GA.ActionId = G.ACTION_ID ORDER BY GA.GroupId FOR XML PATH('')), 1, 2, ''), '(ningun perfil)') AS PERFILES
FROM #GP_A G;

/* ---------------- 2 y 3. Parche de los SP ---------------- */
DECLARE @BLOQUE NVARCHAR(MAX) = N'/* GRILLA_PROY_V2: Proyectos | Servicios (iconos del alta) | Normas | Estado | Avance | menu de 3 puntos.
   Acciones del menu y boton Nuevo: VCT_MAIN_GET_ACTIONS(@IUNIDAD,''PROYECTOS'') (PrmActions + permisos del perfil). */
    IF OBJECT_ID(''tempdb..#PACC'') IS NOT NULL DROP TABLE #PACC;
    SELECT A.ID_PRM, A.ACTION_ID, A.ACTION_TYPE,
           ISNULL(NULLIF(A.TITLE,''''), CASE A.ACTION_TYPE WHEN ''VIEW'' THEN ''Ver proyecto'' WHEN ''EDIT'' THEN ''Editar proyecto'' ELSE ''Nuevo proyecto'' END) AS TITLE,
           ISNULL(NULLIF(A.ICON,''''), CASE A.ACTION_TYPE WHEN ''VIEW'' THEN ''scan-eye'' WHEN ''EDIT'' THEN ''edit'' ELSE ''folder'' END) AS ICON,
           A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID, A.SORT_ORDER
    INTO #PACC
    FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, ''PROYECTOS'') A
    WHERE A.ACTION_TYPE IN (''VIEW'',''EDIT'',''CREATE'');

    DECLARE @PROY_MENU_OK BIT = CASE WHEN EXISTS (SELECT 1 FROM #PACC WHERE ACTION_TYPE IN (''VIEW'',''EDIT'')) THEN 1 ELSE 0 END;
    DECLARE @PROY_BTN_NEW VARCHAR(MAX) = '''';
    SELECT TOP 1 @PROY_BTN_NEW =
        ''<button type="button" class="vct-btn vct-btn-new vct-btn-sm" data-vct-pending-action="project-create" data-vct-tooltip="''
        + REPLACE(REPLACE(TITLE,''"'',''&quot;''),''<'',''&lt;'') + ''"><span data-vct-icon="'' + REPLACE(ICON,''"'','''') + ''"></span><span>Nuevo</span></button>''
    FROM #PACC WHERE ACTION_TYPE = ''CREATE'' ORDER BY SORT_ORDER, ID_PRM;

    DECLARE @SRV_CO VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CONSULTORIA''), ''Consultoria''),
            @SRV_AU VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''AUDITORIA''), ''Auditoria''),
            @SRV_CA VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CAPACITACION''), ''Capacitacion'');

    SELECT @HTML_PROYECTOS = ISNULL((
        SELECT
            ''<tr data-vct-row data-vct-filter-estado="'' + EstadoCod + ''" data-vct-search="'' + REPLACE(REPLACE(REPLACE(RawServicios,''&'',''&amp;''),''"'',''&quot;''),''<'',''&lt;'') + '' '' + EscNormas + ''">'' +
                ''<td data-label="Proyecto" data-vct-sort-value="'' + EscCodigo + ''"><span class="vct-360-project-name">('' + EscCodigo + '') '' + EscNombre + ''</span>'' +
                    CASE WHEN EscReferencia <> '''' THEN ''<span class="vct-360-project-ref">'' + EscReferencia + ''</span>'' ELSE '''' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Servicios" data-vct-export-value="'' + REPLACE(REPLACE(REPLACE(RawServicios,''&'',''&amp;''),''"'',''&quot;''),''<'',''&lt;'') + ''"><span class="vctdg-svc-set">'' +
                    ''<span class="vctdg-svc is-co'' + CASE WHEN HasCo = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCo + CASE WHEN HasCo = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="briefcase"></span></span>'' +
                    ''<span class="vctdg-svc is-au'' + CASE WHEN HasAu = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvAu + CASE WHEN HasAu = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="clipboard-check"></span></span>'' +
                    ''<span class="vctdg-svc is-ca'' + CASE WHEN HasCa = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCa + CASE WHEN HasCa = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="users"></span></span>'' +
                ''</span></td>'' +
                ''<td data-label="Normas" data-vct-export-value="'' + EscNormas + ''"><span class="vctdg-tags">'' +
                    CASE WHEN NormasTop = '''' THEN ''-'' ELSE NormasTop END +
                    CASE WHEN NormasCount > 2 THEN ''<span class="vctdg-tag is-more" title="'' + EscNormas + ''">+'' + CONVERT(VARCHAR(10), NormasCount - 2) + ''</span>'' ELSE '''' END +
                ''</span></td>'' +
                ''<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '' + EstadoClase + ''">'' + EscEstado + ''</span></td>'' +
                ''<td data-label="Avance" data-vct-sort-value="'' + AvanceTxt + ''"><span class="vctdg-progress"><span class="vctdg-progress-bar"><i style="width:'' + AvanceBarTxt + ''%"></i></span><b>'' + AvanceTxt + ''%</b></span></td>'' +
                ''<td class="vct-table-action-cell" data-label="" data-vct-export-ignore="true">'' +
                    CASE WHEN @PROY_MENU_OK = 1 THEN
                        ''<button type="button" class="vct-row-menu-trigger" data-vctdg-rowmenu aria-label="Acciones" title="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'' +
                        ''<div class="vctdg-rowmenu-items" hidden>'' + MenuItems + ''</div>''
                    ELSE '''' END +
                ''</td>'' +
            ''</tr>''
        FROM
        (
            SELECT
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.CODIGO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.NOMBRE,''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.REFERENCIA,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscReferencia,
                REPLACE(REPLACE(REPLACE(REPLACE(
                    CASE WHEN P.ESTADO_CODIGO = ''ENCURSO'' THEN ''ACTIVO'' ELSE ISNULL(NULLIF(P.ESTADO,''''),''Sin estado'') END,
                    ''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscEstado,
                REPLACE(ISNULL(P.ESTADO_CODIGO,''''),''"'','''') AS EstadoCod,
                CASE
                    WHEN P.ESTADO_CODIGO = ''ENCURSO'' THEN ''is-progress''
                    WHEN P.ESTADO_CODIGO = ''CONFIRMADO'' THEN ''is-planned''
                    WHEN P.ESTADO_CODIGO = ''TERMINADO'' THEN ''is-done''
                    WHEN P.ESTADO_CODIGO = ''CANCELADO'' THEN ''is-cancel''
                    ELSE ''is-neutral''
                END AS EstadoClase,
                CONVERT(VARCHAR(10), ISNULL(P.PORCENTAJE_AVANCE,0)) AS AvanceTxt,
                CONVERT(VARCHAR(10), CASE WHEN ISNULL(P.PORCENTAJE_AVANCE,0) < 0 THEN 0 WHEN ISNULL(P.PORCENTAJE_AVANCE,0) > 100 THEN 100 ELSE ISNULL(P.PORCENTAJE_AVANCE,0) END) AS AvanceBarTxt,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CONSULTORIA'') THEN 1 ELSE 0 END AS HasCo,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''AUDITORIA'') THEN 1 ELSE 0 END AS HasAu,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CAPACITACION'') THEN 1 ELSE 0 END AS HasCa,
                REPLACE(REPLACE(@SRV_CO,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCo,
                REPLACE(REPLACE(@SRV_AU,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvAu,
                REPLACE(REPLACE(@SRV_CA,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCa,
                ISNULL(STUFF((
                    SELECT '', '' + S.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO
                    WHERE PS.ID_PROYECTO = P.ID
                    ORDER BY ISNULL(PS.ORDEN, 99), S.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), '''') AS RawServicios,
                ISNULL(REPLACE(REPLACE(REPLACE(STUFF((
                    SELECT '', '' + N.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    ORDER BY ISNULL(PN.PRINCIPAL,0) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), ''&'', ''&amp;''), ''"'', ''&quot;''), ''<'', ''&lt;''), '''') AS EscNormas,
                ISNULL((
                    SELECT TOP 2 ''<span class="vctdg-tag" title="'' + REPLACE(REPLACE(N.DESCRIPCION,''"'',''&quot;''),''<'',''&lt;'') + ''">''
                           + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</span>''
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    ORDER BY ISNULL(PN.PRINCIPAL,0) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS NormasTop,
                (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                 WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA'') AS NormasCount,
                ISNULL((
                    SELECT dbo.VCT_MAIN_RENDER_ACTION(A.ACTION_ID, A.TITLE, A.ICON, A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID,
                                                      CONVERT(VARCHAR(20), P.ID), ''vctdg-menu-item'', A.TITLE)
                    FROM #PACC A
                    WHERE A.ACTION_TYPE IN (''VIEW'',''EDIT'')
                    ORDER BY CASE A.ACTION_TYPE WHEN ''VIEW'' THEN 0 ELSE 1 END, A.SORT_ORDER, A.ID_PRM
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS MenuItems,
                P.FECHA_INICIO AS SortFecha,
                P.ID AS SortID
            FROM #PROYECTOS360 P
        ) X
        ORDER BY
            CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END,
            SortFecha DESC,
            SortID DESC
        FOR XML PATH(''''), TYPE
    ).value(''.'',''VARCHAR(MAX)''),'''');

    SET @HTML_PROYECTOS =
        ''<div data-vct-dg data-vct-dg-id="v360_proy" data-vct-dg-title="Proyectos del cliente" data-vct-dg-subtitle="Cliente: ''+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Cliente,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'')+''" data-vct-dg-unit="proyecto(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar proyecto, servicio, norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+
        ''<div data-vct-dg-slot="filters"><select data-vct-dg-filter="estado" aria-label="Estado"><option value="">Todos los estados</option>''+
            ISNULL((SELECT ''<option value="''+REPLACE(E.CODIGO,''"'','''')+''">''+REPLACE(REPLACE(E.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;'')+''</option>''
                    FROM dbo.VCT_PRM_PROYECTOS_ESTADOS E WITH(NOLOCK)
                    WHERE EXISTS (SELECT 1 FROM #PROYECTOS360 P WHERE P.ESTADO_CODIGO = E.CODIGO)
                    ORDER BY E.ID
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''),'''')+
        ''</select></div>''+
        CASE WHEN @PROY_BTN_NEW <> '''' THEN ''<div data-vct-dg-slot="actions">''+@PROY_BTN_NEW+''</div>'' ELSE '''' END+
        ''<table>''+
        ''<thead><tr>''+
            ''<th data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span></th>''+
            ''<th class="vct-text-center" data-vct-width="12%"><span>Servicios</span></th>''+
            ''<th data-vct-width="24%" data-vct-sort="normas" data-vct-sortable="true"><span>Normas</span></th>''+
            ''<th class="vct-text-center" data-vct-width="12%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span></th>''+
            ''<th data-vct-width="14%" data-vct-sort="avance" data-vct-sortable="true" data-vct-sort-type="number"><span>Avance</span></th>''+
            ''<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>''+
        ''</tr></thead>''+
        ''<tbody>''+@HTML_PROYECTOS+''</tbody>''+
        ''</table>''+
        ''</div>'';

';

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @ini INT, @fin INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT, @trg_on BIT = 0;

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

        /* grilla de proyectos (solo la 360 de cliente) */
        IF @nom = N'VCT_MAIN_CLIENTES_V360'
        BEGIN
            IF CHARINDEX(N'GRILLA_PROY_V2', @d) > 0
                PRINT @nom + ': la grilla de proyectos ya estaba aplicada (GRILLA_PROY_V2).';
            ELSE
            BEGIN
                SET @ini = CHARINDEX(N'SELECT @HTML_PROYECTOS = ISNULL((', @d);
                SET @fin = CASE WHEN @ini > 0 THEN CHARINDEX(N'SELECT @HTML_PROYECTOS_TOP = ISNULL((', @d, @ini) ELSE 0 END;
                IF @ini = 0 OR @fin = 0 OR CHARINDEX(N'data-vct-dg-id="v360_proy"', SUBSTRING(@d, @ini, @fin - @ini)) = 0
                    PRINT @nom + ': NO se encontro el bloque de la grilla de proyectos; no se modifico la grilla.';
                ELSE
                    SET @d = STUFF(@d, @ini, @fin - @ini, @BLOQUE + NCHAR(13) + NCHAR(10) + N'    ');
            END;
        END;

        /* version de los archivos de la grilla */
        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'8' ELSE N'6' END;
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
