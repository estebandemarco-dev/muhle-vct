/* DIAG_OBJETOS_FALTAN (solo lectura) - correr con Query > SQLCMD Mode
   Confirma cuales de nuestros objetos EXISTEN hoy en la base y cuales
   faltan (tras los DROP del 10/10). No cambia nada. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_OBJETOS_FALTAN.txt
USE [MuhlePROD];
SET NOCOUNT ON;

SELECT N AS OBJETO,
       CASE WHEN OBJECT_ID(N) IS NULL THEN 'FALTA' ELSE 'ok' END AS ESTADO
FROM (VALUES
    ('dbo.VCT_PROYECTO_AVANCE'),
    ('dbo.VCT_PROYECTO_AVANCE_SYNC'),
    ('dbo.VCT_HTML_ESC'),
    ('dbo.VCT_FMT_HORAS'),
    ('dbo.VCT_CK_VALOR'),
    ('dbo.VCT_PERFIL_PUEDE'),
    ('dbo.VCT_USER_HAS_ACTION'),
    ('dbo.VCT_USER_CAN_SEE_SIDEBAR'),
    ('dbo.VCT_PROYECTO_HORAS_USADAS_TXT'),
    ('dbo.VCT_MIG_PROY_IMPORTE'),
    ('dbo.VCT_EVENTO_PROCESAR'),
    ('dbo.VCT_EVENTO_REGISTRAR'),
    ('dbo.VCT_PROYECTO_LANZ_ESTADO'),
    ('dbo.VCT_PROYECTO_PLAN_CALC'),
    ('dbo.VCT_MAIN_ACCIONES'),
    ('dbo.VCT_MAIN_PROYECTO_V360'),
    ('dbo.VCT_MAIN_CONSULTORES_V360'),
    ('dbo.VCT_GET_SHELL'),
    ('dbo.VCT_MAIN_GET_ACTIONS'),
    ('dbo.VCT_PROYECTOS_DOCUMENTOS_ITEMS')
) T(N)
ORDER BY CASE WHEN OBJECT_ID(N) IS NULL THEN 0 ELSE 1 END, N;
GO
