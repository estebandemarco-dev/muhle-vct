/* DIAG_FLOW_DETAILS (SOLO LECTURA) - Query > SQLCMD Mode (F5), ventana NUEVA.
   Vuelca CONV_STRUCTURE_DETAILS (donde el step-script ata el SP) de la
   estructura que ANDA (C576D92F = Configuracion) vs la de AGENDA (EE2B3F6F),
   linea por linea para no truncar. Asi vemos que SP referencia cada una. */
:OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_FLOW_DETAILS.txt
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @keys TABLE (k VARCHAR(36), etiqueta VARCHAR(40));
INSERT INTO @keys VALUES
 ('C576D92F-6A0A-4E7A-8F0C-48BF0C05F404','CONFIGURACION (anda)'),
 ('EE2B3F6F-4900-4C8C-A287-D4630D65B344','AGENDA (no anda)');

DECLARE @k VARCHAR(36), @et VARCHAR(40), @D NVARCHAR(MAX), @TOTAL INT, @P INT, @E INT, @LINE NVARCHAR(MAX), @N INT;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT k, etiqueta FROM @keys;
OPEN c; FETCH NEXT FROM c INTO @k, @et;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '';
    PRINT '================= ' + @et + '  [' + @k + '] =================';

    SELECT @D = CONVERT(NVARCHAR(MAX), CONV_STRUCTURE_DETAILS)
    FROM dbo.CALL_CONV_STRUCTURES WHERE CONVERT(VARCHAR(36), PKEY) = @k;

    IF @D IS NULL OR LTRIM(RTRIM(@D)) = ''
        PRINT '(CONV_STRUCTURE_DETAILS vacio o NULL)';
    ELSE
    BEGIN
        /* un salto de linea cada > o cada CRLF, para que sea legible */
        SET @D = REPLACE(REPLACE(@D, NCHAR(13)+NCHAR(10), NCHAR(10)), '>', '>' + NCHAR(10));
        SET @TOTAL = DATALENGTH(@D)/2; SET @P = 1; SET @N = 0;
        WHILE @P <= @TOTAL
        BEGIN
            SET @E = CHARINDEX(NCHAR(10), @D, @P);
            IF @E = 0 SET @E = @TOTAL + 1;
            SET @LINE = SUBSTRING(@D, @P, @E - @P);
            IF LTRIM(RTRIM(@LINE)) <> ''
            BEGIN
                SET @N = @N + 1;
                PRINT @LINE;
            END;
            SET @P = @E + 1;
        END;
    END;

    FETCH NEXT FROM c INTO @k, @et;
END;
CLOSE c; DEALLOCATE c;

PRINT '';
PRINT '===== FIN =====';
GO
