/* ========================================================================
   DIAG_CONSULTOR_V360_DEF
   ------------------------------------------------------------------------
   Solo lectura. Devuelve la definicion VIGENTE de dbo.VCT_MAIN_CONSULTORES_V360
   en una celda XML clickeable (no se corta como el texto de la grilla).
   Uso: F5 -> click en el link de la columna DEFINICION -> se abre en una
   pestana -> Ctrl+A, Ctrl+C y pegarlo en un archivo nuevo:
     C:\Users\EstebanDemarco\Desktop\Vocaturo\muhle-vct\_diag\VCT_MAIN_CONSULTORES_V360_actual.sql
   (se ve entre <?def ... ?>; copiar todo, incluido eso, no importa).
   Si al hacer click dice que el XML es muy grande: Herramientas > Opciones >
   Resultados de consultas > SQL Server > Resultados a cuadricula >
   Datos XML = Ilimitado.
   ======================================================================== */
USE [MuhlePROD];
SELECT (SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')) AS [processing-instruction(def)]
        FOR XML PATH(''), TYPE) AS DEFINICION;
GO
