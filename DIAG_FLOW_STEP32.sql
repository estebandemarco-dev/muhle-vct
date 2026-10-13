/* DIAG_FLOW_STEP32 (SOLO LECTURA) - Query > SQLCMD Mode (F5), ventana NUEVA.
   Lista los pasos de la estructura del menu padre (C31037CE) donde vive la
   decision. Queremos ver si existe el paso 32 (-> "16 - Agenda") igual que
   el paso 18 (-> "99 - Configuracion"). No cambia nada. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_FLOW_STEP32.txt
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @PADRE VARCHAR(36) = 'C31037CE-DE04-4735-9C59-8658C1C8C4F3';

PRINT '===== pasos NORMAL de la estructura padre (ordenado por paso) =====';
SELECT STEP_NUMBER, STEP_TYPE_CODE, STEP_AGENT_CAPTION, CONVERT(VARCHAR(36),PKEY) AS PKEY
FROM dbo.CONV_STRUCTURE_STEP_NORMAL
WHERE CONVERT(VARCHAR(36), PAR_KEY) = @PADRE
ORDER BY STEP_NUMBER;

PRINT '';
PRINT '===== pasos TRANSACCION de la estructura padre =====';
SELECT STEP_NUMBER, STEP_TYPE_CODE, TRAN_CODE, STEP_AGENT_CAPTION
FROM dbo.CONV_STRUCTURE_STEP_TRAN
WHERE CONVERT(VARCHAR(36), PAR_KEY) = @PADRE
ORDER BY STEP_NUMBER;

PRINT '';
PRINT '===== transiciones de la decision (paso 2) en la estructura padre =====';
SELECT STEP_NUMBER, STEP_TO_NUMBER, TRAN_CODE,
       CONVERT(VARCHAR(36),CONV_STRUCTURE_TO_KEY) AS ESTRUCTURA_DESTINO,
       STEP_TO_CAPTION, PRM_VALUE
FROM dbo.STEP_TRANSACTION_FLOW
WHERE CONVERT(VARCHAR(36), CONV_STRUCTURE_KEY) = @PADRE
ORDER BY STEP_NUMBER, STEP_TO_NUMBER;

PRINT '';
PRINT '===== FIN =====';
GO
