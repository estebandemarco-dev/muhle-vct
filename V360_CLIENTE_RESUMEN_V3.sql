/* ========================================================================
   V360_CLIENTE_RESUMEN_V3
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CLIENTES_V360:
   1) "Ultimas Acciones" (marca ACCIONES_TOP_V2): Servicios y Normas del
      PROYECTO de cada accion (igual que Ultimos proyectos), columna
      "Responsable" centrada con iniciales y tooltip, columnas flexibles.
   2) "Ultimos proyectos": columnas flexibles segun el contenido.
   3) Titulo "Ultimas Acciones".
   4) Version de la grilla: vct-datagrid.css?v=16 (js v=7). El css v16
      devuelve los colores originales a la barra de acciones, centra las
      iniciales y pone la rentabilidad con la paleta institucional.
   Antes de correrlo: subir css/vct-datagrid.css (v16). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @ACC NVARCHAR(MAX) = N'SELECT @HTML_GESTIONES_TOP=ISNULL((
            /* ACCIONES_TOP_V2: Fecha | Accion | Proyecto | Servicios | Normas (del proyecto) | Responsable | Estado (ultimas 5, proyectos activos) */
            SELECT
                ''<tr data-vct-row>'' +
                    ''<td class="vct-text-center" data-label="Fecha">'' + FechaTxt + ''</td>'' +
                    ''<td data-label="Acci&oacute;n"><span class="vct-360-project-name">'' + AccionTitulo + ''</span>'' +
                        CASE WHEN SubtipoTxt <> '''' THEN ''<span class="vct-360-project-ref">'' + SubtipoTxt + ''</span>'' ELSE '''' END +
                    ''</td>'' +
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
                SELECT TOP 5
                    G.ID AS SortID,
                    ISNULL(G.FECHA_CIERRE,ISNULL(G.FECHA_INICIO,G.FECHA_CREACION)) AS SortFecha,
                    ISNULL(CONVERT(VARCHAR(10),ISNULL(G.FECHA_CIERRE,ISNULL(G.FECHA_INICIO,G.FECHA_CREACION)),103),''-'') AS FechaTxt,
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.TITULO,''''),''Accion''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS AccionTitulo,
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(ST.DESCRIPCION,ISNULL(ST.CODIGO,'''')),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS SubtipoTxt,
                    REPLACE(REPLACE(REPLACE(REPLACE(CASE WHEN P.CODIGO IS NULL THEN ''-'' ELSE CONVERT(VARCHAR(100),P.CODIGO) END,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoCodigo,
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.NOMBRE,''''),''Sin proyecto''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoNombre,
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.REFERENCIA,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS ProyectoReferencia,
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
                        SELECT TOP 3 ''<span class="vctdg-li">'' + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') + ''</span>''
                        FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                        INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                        WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA''
                        GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                        FOR XML PATH(''''), TYPE).value(''.'',''VARCHAR(MAX)''), '''') AS NormasTop,
                    (SELECT COUNT(DISTINCT PN.ID_NORMA) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                     WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,''ACTIVA'') <> ''INACTIVA'') AS NormasCount,
                    REPLACE(REPLACE(REPLACE(REPLACE(
                        CASE
                            WHEN GR.TIPO_ENTIDAD IS NULL THEN ''''
                            WHEN GR.TIPO_ENTIDAD=''SISTEMA'' THEN ''Sistema''
                            ELSE ISNULL(NULLIF(LTRIM(RTRIM(GR.NOMBRE)),''''),''#''+CONVERT(VARCHAR(20),GR.ID_ENTIDAD))
                        END,
                        ''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'') AS AsignadoNombre,
                    CASE
                        WHEN GR.TIPO_ENTIDAD IS NULL THEN ''''
                        WHEN GR.TIPO_ENTIDAD=''SISTEMA'' THEN ''SI''
                        WHEN CHARINDEX('' '',LTRIM(RTRIM(ISNULL(GR.NOMBRE,''''))))>0
                            THEN UPPER(LEFT(LTRIM(RTRIM(GR.NOMBRE)),1)+LEFT(REVERSE(LEFT(REVERSE(RTRIM(GR.NOMBRE)),CHARINDEX('' '',REVERSE(RTRIM(GR.NOMBRE))+'' '')-1)),1))
                        ELSE UPPER(LEFT(LTRIM(RTRIM(ISNULL(GR.NOMBRE,GR.TIPO_ENTIDAD))),2))
                    END AS AsignadoIniciales,
                    CASE WHEN GR.TIPO_ENTIDAD=''EMPLEADO'' THEN ''is-a'' ELSE ''is-c'' END AS AsignadoClase,
                    CASE
                        WHEN GE.ES_FINAL=1 THEN ISNULL(GE.DESCRIPCION,GE.CODIGO)
                        WHEN G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)<0 THEN ''Vencida''
                        WHEN G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)=0 THEN ''Vence hoy''
                        WHEN G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)>0 THEN ''Pr&oacute;xima''
                        ELSE ISNULL(GE.DESCRIPCION,ISNULL(GE.CODIGO,''Sin estado''))
                    END AS EstadoVisual,
                    CASE
                        WHEN GE.CODIGO=''CUMPLIDA'' THEN ''is-done''
                        WHEN GE.CODIGO=''CANCELADA'' THEN ''is-cancel''
                        WHEN ISNULL(GE.ES_FINAL,0)=0 AND G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)<0 THEN ''is-cancel''
                        WHEN ISNULL(GE.ES_FINAL,0)=0 AND G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)=0 THEN ''is-paused''
                        WHEN GE.CODIGO IN (''EN_PROCESO'',''EN_ESPERA'') THEN ''is-progress''
                        WHEN ISNULL(GE.ES_FINAL,0)=0 THEN ''is-planned''
                        ELSE ''is-neutral''
                    END AS EstadoClase
                FROM dbo.VCT_ACCIONES G WITH(NOLOCK)
                INNER JOIN dbo.VCT_PROYECTOS P WITH(NOLOCK)
                    ON P.ID=G.ID_PROYECTO
                LEFT JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS PE WITH(NOLOCK)
                    ON PE.ID=P.ID_ESTADO
                LEFT JOIN dbo.VCT_PRM_ACCIONES_SUBTIPOS ST WITH(NOLOCK)
                    ON ST.ID=G.ID_SUBTIPO
                LEFT JOIN dbo.VCT_PRM_ACCIONES_ESTADOS GE WITH(NOLOCK)
                    ON GE.ID=G.ID_ESTADO
                OUTER APPLY
                (
                    SELECT TOP 1 AP.TIPO_ENTIDAD, AP.ID_ENTIDAD,
                           CASE AP.TIPO_ENTIDAD
                               WHEN ''EMPLEADO''  THEN (SELECT TOP 1 LTRIM(RTRIM(ISNULL(E.NOMBRES,'''')+'' ''+ISNULL(E.APELLIDOS,''''))) FROM dbo.VCT_EMPLEADOS E WITH(NOLOCK) WHERE E.ID=AP.ID_ENTIDAD)
                               WHEN ''CONSULTOR'' THEN (SELECT TOP 1 LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(150),C.NOMBRES),'''')+'' ''+ISNULL(CONVERT(VARCHAR(150),C.APELLIDOS),''''))) FROM dbo.VCT_CONSULTORES C WITH(NOLOCK) WHERE C.ID=AP.ID_ENTIDAD)
                               ELSE NULL END AS NOMBRE
                    FROM dbo.VCT_ACCIONES_PARTICIPANTES AP WITH(NOLOCK)
                    WHERE AP.ID_ACCION=G.ID AND AP.ROL_PARTICIPANTE=''RESPONSABLE'' AND AP.ESTADO=''ACTIVO''
                    ORDER BY AP.PRINCIPAL DESC, AP.ID
                ) GR
                WHERE ISNULL(G.ID_CLIENTE,P.IDCLIENTE)=@ID_CLIENTE
                  AND PE.CODIGO IN (''ENCURSO'',''CONFIRMADO'',''PAUSADO'')
                ORDER BY
                    CASE WHEN ISNULL(G.FECHA_CIERRE,ISNULL(G.FECHA_INICIO,G.FECHA_CREACION)) IS NULL THEN 1 ELSE 0 END,
                    ISNULL(G.FECHA_CIERRE,ISNULL(G.FECHA_INICIO,G.FECHA_CREACION)) DESC,
                    G.ID DESC
            ) X
            ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END, SortFecha DESC, SortID DESC
            FOR XML PATH(''''),TYPE
        ).value(''.'',''VARCHAR(MAX)''),'''');

    
',
        @WRAP NVARCHAR(MAX) = N'IF @HTML_GESTIONES_TOP=''''
        SET @HTML_GESTIONES_TOP=
            ''<div class="vct-360-empty vct-360-fixed-empty">Sin acciones recientes en proyectos activos.</div>'';
    ELSE
        SET @HTML_GESTIONES_TOP=
            ''<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap"><table class="vctdg-table">'' +
                ''<colgroup><col style="width:80px"><col><col><col style="width:96px"><col style="width:150px"><col style="width:96px"><col style="width:112px"></colgroup>'' +
                ''<thead><tr><th class="vct-text-center">Fecha</th><th>Acci&oacute;n</th><th>Proyecto</th><th class="vct-text-center">Servicios</th><th>Normas</th><th class="vct-text-center">Responsable</th><th class="vct-text-center">Estado</th></tr></thead>'' +
                ''<tbody>'' + @HTML_GESTIONES_TOP + ''</tbody>'' +
            ''</table></div></div>'';

    
';

DECLARE @R TABLE (ORD INT, VIEJO NVARCHAR(600), NUEVO NVARCHAR(600));
INSERT INTO @R VALUES
 (1, N'<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap"><table class="vctdg-table is-fixed">', N'<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap"><table class="vctdg-table">'),
 (2, N'<colgroup><col><col style="width:96px"><col style="width:22%"><col style="width:76px"><col style="width:80px"><col style="width:112px"><col style="width:14%"><col style="width:44px"></colgroup>', N'<colgroup><col><col style="width:96px"><col><col style="width:80px"><col style="width:80px"><col style="width:112px"><col style="width:150px"><col style="width:44px"></colgroup>'),
 (3, N'ltimas acciones</h3>', N'ltimas Acciones</h3>'),
 (4, N'ltimas Gestiones</h3>', N'ltimas Acciones</h3>');

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CLIENTES_V360')), @orig NVARCHAR(MAX),
        @s1 INT, @e1 INT, @s2 INT, @p13 INT, @e2 INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10), @p INT, @q INT, @k INT,
        @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000), @rv NVARCHAR(600), @rn NVARCHAR(600), @ro INT;

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CLIENTES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. Ultimas acciones */
IF CHARINDEX(N'ACCIONES_TOP_V2', @d) > 0
    PRINT 'Paso 1: "Ultimas Acciones" ya estaba en la version nueva (ACCIONES_TOP_V2).';
ELSE
BEGIN
    SET @s1 = CHARINDEX(N'SELECT @HTML_GESTIONES_TOP=ISNULL((', @d);
    SET @e1 = CASE WHEN @s1 > 0 THEN CHARINDEX(N'END TRY', @d, @s1) ELSE 0 END;
    IF @s1 = 0 OR @e1 = 0
        PRINT 'AVISO: no se encontro la consulta de "Ultimas acciones"; no se modifico.';
    ELSE
    BEGIN
        SET @d = STUFF(@d, @s1, @e1 - @s1, @ACC);
        PRINT 'Paso 1a: consulta de Ultimas Acciones reemplazada.';
        SET @s2 = CHARINDEX(N'IF @HTML_GESTIONES_TOP=''''', @d, @s1);
        SET @p13 = CASE WHEN @s2 > 0 THEN CHARINDEX(N'13. GRAFICOS / RESUMENES', @d, @s2) ELSE 0 END;
        SET @e2 = CASE WHEN @p13 > 0 THEN (@p13 - 1) - CHARINDEX(N'*/', REVERSE(LEFT(@d, @p13 - 1))) ELSE 0 END;
        IF @s2 = 0 OR @e2 <= @s2 OR CHARINDEX(N'SET @HTML_GESTIONES_TOP=', SUBSTRING(@d, @s2, @e2 - @s2)) = 0
        BEGIN
            PRINT 'AVISO: no se encontro el armado de la tabla de "Ultimas acciones"; no se modifico nada.';
            SET @d = @orig;
        END
        ELSE
        BEGIN
            SET @d = STUFF(@d, @s2, @e2 - @s2, @WRAP);
            PRINT 'Paso 1b: tabla de Ultimas Acciones reemplazada.';
        END;
    END;
END;

/* 2 y 3. Ultimos proyectos flexibles + titulo */
DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R ORDER BY ORD;
OPEN crp;
FETCH NEXT FROM crp INTO @ro, @rv, @rn;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF CHARINDEX(@rv, @d) > 0 BEGIN SET @d = REPLACE(@d, @rv, @rn); PRINT 'Paso 2/3: cambio ' + CONVERT(VARCHAR(5), @ro) + ' aplicado.'; END;
    FETCH NEXT FROM crp INTO @ro, @rv, @rn;
END;
CLOSE crp;
DEALLOCATE crp;

/* 4. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'16' ELSE N'7' END;
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

IF @d = @orig BEGIN PRINT 'VCT_MAIN_CLIENTES_V360: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_CLIENTES_V360 actualizado.';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CLIENTES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    RAISERROR('%s', 16, 1, @msg);
END CATCH;
GO
