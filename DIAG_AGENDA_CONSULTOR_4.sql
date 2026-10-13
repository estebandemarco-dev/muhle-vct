/* DIAG_AGENDA_CONSULTOR_4 (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   Ultimo dato para el alta de permisos: columnas de GroupsActions y
   confirmacion de que PrmActions.Id es IDENTITY, + muestra de SideBarGroups.Id. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_AGENDA_CONSULTOR_4.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 1) Columnas de GroupsActions =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='GroupsActions' ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 2) Columnas de Actions (nulabilidad/defaults) =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Actions' ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 3) Columnas de SideBarGroups (nulabilidad/defaults) =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='SideBarGroups' ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 4) PrmActions.Id es IDENTITY? =====';
SELECT COLUMN_NAME, COLUMNPROPERTY(OBJECT_ID('dbo.PrmActions'), COLUMN_NAME, 'IsIdentity') AS IS_IDENTITY
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='PrmActions' AND COLUMN_NAME='Id';

PRINT '';
PRINT '===== 5) Muestra de Id de SideBarGroups (ver si es numerico o guid) =====';
SELECT TOP 10 Id, SideBarId, GroupId FROM dbo.SideBarGroups ORDER BY Id;

PRINT '';
PRINT '===== FIN =====';
GO
