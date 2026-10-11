/* ========================================================================
   V360_CLIENTE_RESUMEN_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CLIENTES_V360
   (pestana Resumen):
   1) "Ultimas Gestiones" pasa a "Ultimas acciones" (marca ACCIONES_TOP_V1):
      Fecha | Accion | Proyecto | Servicio | Norma | Asignado | Estado,
      con el mismo diseno de grilla (servicio con su icono, norma en lista,
      asignado con iniciales y tooltip, estado con el badge unificado).
   2) Textos: Gestiones -> Acciones (grafico intermedio, total, encabezado).
   3) Grafico "Proyectos por estado" con la paleta institucional.
      (barra de acciones y rentabilidad toman colores desde el css v14)
   4) Version de la grilla: vct-datagrid.css?v=14 (js v=7).
   El servicio y la norma de cada accion salen de las columnas que tenga
   VCT_ACCIONES (ID_PROYECTO_SERVICIO / ID_SERVICIO y ID_PROYECTO_NORMA /
   ID_NORMA); si no existen, la columna muestra "-" y se avisa.
   Antes de correrlo: subir css/vct-datagrid.css (v14). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @ACC NVARCHAR(MAX) = N'SELECT @HTML_GESTIONES_TOP=ISNULL((
            /* ACCIONES_TOP_V1: Fecha | Accion | Proyecto | Servicio | Norma | Asignado | Estado (ultimas 5, proyectos activos) */
            SELECT
                ''<tr data-vct-row>'' +
                    ''<td class="vct-text-center" data-label="Fecha">'' + FechaTxt + ''</td>'' +
                    ''<td data-label="Acci&oacute;n"><span class="vct-360-project-name">'' + AccionTitulo + ''</span>'' +
                        CASE WHEN SubtipoTxt <> '''' THEN ''<span class="vct-360-project-ref">'' + SubtipoTxt + ''</span>'' ELSE '''' END +
                    ''</td>'' +
                    ''<td data-label="Proyecto"><span class="vct-360-project-name">('' + ProyectoCodigo + '') '' + ProyectoNombre + ''</span>'' +
                        CASE WHEN ProyectoReferencia <> '''' THEN ''<span class="vct-360-project-ref">'' + ProyectoReferencia + ''</span>'' ELSE '''' END +
                    ''</td>'' +
                    ''<td class="vct-text-center" data-label="Servicio">'' +
                        CASE ServicioCod
                            WHEN ''CONSULTORIA''  THEN ''<span class="vctdg-svc-set"><span class="vctdg-svc is-co is-on" title="'' + ServicioDesc + ''"><span data-vct-icon="briefcase"></span></span></span>''
                            WHEN ''AUDITORIA''    THEN ''<span class="vctdg-svc-set"><span class="vctdg-svc is-au is-on" title="'' + ServicioDesc + ''"><span data-vct-icon="clipboard-check"></span></span></span>''
                            WHEN ''CAPACITACION'' THEN ''<span class="vctdg-svc-set"><span class="vctdg-svc is-ca is-on" title="'' + ServicioDesc + ''"><span data-vct-icon="users"></span></span></span>''
                            ELSE ''<span class="vctdg-none">-</span>'' END +
                    ''</td>'' +
                    ''<td data-label="Norma">'' +
                        CASE WHEN NormaTxt = '''' THEN ''<span class="vctdg-none">-</span>''
                             ELSE ''<span class="vctdg-list"><span class="vctdg-li">'' + NormaTxt + ''</span></span>'' END +
                    ''</td>'' +
                    ''<td class="vct-text-center" data-label="Asignado">'' +
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
                    ISNULL({SRV_COD},'''') AS ServicioCod,
                    REPLACE(REPLACE(ISNULL({SRV_DESC},''''),''"'',''&quot;''),''<'',''&lt;'') AS ServicioDesc,
                    REPLACE(REPLACE(REPLACE(ISNULL({NORMA},''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') AS NormaTxt,
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
            ''<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap"><table class="vctdg-table is-fixed">'' +
                ''<colgroup><col style="width:84px"><col><col style="width:26%"><col style="width:72px"><col style="width:15%"><col style="width:76px"><col style="width:112px"></colgroup>'' +
                ''<thead><tr><th class="vct-text-center">Fecha</th><th>Acci&oacute;n</th><th>Proyecto</th><th class="vct-text-center">Servicio</th><th>Norma</th><th class="vct-text-center">Asignado</th><th class="vct-text-center">Estado</th></tr></thead>'' +
                ''<tbody>'' + @HTML_GESTIONES_TOP + ''</tbody>'' +
            ''</table></div></div>'';

    
';

/* ---- servicio y norma de la accion segun las columnas existentes ---- */
DECLARE @SRV_COD NVARCHAR(600) = N'NULL', @SRV_DESC NVARCHAR(600) = N'NULL', @NORMA NVARCHAR(600) = N'NULL';
IF COL_LENGTH('dbo.VCT_ACCIONES','ID_PROYECTO_SERVICIO') IS NOT NULL
BEGIN
    SET @SRV_COD  = N'(SELECT TOP 1 S.CODIGO FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID = G.ID_PROYECTO_SERVICIO)';
    SET @SRV_DESC = N'(SELECT TOP 1 S.DESCRIPCION FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID = G.ID_PROYECTO_SERVICIO)';
    PRINT 'Servicio de la accion: VCT_ACCIONES.ID_PROYECTO_SERVICIO';
END
ELSE IF COL_LENGTH('dbo.VCT_ACCIONES','ID_SERVICIO') IS NOT NULL
BEGIN
    SET @SRV_COD  = N'(SELECT TOP 1 S.CODIGO FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) WHERE S.ID = G.ID_SERVICIO)';
    SET @SRV_DESC = N'(SELECT TOP 1 S.DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) WHERE S.ID = G.ID_SERVICIO)';
    PRINT 'Servicio de la accion: VCT_ACCIONES.ID_SERVICIO';
END
ELSE
    PRINT 'AVISO: VCT_ACCIONES no tiene columna de servicio (ID_PROYECTO_SERVICIO / ID_SERVICIO): la columna Servicio muestra "-".';

IF COL_LENGTH('dbo.VCT_ACCIONES','ID_PROYECTO_NORMA') IS NOT NULL
BEGIN
    SET @NORMA = N'(SELECT TOP 1 N.DESCRIPCION FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA WHERE PN.ID = G.ID_PROYECTO_NORMA)';
    PRINT 'Norma de la accion: VCT_ACCIONES.ID_PROYECTO_NORMA';
END
ELSE IF COL_LENGTH('dbo.VCT_ACCIONES','ID_NORMA') IS NOT NULL
BEGIN
    SET @NORMA = N'(SELECT TOP 1 N.DESCRIPCION FROM dbo.VCT_PRM_NORMAS N WITH(NOLOCK) WHERE N.ID = G.ID_NORMA)';
    PRINT 'Norma de la accion: VCT_ACCIONES.ID_NORMA';
END
ELSE
    PRINT 'AVISO: VCT_ACCIONES no tiene columna de norma (ID_PROYECTO_NORMA / ID_NORMA): la columna Norma muestra "-".';

SET @ACC = REPLACE(REPLACE(REPLACE(@ACC, N'{SRV_COD}', @SRV_COD), N'{SRV_DESC}', @SRV_DESC), N'{NORMA}', @NORMA);

DECLARE @R TABLE (ORD INT, VIEJO NVARCHAR(400), NUEVO NVARCHAR(400));
INSERT INTO @R VALUES
 (1, N'Gestiones de proyectos activos</h3>', N'Acciones de proyectos activos</h3>'),
 (2, N'de las gestiones vinculadas a proyectos activos.', N'de las acciones vinculadas a proyectos activos.'),
 (3, N'ltimas Gestiones</h3>', N'ltimas acciones</h3>'),
 (4, N'<span>Total de gestiones</span>', N'<span>Total de acciones</span>'),
 (5, N'No hay gestiones asociadas a proyectos activos.', N'No hay acciones asociadas a proyectos activos.'),
 (6, N'ltima Gesti', N'ltima Acci'),
 (7, N'#10b981', N'#8C1D47'),
 (8, N'#f59e0b', N'#CF6F92'),
 (9, N'#94a3b8', N'#8E8C8D'),
 (10, N'#e2e8f0 ''', N'#E2E1E1 ''');

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CLIENTES_V360')), @orig NVARCHAR(MAX),
        @s1 INT, @e1 INT, @s2 INT, @p13 INT, @e2 INT, @marca NVARCHAR(40), @nuevo NVARCHAR(10), @p INT, @q INT, @k INT,
        @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000), @rv NVARCHAR(400), @rn NVARCHAR(400), @ro INT;

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CLIENTES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. Ultimas acciones */
IF CHARINDEX(N'ACCIONES_TOP_V1', @d) > 0
    PRINT '"Ultimas acciones" ya estaba aplicado (ACCIONES_TOP_V1).';
ELSE
BEGIN
    SET @s1 = CHARINDEX(N'SELECT @HTML_GESTIONES_TOP=ISNULL((', @d);
    SET @e1 = CASE WHEN @s1 > 0 THEN CHARINDEX(N'END TRY', @d, @s1) ELSE 0 END;
    IF @s1 = 0 OR @e1 = 0 OR CHARINDEX(N'vct-360-management-type-icon', SUBSTRING(@d, @s1, @e1 - @s1)) = 0
        PRINT 'AVISO: no se encontro el bloque de "Ultimas Gestiones" (consulta); no se modifico.';
    ELSE
    BEGIN
        SET @d = STUFF(@d, @s1, @e1 - @s1, @ACC);
        SET @s2 = CHARINDEX(N'IF @HTML_GESTIONES_TOP=''''', @d, @s1);
        SET @p13 = CASE WHEN @s2 > 0 THEN CHARINDEX(N'13. GRAFICOS / RESUMENES', @d, @s2) ELSE 0 END;
        SET @e2 = CASE WHEN @p13 > 0 THEN (@p13 - 1) - CHARINDEX(N'*/', REVERSE(LEFT(@d, @p13 - 1))) ELSE 0 END;
        IF @s2 = 0 OR @e2 <= @s2 OR CHARINDEX(N'vct-360-management-table-recent', SUBSTRING(@d, @s2, @e2 - @s2)) = 0
        BEGIN
            PRINT 'AVISO: no se encontro el armado de la tabla de "Ultimas Gestiones"; no se modifico nada.';
            SET @d = @orig;
        END
        ELSE
            SET @d = STUFF(@d, @s2, @e2 - @s2, @WRAP);
    END;
END;

/* 2 y 3. textos y colores */
DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R ORDER BY ORD;
OPEN crp;
FETCH NEXT FROM crp INTO @ro, @rv, @rn;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @d = REPLACE(@d, @rv, @rn);
    FETCH NEXT FROM crp INTO @ro, @rv, @rn;
END;
CLOSE crp;
DEALLOCATE crp;

/* 4. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'14' ELSE N'7' END;
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
