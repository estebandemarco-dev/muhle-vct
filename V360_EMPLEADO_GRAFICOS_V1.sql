/* ========================================================================
   V360_EMPLEADO_GRAFICOS_V1
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_EMPLEADOS_V360,
   graficos del Resumen, con el mismo criterio que la 360 de Consultor:
   - "Proyectos por estado": paleta institucional (En curso bordo medio,
     Otros abiertos bordo claro, Terminados gris medio, Otros grafito).
   - "Clientes asignados": bordo medio.
   - Leyendas con la tipografia estandar.
   - "Acciones por estado" NO se modifica.
   No cambia css ni js. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_EMPLEADOS_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @seg NVARCHAR(MAX), @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0,
        @msg NVARCHAR(2000), @nom SYSNAME = N'VCT_MAIN_EMPLEADOS_V360';

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_EMPLEADOS_V360.', 16, 1); RETURN; END;
SET @orig = @d;

    /* 1c. Graficos: Proyectos por estado (solo su tramo) */
    SET @s = CHARINDEX(N'SET @P_BG=', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'@G_REAL=SUM', @d, @s) ELSE 0 END;
    IF @s = 0 OR @e = 0
        PRINT 'AVISO: no se encontro el grafico Proyectos por estado; no se modifico.';
    ELSE
    BEGIN
        SET @seg = SUBSTRING(@d, @s, @e - @s);
        SET @seg = REPLACE(REPLACE(REPLACE(REPLACE(@seg, N'#12B76A', N'#8C1D47'), N'#F79009', N'#CF6F92'), N'#98A2B3', N'#8E8C8D'), N'#7F56D9', N'#4A4849');
        SET @seg = REPLACE(@seg, N'class="vct-360-donut-legend-lg"', N'class="vct-360-donut-legend vct-360-donut-legend-lg"');
        SET @d = STUFF(@d, @s, @e - @s, @seg);
        PRINT 'Paso 1c: grafico Proyectos por estado con paleta institucional.';
    END;

    /* 1c. Graficos: Clientes asignados (solo su tramo) */
    SET @s = CHARINDEX(N'SET @HTML_CHART_CLIENTES=', @d);
    SET @e = CASE WHEN @s > 0 THEN CHARINDEX(N'DECLARE', @d, @s) ELSE 0 END;
    IF @s = 0 OR @e = 0
        PRINT 'AVISO: no se encontro el grafico Clientes asignados; no se modifico.';
    ELSE
    BEGIN
        SET @seg = SUBSTRING(@d, @s, @e - @s);
        SET @seg = REPLACE(@seg, N'#2E90FA', N'#8C1D47');
        SET @seg = REPLACE(@seg, N'class="vct-360-donut-legend-lg"', N'class="vct-360-donut-legend vct-360-donut-legend-lg"');
        SET @d = STUFF(@d, @s, @e - @s, @seg);
        PRINT 'Paso 1c: grafico Clientes asignados con paleta institucional.';
    END;

IF @d = @orig BEGIN PRINT 'VCT_MAIN_EMPLEADOS_V360: sin cambios.'; RETURN; END;

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
    PRINT 'OK: VCT_MAIN_EMPLEADOS_V360 actualizado (graficos).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_EMPLEADOS_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
