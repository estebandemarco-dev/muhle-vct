/* DUMP_DASHBOARD (SOLO LECTURA) - Query > SQLCMD Mode (F5)
   Vuelca la definicion COMPLETA y VIGENTE de dbo.VCT_MAIN_DASHBOARD a un
   archivo, linea por linea (sin truncar), para ver como rutear la Agenda. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DASHBOARD_SERVIDOR.txt
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @NAME SYSNAME = 'dbo.VCT_MAIN_DASHBOARD';
DECLARE @D NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(@NAME));

IF @D IS NULL
BEGIN
    RAISERROR('No se encontro %s.',16,1,@NAME);
    RETURN;
END;

DECLARE @TOTAL INT = DATALENGTH(@D) / 2;
DECLARE @P INT = 1, @E INT, @LINE NVARCHAR(MAX), @N INT = 0;

WHILE @P <= @TOTAL
BEGIN
    SET @E = CHARINDEX(NCHAR(10), @D, @P);
    IF @E = 0 SET @E = @TOTAL + 1;
    SET @LINE = SUBSTRING(@D, @P, @E - @P);
    IF DATALENGTH(@LINE) > 0 AND RIGHT(@LINE, 1) = NCHAR(13)
        SET @LINE = SUBSTRING(@LINE, 1, (DATALENGTH(@LINE) / 2) - 1);
    SET @N = @N + 1;
    PRINT RIGHT('     ' + CONVERT(VARCHAR(5), @N), 5) + ': ' + @LINE;
    SET @P = @E + 1;
END;
GO
