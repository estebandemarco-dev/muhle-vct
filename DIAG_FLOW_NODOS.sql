/* DIAG_FLOW_NODOS (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   Ve como el nodo-actividad destino se ata al SP, comparando el destino de
   CONFIGURACION (C576D92F, anda) contra el de AGENDA (EE2B3F6F, no anda).
   No cambia nada. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_FLOW_NODOS.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 0) Tablas candidatas del motor de flujo (CONV / STRUCTURE / STEP / ACTIVITY) =====';
SELECT DISTINCT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%CONV%' OR TABLE_NAME LIKE '%STRUCTURE%'
   OR TABLE_NAME LIKE '%STEP%' OR TABLE_NAME LIKE '%ACTIVIT%'
   OR TABLE_NAME LIKE '%PA[_]SYS%'
ORDER BY TABLE_NAME;

PRINT '';
PRINT '===== 1) Columnas de CONV_STRUCTURE (si existe) =====';
IF OBJECT_ID('dbo.CONV_STRUCTURE') IS NOT NULL
    SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH AS LEN
    FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='CONV_STRUCTURE' ORDER BY ORDINAL_POSITION;
ELSE
    PRINT 'dbo.CONV_STRUCTURE no existe (ver tablas del paso 0).';

PRINT '';
PRINT '===== 2) CONV_STRUCTURE: nodos origen y destino de CONFIG vs AGENDA =====';
/* C31037CE = estructura origen (menu, comun) ; C576D92F = destino CONFIGURACION ; EE2B3F6F = destino AGENDA */
IF OBJECT_ID('dbo.CONV_STRUCTURE') IS NOT NULL
    SELECT * FROM dbo.CONV_STRUCTURE
    WHERE CONVERT(VARCHAR(36), PKEY) IN
        ('C31037CE-DE04-4735-9C59-8658C1C8C4F3',
         'C576D92F-6A0A-4E7A-8F0C-48BF0C05F404',
         'EE2B3F6F-4900-4C8C-A287-D4630D65B344');
ELSE
    PRINT 'omitido (ver paso 0 para el nombre real de la tabla de estructura).';

PRINT '';
PRINT '===== FIN =====';
GO
