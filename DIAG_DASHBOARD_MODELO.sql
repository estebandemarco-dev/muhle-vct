/* DIAG_DASHBOARD_MODELO (solo lectura) - correr con Query > SQLCMD Mode
   Base para rehacer el Inicio/Dashboard por perfil (GERENCIA, ADMINISTRACION,
   PROYECTOS, CONSULTORES, CLIENTES) sin vistas ni funciones nuevas.
   Si no se usa SQLCMD Mode, borrar la linea :OUT y copiar la pestaña Mensajes/Resultados. */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\DIAG_DASHBOARD_MODELO.txt
GO
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '=== 1. tablas VCT_* con filas ===';
SELECT T.name AS TABLA, SUM(P.rows) AS FILAS
FROM sys.tables T JOIN sys.partitions P ON P.object_id = T.object_id AND P.index_id IN (0,1)
WHERE T.name LIKE 'VCT[_]%' GROUP BY T.name ORDER BY T.name;
GO

PRINT '=== 2. columnas de las tablas del dashboard ===';
SELECT T.name AS TABLA, C.column_id, C.name AS COLUMNA, TY.name AS TIPO, C.max_length, C.is_nullable
FROM sys.tables T JOIN sys.columns C ON C.object_id = T.object_id JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE T.name IN ('VCT_PROYECTOS','VCT_PROYECTOS_RENTABILIDAD','VCT_PROYECTOS_SERVICIOS','VCT_PROYECTOS_EQUIPO',
                 'VCT_PROYECTOS_VISITAS','VCT_PROYECTOS_VISITAS_CONSULTORES','VCT_PROYECTOS_NORMAS','VCT_PROYECTOS_VIATICOS',
                 'VCT_CLIENTES','VCT_CLIENTES_CONTACTOS','VCT_CONTACTOS','VCT_CONSULTORES','VCT_EMPLEADOS','VCT_PROVEEDORES',
                 'VCT_ACCIONES','VCT_GESTIONES','VCT_ACCIONES_PARTICIPANTES','VCT_GESTIONES_PARTICIPANTES',
                 'VCT_PRM_PROYECTOS_ESTADOS','VCT_PRM_ACCIONES_ESTADOS','VCT_PRM_GESTIONES_ESTADOS',
                 'VCT_PRM_ACCIONES_TIPOS','VCT_PRM_GESTIONES_TIPOS','VCT_PRM_SERVICIOS')
   OR T.name LIKE 'VCT[_]%FACTUR%' OR T.name LIKE 'VCT[_]%COBR%' OR T.name LIKE 'VCT[_]%PRESUP%' OR T.name LIKE 'VCT[_]%VIATIC%'
   OR T.name LIKE 'VCT[_]%HONORAR%' OR T.name LIKE 'VCT[_]%PLAN%'
ORDER BY T.name, C.column_id;
GO

PRINT '=== 3. estados de proyecto y cantidad ===';
SELECT E.ID, E.CODIGO, E.DESCRIPCION, (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS P WHERE P.ID_ESTADO = E.ID) AS PROYECTOS
FROM dbo.VCT_PRM_PROYECTOS_ESTADOS E ORDER BY E.ID;
GO

PRINT '=== 4. estados de acciones (ex gestiones) ===';
IF OBJECT_ID('dbo.VCT_PRM_ACCIONES_ESTADOS') IS NOT NULL EXEC ('SELECT * FROM dbo.VCT_PRM_ACCIONES_ESTADOS');
IF OBJECT_ID('dbo.VCT_PRM_GESTIONES_ESTADOS') IS NOT NULL EXEC ('SELECT * FROM dbo.VCT_PRM_GESTIONES_ESTADOS');
GO

PRINT '=== 5. muestra de montos en proyectos y rentabilidad (TOP 5) ===';
BEGIN TRY EXEC ('SELECT TOP 5 * FROM dbo.VCT_PROYECTOS ORDER BY ID DESC'); END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC ('SELECT TOP 5 * FROM dbo.VCT_PROYECTOS_RENTABILIDAD'); END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;
GO

PRINT '=== 6. perfiles, usuarios y vinculo usuario -> persona ===';
SELECT G.GroupId AS PERFIL, COUNT(*) AS USUARIOS FROM dbo.GroupsUserMembers G GROUP BY G.GroupId ORDER BY 1;
SELECT U.Id, U.Name, G.GroupId FROM dbo.Users U JOIN dbo.GroupsUserMembers G ON G.UserMemberId = U.Id
WHERE U.Id IN ('svocaturo','avocaturo','maja','edemarco','cromero','lcavana') OR G.GroupId IN ('CLIENTES','ADMINISTRACION');
PRINT '--- columnas que vinculan un usuario con cliente/contacto:';
SELECT T.name AS TABLA, C.name AS COLUMNA FROM sys.columns C JOIN sys.tables T ON T.object_id = C.object_id
WHERE T.name LIKE 'VCT[_]%' AND (C.name LIKE '%USUARIO_SEGURIDAD%' OR C.name LIKE '%ID_USUARIO%') ORDER BY 1;
GO

PRINT '=== 7. permisos de INICIO / DASHBOARD en PrmActions y por perfil ===';
SELECT PA.* FROM dbo.PrmActions PA WHERE PA.ActionID LIKE 'INICIO.%' OR PA.ActionID LIKE 'DASHBOARD.%' OR PA.ActionID LIKE 'RENTABILIDAD.%';
SELECT GA.GroupId, GA.ActionId FROM dbo.GroupsActions GA
WHERE GA.ActionId LIKE 'INICIO.%' OR GA.ActionId LIKE 'DASHBOARD.%' OR GA.ActionId LIKE 'RENTABILIDAD.%' ORDER BY 1, 2;
GO

PRINT '=== 8. que SP arma el Inicio y si compila hoy ===';
SELECT name, modify_date FROM sys.procedures WHERE name IN ('VCT_MAIN_DASHBOARD','VCT_MAIN_ACCIONES','VCT_NOTIF_GENERAR','VCT_NOTIF_RENDER','VCT_NOTIF_ACCION');
SELECT DISTINCT OBJECT_NAME(D.referencing_id) AS SP, D.referenced_entity_name AS NO_EXISTE
FROM sys.sql_expression_dependencies D
WHERE OBJECT_NAME(D.referencing_id) IN ('VCT_MAIN_DASHBOARD','VCT_NOTIF_GENERAR','VCT_NOTIF_RENDER','VCT_NOTIF_ACCION','VCT_GET_SHELL','VCT_GET_SIDEBAR','VCT_GET_HEADER')
  AND D.referenced_id IS NULL AND D.referenced_schema_name = 'dbo'
  AND OBJECT_ID('dbo.' + D.referenced_entity_name) IS NULL;
GO

PRINT '=== FIN ===';
GO
