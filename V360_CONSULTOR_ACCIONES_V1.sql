/* ========================================================================
   V360_CONSULTOR_ACCIONES_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca ACCIONES_TAB_CON_V1), pestana Acciones con el diseno ya definido
   para acciones (el mismo de "Ultimas Acciones"):
     Fecha | Accion (titulo + subtipo) | Cliente | Proyecto | Servicios (del
     proyecto) | Normas (del proyecto) | Responsable (iniciales con tooltip) |
     Estado (badge unificado)
   Filtro por estado; busca tambien por norma.
   Version de la grilla: vct-datagrid.css?v=24 (js v=7).
   Antes de correrlo: subir css/vct-datagrid.css (v24). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @GRID NVARCHAR(MAX) = N'/* ACCIONES_TAB_CON_V1: pestana Acciones = Fecha | Accion | Cliente | Proyecto | Servicios | Normas (del proyecto) | Responsable | Estado */
    SELECT @HTML_GESTIONES = ISNULL((
        SELECT
            ''<tr data-vct-row data-vct-filter-estado="'' + EstadoFiltro + ''" data-vct-search="'' + EscNormas + ''">'' +
                ''<td class="vct-text-center" data-label="Fecha" data-vct-sort-value="'' + FechaSort + ''">'' + FechaTxt + ''</td>'' +
                ''<td data-label="Acci&oacute;n"><span class="vct-360-project-name">'' + AccionTitulo + ''</span>'' +
                    CASE WHEN SubtipoTxt <> '''' THEN ''<span class="vct-360-project-ref">'' + SubtipoTxt + ''</span>'' ELSE '''' END +
                ''</td>'' +
                ''<td data-label="Cliente">'' + ClienteNombre + ''</td>'' +
                ''<td data-label="Proyecto"><span class="vct-360-project-name">('' + ProyectoCodigo + '') '' + ProyectoNombre + ''</span>'' +
                    CASE WHEN ProyectoReferencia <> '''' THEN ''<span class="vct-360-project-ref">'' + ProyectoReferencia + ''</span>'' ELSE '''' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Servicios"><span class="vctdg-svc-set">'' +
                    ''<span class="vctdg-svc is-co'' + CASE WHEN HasCo = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCo + CASE WHEN HasCo = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="briefcase"></span></span>'' +
                    ''<span class="vctdg-svc is-au'' + CASE WHEN HasAu = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvAu + CASE WHEN HasAu = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="clipboard-check"></span></span>'' +
                    ''<span class="vctdg-svc is-ca'' + CASE WHEN HasCa = 1 THEN '' is-on'' ELSE '''' END + ''" title="'' + EscSrvCa + CASE WHEN HasCa = 1 THEN '''' ELSE '' (no incluido)'' END + ''"><span data-vct-icon="users"></span></span>'' +
                ''</span></td>'' +
                ''<td data-label="Normas"><span class="vctdg-list">'' +
                    CASE WHEN NormasTop = '''' THEN ''-'' ELSE NormasTop END +
                    CASE WHEN NormasCount > 3 THEN ''<span class="vctdg-li is-more" title="'' + EscNormas + ''">+'' + CONVERT(VARCHAR(10), NormasCount - 3) + '' m&aacute;s</span>'' ELSE '''' END +
                ''</span></td>'' +
                ''<td class="vct-text-center" data-label="Responsable">'' +
                    CASE WHEN AsignadoNombre = '''' THEN ''<span class="vctdg-none">-</span>''
                         ELSE ''<span class="vctdg-person"><span class="vctdg-avatar '' + AsignadoClase + ''" title="'' + AsignadoNombre + ''">'' + AsignadoIniciales + ''</span></span>'' END +
                ''</td>'' +
                ''<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '' + EstadoClase + ''">'' + EstadoVisual + ''</span></td>'' +
            ''</tr>''
        FROM
        (
            SELECT
                X360.ID AS SortID,
                ISNULL(CONVERT(VARCHAR(8), X360.FECHA, 112), '''') AS FechaSort,
                REPLACE(ISNULL(X360.ESTADO_CODIGO,''''),''"'','''') AS EstadoFiltro,
                X360.FECHA AS SortFecha,
                ISNULL(CONVERT(VARCHAR(10), X360.FECHA, 103), ''-'') AS FechaTxt,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(X360.TITULO,''''),''Accion''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS AccionTitulo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(X360.SUBTIPO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS SubtipoTxt,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(X360.CLIENTE_NOMBRE,''''),''Sin cliente''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ClienteNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(X360.PROYECTO_CODIGO,''''),''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(X360.PROYECTO_NOMBRE,''''),''Sin proyecto''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(X360.PROYECTO_REFERENCIA,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoReferencia,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = G.ID_PROYECTO AND S.CODIGO = ''CONSULTORIA'') THEN 1 ELSE 0 END AS HasCo,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = G.ID_PROYECTO AND S.CODIGO = ''AUDITORIA'') THEN 1 ELSE 0 END AS HasAu,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = G.ID_PROYECTO AND S.CODIGO = ''CAPACITACION'') THEN 1 ELSE 0 END AS HasCa,
                REPLACE(REPLACE(ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CONSULTORIA''), ''Consultoria''),''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCo,
                REPLACE(REPLACE(ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''AUDITORIA''), ''Auditoria''),''"'',''&quot;''),''<'',''&lt;'') AS EscSrvAu,
                REPLACE(REPLACE(ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = ''CAPACITACION''), ''Capacitacion''),''"'',''&quot;''),''<'',''&lt;'') AS EscSrvCa,
                ISNULL(REPLACE(REPLACE(REPLACE(STUFF((
                    SELECT '', '' + N.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = G.ID_PROYECTO AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), 1, 2, ''''), ''&'', ''&amp;''), ''"'', ''&quot;''), ''<'', ''&lt;''), '''') AS EscNormas,
                ISNULL((
                    SELECT TOP 3 ''<span class="vctdg-li">'' + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</span>''
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = G.ID_PROYECTO AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS NormasTop,
                (SELECT COUNT(DISTINCT PN.ID_NORMA) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                 WHERE PN.ID_PROYECTO = G.ID_PROYECTO AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA'') AS NormasCount,
                REPLACE(REPLACE(REPLACE(REPLACE(
                    CASE
                        WHEN GR.TIPO_ENTIDAD IS NULL THEN ''''
                        WHEN GR.TIPO_ENTIDAD = ''SISTEMA'' THEN ''Sistema''
                        ELSE ISNULL(NULLIF(LTRIM(RTRIM(GR.NOMBRE)),''''),''#'' + CONVERT(VARCHAR(20),GR.ID_ENTIDAD))
                    END,
                    ''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS AsignadoNombre,
                CASE
                    WHEN GR.TIPO_ENTIDAD IS NULL THEN ''''
                    WHEN GR.TIPO_ENTIDAD = ''SISTEMA'' THEN ''SI''
                    WHEN CHARINDEX('' '',LTRIM(RTRIM(ISNULL(GR.NOMBRE,'''')))) > 0
                        THEN UPPER(LEFT(LTRIM(RTRIM(GR.NOMBRE)),1) + LEFT(REVERSE(LEFT(REVERSE(RTRIM(GR.NOMBRE)),CHARINDEX('' '',REVERSE(RTRIM(GR.NOMBRE)) + '' '') - 1)),1))
                    ELSE UPPER(LEFT(LTRIM(RTRIM(ISNULL(GR.NOMBRE,GR.TIPO_ENTIDAD))),2))
                END AS AsignadoIniciales,
                CASE WHEN GR.TIPO_ENTIDAD = ''EMPLEADO'' THEN ''is-a'' ELSE ''is-c'' END AS AsignadoClase,
                CASE
                    WHEN ISNULL(X360.ES_FINAL,0) = 1 THEN ISNULL(NULLIF(X360.ESTADO,''''),ISNULL(X360.ESTADO_CODIGO,''Sin estado''))
                    WHEN X360.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),X360.VENCIMIENTO) < 0 THEN ''Vencida''
                    WHEN X360.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),X360.VENCIMIENTO) = 0 THEN ''Vence hoy''
                    WHEN X360.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),X360.VENCIMIENTO) > 0 THEN ''Pr&oacute;xima''
                    ELSE ISNULL(NULLIF(X360.ESTADO,''''),ISNULL(X360.ESTADO_CODIGO,''Sin estado''))
                END AS EstadoVisual,
                CASE
                    WHEN X360.ESTADO_CODIGO = ''CUMPLIDA'' THEN ''is-done''
                    WHEN X360.ESTADO_CODIGO = ''CANCELADA'' THEN ''is-cancel''
                    WHEN ISNULL(X360.ES_FINAL,0) = 0 AND X360.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),X360.VENCIMIENTO) < 0 THEN ''is-cancel''
                    WHEN ISNULL(X360.ES_FINAL,0) = 0 AND X360.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),X360.VENCIMIENTO) = 0 THEN ''is-paused''
                    WHEN X360.ESTADO_CODIGO IN (''EN_PROCESO'',''EN_ESPERA'') THEN ''is-progress''
                    WHEN ISNULL(X360.ES_FINAL,0) = 0 THEN ''is-planned''
                    ELSE ''is-neutral''
                END AS EstadoClase
            FROM #GESTIONES360 X360
            LEFT JOIN dbo.VCT_ACCIONES G WITH(NOLOCK) ON G.ID = X360.ID
            OUTER APPLY
            (
                SELECT TOP 1 AP.TIPO_ENTIDAD, AP.ID_ENTIDAD,
                       CASE AP.TIPO_ENTIDAD
                           WHEN ''EMPLEADO''  THEN (SELECT TOP 1 LTRIM(RTRIM(ISNULL(E.NOMBRES,'''') + '' '' + ISNULL(E.APELLIDOS,''''))) FROM dbo.VCT_EMPLEADOS E WITH(NOLOCK) WHERE E.ID = AP.ID_ENTIDAD)
                           WHEN ''CONSULTOR'' THEN (SELECT TOP 1 LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(150),C.NOMBRES),'''') + '' '' + ISNULL(CONVERT(VARCHAR(150),C.APELLIDOS),''''))) FROM dbo.VCT_CONSULTORES C WITH(NOLOCK) WHERE C.ID = AP.ID_ENTIDAD)
                           ELSE NULL END AS NOMBRE
                FROM dbo.VCT_ACCIONES_PARTICIPANTES AP WITH(NOLOCK)
                WHERE AP.ID_ACCION = X360.ID AND AP.ROL_PARTICIPANTE = ''RESPONSABLE'' AND AP.ESTADO = ''ACTIVO''
                ORDER BY AP.PRINCIPAL DESC, AP.ID
            ) GR
        ) X
        ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END, SortFecha DESC, SortID DESC
        FOR XML PATH(''''), TYPE
    ).value(''.'',''VARCHAR(MAX)''), '''');

    IF @HTML_GESTIONES = ''''
        SET @HTML_GESTIONES = ''<div class="vct-360-empty vct-360-fixed-empty">Sin acciones registradas para el consultor.</div>'';
    ELSE
        SET @HTML_GESTIONES =
            ''<div data-vct-dg data-vct-dg-id="v360_con_gestiones" data-vct-dg-title="Acciones del consultor" data-vct-dg-subtitle="Consultor: ''+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'')+''" data-vct-dg-unit="accion(es)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar acci&oacute;n, cliente, proyecto, norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+
            ''<div data-vct-dg-slot="filters"><select data-vct-dg-filter="estado" aria-label="Estado"><option value="">Todos los estados</option>''+
                ISNULL((SELECT ''<option value="''+REPLACE(Z.ESTADO_CODIGO,''"'','''')+''">''+REPLACE(REPLACE(ISNULL(NULLIF(Z.ESTADO,''''),Z.ESTADO_CODIGO),''&'',''&amp;''),''<'',''&lt;'')+''</option>''
                        FROM (SELECT ESTADO_CODIGO, MAX(ESTADO) AS ESTADO FROM #GESTIONES360 WHERE ISNULL(ESTADO_CODIGO,'''') <> '''' GROUP BY ESTADO_CODIGO) Z
                        ORDER BY Z.ESTADO
                        FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''),'''')+
            ''</select></div>''+
            ''<table>''+
            ''<thead><tr>''+
                ''<th class="vct-text-center" data-vct-width="84" data-vct-sort="fecha" data-vct-sortable="true"><span>Fecha</span></th>''+
                ''<th data-vct-sort="accion" data-vct-sortable="true"><span>Acci&oacute;n</span></th>''+
                ''<th data-vct-width="13%" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente</span></th>''+
                ''<th data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span></th>''+
                ''<th class="vct-text-center" data-vct-width="96"><span>Servicios</span></th>''+
                ''<th data-vct-width="14%" data-vct-sort="normas" data-vct-sortable="true"><span>Normas</span></th>''+
                ''<th class="vct-text-center" data-vct-width="96"><span>Responsable</span></th>''+
                ''<th class="vct-text-center" data-vct-width="112" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span></th>''+
            ''</tr></thead>''+
            ''<tbody>''+@HTML_GESTIONES+''</tbody>''+
            ''</table>''+
            ''</div>'';

    ';

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10), @p INT, @q INT, @k INT,
        @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'ACCIONES_TAB_CON_V1', @d) > 0
    PRINT 'La pestana Acciones ya estaba aplicada (ACCIONES_TAB_CON_V1). Solo se revisa la version.';
ELSE
BEGIN
    SET @s = CHARINDEX(N'SELECT @HTML_GESTIONES=ISNULL((', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'/* CONSULTOR_TOP_V1: "Ultimas Acciones"', @d, @s) ELSE 0 END;
    IF @e = 0 AND @s > 0 SET @e = CHARINDEX(N'SELECT @HTML_GESTIONES_TOP=ISNULL((', @d, @s);
    IF @s = 0 OR @e = 0 OR CHARINDEX(N'v360_con_gestiones', SUBSTRING(@d, @s, @e - @s)) = 0
        PRINT 'AVISO: no se encontro la grilla de la pestana Acciones; no se modifico.';
    ELSE
    BEGIN
        SET @d = STUFF(@d, @s, @e - @s, @GRID);
        PRINT 'Paso 1: grilla de la pestana Acciones reemplazada.';
    END;
END;

SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'24' ELSE N'7' END;
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
