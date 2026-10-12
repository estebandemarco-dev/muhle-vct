/* ========================================================================
   V360_CONSULTOR_NORMAS_V3
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca NORMAS_V3), drawer de Norma:
   1) El desplegable Servicio trae solo los servicios que el consultor tiene
      en la pestana Servicios (mas los que ya usan sus normas, para que una
      norma vieja se pueda editar). Orden: Consultoria, Auditoria, Capacitacion.
   2) Al guardar se valida lo mismo: el servicio tiene que ser del consultor
      (en una edicion se acepta el servicio que la norma ya tenia).
   Correr despues de V360_CONSULTOR_NORMAS_V2.sql. Re-ejecutable.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')),
        @s INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000), @a NVARCHAR(MAX);

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
IF CHARINDEX(N'NORMAS_V3', @d) > 0 BEGIN PRINT 'Ya estaba aplicado (NORMAS_V3). No se hizo nada.'; RETURN; END;
IF CHARINDEX(N'ORDER BY PS.DESCRIPCION,PS.ID', @d) = 0 OR CHARINDEX(N'SET @VFORM_ERROR=''El servicio seleccionado no existe.'';', @d) = 0
BEGIN
    PRINT 'No se encontraron las opciones de servicio del drawer de Norma o la validacion del servicio. No se aplico nada.';
    RETURN;
END;

/* 1. opciones (unica aparicion) */
SET @a = N'ORDER BY PS.DESCRIPCION,PS.ID';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'/* NORMAS_V3: solo servicios del consultor (y los que ya usan sus normas, para poder editarlas) */
              AND (EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CSN WITH(NOLOCK) WHERE CSN.ID_CONSULTOR=@ID_CONSULTOR AND CSN.ID_SERVICIO=PS.ID)
                   OR EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_NORMAS CNN WITH(NOLOCK) WHERE CNN.ID_CONSULTOR=@ID_CONSULTOR AND CNN.ID_SERVICIO=PS.ID))
            ORDER BY CASE PS.CODIGO WHEN ''CONSULTORIA'' THEN 1 WHEN ''AUDITORIA'' THEN 2 WHEN ''CAPACITACION'' THEN 3 ELSE 4 END,PS.ID');

/* 2. validacion (primera aparicion = bloque NORMA; la segunda es la de SERVCONS) */
SET @a = N'SET @VFORM_ERROR=''El servicio seleccionado no existe.'';';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'SET @VFORM_ERROR=''El servicio seleccionado no existe.'';
                /* NORMAS_V3: el servicio tiene que ser uno de los servicios del consultor
                   (en una edicion se acepta el servicio que la norma ya tenia) */
                ELSE IF OBJECT_ID(''dbo.VCT_CONSULTORES_SERVICIOS'',''U'') IS NOT NULL
                     AND NOT EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS WITH(NOLOCK) WHERE ID_CONSULTOR=@ID_CONSULTOR AND ID_SERVICIO=@EXEC_NORM_SERV)
                     AND NOT (@VFORM_ROW_ID<>'''' AND EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_NORMAS WITH(NOLOCK) WHERE ID_CONSULTOR=@ID_CONSULTOR AND CONVERT(VARCHAR(100),ID)=@VFORM_ROW_ID AND ID_SERVICIO=@EXEC_NORM_SERV))
                    SET @VFORM_ERROR=''El consultor no tiene ese servicio. Agr''+CHAR(233)+''guelo primero en la pesta''+CHAR(241)+''a Servicios.'';');
PRINT 'Pasos 1 y 2 preparados.';

SET @i = CHARINDEX(N'CREATE', @d);
WHILE @i > 0 AND @hecho = 0
BEGIN
    SET @rest = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@d, @i + 6, 60), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' '));
    IF @rest LIKE N'PROC%' BEGIN SET @d = STUFF(@d, @i, 6, N'ALTER'); SET @hecho = 1; END
    ELSE SET @i = CHARINDEX(N'CREATE', @d, @i + 6);
END;
IF @hecho = 0 BEGIN RAISERROR('No se encontro CREATE PROCEDURE. No se hizo nada.', 16, 1); RETURN; END;

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
BEGIN TRY
    IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    EXEC sp_executesql @d;
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 actualizado (servicios del drawer de Norma).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONSULTORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
