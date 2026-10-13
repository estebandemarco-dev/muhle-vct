/* ============================================================
   DIAG_AGENDA_CONSULTOR  (SOLO LECTURA)
   Confirma el cableado para crear la pantalla Agenda del Consultor:
     1) tabla de menu lateral (sidebar) y las filas Id 8 y 9 (GUID, Code)
     2) permisos existentes AGENDA.%  y  AGENDA_CONSULTOR.%
     3) perfiles (Groups) y quien ve hoy la Agenda General (para calcar grants)
     4) consultores activos y cuantos tienen usuario de seguridad
   No cambia nada. Correr con Query > SQLCMD Mode (F5).
   ============================================================ */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_AGENDA_CONSULTOR.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 0) TABLAS DE SIDEBAR (nombre + columnas) =====';
SELECT c.TABLE_NAME, c.ORDINAL_POSITION AS POS, c.COLUMN_NAME, c.DATA_TYPE, c.CHARACTER_MAXIMUM_LENGTH AS LEN
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME LIKE '%SIDEBAR%' OR c.TABLE_NAME LIKE '%SIDE[_]BAR%'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

PRINT '';
PRINT '===== 0b) FK que apunta a lo que referencia PrmActions.SideBarId =====';
SELECT fk.name AS FK, OBJECT_NAME(fk.parent_object_id) AS TABLA_HIJA,
       OBJECT_NAME(fk.referenced_object_id) AS TABLA_PADRE
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) = 'PrmActions';

PRINT '';
PRINT '===== 1) FILAS DE SIDEBAR Id 8 y 9 (SideBarGroups si existe) =====';
IF OBJECT_ID('dbo.SideBarGroups') IS NOT NULL
    SELECT * FROM dbo.SideBarGroups WHERE Id IN (8,9) ORDER BY Id;
ELSE
    PRINT 'dbo.SideBarGroups no existe; ver la tabla listada en el paso 0.';

PRINT '';
PRINT '===== 2) PrmActions de AGENDA y AGENDA_CONSULTOR =====';
SELECT * FROM dbo.PrmActions WHERE UPPER(ActionID) LIKE 'AGENDA%' ORDER BY ActionID;

PRINT '';
PRINT '===== 2b) Actions de AGENDA% =====';
SELECT * FROM dbo.Actions WHERE UPPER(Id) LIKE 'AGENDA%' ORDER BY Id;

PRINT '';
PRINT '===== 3) Perfiles (Groups) =====';
SELECT * FROM dbo.Groups ORDER BY 1;

PRINT '';
PRINT '===== 3b) Quien tiene hoy AGENDA.VIEW (para calcar los grants) =====';
SELECT GA.GroupId, GA.ActionId
FROM dbo.GroupsActions GA
WHERE UPPER(GA.ActionId) LIKE 'AGENDA%'
ORDER BY GA.ActionId, GA.GroupId;

PRINT '';
PRINT '===== 4) Consultores activos / con usuario de seguridad =====';
SELECT COUNT(*) AS CONSULTORES_ACTIVOS,
       SUM(CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,''))),'') IS NOT NULL THEN 1 ELSE 0 END) AS CON_USUARIO,
       SUM(CASE WHEN INGRESA_SISTEMA=1 THEN 1 ELSE 0 END) AS INGRESAN_SISTEMA
FROM dbo.VCT_CONSULTORES
WHERE UPPER(ISNULL(ESTADO,'')) = 'ACTIVO';

PRINT '';
PRINT '===== 4b) Muestra de consultores activos (id, nombre, usuario) =====';
SELECT TOP 10 ID,
       LTRIM(RTRIM(ISNULL(APELLIDOS,'') + ', ' + ISNULL(NOMBRES,''))) AS NOMBRE,
       ID_USUARIO_SEGURIDAD, INGRESA_SISTEMA
FROM dbo.VCT_CONSULTORES
WHERE UPPER(ISNULL(ESTADO,'')) = 'ACTIVO'
ORDER BY APELLIDOS, NOMBRES;

PRINT '';
PRINT '===== FIN DIAG_AGENDA_CONSULTOR =====';
GO
