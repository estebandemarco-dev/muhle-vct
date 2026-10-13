/* DIAG_AGENDA_CONSULTOR_3 (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   OBJETIVO: ver con que ACTION dispara el menu "Agenda" (SideBar Id=9).
   PASOS:
     1) En la app (logueado como GERENCIA o SQUAD, que son los que hoy ven
        el menu), hace CLIC en el item "Agenda" del menu lateral.
        (Va a caer en el Inicio: es lo esperado, todavia no tiene SP.)
     2) Volve aca y corre este script (F5).
   Muestra las filas del buffer con su ACTION para identificar el valor. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_AGENDA_CONSULTOR_3.txt
USE [MuhlePROD];
SET NOCOUNT ON;

PRINT '===== 0) Columnas de VCT_BUFFER (para ubicar fecha/usuario) =====';
SELECT ORDINAL_POSITION AS POS, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'VCT_BUFFER'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '===== 1) Filas del buffer con ACTION (candidatos) =====';
SELECT TOP 30
       PAR_KEY,
       UPPER(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(100), ACTION),'')))) AS ACTION_VAL,
       CONVERT(VARCHAR(100), ISNULL(TEXTO30,''))  AS TEXTO30,
       CONVERT(VARCHAR(100), ISNULL(IDSELEC01,'')) AS IDSELEC01,
       CONVERT(VARCHAR(100), ISNULL(IDSELEC02,'')) AS IDSELEC02
FROM dbo.VCT_BUFFER WITH(NOLOCK)
WHERE NULLIF(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(100), ACTION),''))),'') IS NOT NULL
ORDER BY PAR_KEY DESC;

PRINT '';
PRINT '===== 2) Conteo de valores de ACTION distintos =====';
SELECT UPPER(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(100), ACTION),'')))) AS ACTION_VAL, COUNT(*) AS FILAS
FROM dbo.VCT_BUFFER WITH(NOLOCK)
GROUP BY UPPER(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(100), ACTION),''))))
ORDER BY FILAS DESC;

PRINT '';
PRINT '===== FIN =====';
GO
