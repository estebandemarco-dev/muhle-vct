/* ========================================================================
   VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS_3
   ------------------------------------------------------------------------
   NO toca permisos. Modifica SP existentes:
   1) dbo.VCT_MAIN_CLIENTES_V360 - "Ultimos proyectos" del Resumen (TOP_PROY_V2):
      Proyecto | Servicios | Normas | Analista | Consultor | Estado | Avance | menu
      (mismo diseno que la pestana Proyectos; sin Inicio ni Fin; ultimos 5).
   2) dbo.VCT_MAIN_CLIENTES_V360 - pestana Proyectos: el estado muestra la
      descripcion del estado (En curso, Confirmado...) y Pausado/Borrador
      tienen su propio color.
   3) Version de la grilla en dbo.VCT_MAIN_CLIENTES y dbo.VCT_MAIN_CLIENTES_V360:
      vct-datagrid.css?v=10 y vct-datagrid.js?v=7.
   Antes de correrlo: subir css/vct-datagrid.css (v10). El js no cambia.
   Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @BLOQUE NVARCHAR(MAX) = N'/* TOP_PROY_V2: "Ultimos proyectos" del Resumen = misma grilla que la pestana Proyectos
   (Proyecto | Servicios | Normas | Analista | Consultor | Estado | Avance | menu), ultimos 5.
   Usa #PACC, @PROY_MENU_OK y @SRV_* del bloque GRILLA_PROY_V2. */
    SELECT @HTML_PROYECTOS_TOP = ISNULL((
        SELECT
            ''<tr data-vct-row>'' +
                ''<td data-label="Proyecto"><span class="vct-360-project-name" title="'' + EscCodigo + '' '' + EscNombre + ''">('' + EscCodigo + '') '' + EscNombre + ''</span>'' +
                    CASE WHEN EscReferencia <> '''' THEN ''<span class="vct-360-project-ref" title="'' + EscReferencia + ''">'' + EscReferencia + ''</span>'' ELSE '''' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Servicios"><span class="vctdg-svc-set">'' +
                    ''<span class="vctdg-svc is-co'' + CASE WHEN HasCo = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCo + CASE WHEN HasCo = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="briefcase"></span></span>'' +
                    ''<span class="vctdg-svc is-au'' + CASE WHEN HasAu = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvAu + CASE WHEN HasAu = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="clipboard-check"></span></span>'' +
                    ''<span class="vctdg-svc is-ca'' + CASE WHEN HasCa = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCa + CASE WHEN HasCa = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="users"></span></span>'' +
                ''</span></td>'' +
                ''<td data-label="Normas"><span class="vctdg-tags">'' +
                    CASE WHEN NormasTop = '''' THEN ''-'' ELSE NormasTop END +
                    CASE WHEN NormasCount > 2 THEN ''<span class="vctdg-tag is-more" title="'' + EscNormas + ''">+'' + CONVERT(VARCHAR(10), NormasCount - 2) + ''</span>'' ELSE '''' END +
                ''</span></td>'' +
                ''<td data-label="Analista">'' +
                    CASE WHEN EscAnalista = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-a">'' + IniAnalista + ''</span><span class="vctdg-person-name" title="'' + EscAnalista + ''">'' + EscAnalista + ''</span></span>'' END +
                ''</td>'' +
                ''<td data-label="Consultor">'' +
                    CASE WHEN EscConsultor = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar is-c">'' + IniConsultor + ''</span><span class="vctdg-person-name" title="'' + EscConsultor + ''">'' + EscConsultor + ''</span></span>'' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '' + EstadoClase + ''">'' + EscEstado + ''</span></td>'' +
                ''<td data-label="Avance"><span class="vctdg-progress"><span class="vctdg-progress-bar"><i style="width:'' + AvanceBarTxt + ''%"></i></span><b>'' + AvanceTxt + ''%</b></span></td>'' +
                ''<td class="vct-table-action-cell" data-label="">'' +
                    CASE WHEN @PROY_MENU_OK = 1 THEN
                        ''<button type="button" class="vct-row-menu-trigger" data-vctdg-rowmenu aria-label="Acciones" title="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'' +
                        ''<div class="vctdg-rowmenu-items" hidden>'' + MenuItems + ''</div>''
                    ELSE '''' END +
                ''</td>'' +
            ''</tr>''
        FROM
        (
            SELECT TOP 5
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.CODIGO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.NOMBRE,''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.REFERENCIA,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscReferencia,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.ESTADO,''''),''Sin estado''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscEstado,
                CASE P.ESTADO_CODIGO
                    WHEN ''ENCURSO'' THEN ''is-progress'' WHEN ''CONFIRMADO'' THEN ''is-planned'' WHEN ''PAUSADO'' THEN ''is-paused''
                    WHEN ''TERMINADO'' THEN ''is-done'' WHEN ''CANCELADO'' THEN ''is-cancel'' WHEN ''BORRADOR'' THEN ''is-draft''
                    ELSE ''is-neutral'' END AS EstadoClase,
                REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(P.ANALISTA,''''))),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS EscAnalista,
                CASE WHEN CHARINDEX('' '', LTRIM(RTRIM(ISNULL(P.ANALISTA,'''')))) > 0
                     THEN UPPER(LEFT(LTRIM(P.ANALISTA),1) + LEFT(REVERSE(LEFT(REVERSE(RTRIM(P.ANALISTA)), CHARINDEX('' '', REVERSE(RTRIM(P.ANALISTA)) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(LTRIM(ISNULL(P.ANALISTA,'''')),2)) END AS IniAnalista,
                CASE WHEN P.CONSULTOR_ID IS NULL THEN ''''
                     ELSE REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(LTRIM(RTRIM(P.CONSULTOR_NOMBRE)),''''),''#''+CONVERT(VARCHAR(20),P.CONSULTOR_ID)),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') END AS EscConsultor,
                CASE WHEN CHARINDEX('' '', LTRIM(RTRIM(ISNULL(P.CONSULTOR_NOMBRE,'''')))) > 0
                     THEN UPPER(LEFT(LTRIM(P.CONSULTOR_NOMBRE),1) + LEFT(REVERSE(LEFT(REVERSE(RTRIM(P.CONSULTOR_NOMBRE)), CHARINDEX('' '', REVERSE(RTRIM(P.CONSULTOR_NOMBRE)) + '' '') - 1)),1))
                     ELSE UPPER(LEFT(LTRIM(ISNULL(NULLIF(P.CONSULTOR_NOMBRE,''''),''C'')),2)) END AS IniConsultor,
                CONVERT(VARCHAR(10), ISNULL(P.PORCENTAJE_AVANCE,0)) AS AvanceTxt,
                CONVERT(VARCHAR(10), CASE WHEN ISNULL(P.PORCENTAJE_AVANCE,0) < 0 THEN 0 WHEN ISNULL(P.PORCENTAJE_AVANCE,0) > 100 THEN 100 ELSE ISNULL(P.PORCENTAJE_AVANCE,0) END) AS AvanceBarTxt,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CONSULTORIA'') THEN 1 ELSE 0 END AS HasCo,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''AUDITORIA'') THEN 1 ELSE 0 END AS HasAu,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = ''CAPACITACION'') THEN 1 ELSE 0 END AS HasCa,
                REPLACE(REPLACE(@SRV_CO,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCo,
                REPLACE(REPLACE(@SRV_AU,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvAu,
                REPLACE(REPLACE(@SRV_CA,''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCa,
                ISNULL(REPLACE(REPLACE(REPLACE(STUFF((
                    SELECT '', '' + N.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), ''&'', ''&amp;''), ''"'', ''&quot;''), ''<'', ''&lt;''), '''') AS EscNormas,
                ISNULL((
                    SELECT TOP 2 ''<span class="vctdg-tag" title="'' + REPLACE(REPLACE(N.DESCRIPCION,''"'',''&quot;''),''<'',''&lt;'') + ''">''
                           + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</span>''
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
                    FROM #PACC A
                    WHERE A.ACTION_TYPE IN (''VIEW'',''EDIT'')
                    ORDER BY CASE A.ACTION_TYPE WHEN ''VIEW'' THEN 0 ELSE 1 END, A.SORT_ORDER, A.ID_PRM
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS MenuItems,
                P.FECHA_INICIO AS SortFecha,
                P.ID AS SortID
            FROM #PROYECTOS360 P
            ORDER BY CASE WHEN P.FECHA_INICIO IS NULL THEN 1 ELSE 0 END, P.FECHA_INICIO DESC, P.ID DESC
        ) X
        ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END, SortFecha DESC, SortID DESC
        FOR XML PATH(''''), TYPE
    ).value(''.'',''VARCHAR(MAX)''), '''');

    IF @HTML_PROYECTOS_TOP = ''''
        SET @HTML_PROYECTOS_TOP = ''<div class="vct-360-empty vct-360-fixed-empty">Este cliente no tiene proyectos asociados.</div>'';
    ELSE
        SET @HTML_PROYECTOS_TOP =
            ''<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap"><table class="vctdg-table is-fixed">'' +
                ''<colgroup><col><col style="width:10%"><col style="width:17%"><col style="width:14%"><col style="width:14%"><col style="width:11%"><col style="width:11%"><col style="width:44px"></colgroup>'' +
                ''<thead><tr><th>Proyecto</th><th class="vct-text-center">Servicios</th><th>Normas</th><th>Analista</th><th>Consultor</th><th class="vct-text-center">Estado</th><th>Avance</th><th class="vct-col-action"></th></tr></thead>'' +
                ''<tbody>'' + @HTML_PROYECTOS_TOP + ''</tbody>'' +
            ''</table></div></div>'';

    /* ============================================================
       8. HTML DOMICILIOS
       ============================================================ */
    
';

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CLIENTES');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @ini INT, @fin INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10),
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
            IF CHARINDEX(N'GRILLA_PROY_V2', @d) = 0
                PRINT @nom + ': falta la grilla nueva de la pestana (GRILLA_PROY_V2). Correr antes VCT_MAIN_CLIENTES_V360_GRILLA_PROYECTOS.sql.';
            ELSE
            BEGIN
                /* 2. Estado en la pestana Proyectos */
                IF CHARINDEX(N'THEN ''is-paused''', @d) = 0
                BEGIN
                    SET @d = REPLACE(@d, N'CASE WHEN P.ESTADO_CODIGO = ''ENCURSO'' THEN ''ACTIVO'' ELSE ISNULL(NULLIF(P.ESTADO,''''),''Sin estado'') END,',
                                         N'ISNULL(NULLIF(P.ESTADO,''''),''Sin estado''),');
                    SET @d = REPLACE(@d, N'WHEN P.ESTADO_CODIGO = ''CANCELADO'' THEN ''is-cancel''',
                                         N'WHEN P.ESTADO_CODIGO = ''CANCELADO'' THEN ''is-cancel'' WHEN P.ESTADO_CODIGO = ''PAUSADO'' THEN ''is-paused'' WHEN P.ESTADO_CODIGO = ''BORRADOR'' THEN ''is-draft''');
                END;

                /* 1. Ultimos proyectos */
                IF CHARINDEX(N'TOP_PROY_V2', @d) > 0
                    PRINT @nom + ': "Ultimos proyectos" ya estaba aplicado (TOP_PROY_V2).';
                ELSE
                BEGIN
                    SET @ini = CHARINDEX(N'SELECT @HTML_PROYECTOS_TOP = ISNULL((', @d);
                    SET @fin = CASE WHEN @ini > 0 THEN CHARINDEX(N'DECLARE @HTML_DOMICILIOS', @d, @ini) ELSE 0 END;
                    IF @ini = 0 OR @fin = 0 OR CHARINDEX(N'vct-360-project-table-recent', SUBSTRING(@d, @ini, @fin - @ini)) = 0
                        PRINT @nom + ': NO se encontro el bloque de "Ultimos proyectos"; no se modifico.';
                    ELSE
                        SET @d = STUFF(@d, @ini, @fin - @ini, @BLOQUE);
                END;
            END;
        END;

        /* 3. Version de los archivos de la grilla */
        SET @k = 1;
        WHILE @k <= 2
        BEGIN
            SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
            SET @nuevo = CASE @k WHEN 1 THEN N'10' ELSE N'7' END;
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
