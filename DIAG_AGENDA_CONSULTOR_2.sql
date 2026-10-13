/* DIAG_AGENDA_CONSULTOR_2 (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   Cierra lo que falto: filas de SideBar Id 8 y 9 (rowguid + Code) y
   que grupos ven hoy cada entrada de menu. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_AGENDA_CONSULTOR_2.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 1) SideBar: entradas de menu Id 8 y 9 (Id es nvarchar) =====';
SELECT Id, Name, Code, CONVERT(VARCHAR(50), rowguid) AS ROWGUID
FROM dbo.SideBar
WHERE Id IN (N'8', N'9')
ORDER BY Id;

PRINT '';
PRINT '===== 1b) Todas las entradas de SideBar (para ubicar codigos/guid) =====';
SELECT Id, Name, Code, CONVERT(VARCHAR(50), rowguid) AS ROWGUID
FROM dbo.SideBar
ORDER BY Id;

PRINT '';
PRINT '===== 2) SideBarGroups: quien ve las entradas 8 y 9 =====';
SELECT SideBarId, GroupId
FROM dbo.SideBarGroups
WHERE SideBarId IN (N'8', N'9')
ORDER BY SideBarId, GroupId;

PRINT '';
PRINT '===== FIN =====';
GO
