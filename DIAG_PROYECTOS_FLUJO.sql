/* ========================================================================
   DIAG_PROYECTOS_FLUJO  (solo lectura, no modifica nada)
   Muestra como esta cableado en el flujo de la plataforma el menu
   Proyectos (ACTION = PROYECTOS) y si existe PROYECTOS_OTROS.
   ======================================================================== */
SET NOCOUNT ON;

SELECT STEP_NUMBER, STEP_TO_NUMBER, TRAN_CODE, PRM_VALUE, STEP_TO_CAPTION,
       CONVERT(VARCHAR(36), CONV_STRUCTURE_KEY)    AS ESTRUCTURA,
       CONVERT(VARCHAR(36), CONV_STRUCTURE_TO_KEY) AS ESTRUCTURA_DESTINO
FROM dbo.STEP_TRANSACTION_FLOW
WHERE UPPER(CONVERT(NVARCHAR(400), PRM_VALUE)) LIKE '%PROYECTOS%'
   OR UPPER(CONVERT(NVARCHAR(400), PRM_VALUE)) LIKE '%ACCIONES%'
   OR UPPER(CONVERT(NVARCHAR(400), PRM_VALUE)) LIKE '%PLANIFICACION%'
ORDER BY ESTRUCTURA, STEP_NUMBER, STEP_TO_NUMBER;
