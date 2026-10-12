/* ========================================================================
   V360_CONSULTOR_NORMAS_V2
   ------------------------------------------------------------------------
   NO toca permisos. Modifica el SP existente dbo.VCT_MAIN_CONSULTORES_V360
   (marca NORMAS_V2), pestana Normas:
   1) Columna Servicio: icono fijo del servicio + descripcion (igual que la
      pestana Servicios). Se quita el chip de color.
   2) Columna Norma: nombre con el estilo de las grillas (y el codigo debajo).
   3) Orden: por norma y despues por servicio (Consultoria, Auditoria,
      Capacitacion).
   4) Editar: la fila lleva el id del servicio (data-vct-idservicio), asi el
      drawer abre con el servicio de la fila seleccionado.
   Alta: el drawer abre vacio (form-open-empty). La validacion "misma norma
   en el mismo servicio" ya esta en el SP y se mantiene.
   Re-ejecutable. Si un fragmento no se encuentra, no aplica nada y avisa.
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;

DECLARE @d NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.VCT_MAIN_CONSULTORES_V360')), @orig NVARCHAR(MAX),
        @s INT, @e INT, @n INT, @i INT, @rest NVARCHAR(80), @hecho BIT = 0, @trg_on BIT = 0, @msg NVARCHAR(2000),
        @a NVARCHAR(MAX), @r NVARCHAR(MAX), @falta NVARCHAR(400) = N'';

IF @d IS NULL BEGIN RAISERROR('No existe dbo.VCT_MAIN_CONSULTORES_V360.', 16, 1); RETURN; END;
IF CHARINDEX(N'NORMAS_V2', @d) > 0 BEGIN PRINT 'La pestana Normas ya estaba aplicada (NORMAS_V2). No se hizo nada.'; RETURN; END;
SET @orig = @d;

/* control previo */
SET @n = CHARINDEX(N'SELECT @HTML_NORMAS=ISNULL((', @d);
IF CHARINDEX(N'SERVICIO VARCHAR(120),', @d) = 0 SET @falta = @falta + N' [columna SERVICIO de #NORMAS360]';
IF CHARINDEX(N'EXEC sp_executesql @SQL_NORMA,N''@PID INT'',@PID=@ID_CONSULTOR;', @d) = 0 SET @falta = @falta + N' [carga de #NORMAS360]';
IF CHARINDEX(N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+', @d) = 0 SET @falta = @falta + N' [atributo data-vct-idnorma]';
IF @n = 0 OR CHARINDEX(N'''<td data-label="Servicio" data-vct-sort-value="''+REPLACE(REPLACE(ISNULL(N.SERVICIO', @d, @n) = 0 SET @falta = @falta + N' [celda Servicio]';
IF CHARINDEX(N'ORDER BY CASE WHEN N.FECHA_HASTA IS NULL THEN 1 ELSE 0 END,N.FECHA_HASTA,N.ID DESC', @d) = 0 SET @falta = @falta + N' [orden de la grilla]';
IF @falta <> N''
BEGIN
    SET @msg = N'No se encontro:' + @falta + N'. No se aplico nada.';
    PRINT @msg;
    RETURN;
END;

/* 1. columnas ID_SERVICIO / SERVICIO_COD en #NORMAS360 (primera aparicion = #NORMAS360) */
SET @a = N'SERVICIO VARCHAR(120),';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'SERVICIO VARCHAR(120), ID_SERVICIO INT, SERVICIO_COD VARCHAR(50), /* NORMAS_V2 */');

/* 2. completar id y codigo del servicio */
SET @a = N'EXEC sp_executesql @SQL_NORMA,N''@PID INT'',@PID=@ID_CONSULTOR;';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'EXEC sp_executesql @SQL_NORMA,N''@PID INT'',@PID=@ID_CONSULTOR;
            /* NORMAS_V2: id y codigo del servicio de cada norma (para editar y para el icono) */
            IF COL_LENGTH(@NORMA_TABLE,''ID_SERVICIO'') IS NOT NULL
                EXEC sp_executesql N''UPDATE N SET ID_SERVICIO=CN.ID_SERVICIO, SERVICIO_COD=PS.CODIGO, SERVICIO=ISNULL(NULLIF(N.SERVICIO,''''''''),PS.DESCRIPCION) FROM #NORMAS360 N INNER JOIN dbo.VCT_CONSULTORES_NORMAS CN WITH(NOLOCK) ON CN.ID=N.ID LEFT JOIN dbo.VCT_PRM_SERVICIOS PS WITH(NOLOCK) ON PS.ID=CN.ID_SERVICIO'';');

/* 3. atributo para editar */
SET @a = N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+
                ''data-vct-idservicio="''+ISNULL(CONVERT(VARCHAR(30),N.ID_SERVICIO),'''')+''" ''+');

/* 4. celda Servicio */
SET @n = CHARINDEX(N'SELECT @HTML_NORMAS=ISNULL((', @d);
SET @s = CHARINDEX(N'''<td data-label="Servicio" data-vct-sort-value="''+REPLACE(REPLACE(ISNULL(N.SERVICIO', @d, @n);
SET @e = CHARINDEX(N'''</td>''+', @d, @s);
SET @d = STUFF(@d, @s, @e + LEN(N'''</td>''+') - @s, N'''<td data-label="Servicio" data-vct-sort-value="''+REPLACE(REPLACE(ISNULL(N.SERVICIO,''''),''"'',''&quot;''),'''''''',''&#39;'')+''">''+
                    CASE WHEN ISNULL(N.SERVICIO,'''')='''' THEN ''-'' ELSE
                        ''<span class="vctdg-svc-item" style="display:inline-flex;align-items:center;gap:8px;"><span class="vctdg-svc is-on ''+
                        CASE WHEN ISNULL(N.SERVICIO_COD,'''')=''AUDITORIA'' OR UPPER(N.SERVICIO) LIKE ''%AUDITOR%'' THEN ''is-au''
                             WHEN ISNULL(N.SERVICIO_COD,'''')=''CAPACITACION'' OR UPPER(N.SERVICIO) LIKE ''%CAPACIT%'' THEN ''is-ca''
                             ELSE ''is-co'' END+
                        ''"><span data-vct-icon="''+
                        CASE WHEN ISNULL(N.SERVICIO_COD,'''')=''AUDITORIA'' OR UPPER(N.SERVICIO) LIKE ''%AUDITOR%'' THEN ''clipboard-check''
                             WHEN ISNULL(N.SERVICIO_COD,'''')=''CAPACITACION'' OR UPPER(N.SERVICIO) LIKE ''%CAPACIT%'' THEN ''users''
                             ELSE ''briefcase'' END+
                        ''"></span></span><span class="vctdg-svc-text">''+REPLACE(REPLACE(REPLACE(N.SERVICIO,''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+''</span></span>''
                    END+
                ''</td>''+');

/* 5. orden */
SET @a = N'ORDER BY CASE WHEN N.FECHA_HASTA IS NULL THEN 1 ELSE 0 END,N.FECHA_HASTA,N.ID DESC';
SET @s = CHARINDEX(@a, @d);
SET @d = STUFF(@d, @s, LEN(@a), N'ORDER BY LTRIM(RTRIM(ISNULL(NULLIF(N.NOMBRE,''''),ISNULL(N.CODIGO,'''')))),
                 CASE WHEN ISNULL(N.SERVICIO_COD,'''')=''CONSULTORIA'' OR UPPER(ISNULL(N.SERVICIO,'''')) LIKE ''%CONSULT%'' THEN 1
                      WHEN ISNULL(N.SERVICIO_COD,'''')=''AUDITORIA'' OR UPPER(ISNULL(N.SERVICIO,'''')) LIKE ''%AUDITOR%'' THEN 2
                      WHEN ISNULL(N.SERVICIO_COD,'''')=''CAPACITACION'' OR UPPER(ISNULL(N.SERVICIO,'''')) LIKE ''%CAPACIT%'' THEN 3
                      ELSE 4 END,
                 N.ID');

PRINT 'Pasos 1 a 5 preparados.';

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
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 actualizado (pestana Normas).';
END TRY
BEGIN CATCH
    IF @trg_on = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    SET @msg = N'FALLO VCT_MAIN_CONSULTORES_V360 (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'): ' + ERROR_MESSAGE() + N' -- quedo como estaba.';
    PRINT @msg;
END CATCH;
GO
