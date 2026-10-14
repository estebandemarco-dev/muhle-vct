/* ========================================================================
   PROYECTOS_GRILLA_1  (CORREGIDO 14/10 - reemplaza la version subida a main)
   ------------------------------------------------------------------------
   La pantalla Proyectos del sidebar quedo definida con el diseno aprobado
   (boceto_proyectos_v2): la instala PROYECTOS_PANTALLA_V1.sql
   (dbo.VCT_MAIN_PROYECTOS, marca PROYECTOS_PANTALLA_V1, + ruteo
   PROYECTOS_RUTEO_V1 en VCT_MAIN_DASHBOARD).
   La version anterior de este script creaba otro VCT_MAIN_PROYECTOS con
   otro diseno: el que se corriera ultimo pisaba al otro.
   Este script ya NO modifica nada: solo verifica y avisa. Se deja en el
   repo para que nadie corra la version anterior por error.
   ======================================================================== */
SET NOCOUNT ON;
DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_PROYECTOS')),
        @h NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_DASHBOARD'));
PRINT 'dbo.VCT_MAIN_PROYECTOS (PROYECTOS_PANTALLA_V1): ' + CASE WHEN @d IS NULL THEN 'NO EXISTE -> correr PROYECTOS_PANTALLA_V1.sql'
      WHEN CHARINDEX(N'PROYECTOS_PANTALLA_V1', @d) > 0 THEN 'OK' ELSE 'es otra version -> correr PROYECTOS_PANTALLA_V1.sql' END;
PRINT 'Ruteo del menu en VCT_MAIN_DASHBOARD (PROYECTOS_RUTEO_V1): ' + CASE WHEN CHARINDEX(N'PROYECTOS_RUTEO_V1', ISNULL(@h,N'')) > 0 THEN 'OK' ELSE 'FALTA -> correr PROYECTOS_PANTALLA_V1.sql' END;
