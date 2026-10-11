/* DIAG_ACTIONS_GESTIONES (solo lectura) - correr con Query > SQLCMD Mode
   Base para redefinir dbo.Actions y renombrar Gestiones -> Acciones:
     1. estructura de Actions y quien la referencia (FK, columnas ActionId)
     2. por cada accion: perfiles que la tienen y objetos SQL que la nombran
     3. tablas/vistas/SP "gestion": filas, FK y objetos que las usan
   Si la carpeta _diag no existe, crearla antes (SQLCMD no la crea). */
:OUT C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\DIAG_ACTIONS_GESTIONES.txt
USE [MuhlePROD];
SET NOCOUNT ON;
GO

PRINT '=== 1a. columnas, PK e indices de dbo.Actions ===';
SELECT C.column_id, C.name AS COLUMNA, TY.name AS TIPO, C.max_length, C.is_nullable, C.is_identity
FROM sys.columns C JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE C.object_id = OBJECT_ID('dbo.Actions') ORDER BY C.column_id;
SELECT I.name, I.is_primary_key, I.is_unique,
       STUFF((SELECT ',' + C.name FROM sys.index_columns IC JOIN sys.columns C ON C.object_id = IC.object_id AND C.column_id = IC.column_id
              WHERE IC.object_id = I.object_id AND IC.index_id = I.index_id ORDER BY IC.key_ordinal FOR XML PATH('')),1,1,'') AS COLUMNAS
FROM sys.indexes I WHERE I.object_id = OBJECT_ID('dbo.Actions') AND I.index_id > 0;
GO

PRINT '=== 1b. FK que apuntan a Actions y columnas tipo ActionId en otras tablas ===';
SELECT OBJECT_NAME(FK.parent_object_id) AS TABLA, FK.name AS FK, FK.delete_referential_action_desc AS ON_DELETE, FK.update_referential_action_desc AS ON_UPDATE
FROM sys.foreign_keys FK WHERE FK.referenced_object_id = OBJECT_ID('dbo.Actions');
SELECT T.name AS TABLA, C.name AS COLUMNA, TY.name AS TIPO, C.max_length
FROM sys.columns C JOIN sys.tables T ON T.object_id = C.object_id JOIN sys.types TY ON TY.user_type_id = C.user_type_id
WHERE (C.name LIKE '%ActionId%' OR C.name LIKE '%ACTION_ID%' OR C.name IN ('IdAction','ID_ACCION','ACCION'))
ORDER BY T.name;
GO

PRINT '=== 1c. triggers sobre Actions / GroupsActions ===';
SELECT OBJECT_NAME(parent_id) AS TABLA, name, is_disabled FROM sys.triggers
WHERE parent_id IN (OBJECT_ID('dbo.Actions'), OBJECT_ID('dbo.GroupsActions'));
GO

PRINT '=== 2. uso de cada accion: perfiles y objetos SQL que la nombran ===';
SELECT A.Id, A.Name, A.IdPadre, A.Tipo,
       (SELECT COUNT(*) FROM dbo.GroupsActions GA WHERE GA.ActionId = A.Id) AS PERFILES,
       ISNULL(STUFF((SELECT ',' + GA.GroupId FROM dbo.GroupsActions GA WHERE GA.ActionId = A.Id ORDER BY GA.GroupId FOR XML PATH('')),1,1,''),'') AS LISTA_PERFILES,
       (SELECT COUNT(*) FROM sys.sql_modules M WHERE M.definition LIKE '%''' + A.Id + '''%') AS OBJETOS,
       ISNULL(STUFF((SELECT ',' + OBJECT_NAME(M.object_id) FROM sys.sql_modules M WHERE M.definition LIKE '%''' + A.Id + '''%' ORDER BY 1 FOR XML PATH('')),1,1,''),'') AS LISTA_OBJETOS
FROM dbo.Actions A
ORDER BY A.Id;
GO

PRINT '=== 2b. GroupsActions que apuntan a acciones que no existen ===';
SELECT GA.GroupId, GA.ActionId FROM dbo.GroupsActions GA
WHERE NOT EXISTS (SELECT 1 FROM dbo.Actions A WHERE A.Id = GA.ActionId);
GO

PRINT '=== 2c. objetos que leen Actions / GroupsActions (la logica de permisos) ===';
SELECT O.type_desc, O.name, O.modify_date FROM sys.objects O JOIN sys.sql_modules M ON M.object_id = O.object_id
WHERE M.definition LIKE '%GroupsActions%' OR M.definition LIKE '%dbo.Actions%' OR M.definition LIKE '%[[]Actions]%'
ORDER BY O.name;
GO

PRINT '=== 3a. tablas y vistas con GESTION en el nombre: filas ===';
SELECT O.type_desc, O.name, SUM(CASE WHEN P.index_id IN (0,1) THEN P.rows ELSE 0 END) AS FILAS
FROM sys.objects O LEFT JOIN sys.partitions P ON P.object_id = O.object_id
WHERE O.type IN ('U','V') AND O.name LIKE '%GESTION%'
GROUP BY O.type_desc, O.name ORDER BY O.type_desc, O.name;
GO

PRINT '=== 3b. FK entre tablas GESTION y el resto ===';
SELECT OBJECT_NAME(FK.parent_object_id) AS TABLA, FK.name AS FK, OBJECT_NAME(FK.referenced_object_id) AS REFERENCIA
FROM sys.foreign_keys FK
WHERE OBJECT_NAME(FK.parent_object_id) LIKE '%GESTION%' OR OBJECT_NAME(FK.referenced_object_id) LIKE '%GESTION%'
ORDER BY 1;
GO

PRINT '=== 3c. por tabla/vista GESTION: cuantos objetos la usan y cuales ===';
SELECT T.name AS TABLA,
       (SELECT COUNT(*) FROM sys.sql_modules M WHERE M.definition LIKE '%' + T.name + '%' AND M.object_id <> T.object_id) AS OBJETOS,
       ISNULL(STUFF((SELECT ',' + OBJECT_NAME(M.object_id) FROM sys.sql_modules M
                     WHERE M.definition LIKE '%' + T.name + '%' AND M.object_id <> T.object_id ORDER BY 1 FOR XML PATH('')),1,1,''),'') AS LISTA
FROM sys.objects T
WHERE T.type IN ('U','V') AND T.name LIKE '%GESTION%'
ORDER BY T.name;
GO

PRINT '=== 3d. SP y funciones con GESTION en el nombre ===';
SELECT type_desc, name, modify_date FROM sys.objects
WHERE type IN ('P','FN','IF','TF') AND name LIKE '%GESTION%' ORDER BY name;
GO

PRINT '=== 3e. sinonimos existentes (para renombrar sin romper) ===';
SELECT name, base_object_name FROM sys.synonyms ORDER BY name;
GO

PRINT '=== FIN ===';
GO
