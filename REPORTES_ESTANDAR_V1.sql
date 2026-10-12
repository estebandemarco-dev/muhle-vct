/* ========================================================================
   REPORTES_ESTANDAR_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_REPORTES (lee su
   definicion actual de la base y aplica cambios por anclas):
   1) Grillas "opcion A": en cada reporte se marcan en el encabezado
        data-vct-detail  -> columna de texto largo/secundaria: no se muestra en
                            la grilla, se ve al abrir la flecha de la fila;
        data-vct-sub-of  -> Proyecto / Descripcion como 2do renglon de Cliente;
        data-vct-person  -> Consultor / Huesped / Pasajero con avatar + nombre;
        data-vct-svc     -> Servicio con icono + nombre.
      Excel y PDF siguen exportando TODAS las columnas.
   2) Pestanas: chevron de categoria igual al de Agenda (SVG propio).
   3) Version: vct-datagrid.css 28, vct-datagrid.js 10, vct-reportes.css 28,
      vct-reportes.js 15.
   Antes de correrlo: subir css/vct-datagrid.css, css/vct-reportes.css,
   js/vct-datagrid.js y js/vct-reportes.js. Re-ejecutable (lo ya aplicado se
   saltea).
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_REPORTES')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @p INT, @t INT, @q INT, @k INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0,
        @trg_on BIT = 0, @msg NVARCHAR(2000), @marca NVARCHAR(60), @nuevo NVARCHAR(10),
        @ro INT, @rm NVARCHAR(200), @ra NVARCHAR(400), @rt NVARCHAR(200), @attr NVARCHAR(60),
        @cnt INT = 0, @ya INT = 0;

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_REPORTES.', 16, 1); RETURN; END;
SET @orig = @d;

/* 1. atributos en los encabezados, solo dentro del <thead> de cada reporte */
DECLARE @R TABLE (ORD INT, MARCA NVARCHAR(200), ANCLA NVARCHAR(400), ATTR NVARCHAR(200));
INSERT INTO @R VALUES
    (1, N'data-vct-dg-id="reportes-parte-actividades"', N'data-vct-sort="descripcion"', N'data-vct-sub-of="Cliente" '),
    (2, N'data-vct-dg-id="reportes-parte-actividades"', N'data-vct-sort="servicio"', N'data-vct-svc="1" '),
    (3, N'data-vct-dg-id="reportes-parte-actividades"', N'data-vct-sort="consultor"', N'data-vct-person="1" '),
    (4, N'data-vct-dg-id="reportes-parte-actividades"', N'>Observaciones</th>', N'data-vct-detail="1" '),
    (5, N'data-vct-dg-id="reportes-parte-actividades"', N'>Obs. Calif', N'data-vct-detail="1" '),
    (6, N'data-vct-dg-id="reportes-parte-actividades"', N'>Obs. Hoja Ruta</th>', N'data-vct-detail="1" '),
    (7, N'data-vct-dg-id="reportes-seg-consultoria"', N'data-vct-sort="proyecto"', N'data-vct-sub-of="Cliente" '),
    (8, N'data-vct-dg-id="reportes-seg-consultoria"', N'>Personal Afectado</th>', N'data-vct-detail="1" '),
    (9, N'data-vct-dg-id="reportes-seg-consultoria"', N'>Frec. Env', N'data-vct-detail="1" '),
    (10, N'data-vct-dg-id="reportes-seg-consultoria"', N'>Observaciones</th>', N'data-vct-detail="1" '),
    (11, N'data-vct-dg-id="reportes-seg-auditoria"', N'data-vct-sort="proyecto"', N'data-vct-sub-of="Cliente" '),
    (12, N'data-vct-dg-id="reportes-seg-auditoria"', N'>Lugar</th>', N'data-vct-detail="1" '),
    (13, N'data-vct-dg-id="reportes-seg-auditoria"', N'>Auditores</th>', N'data-vct-detail="1" '),
    (14, N'data-vct-dg-id="reportes-seg-auditoria"', N'>Fecha PA</th>', N'data-vct-detail="1" '),
    (15, N'data-vct-dg-id="reportes-seg-auditoria"', N'>Fecha Inf.</th>', N'data-vct-detail="1" '),
    (16, N'data-vct-dg-id="reportes-seg-auditoria"', N'>Tiempo Inf.</th>', N'data-vct-detail="1" '),
    (17, N'data-vct-dg-id="reportes-seg-capacitacion"', N'data-vct-sort="proyecto"', N'data-vct-sub-of="Cliente" '),
    (18, N'data-vct-dg-id="reportes-seg-capacitacion"', N'>Instructores</th>', N'data-vct-detail="1" '),
    (19, N'data-vct-dg-id="reportes-seg-capacitacion"', N'>Material</th>', N'data-vct-detail="1" '),
    (20, N'data-vct-dg-id="reportes-seg-capacitacion"', N'>Recibido</th>', N'data-vct-detail="1" '),
    (21, N'data-vct-dg-id="reportes-seg-capacitacion"', N'>Fecha Inf.</th>', N'data-vct-detail="1" '),
    (22, N'data-vct-dg-id="reportes-seg-capacitacion"', N'>Tiempo Inf.</th>', N'data-vct-detail="1" '),
    (23, N'data-vct-dg-id="reportes-calif-consultores"', N'data-vct-sort="consultor"', N'data-vct-person="1" '),
    (24, N'data-vct-dg-id="reportes-indice-ocupacion"', N'data-vct-sort="consultor"', N'data-vct-person="1" '),
    (25, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Proyecto</th>', N'data-vct-sub-of="Cliente" '),
    (26, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Servicio</th>', N'data-vct-svc="1" '),
    (27, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Nro Factura</th>', N'data-vct-detail="1" '),
    (28, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Fecha Factura</th>', N'data-vct-detail="1" '),
    (29, N'data-vct-dg-id="reportes-seg-hoteles"', N'vct-col-sm">Tipo Hu', N'data-vct-detail="1" '),
    (30, N'data-vct-dg-id="reportes-seg-hoteles"', N'">Forma Pago</th>', N'data-vct-detail="1" '),
    (31, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Desc. Forma Pago</th>', N'data-vct-detail="1" '),
    (32, N'data-vct-dg-id="reportes-seg-hoteles"', N'>Cuotas</th>', N'data-vct-detail="1" '),
    (33, N'data-vct-dg-id="reportes-seg-hoteles"', N'">Hu', N'data-vct-person="1" '),
    (34, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Proyecto</th>', N'data-vct-sub-of="Cliente" '),
    (35, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Servicio</th>', N'data-vct-svc="1" '),
    (36, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Nro Factura</th>', N'data-vct-detail="1" '),
    (37, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Fecha Factura</th>', N'data-vct-detail="1" '),
    (38, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Tipo Pasajero</th>', N'data-vct-detail="1" '),
    (39, N'data-vct-dg-id="reportes-seg-pasajes"', N'">Forma Pago</th>', N'data-vct-detail="1" '),
    (40, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Desc. Forma Pago</th>', N'data-vct-detail="1" '),
    (41, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Cuotas</th>', N'data-vct-detail="1" '),
    (42, N'data-vct-dg-id="reportes-seg-pasajes"', N'>Pasajero</th>', N'data-vct-person="1" '),
    (43, N'data-vct-dg-id="reportes-seg-remis"', N'>Proyecto</th>', N'data-vct-sub-of="Cliente" '),
    (44, N'data-vct-dg-id="reportes-seg-remis"', N'>Servicio</th>', N'data-vct-svc="1" '),
    (45, N'data-vct-dg-id="reportes-seg-remis"', N'>Nro Factura</th>', N'data-vct-detail="1" '),
    (46, N'data-vct-dg-id="reportes-seg-remis"', N'>Fecha Factura</th>', N'data-vct-detail="1" '),
    (47, N'data-vct-dg-id="reportes-seg-remis"', N'>Tipo Pasajero</th>', N'data-vct-detail="1" '),
    (48, N'data-vct-dg-id="reportes-seg-remis"', N'">Forma Pago</th>', N'data-vct-detail="1" '),
    (49, N'data-vct-dg-id="reportes-seg-remis"', N'>Desc. Forma Pago</th>', N'data-vct-detail="1" '),
    (50, N'data-vct-dg-id="reportes-seg-remis"', N'>Cuotas</th>', N'data-vct-detail="1" '),
    (51, N'data-vct-dg-id="reportes-seg-remis"', N'>Pasajero</th>', N'data-vct-person="1" '),
    (52, N'data-vct-dg-id="reportes-rentabilidad"', N'data-vct-sort="proyecto"', N'data-vct-sub-of="Cliente" '),
    (53, N'data-vct-dg-id="reportes-rentabilidad"', N'data-vct-sort="costo_estim"', N'data-vct-detail="1" '),
    (54, N'data-vct-dg-id="reportes-rentabilidad"', N'data-vct-sort="utilidad_estim"', N'data-vct-detail="1" '),
    (55, N'data-vct-dg-id="reportes-rentabilidad"', N'data-vct-sort="compras_acum"', N'data-vct-detail="1" ');

DECLARE crp CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, MARCA, ANCLA, ATTR FROM @R ORDER BY ORD;
OPEN crp;
FETCH NEXT FROM crp INTO @ro, @rm, @ra, @rt;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @attr = LEFT(@rt, CHARINDEX(N'=', @rt) - 1);
    SET @s = CHARINDEX(@rm, @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'</thead>', @d, @s) ELSE 0 END;
    SET @p = CASE WHEN @e > 0 THEN CHARINDEX(@ra, @d, @s) ELSE 0 END;
    IF @p = 0 OR @p > @e
        PRINT 'AVISO: cambio ' + CONVERT(VARCHAR(5), @ro) + ' no encontrado (' + CONVERT(VARCHAR(200), @rm) + ' / ' + CONVERT(VARCHAR(200), @ra) + '). Se saltea.';
    ELSE
    BEGIN
        /* inicio del <th que contiene el ancla */
        SET @t = @p - CHARINDEX(REVERSE(N'<th '), REVERSE(LEFT(@d, @p))) - 4 + 2;
        IF @t < @s OR SUBSTRING(@d, @t, 4) <> N'<th '
            PRINT 'AVISO: cambio ' + CONVERT(VARCHAR(5), @ro) + ': no se ubico el encabezado. Se saltea.';
        ELSE IF CHARINDEX(@attr, SUBSTRING(@d, @t, @p - @t)) > 0
            SET @ya = @ya + 1;
        ELSE
        BEGIN
            SET @d = STUFF(@d, @t + 4, 0, @rt);
            SET @cnt = @cnt + 1;
        END;
    END;
    FETCH NEXT FROM crp INTO @ro, @rm, @ra, @rt;
END;
CLOSE crp;
DEALLOCATE crp;
PRINT 'Paso 1: ' + CONVERT(VARCHAR(5), @cnt) + ' encabezados marcados, ' + CONVERT(VARCHAR(5), @ya) + ' ya estaban.';

/* 2. chevron de las categorias (igual que Agenda) */
IF CHARINDEX(N'<span class="vct-report-chevron" data-vct-icon="chevrons-up-down"></span>', @d) > 0
BEGIN
    SET @d = REPLACE(@d, N'<span class="vct-report-chevron" data-vct-icon="chevrons-up-down"></span>', N'<span class="vct-report-chevron" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg></span>');
    PRINT 'Paso 2: chevron de pestanas actualizado.';
END
ELSE PRINT 'Paso 2: chevron ya aplicado o no encontrado.';

/* 3. version */
SET @k = 1;
WHILE @k <= 4
BEGIN
    SET @marca = CASE @k WHEN 1 THEN N'vct-datagrid.css?v=' WHEN 2 THEN N'vct-datagrid.js?v=' WHEN 3 THEN N'vct-reportes.css?v=' ELSE N'vct-reportes.js?v=' END;
    SET @nuevo = CASE @k WHEN 1 THEN N'28' WHEN 2 THEN N'10' WHEN 3 THEN N'28' ELSE N'15' END;
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
PRINT 'Paso 3: version datagrid css 28 / js 10, reportes css 28 / js 15.';

IF @d = @orig BEGIN PRINT 'VCT_MAIN_REPORTES: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_REPORTES actualizado (estandar de grillas y pestanas).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_REPORTES (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
