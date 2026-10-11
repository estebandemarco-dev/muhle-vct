/* DIAG_V360_RESUMEN (solo lectura) - correr con Query > SQLCMD Mode activado
   Para rehacer en la 360 de cliente: "Ultimas acciones" (fecha, accion,
   proyecto, servicio, norma, asignado, estado) y los graficos del Resumen.
   Guarda todo en _diag\DIAG_V360_RESUMEN.txt (la carpeta ya esta creada). */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\DIAG_V360_RESUMEN.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '=== 1. columnas de las tablas de acciones, servicios y normas ===';
SELECT T.name AS TABLA, C.column_id, C.name AS COLUMNA, TY.name AS TIPO, C.max_length, C.is_nullable
FROM sys.tables T
JOIN sys.columns C ON C.object_id = T.object_id
JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE T.name IN ('VCT_ACCIONES','VCT_ACCIONES_PARTICIPANTES','VCT_PRM_ACCIONES_ESTADOS','VCT_PRM_ACCIONES_TIPOS',
                 'VCT_PRM_ACCIONES_SUBTIPOS','VCT_PROYECTOS_SERVICIOS','VCT_PROYECTOS_NORMAS','VCT_PRM_NORMAS','VCT_PRM_SERVICIOS')
ORDER BY T.name, C.column_id;
GO

PRINT '=== 2. estados y tipos de acciones ===';
IF OBJECT_ID('dbo.VCT_PRM_ACCIONES_ESTADOS') IS NOT NULL EXEC ('SELECT * FROM dbo.VCT_PRM_ACCIONES_ESTADOS');
IF OBJECT_ID('dbo.VCT_PRM_ACCIONES_TIPOS') IS NOT NULL EXEC ('SELECT * FROM dbo.VCT_PRM_ACCIONES_TIPOS');
GO

PRINT '=== 3. ultimas 5 acciones (muestra) ===';
IF OBJECT_ID('dbo.VCT_ACCIONES') IS NOT NULL EXEC ('SELECT TOP 5 * FROM dbo.VCT_ACCIONES ORDER BY ID DESC');
GO

PRINT '=== 4. definicion vigente de VCT_MAIN_CLIENTES_V360 (linea por linea) ===';
DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_CLIENTES_V360')), @p INT = 1, @n INT, @lin NVARCHAR(MAX);
SET @d = REPLACE(@d, CHAR(13), N'');
WHILE @p <= LEN(@d)
BEGIN
    SET @n = CHARINDEX(CHAR(10), @d, @p);
    IF @n = 0 SET @n = LEN(@d) + 1;
    SET @lin = SUBSTRING(@d, @p, @n - @p);
    WHILE LEN(@lin) > 3900 BEGIN PRINT LEFT(@lin, 3900); SET @lin = SUBSTRING(@lin, 3901, LEN(@lin)); END;
    PRINT @lin;
    SET @p = @n + 1;
END;
GO
PRINT '=== FIN ===';
GO
