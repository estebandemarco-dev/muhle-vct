/* ========================================================================
   V360_PROVEEDOR_ESTANDAR_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_PROVEEDORES_V360
   (marca PROV360_V1) con los criterios del resto de las Vista 360:
   1) KPIs: se quitan los colores fijos (ambar) de Proyectos y Viaticos; los 5
      KPIs toman la paleta institucional por posicion (css).
   2) Resumen: "Proyectos recientes con viaticos" y "Consultores con viaticos"
      pasan a tabla estatica estandar (.vctdg-static): tipografia 10px,
      encabezados 10,5px, badges unificados con la descripcion del estado,
      nombres sin negrita, subtitulos de tarjeta estandar.
   3) Graficos: "Viaticos por tipo de servicio" con la paleta institucional
      (bordo medio, grafito, bordo claro, gris medio para Otros) y leyenda
      estandar. "Viaticos por mes": barras en bordo medio (css v27).
   4) Version: vct-datagrid.css?v=27 y vct-datagrid.js?v=9 (pestana Viaticos
      con toolbar, filtros, paginado y tipografia estandar).
   Antes de correrlo: subir css/vct-datagrid.css (v27). Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_PROVEEDORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @seg NVARCHAR(MAX), @p INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0,
        @trg_on BIT = 0, @msg NVARCHAR(2000), @marca NVARCHAR(40), @nuevo NVARCHAR(10),
        @ro INT, @rv NVARCHAR(1000), @rn NVARCHAR(1000), @cnt INT = 0;

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_PROVEEDORES_V360.', 16, 1); RETURN; END;
SET @orig = @d;

IF CHARINDEX(N'PROV360_V1', @d) > 0
    PRINT 'Ya estaba aplicado (PROV360_V1). Solo se revisa la version.';
ELSE
BEGIN
    /* marca */
    SET @s = CHARINDEX(N'SET @OUTPARAM2=', @d);
    IF @s > 0 SET @d = STUFF(@d, @s, 0, N'/* PROV360_V1: Resumen, KPIs y graficos con el estandar 360 */' + NCHAR(13) + NCHAR(10) + N'    ');

    /* 1-3. reemplazos puntuales */
    DECLARE @R TABLE (ORD INT, VIEJO NVARCHAR(1000), NUEVO NVARCHAR(1000));
    INSERT INTO @R VALUES
    (1, N'<div class="vct-360-stat" style="--vct-kpi-accent:#A85E08;--vct-kpi-bg:#FFF9F1;--vct-kpi-icon-bg:#F8E8D1;--vct-kpi-icon:#8A4B05;">', N'<div class="vct-360-stat">'),
    (2, N'<div class="vct-360-stat" style="--vct-kpi-accent:#B56E18;--vct-kpi-bg:#FFFAF3;--vct-kpi-icon-bg:#F8EBD8;--vct-kpi-icon:#9B5D12;">', N'<div class="vct-360-stat">'),
    (3, N'<div class="vct-360-grid-fixed vct-360-grid-five vct-360-projects-recent" style="overflow:hidden;">', N'<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap">'),
    (4, N'<table class="vct-360-table vct-360-project-table vct-360-project-table-recent" style="width:100%;table-layout:fixed;">', N'<table class="vctdg-table"><colgroup><col><col style="width:112px"><col style="width:90px"><col style="width:90px"><col style="width:120px"></colgroup>'),
    (5, N'<div class="vct-table-wrap" style="overflow-x:hidden;">', N'<div class="vctdg vctdg-static is-compact"><div class="vctdg-wrap">'),
    (6, N'<table class="vct-table vct-360-table" style="width:100%;table-layout:fixed;">', N'<table class="vctdg-table"><colgroup><col><col style="width:84px"><col style="width:120px"></colgroup>'),
    (7, N'<div style="margin-top:3px;color:#8793a5;font-size:9px;">', N'<div class="vct-360-box-subtitle">'),
    (8, N'WHEN 1 THEN ''#8A003B''', N'WHEN 1 THEN ''#8C1D47'''),
    (9, N'WHEN 2 THEN ''#C77B9D''', N'WHEN 2 THEN ''#4A4849'''),
    (10, N'ELSE ''#D1A15D''', N'ELSE ''#CF6F92'''),
    (11, N'''#94A3B8''', N'''#8E8C8D'''),
    (12, N'<div class="vct-360-donut-legend-lg" style="min-width:200px;">', N'<div class="vct-360-donut-legend vct-360-donut-legend-lg" style="min-width:200px;">');
    DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, VIEJO, NUEVO FROM @R ORDER BY ORD;
    OPEN crp;
    FETCH NEXT FROM crp INTO @ro, @rv, @rn;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF CHARINDEX(@rv, @d) > 0 BEGIN SET @d = REPLACE(@d, @rv, @rn); SET @cnt = @cnt + 1; END
        ELSE PRINT 'AVISO: no se encontro el cambio ' + CONVERT(VARCHAR(5), @ro) + ' (se saltea).';
        FETCH NEXT FROM crp INTO @ro, @rv, @rn;
    END;
    CLOSE crp;
    DEALLOCATE crp;

    /* las dos tablas del Resumen ahora tienen 2 contenedores: cerrar el segundo */
    SET @s = CHARINDEX(N'ISNULL(@HTML_VIAT_PROJECTS,'''')+''</tbody>', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</table>', @d, @s) ELSE 0 END;
    IF @e > 0 SET @d = STUFF(@d, @e + LEN(N'</table>'), 0, N'</div>');
    SET @s = CHARINDEX(N'ISNULL(@HTML_VIAT_CONS,'''')+''</tbody>', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</table>', @d, @s) ELSE 0 END;
    IF @e > 0 SET @d = STUFF(@d, @e + LEN(N'</table>'), 0, N'</div>');

    /* estado de proyecto con su descripcion (badge unificado) */
    SET @s = CHARINDEX(N'SELECT @HTML_VIAT_PROJECTS=ISNULL((', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'FROM #V360_VIAT_PROJECTS', @d, @s) ELSE 0 END;
    IF @s > 0 AND @e > 0
    BEGIN
        SET @seg = SUBSTRING(@d, @s, @e - @s);
        SET @seg = REPLACE(@seg, N'THEN ''EN CURSO''', N'THEN ISNULL(NULLIF(P.ESTADO,''''),''En curso'')');
        SET @seg = REPLACE(@seg, N'THEN ''HISTORICO''', N'THEN ''Hist&oacute;rico''');
        SET @seg = REPLACE(@seg, N'''SIN ESTADO''', N'''Sin estado''');
        SET @seg = REPLACE(@seg, N'WHEN P.ESTADO_CODIGO IN (''BORRADOR'',''CONFIRMADO'',''PAUSADO'') THEN ''is-planned''',
                                 N'WHEN P.ESTADO_CODIGO=''CONFIRMADO'' THEN ''is-planned'' WHEN P.ESTADO_CODIGO=''PAUSADO'' THEN ''is-paused'' WHEN P.ESTADO_CODIGO=''BORRADOR'' THEN ''is-draft''');
        SET @d = STUFF(@d, @s, @e - @s, @seg);
    END;

    /* consultor sin negrita */
    SET @s = CHARINDEX(N'SELECT @HTML_VIAT_CONS=ISNULL((', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'FROM #V360_VIAT_CONS', @d, @s) ELSE 0 END;
    IF @s > 0 AND @e > 0
    BEGIN
        SET @seg = SUBSTRING(@d, @s, @e - @s);
        SET @seg = REPLACE(REPLACE(@seg, N'''<strong>''+', N'''<span class="vct-360-project-name" style="font-weight:400 !important;">''+'), N'''</strong>''+', N'''</span>''+');
        SET @d = STUFF(@d, @s, @e - @s, @seg);
    END;
    PRINT 'Pasos 1 a 3: ' + CONVERT(VARCHAR(5), @cnt) + ' cambios de KPIs, tablas y graficos.';
END;

/* 4. version */
SET @k = 1;
WHILE @k <= 2
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' ELSE N'vct-datagrid.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'27' ELSE N'9' END;
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
PRINT 'Paso 4: version css 27 / js 9.';

IF @d = @orig BEGIN PRINT 'VCT_MAIN_PROVEEDORES_V360: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_PROVEEDORES_V360 actualizado (estandar 360).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_PROVEEDORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
