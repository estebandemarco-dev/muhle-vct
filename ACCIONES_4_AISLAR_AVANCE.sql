/* ========================================================================
   ACCIONES_4_AISLAR_AVANCE  (v2: robusto a CRLF)
   ------------------------------------------------------------------------
   Separa el flujo de CERRAR/REABRIR gestion del recalculo de avance.
   Hoy VCT_MAIN_ACCIONES, despues de commitear el cambio de estado, llama
   VCT_PROYECTO_AVANCE_SYNC (que usa la funcion VCT_PROYECTO_AVANCE, BORRADA
   el 10/10). Ese EXEC esta dentro del TRY grande: si falla, la gestion ya
   quedo cambiada pero el usuario ve error rojo.

   Este parche envuelve SOLO ese EXEC en su propio TRY/CATCH: el cierre
   funciona igual aunque falte VCT_PROYECTO_AVANCE; el avance se sincroniza
   cuando la funcion vuelva. NO recrea nada borrado.

   Normaliza saltos de linea (CRLF->LF) antes del REPLACE. Re-ejecutable.
   Compat 100/140.
   ======================================================================== */
USE [MuhlePROD];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @D NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_ACCIONES'));
IF @D IS NULL
BEGIN
    RAISERROR('No existe dbo.VCT_MAIN_ACCIONES.',16,1);
    RETURN;
END;

IF CHARINDEX(N'AISLAR_AVANCE_V1', @D) > 0
BEGIN
    PRINT 'VCT_MAIN_ACCIONES ya tenia el flujo aislado. Sin cambios.';
    RETURN;
END;

/* normalizar fin de linea para que el anclaje matchee siempre */
SET @D = REPLACE(@D, NCHAR(13) + NCHAR(10), NCHAR(10));

DECLARE @NL NCHAR(1) = NCHAR(10);
DECLARE @ANCLA NVARCHAR(MAX) =
    N'            IF @ID_PROY_GE IS NOT NULL AND OBJECT_ID(''dbo.VCT_PROYECTO_AVANCE_SYNC'') IS NOT NULL' + @NL +
    N'                EXEC dbo.VCT_PROYECTO_AVANCE_SYNC @ID_PROYECTO = @ID_PROY_GE;';

IF (DATALENGTH(@D) - DATALENGTH(REPLACE(@D, @ANCLA, N''))) / NULLIF(DATALENGTH(@ANCLA),0) <> 1
BEGIN
    RAISERROR('No se encontro (o esta repetido) el bloque del EXEC de VCT_PROYECTO_AVANCE_SYNC. No se aplico nada.',16,1);
    RETURN;
END;

DECLARE @NUEVO NVARCHAR(MAX) =
    N'            /* AISLAR_AVANCE_V1: el recalculo de avance no debe frenar el cierre de la gestion */' + @NL +
    N'            IF @ID_PROY_GE IS NOT NULL AND OBJECT_ID(''dbo.VCT_PROYECTO_AVANCE_SYNC'') IS NOT NULL' + @NL +
    N'            BEGIN TRY' + @NL +
    N'                EXEC dbo.VCT_PROYECTO_AVANCE_SYNC @ID_PROYECTO = @ID_PROY_GE;' + @NL +
    N'            END TRY' + @NL +
    N'            BEGIN CATCH' + @NL +
    N'                /* si falta VCT_PROYECTO_AVANCE u otro, el cambio de estado ya quedo commiteado */' + @NL +
    N'            END CATCH;';

SET @D = REPLACE(@D, @ANCLA, @NUEVO);

/* CREATE -> ALTER en el encabezado (40 letras antes de PROCEDURE) */
DECLARE @kp INT = CHARINDEX(N'PROCEDURE', @D), @kpre NVARCHAR(60);
SET @kpre = SUBSTRING(@D, CASE WHEN @kp > 40 THEN @kp - 40 ELSE 1 END, CASE WHEN @kp > 40 THEN 40 ELSE @kp - 1 END);
IF CHARINDEX(N'OR ALTER', @kpre) = 0 AND CHARINDEX(N'CREATE', @kpre) > 0
    SET @D = STUFF(@D, (CASE WHEN @kp > 40 THEN @kp - 40 ELSE 1 END) + CHARINDEX(N'CREATE', @kpre) - 1, 6, N'ALTER');

BEGIN TRY
    EXEC sp_executesql @D;
    PRINT 'OK: VCT_MAIN_ACCIONES - el cierre/reabrir ya no depende de VCT_PROYECTO_AVANCE.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE() + ' (sin cambios)';
END CATCH;
GO
