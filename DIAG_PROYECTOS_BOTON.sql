/* ========================================================================
   DIAG_PROYECTOS_BOTON  (solo lectura, no modifica nada)
   Correr en SSMS INMEDIATAMENTE DESPUES de apretar "Otros estados" en la
   pantalla Proyectos (cuando ya te mostro el Inicio). Pegar las 3 grillas.
   ======================================================================== */
SET NOCOUNT ON;

/* 1. Que version quedo instalada */
SELECT 'VCT_MAIN_PROYECTOS' AS OBJETO,
       CASE WHEN OBJECT_ID('dbo.VCT_MAIN_PROYECTOS') IS NULL THEN 'NO EXISTE'
            WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_PROYECTOS')) LIKE '%PROYECTOS_OTROS%' THEN 'OK (boton nuevo)'
            ELSE 'VERSION VIEJA' END AS ESTADO,
       (SELECT modify_date FROM sys.objects WHERE object_id = OBJECT_ID('dbo.VCT_MAIN_PROYECTOS')) AS MODIFICADO
UNION ALL
SELECT 'VCT_MAIN_DASHBOARD',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_DASHBOARD')) LIKE '%PROYECTOS_RUTEO_V3%' THEN 'OK (ruteo V3)'
            WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_DASHBOARD')) LIKE '%PROYECTOS_RUTEO_V2%' THEN 'ruteo V2'
            WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_DASHBOARD')) LIKE '%PROYECTOS_RUTEO_V1%' THEN 'ruteo V1'
            ELSE 'SIN RUTEO' END,
       (SELECT modify_date FROM sys.objects WHERE object_id = OBJECT_ID('dbo.VCT_MAIN_DASHBOARD'));

/* 2. El texto del ruteo de Proyectos dentro del Inicio */
DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_DASHBOARD')), @p INT;
SET @p = CHARINDEX(N'PROYECTOS_RUTEO', ISNULL(@d, N''));
SELECT CASE WHEN @p = 0 THEN '(no hay ruteo de Proyectos)' ELSE SUBSTRING(@d, @p, 600) END AS RUTEO_EN_EL_INICIO;

/* 3. Las ultimas tareas en el buffer: que ACTION llego al apretar el boton */
SELECT TOP 10 PAR_KEY, ACTION, TEXTO30
FROM dbo.VCT_BUFFER WITH(NOLOCK)
ORDER BY PAR_KEY DESC;
