/* ========================================================================
   CONSULTOR_SERVICIOS_2_NORMAS  (CORREGIDO 14/10 - reemplaza la version subida a main)
   ------------------------------------------------------------------------
   La version anterior era un ALTER completo de dbo.VCT_MAIN_CONSULTORES_V360
   generado desde db/objetos (copia del 09/10). Correrla borraba todo lo
   hecho despues en la 360 de Consultor (grillas estandar, Resumen, Acciones,
   Agenda, orden de pestanas, columnas de proyecto).
   Lo que agregaba (normas por servicio, validacion norma+servicio, filtro
   por servicio, solapa Servicios con alta) YA esta en la base por los
   scripts CONSULTOR_SERVICIOS_2_V360 (marca SERVICIOS_V1),
   V360_CONSULTOR_SERVICIOS_V2/V3 y V360_CONSULTOR_NORMAS_V2/V3.
   El chip de color por servicio NO se usa: el estandar (CLAUDE.md regla 10
   y 15) es el circulo con icono fijo (.vctdg-svc).
   Este script ya NO modifica nada: solo verifica y avisa. Se deja en el
   repo para que nadie corra la version anterior por error.
   ======================================================================== */
SET NOCOUNT ON;
DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360'));
IF @d IS NULL
    PRINT 'AVISO: no existe dbo.VCT_MAIN_CONSULTORES_V360.';
ELSE
BEGIN
    PRINT 'Normas por servicio / solapa Servicios (SERVICIOS_V1): ' + CASE WHEN CHARINDEX(N'SERVICIOS_V1', @d) > 0 THEN 'OK' ELSE 'FALTA -> correr CONSULTOR_SERVICIOS_2_V360.sql' END;
    PRINT 'Grilla de Servicios (SERVICIOS_V2): ' + CASE WHEN CHARINDEX(N'SERVICIOS_V2', @d) > 0 THEN 'OK' ELSE 'FALTA -> correr V360_CONSULTOR_SERVICIOS_V2.sql' END;
    PRINT 'Boton Nuevo de Servicios (SERVICIOS_V3): ' + CASE WHEN CHARINDEX(N'SERVICIOS_V3', @d) > 0 THEN 'OK' ELSE 'FALTA -> correr V360_CONSULTOR_SERVICIOS_V3.sql' END;
    PRINT 'Grilla de Normas con servicio (NORMAS_V2): ' + CASE WHEN CHARINDEX(N'NORMAS_V2', @d) > 0 THEN 'OK' ELSE 'FALTA -> correr V360_CONSULTOR_NORMAS_V2.sql' END;
    PRINT 'Drawer de Norma por servicio (NORMAS_V3): ' + CASE WHEN CHARINDEX(N'NORMAS_V3', @d) > 0 THEN 'OK' ELSE 'FALTA -> correr V360_CONSULTOR_NORMAS_V3.sql' END;
END;
