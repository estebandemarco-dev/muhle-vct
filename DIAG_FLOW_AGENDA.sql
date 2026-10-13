/* DIAG_FLOW_AGENDA (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   Compara como esta cableado el despacho ACTION->SP de una pantalla que SI
   anda (CONFIGURACION) contra la de Agenda, en las tablas del flow del
   designer (STEP_TRANSACTION_FLOW / STORED_PROCEDURES). No cambia nada. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_FLOW_AGENDA.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 0) Columnas de STORED_PROCEDURES =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH AS LEN
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='STORED_PROCEDURES' ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 0b) Columnas de STEP_TRANSACTION_FLOW =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH AS LEN
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='STEP_TRANSACTION_FLOW' ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 1) STORED_PROCEDURES: filas que mencionan CONFIGURACION / AGENDA =====';
DECLARE @sql NVARCHAR(MAX);

SELECT @sql = N'SELECT * FROM dbo.STORED_PROCEDURES WHERE 1=0'
            + ISNULL((SELECT ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%AGENDA%'''
                           + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%CONFIGURACION%'''
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME='STORED_PROCEDURES'
                        AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text','ntext')
                      FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)'), '');
EXEC sys.sp_executesql @sql;

PRINT '';
PRINT '===== 2) STEP_TRANSACTION_FLOW: filas que mencionan CONFIGURACION / AGENDA =====';
SELECT @sql = N'SELECT * FROM dbo.STEP_TRANSACTION_FLOW WHERE 1=0'
            + ISNULL((SELECT ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%AGENDA%'''
                           + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%CONFIGURACION%'''
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME='STEP_TRANSACTION_FLOW'
                        AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text','ntext')
                      FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)'), '');
EXEC sys.sp_executesql @sql;

PRINT '';
PRINT '===== 3) STORED_PROCEDURES: filas que mencionan el SP del dashboard o de agenda =====';
SELECT @sql = N'SELECT * FROM dbo.STORED_PROCEDURES WHERE 1=0'
            + ISNULL((SELECT ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%VCT_MAIN_AGENDA%'''
                           + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%VCT_MAIN_DASHBOARD%'''
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME='STORED_PROCEDURES'
                        AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text','ntext')
                      FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)'), '');
EXEC sys.sp_executesql @sql;

PRINT '';
PRINT '===== FIN =====';
GO
