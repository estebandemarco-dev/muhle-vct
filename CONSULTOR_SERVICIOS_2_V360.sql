/* ========================================================================
   CONSULTOR_SERVICIOS_2_V360
   ------------------------------------------------------------------------
   Punto 1 del plan (CLAVE): servicios del consultor y normas por servicio.
   PARCHE sobre la definicion VIGENTE de dbo.VCT_MAIN_CONSULTORES_V360:
     - Solapa nueva "Servicios" (antes de Normas): lista los servicios del
       consultor (VCT_CONSULTORES_SERVICIOS) con cantidad de normas por
       servicio; Agregar / Editar / Eliminar. No deja quitar un servicio que
       tenga normas cargadas, ni repetir un servicio.
     - Norma: campo Servicio obligatorio (TEXTO15) con los servicios del
       consultor. La misma norma puede estar una vez por servicio.
       Duplicado = misma norma + mismo servicio (como UQ_VCT_CONSULTORES_NORMAS).
       Hoy el alta de norma falla porque ID_SERVICIO es NOT NULL y no se grababa.
     - Grilla de Normas: columna Servicio, filtro por servicio, orden por
       norma y servicio, y opcion Eliminar en el menu de la fila.
   Requiere: VCT_CONSULTORES_SERVICIOS, VCT_PRM_SERVICIOS y
   VCT_CONSULTORES_NORMAS.ID_SERVICIO (CONSULTOR_SERVICIOS_1_MODELO.sql).
   No cambia css ni js. Anda en compat 100 y 140.
   Si algun fragmento no se encuentra (o esta repetido), NO aplica nada y
   avisa cuales. Si ya fue aplicado (marca SERVICIOS_V1), no hace nada.
   ======================================================================== */
USE [MuhlePROD];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @D NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_CONSULTORES_V360'));
DECLARE @s INT, @e INT;

IF @D IS NULL
BEGIN
    RAISERROR('No se encontro dbo.VCT_MAIN_CONSULTORES_V360.',16,1);
    RETURN;
END;

IF CHARINDEX(N'SERVICIOS_V1',@D) > 0
BEGIN
    PRINT 'VCT_MAIN_CONSULTORES_V360 ya tenia los servicios (SERVICIOS_V1). No se hizo nada.';
    RETURN;
END;

IF OBJECT_ID('dbo.VCT_CONSULTORES_SERVICIOS','U') IS NULL
   OR OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NULL
   OR COL_LENGTH('dbo.VCT_CONSULTORES_NORMAS','ID_SERVICIO') IS NULL
   OR COL_LENGTH('dbo.VCT_CONSULTORES_NORMAS','USUARIO_ALTA') IS NULL
   OR COL_LENGTH('dbo.VCT_CONSULTORES_NORMAS','USUARIO_UPD') IS NULL
   OR COL_LENGTH('dbo.VCT_CONSULTORES_NORMAS','FECHA_UPD') IS NULL
BEGIN
    RAISERROR('Falta el modelo de servicios: correr antes CONSULTOR_SERVICIOS_1_MODELO.sql. No se aplico nada.',16,1);
    RETURN;
END;

SET @D = REPLACE(@D, NCHAR(13)+NCHAR(10), NCHAR(10));

/* ---- fragmentos que tienen que estar exactamente una vez ---- */
DECLARE @chk TABLE (mk NVARCHAR(MAX));
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    /* Días mensuales: detección del modelo para alta de historial. */');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'       6. ELIMINAR');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'        /* ---------------- DIAS MENSUALES ---------------- */');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_SET NVARCHAR(MAX)=QUOTENAME(@NORM_IDNORMA_COL)+N''=@PNORMA'';');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'@POBS VARCHAR(2000),@ORC INT OUTPUT'',');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS,');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_INSERT_VALS NVARCHAR(MAX)=N''@PID,@PNORMA'';');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'N''@PID INT,@PNORMA INT,@PCALIF VARCHAR(1000),@PDESDE DATETIME,@POBS VARCHAR(2000)'',');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS;');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'CREATE TABLE #NORMAS360' + NCHAR(10) + N'    (' + NCHAR(10) + N'        ID INT,' + NCHAR(10) + N'        ID_NORMA INT,');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    /* ---------------- HISTORICO DE DIAS ---------------- */');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'                CASE WHEN @NormHasEstado=1 THEN' + NCHAR(10) + N'                    ''<td class="vct-text-center" data-label="''+@NORMA_ESTADO_LABEL+''"><span class="vct-360-badge ''+');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-command="row-context-menu" data-vct-actions="edit" ''+' + NCHAR(10) + N'                              ''data-vct-target="vctDrawerConsultorNorma" ''+');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'        FROM #NORMAS360 N' + NCHAR(10) + N'        ORDER BY CASE WHEN N.FECHA_HASTA IS NULL THEN 1 ELSE 0 END,N.FECHA_HASTA,N.ID DESC');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'''<th data-vct-sort="norma" data-vct-sortable="true"><span>Norma</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'data-vct-dg-search-placeholder="Buscar norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    IF @HTML_NORMAS=''''' + NCHAR(10) + N'');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    SELECT @HistHasProject=');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    (1,''TEXTO11'',''Norma'',''TEXT'',12,1,100,''Seleccione una norma'',NULL,');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_NORMAS_OPTIONS,'''')+' + NCHAR(10) + N'        ''</template>'';');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'    /* Días mensuales */' + NCHAR(10) + N'    DELETE FROM #VCT_FORM_FIELDS;');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'<button type="button" data-vct-tab="normas">');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="normas">');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_DRAWER_NORMA,'''')+' + NCHAR(10) + N'        ISNULL(@HTML_DRAWER_HIST,'''');');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'            /* Una norma se registra una sola vez por consultor. */');
INSERT INTO @chk VALUES (CONVERT(NVARCHAR(MAX),N'')+N'                    SET @VFORM_ERROR=''El consultor ya tiene registrada esa norma.'';' + NCHAR(10) + N'            END;');

DECLARE @bad NVARCHAR(MAX) = N'';
SELECT @bad = @bad + N' [' + LEFT(REPLACE(mk, NCHAR(10), N' '), 90) + N'] x'
            + CONVERT(NVARCHAR(10), (DATALENGTH(@D) - DATALENGTH(REPLACE(@D, mk, N''))) / NULLIF(DATALENGTH(mk),0))
FROM @chk
WHERE (DATALENGTH(@D) - DATALENGTH(REPLACE(@D, mk, N''))) / NULLIF(DATALENGTH(mk),0) <> 1;
IF @bad <> N''
BEGIN
    PRINT N'Fragmentos no encontrados o repetidos (veces):' + @bad;
    RAISERROR('La definicion del servidor no coincide con la esperada. No se aplico nada (ver PRINT).',16,1);
    RETURN;
END;

DECLARE @a NVARCHAR(MAX), @n NVARCHAR(MAX);

/* ---- 1. variables ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    /* Días mensuales: detección del modelo para alta de historial. */';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    /* SERVICIOS_V1: servicios del consultor y servicio de cada norma */' + NCHAR(10) + N'    DECLARE' + NCHAR(10) + N'        @EXEC_SRV_ID INT=NULL,' + NCHAR(10) + N'        @EXEC_SRV_OLD INT=NULL,' + NCHAR(10) + N'        @EXEC_SRV_OBS VARCHAR(2000)=NULL,' + NCHAR(10) + N'        @EXEC_NORM_SRV INT=NULL,' + NCHAR(10) + N'        @SRV_NORMAS INT=0,' + NCHAR(10) + N'        @ServiciosCount INT=0,' + NCHAR(10) + N'        @HTML_SERVICIOS VARCHAR(MAX)='''',' + NCHAR(10) + N'        @HTML_NORMAS_FILTRO VARCHAR(MAX)='''',' + NCHAR(10) + N'        @BTN_ADD_SERV VARCHAR(MAX)='''',' + NCHAR(10) + N'        @HTML_DRAWER_SERV VARCHAR(MAX)='''',' + NCHAR(10) + N'        @HTML_SERV_OPTIONS VARCHAR(MAX)='''',' + NCHAR(10) + N'        @HTML_NORMA_SERV_OPTIONS VARCHAR(MAX)='''',' + NCHAR(10) + N'        @ERR_SERV VARCHAR(MAX)='''',' + NCHAR(10) + N'        @OPEN_SERV BIT=0;' + NCHAR(10) + N'' + NCHAR(10) + N'    /* Días mensuales: detección del modelo para alta de historial. */';
SET @D = REPLACE(@D, @a, @n);

/* ---- 2. eliminar servicio y norma ---- */
SET @s = CHARINDEX(CONVERT(NVARCHAR(MAX),N'')+N'        SET @VFORM_REOPEN=CASE WHEN @VFORM_ERROR<>'''' THEN 1 ELSE 0 END;', @D, CHARINDEX(CONVERT(NVARCHAR(MAX),N'')+N'       6. ELIMINAR', @D));
IF @s = 0 BEGIN RAISERROR('No se encontro el cierre de ELIMINAR. No se aplico nada.',16,1); RETURN; END;
SET @D = STUFF(@D, @s, 0, CONVERT(NVARCHAR(MAX),N'')+N'        /* SERVICIOS_V1: eliminar servicio (solo si no tiene normas) y eliminar norma */' + NCHAR(10) + N'        IF @VFORM_ERROR='''' AND @VFORM_ENTITY=''SERVICIO''' + NCHAR(10) + N'        BEGIN' + NCHAR(10) + N'            SET @ACTIVE_TAB=''servicios'';' + NCHAR(10) + N'            SET @EXEC_SRV_OLD=NULL;' + NCHAR(10) + N'' + NCHAR(10) + N'            SELECT @EXEC_SRV_OLD=CS.ID_SERVICIO' + NCHAR(10) + N'            FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)' + NCHAR(10) + N'            WHERE CS.ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'              AND CONVERT(VARCHAR(100),CS.ID)=@VFORM_ROW_ID;' + NCHAR(10) + N'' + NCHAR(10) + N'            IF @EXEC_SRV_OLD IS NULL' + NCHAR(10) + N'                SET @VFORM_ERROR=''El servicio seleccionado ya no existe o no pertenece al consultor.'';' + NCHAR(10) + N'            ELSE' + NCHAR(10) + N'            BEGIN' + NCHAR(10) + N'                SELECT @SRV_NORMAS=COUNT(*)' + NCHAR(10) + N'                FROM dbo.VCT_CONSULTORES_NORMAS WITH(NOLOCK)' + NCHAR(10) + N'                WHERE ID_CONSULTOR=@ID_CONSULTOR AND ID_SERVICIO=@EXEC_SRV_OLD;' + NCHAR(10) + N'' + NCHAR(10) + N'                IF @SRV_NORMAS>0' + NCHAR(10) + N'                    SET @VFORM_ERROR=''El consultor tiene ''+CONVERT(VARCHAR(10),@SRV_NORMAS)+'' norma(s) cargada(s) para este servicio. Elimínelas antes de quitar el servicio.'';' + NCHAR(10) + N'                ELSE' + NCHAR(10) + N'                    DELETE FROM dbo.VCT_CONSULTORES_SERVICIOS' + NCHAR(10) + N'                    WHERE ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                      AND CONVERT(VARCHAR(100),ID)=@VFORM_ROW_ID;' + NCHAR(10) + N'            END;' + NCHAR(10) + N'        END;' + NCHAR(10) + N'' + NCHAR(10) + N'        IF @VFORM_ERROR='''' AND @VFORM_ENTITY=''NORMA''' + NCHAR(10) + N'        BEGIN' + NCHAR(10) + N'            SET @ACTIVE_TAB=''normas'';' + NCHAR(10) + N'' + NCHAR(10) + N'            DELETE FROM dbo.VCT_CONSULTORES_NORMAS' + NCHAR(10) + N'            WHERE ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'              AND CONVERT(VARCHAR(100),ID)=@VFORM_ROW_ID;' + NCHAR(10) + N'' + NCHAR(10) + N'            IF @@ROWCOUNT=0' + NCHAR(10) + N'                SET @VFORM_ERROR=''La norma seleccionada ya no existe o no pertenece al consultor.'';' + NCHAR(10) + N'        END;' + NCHAR(10) + N'' + NCHAR(10) + N'');

/* ---- 3. guardar servicio ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'        /* ---------------- DIAS MENSUALES ---------------- */';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'        /* ---------------- SERVICIO (SERVICIOS_V1) ---------------- */' + NCHAR(10) + N'        IF @VFORM_ERROR='''' AND @VFORM_ENTITY=''SERVICIO''' + NCHAR(10) + N'        BEGIN' + NCHAR(10) + N'            SET @ACTIVE_TAB=''servicios'';' + NCHAR(10) + N'            SET @EXEC_SRV_ID=NULL;' + NCHAR(10) + N'            SET @EXEC_SRV_OLD=NULL;' + NCHAR(10) + N'            SET @EXEC_SRV_OBS=NULLIF(LTRIM(RTRIM(@VFORM_T12)),'''');' + NCHAR(10) + N'' + NCHAR(10) + N'            IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'''') IS NULL' + NCHAR(10) + N'                SET @VFORM_ERROR=''El servicio es obligatorio.'';' + NCHAR(10) + N'            ELSE IF LTRIM(RTRIM(@VFORM_T11)) LIKE ''%[^0-9]%''' + NCHAR(10) + N'                SET @VFORM_ERROR=''El servicio seleccionado no es válido.'';' + NCHAR(10) + N'            ELSE' + NCHAR(10) + N'            BEGIN' + NCHAR(10) + N'                SELECT @EXEC_SRV_ID=S.ID' + NCHAR(10) + N'                FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK)' + NCHAR(10) + N'                WHERE CONVERT(VARCHAR(100),S.ID)=LTRIM(RTRIM(@VFORM_T11));' + NCHAR(10) + N'' + NCHAR(10) + N'                IF @EXEC_SRV_ID IS NULL' + NCHAR(10) + N'                    SET @VFORM_ERROR=''El servicio seleccionado no existe.'';' + NCHAR(10) + N'            END;' + NCHAR(10) + N'' + NCHAR(10) + N'            /* Edicion: si cambia el servicio, el anterior no puede tener normas cargadas. */' + NCHAR(10) + N'            IF @VFORM_ERROR='''' AND @VFORM_ROW_ID<>''''' + NCHAR(10) + N'            BEGIN' + NCHAR(10) + N'                SELECT @EXEC_SRV_OLD=CS.ID_SERVICIO' + NCHAR(10) + N'                FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)' + NCHAR(10) + N'                WHERE CS.ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                  AND CONVERT(VARCHAR(100),CS.ID)=@VFORM_ROW_ID;' + NCHAR(10) + N'' + NCHAR(10) + N'                IF @EXEC_SRV_OLD IS NULL' + NCHAR(10) + N'                    SET @VFORM_ERROR=''El servicio a editar ya no existe o no pertenece al consultor.'';' + NCHAR(10) + N'                ELSE IF @EXEC_SRV_OLD<>@EXEC_SRV_ID' + NCHAR(10) + N'                BEGIN' + NCHAR(10) + N'                    SELECT @SRV_NORMAS=COUNT(*)' + NCHAR(10) + N'                    FROM dbo.VCT_CONSULTORES_NORMAS WITH(NOLOCK)' + NCHAR(10) + N'                    WHERE ID_CONSULTOR=@ID_CONSULTOR AND ID_SERVICIO=@EXEC_SRV_OLD;' + NCHAR(10) + N'' + NCHAR(10) + N'                    IF @SRV_NORMAS>0' + NCHAR(10) + N'                        SET @VFORM_ERROR=''No se puede cambiar el servicio: tiene ''+CONVERT(VARCHAR(10),@SRV_NORMAS)+'' norma(s) cargada(s).'';' + NCHAR(10) + N'                END;' + NCHAR(10) + N'            END;' + NCHAR(10) + N'' + NCHAR(10) + N'            /* Un servicio una sola vez por consultor. */' + NCHAR(10) + N'            IF @VFORM_ERROR=''''' + NCHAR(10) + N'               AND EXISTS(SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS WITH(NOLOCK)' + NCHAR(10) + N'                          WHERE ID_CONSULTOR=@ID_CONSULTOR AND ID_SERVICIO=@EXEC_SRV_ID' + NCHAR(10) + N'                            AND (@VFORM_ROW_ID='''' OR CONVERT(VARCHAR(100),ID)<>@VFORM_ROW_ID))' + NCHAR(10) + N'                SET @VFORM_ERROR=''El consultor ya tiene ese servicio.'';' + NCHAR(10) + N'' + NCHAR(10) + N'            IF @VFORM_ERROR=''''' + NCHAR(10) + N'            BEGIN TRY' + NCHAR(10) + N'                IF @VFORM_ROW_ID=''''' + NCHAR(10) + N'                    INSERT INTO dbo.VCT_CONSULTORES_SERVICIOS' + NCHAR(10) + N'                        (ID_CONSULTOR,ID_SERVICIO,OBSERVACIONES,FECHA_ALTA,USUARIO_ALTA)' + NCHAR(10) + N'                    VALUES' + NCHAR(10) + N'                        (@ID_CONSULTOR,@EXEC_SRV_ID,@EXEC_SRV_OBS,GETDATE(),@IAGENTE);' + NCHAR(10) + N'                ELSE' + NCHAR(10) + N'                    UPDATE dbo.VCT_CONSULTORES_SERVICIOS' + NCHAR(10) + N'                       SET ID_SERVICIO=@EXEC_SRV_ID,' + NCHAR(10) + N'                           OBSERVACIONES=@EXEC_SRV_OBS,' + NCHAR(10) + N'                           FECHA_UPD=GETDATE(),' + NCHAR(10) + N'                           USUARIO_UPD=@IAGENTE' + NCHAR(10) + N'                     WHERE ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                       AND CONVERT(VARCHAR(100),ID)=@VFORM_ROW_ID;' + NCHAR(10) + N'            END TRY' + NCHAR(10) + N'            BEGIN CATCH' + NCHAR(10) + N'                SET @VFORM_ERROR=ERROR_MESSAGE();' + NCHAR(10) + N'            END CATCH;' + NCHAR(10) + N'        END;' + NCHAR(10) + N'' + NCHAR(10) + N'        /* ---------------- DIAS MENSUALES ---------------- */';
SET @D = REPLACE(@D, @a, @n);

/* ---- 4. norma: servicio y duplicados (bloque) ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'            /* Una norma se registra una sola vez por consultor. */';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'                    SET @VFORM_ERROR=''El consultor ya tiene registrada esa norma.'';' + NCHAR(10) + N'            END;';
SET @s = CHARINDEX(@a, @D);
SET @e = CHARINDEX(@n, @D, @s) + LEN(@n + N'x') - 1;
SET @D = STUFF(@D, @s, @e - @s, CONVERT(NVARCHAR(MAX),N'')+N'            /* SERVICIOS_V1: servicio obligatorio, uno de los servicios del consultor.' + NCHAR(10) + N'               En una edicion se acepta tambien el servicio que la norma ya tenia. */' + NCHAR(10) + N'            SET @EXEC_NORM_SRV=NULL;' + NCHAR(10) + N'            IF @VFORM_ERROR=''''' + NCHAR(10) + N'            BEGIN' + NCHAR(10) + N'                IF NULLIF(LTRIM(RTRIM(@VFORM_T15)),'''') IS NULL' + NCHAR(10) + N'                    SET @VFORM_ERROR=''El servicio es obligatorio.'';' + NCHAR(10) + N'                ELSE IF LTRIM(RTRIM(@VFORM_T15)) LIKE ''%[^0-9]%''' + NCHAR(10) + N'                    SET @VFORM_ERROR=''El servicio seleccionado no es válido.'';' + NCHAR(10) + N'                ELSE' + NCHAR(10) + N'                BEGIN' + NCHAR(10) + N'                    SELECT @EXEC_NORM_SRV=CS.ID_SERVICIO' + NCHAR(10) + N'                    FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)' + NCHAR(10) + N'                    WHERE CS.ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                      AND CONVERT(VARCHAR(100),CS.ID_SERVICIO)=LTRIM(RTRIM(@VFORM_T15));' + NCHAR(10) + N'' + NCHAR(10) + N'                    IF @EXEC_NORM_SRV IS NULL AND @VFORM_ROW_ID<>''''' + NCHAR(10) + N'                        SELECT @EXEC_NORM_SRV=N.ID_SERVICIO' + NCHAR(10) + N'                        FROM dbo.VCT_CONSULTORES_NORMAS N WITH(NOLOCK)' + NCHAR(10) + N'                        WHERE N.ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                          AND CONVERT(VARCHAR(100),N.ID)=@VFORM_ROW_ID' + NCHAR(10) + N'                          AND CONVERT(VARCHAR(100),N.ID_SERVICIO)=LTRIM(RTRIM(@VFORM_T15));' + NCHAR(10) + N'' + NCHAR(10) + N'                    IF @EXEC_NORM_SRV IS NULL' + NCHAR(10) + N'                        SET @VFORM_ERROR=''El consultor no tiene ese servicio. Agréguelo primero en la solapa Servicios.'';' + NCHAR(10) + N'                END;' + NCHAR(10) + N'            END;' + NCHAR(10) + N'' + NCHAR(10) + N'            /* SERVICIOS_V1: una norma por servicio y consultor (como el indice UQ_VCT_CONSULTORES_NORMAS). */' + NCHAR(10) + N'            IF @VFORM_ERROR=''''' + NCHAR(10) + N'               AND EXISTS(SELECT 1 FROM dbo.VCT_CONSULTORES_NORMAS WITH(NOLOCK)' + NCHAR(10) + N'                          WHERE ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'                            AND ID_NORMA=@EXEC_NORM_ID' + NCHAR(10) + N'                            AND ID_SERVICIO=@EXEC_NORM_SRV' + NCHAR(10) + N'                            AND (@VFORM_ROW_ID='''' OR CONVERT(VARCHAR(100),ID)<>@VFORM_ROW_ID))' + NCHAR(10) + N'                SET @VFORM_ERROR=''El consultor ya tiene esa norma para ese servicio.'';');

/* ---- 5. update: columnas ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_SET NVARCHAR(MAX)=QUOTENAME(@NORM_IDNORMA_COL)+N''=@PNORMA'';';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_SET NVARCHAR(MAX)=QUOTENAME(@NORM_IDNORMA_COL)+N''=@PNORMA'';' + NCHAR(10) + N'                    SET @NORM_SET=@NORM_SET+N'',[ID_SERVICIO]=@PSERV,[FECHA_UPD]=GETDATE(),[USUARIO_UPD]=@PUSR''; /* SERVICIOS_V1 */';
SET @D = REPLACE(@D, @a, @n);

/* ---- 6. update: parametros ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'@POBS VARCHAR(2000),@ORC INT OUTPUT'',';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'@POBS VARCHAR(2000),@PSERV INT,@PUSR VARCHAR(100),@ORC INT OUTPUT'',';
SET @D = REPLACE(@D, @a, @n);

/* ---- 7. update: argumentos ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS,';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS,@PSERV=@EXEC_NORM_SRV,@PUSR=@IAGENTE,';
SET @D = REPLACE(@D, @a, @n);

/* ---- 8. insert: columnas ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_INSERT_VALS NVARCHAR(MAX)=N''@PID,@PNORMA'';';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'DECLARE @NORM_INSERT_VALS NVARCHAR(MAX)=N''@PID,@PNORMA'';' + NCHAR(10) + N'                    SET @NORM_INSERT_COLS=@NORM_INSERT_COLS+N'',[ID_SERVICIO],[USUARIO_ALTA]''; /* SERVICIOS_V1 */' + NCHAR(10) + N'                    SET @NORM_INSERT_VALS=@NORM_INSERT_VALS+N'',@PSERV,@PUSR'';';
SET @D = REPLACE(@D, @a, @n);

/* ---- 9. insert: parametros ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'N''@PID INT,@PNORMA INT,@PCALIF VARCHAR(1000),@PDESDE DATETIME,@POBS VARCHAR(2000)'',';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'N''@PID INT,@PNORMA INT,@PCALIF VARCHAR(1000),@PDESDE DATETIME,@POBS VARCHAR(2000),@PSERV INT,@PUSR VARCHAR(100)'',';
SET @D = REPLACE(@D, @a, @n);

/* ---- 10. insert: argumentos ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS;';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'@POBS=@EXEC_NORM_OBS,@PSERV=@EXEC_NORM_SRV,@PUSR=@IAGENTE;';
SET @D = REPLACE(@D, @a, @n);

/* ---- 11. #NORMAS360: columnas ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'CREATE TABLE #NORMAS360' + NCHAR(10) + N'    (' + NCHAR(10) + N'        ID INT,' + NCHAR(10) + N'        ID_NORMA INT,';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'CREATE TABLE #NORMAS360' + NCHAR(10) + N'    (' + NCHAR(10) + N'        ID INT,' + NCHAR(10) + N'        ID_NORMA INT,' + NCHAR(10) + N'        ID_SERVICIO INT,' + NCHAR(10) + N'        SERVICIO VARCHAR(200),';
SET @D = REPLACE(@D, @a, @n);

/* ---- 12. #NORMAS360: servicio de cada norma ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    /* ---------------- HISTORICO DE DIAS ---------------- */';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    /* SERVICIOS_V1: servicio de cada norma */' + NCHAR(10) + N'    UPDATE T' + NCHAR(10) + N'       SET T.ID_SERVICIO=N.ID_SERVICIO,' + NCHAR(10) + N'           T.SERVICIO=ISNULL(NULLIF(S.DESCRIPCION,''''),S.CODIGO)' + NCHAR(10) + N'      FROM #NORMAS360 T' + NCHAR(10) + N'      INNER JOIN dbo.VCT_CONSULTORES_NORMAS N WITH(NOLOCK) ON N.ID=T.ID' + NCHAR(10) + N'      LEFT JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID=N.ID_SERVICIO;' + NCHAR(10) + N'' + NCHAR(10) + N'    /* ---------------- HISTORICO DE DIAS ---------------- */';
SET @D = REPLACE(@D, @a, @n);

/* ---- 13. normas: atributos de fila ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-idnorma="''+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'''')+''" ''+' + NCHAR(10) + N'                ''data-vct-idservicio="''+ISNULL(CONVERT(VARCHAR(30),N.ID_SERVICIO),'''')+''" ''+' + NCHAR(10) + N'                ''data-vct-filter-servicio="''+ISNULL(CONVERT(VARCHAR(30),N.ID_SERVICIO),'''')+''" ''+';
SET @D = REPLACE(@D, @a, @n);

/* ---- 14. normas: celda Servicio ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'                CASE WHEN @NormHasEstado=1 THEN' + NCHAR(10) + N'                    ''<td class="vct-text-center" data-label="''+@NORMA_ESTADO_LABEL+''"><span class="vct-360-badge ''+';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'                ''<td data-label="Servicio">''+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(N.SERVICIO,''''),''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+''</td>''+' + NCHAR(10) + N'                CASE WHEN @NormHasEstado=1 THEN' + NCHAR(10) + N'                    ''<td class="vct-text-center" data-label="''+@NORMA_ESTADO_LABEL+''"><span class="vct-360-badge ''+';
SET @D = REPLACE(@D, @a, @n);

/* ---- 15. normas: menu editar/eliminar ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-command="row-context-menu" data-vct-actions="edit" ''+' + NCHAR(10) + N'                              ''data-vct-target="vctDrawerConsultorNorma" ''+';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'''data-vct-command="row-context-menu" data-vct-actions="edit,delete" ''+' + NCHAR(10) + N'                              ''data-vct-target="vctDrawerConsultorNorma" ''+';
SET @D = REPLACE(@D, @a, @n);

/* ---- 16. normas: orden (norma y servicio) ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'        FROM #NORMAS360 N' + NCHAR(10) + N'        ORDER BY CASE WHEN N.FECHA_HASTA IS NULL THEN 1 ELSE 0 END,N.FECHA_HASTA,N.ID DESC';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'        FROM #NORMAS360 N' + NCHAR(10) + N'        ORDER BY N.NOMBRE,N.ID_SERVICIO,N.ID';
SET @D = REPLACE(@D, @a, @n);

/* ---- 17. normas: encabezado Servicio ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'''<th data-vct-sort="norma" data-vct-sortable="true"><span>Norma</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'''<th data-vct-sort="norma" data-vct-sortable="true"><span>Norma</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+''<th data-vct-width="14%" data-vct-sort="servicio" data-vct-sortable="true"><span>Servicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+';
SET @D = REPLACE(@D, @a, @n);

/* ---- 18. normas: filtro en la grilla ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'data-vct-dg-search-placeholder="Buscar norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'data-vct-dg-search-placeholder="Buscar norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+' + NCHAR(10) + N'            @HTML_NORMAS_FILTRO+';
SET @D = REPLACE(@D, @a, @n);

/* ---- 19. normas: armado del filtro ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    IF @HTML_NORMAS=''''' + NCHAR(10) + N'';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    /* SERVICIOS_V1: filtro por servicio en la grilla de normas */' + NCHAR(10) + N'    SELECT @HTML_NORMAS_FILTRO=ISNULL((' + NCHAR(10) + N'        SELECT' + NCHAR(10) + N'            ''<option value="''+CONVERT(VARCHAR(30),X.ID_SERVICIO)+''">''+' + NCHAR(10) + N'            REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(X.SERVICIO,''''),''Servicio ''+CONVERT(VARCHAR(30),X.ID_SERVICIO)),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+' + NCHAR(10) + N'            ''</option>''' + NCHAR(10) + N'        FROM (SELECT DISTINCT ID_SERVICIO,SERVICIO FROM #NORMAS360 WHERE ID_SERVICIO IS NOT NULL) X' + NCHAR(10) + N'        ORDER BY X.ID_SERVICIO' + NCHAR(10) + N'        FOR XML PATH(''''),TYPE' + NCHAR(10) + N'    ).value(''.'',''VARCHAR(MAX)''),'''');' + NCHAR(10) + N'' + NCHAR(10) + N'    IF @HTML_NORMAS_FILTRO<>''''' + NCHAR(10) + N'        SET @HTML_NORMAS_FILTRO=' + NCHAR(10) + N'            ''<div data-vct-dg-slot="filters">''+' + NCHAR(10) + N'            ''<select class="vctdg-select" data-vct-dg-filter="servicio" aria-label="Servicio">''+' + NCHAR(10) + N'            ''<option value="">Todos los servicios</option>''+@HTML_NORMAS_FILTRO+' + NCHAR(10) + N'            ''</select></div>'';' + NCHAR(10) + N'' + NCHAR(10) + N'    IF @HTML_NORMAS=''''' + NCHAR(10) + N'';
SET @D = REPLACE(@D, @a, @n);

/* ---- 20. servicios: grilla ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    SELECT @HistHasProject=';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    /* SERVICIOS_V1: grilla de servicios del consultor */' + NCHAR(10) + N'    SELECT @ServiciosCount=COUNT(*)' + NCHAR(10) + N'    FROM dbo.VCT_CONSULTORES_SERVICIOS WITH(NOLOCK)' + NCHAR(10) + N'    WHERE ID_CONSULTOR=@ID_CONSULTOR;' + NCHAR(10) + N'' + NCHAR(10) + N'    SELECT @HTML_SERVICIOS=ISNULL((' + NCHAR(10) + N'        SELECT' + NCHAR(10) + N'            ''<tr data-vct-row ''+' + NCHAR(10) + N'                ''data-vct-id="''+CONVERT(VARCHAR(30),CS.ID)+''" ''+' + NCHAR(10) + N'                ''data-vct-idservicio="''+CONVERT(VARCHAR(30),CS.ID_SERVICIO)+''" ''+' + NCHAR(10) + N'                ''data-vct-observaciones="''+REPLACE(REPLACE(ISNULL(CS.OBSERVACIONES,''''),''"'',''&quot;''),'''''''',''&#39;'')+''">''+' + NCHAR(10) + N'                ''<td class="vct-360-wrap-cell" data-label="Servicio"><span class="vct-360-project-name">''+' + NCHAR(10) + N'                    REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),ISNULL(S.CODIGO,''Servicio ''+CONVERT(VARCHAR(30),CS.ID_SERVICIO))),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+' + NCHAR(10) + N'                ''</span></td>''+' + NCHAR(10) + N'                ''<td class="vct-text-center" data-label="Normas" data-vct-sort-value="''+CONVERT(VARCHAR(10),ISNULL(NC.CANT,0))+''">''+CONVERT(VARCHAR(10),ISNULL(NC.CANT,0))+''</td>''+' + NCHAR(10) + N'                ''<td class="vct-text-center" data-label="Desde">''+CASE WHEN CS.FECHA_ALTA IS NULL THEN ''-'' ELSE CONVERT(VARCHAR(10),CS.FECHA_ALTA,103) END+''</td>''+' + NCHAR(10) + N'                ''<td class="vct-360-wrap-cell" data-label="Observaciones">''+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(CS.OBSERVACIONES,''''),''-''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+''</td>''+' + NCHAR(10) + N'                ''<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">''+' + NCHAR(10) + N'                    CASE WHEN @CAN_EDIT=1' + NCHAR(10) + N'                         THEN ''<button type="button" class="vct-row-menu-trigger" ''+' + NCHAR(10) + N'                              ''data-vct-command="row-context-menu" data-vct-actions="edit,delete" ''+' + NCHAR(10) + N'                              ''data-vct-target="vctDrawerConsultorServicio" ''+' + NCHAR(10) + N'                              ''data-vct-entity="SERVICIO" data-vct-tab="servicios" ''+' + NCHAR(10) + N'                              ''data-vct-form-title="Editar servicio" ''+' + NCHAR(10) + N'                              ''data-vct-form-subtitle="Modifique el servicio del consultor." ''+' + NCHAR(10) + N'                              ''data-vct-form-icon="briefcase" aria-label="Acciones">''+' + NCHAR(10) + N'                              ''<span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>''' + NCHAR(10) + N'                         ELSE '''' END+' + NCHAR(10) + N'                ''</td>''+' + NCHAR(10) + N'            ''</tr>''' + NCHAR(10) + N'        FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)' + NCHAR(10) + N'        LEFT JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID=CS.ID_SERVICIO' + NCHAR(10) + N'        LEFT JOIN' + NCHAR(10) + N'        (' + NCHAR(10) + N'            SELECT ID_SERVICIO,COUNT(*) AS CANT' + NCHAR(10) + N'            FROM dbo.VCT_CONSULTORES_NORMAS WITH(NOLOCK)' + NCHAR(10) + N'            WHERE ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'            GROUP BY ID_SERVICIO' + NCHAR(10) + N'        ) NC ON NC.ID_SERVICIO=CS.ID_SERVICIO' + NCHAR(10) + N'        WHERE CS.ID_CONSULTOR=@ID_CONSULTOR' + NCHAR(10) + N'        ORDER BY CS.ID_SERVICIO,CS.ID' + NCHAR(10) + N'        FOR XML PATH(''''),TYPE' + NCHAR(10) + N'    ).value(''.'',''VARCHAR(MAX)''),'''');' + NCHAR(10) + N'' + NCHAR(10) + N'    IF @HTML_SERVICIOS=''''' + NCHAR(10) + N'        SET @HTML_SERVICIOS=''<div class="vct-360-empty vct-360-fixed-empty">El consultor no tiene servicios cargados.</div>'';' + NCHAR(10) + N'    ELSE' + NCHAR(10) + N'        SET @HTML_SERVICIOS=' + NCHAR(10) + N'            ''<div data-vct-dg data-vct-dg-id="v360_con_servicios" data-vct-dg-title="Servicios del consultor" data-vct-dg-subtitle="Consultor: ''+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;''),''"'',''&quot;'')+''" data-vct-dg-unit="servicio(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar servicio..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">''+' + NCHAR(10) + N'            ''<table>''+' + NCHAR(10) + N'            ''<thead><tr>''+' + NCHAR(10) + N'            ''<th data-vct-width="26%" data-vct-sort="servicio" data-vct-sortable="true"><span>Servicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+' + NCHAR(10) + N'            ''<th class="vct-text-center" data-vct-width="10%" data-vct-sort="normas" data-vct-sortable="true" data-vct-sort-type="number"><span>Normas</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+' + NCHAR(10) + N'            ''<th class="vct-text-center" data-vct-width="12%" data-vct-sort="desde" data-vct-sortable="true" data-vct-sort-type="date"><span>Desde</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+' + NCHAR(10) + N'            ''<th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>''+' + NCHAR(10) + N'            ''<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>''+' + NCHAR(10) + N'            ''</tr></thead>''+' + NCHAR(10) + N'            ''<tbody>''+@HTML_SERVICIOS+''</tbody>''+' + NCHAR(10) + N'            ''</table>''+' + NCHAR(10) + N'            ''</div>'';' + NCHAR(10) + N'' + NCHAR(10) + N'    SELECT @HistHasProject=';
SET @D = REPLACE(@D, @a, @n);

/* ---- 21. norma: campo Servicio ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    (1,''TEXTO11'',''Norma'',''TEXT'',12,1,100,''Seleccione una norma'',NULL,';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    (0,''TEXTO15'',''Servicio'',''TEXT'',12,1,100,''Seleccione un servicio'',NULL,' + NCHAR(10) + N'        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T15 ELSE NULL END,0,0,NULL,''idservicio''),' + NCHAR(10) + N'    (1,''TEXTO11'',''Norma'',''TEXT'',12,1,100,''Seleccione una norma'',NULL,';
SET @D = REPLACE(@D, @a, @n);

/* ---- 22. norma: opciones de Servicio ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_NORMAS_OPTIONS,'''')+' + NCHAR(10) + N'        ''</template>'';';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_NORMAS_OPTIONS,'''')+' + NCHAR(10) + N'        ''</template>'';' + NCHAR(10) + N'' + NCHAR(10) + N'    /* SERVICIOS_V1: Servicio de la norma = servicios del consultor (y los que ya usan sus normas) */' + NCHAR(10) + N'    SELECT @HTML_NORMA_SERV_OPTIONS=ISNULL((' + NCHAR(10) + N'        SELECT' + NCHAR(10) + N'            ''<option value="''+CONVERT(VARCHAR(30),S.ID)+''">''+' + NCHAR(10) + N'            REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),S.CODIGO),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+' + NCHAR(10) + N'            ''</option>''' + NCHAR(10) + N'        FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK)' + NCHAR(10) + N'        WHERE EXISTS(SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK) WHERE CS.ID_CONSULTOR=@ID_CONSULTOR AND CS.ID_SERVICIO=S.ID)' + NCHAR(10) + N'           OR EXISTS(SELECT 1 FROM dbo.VCT_CONSULTORES_NORMAS CN WITH(NOLOCK) WHERE CN.ID_CONSULTOR=@ID_CONSULTOR AND CN.ID_SERVICIO=S.ID)' + NCHAR(10) + N'        ORDER BY S.ID' + NCHAR(10) + N'        FOR XML PATH(''''),TYPE' + NCHAR(10) + N'    ).value(''.'',''VARCHAR(MAX)''),'''');' + NCHAR(10) + N'' + NCHAR(10) + N'    SET @HTML_DRAWER_NORMA=ISNULL(@HTML_DRAWER_NORMA,'''')+' + NCHAR(10) + N'        ''<template data-vct-field-options ''+' + NCHAR(10) + N'        ''data-vct-target="vctDrawerConsultorNorma" ''+' + NCHAR(10) + N'        ''data-vct-field="TEXTO15" data-vct-placeholder="''+' + NCHAR(10) + N'        CASE WHEN @HTML_NORMA_SERV_OPTIONS='''' THEN ''Agregue primero un servicio al consultor'' ELSE ''Seleccione un servicio'' END+''">''+' + NCHAR(10) + N'        @HTML_NORMA_SERV_OPTIONS+' + NCHAR(10) + N'        ''</template>'';';
SET @D = REPLACE(@D, @a, @n);

/* ---- 23. servicio: boton y drawer ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'    /* Días mensuales */' + NCHAR(10) + N'    DELETE FROM #VCT_FORM_FIELDS;';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'    /* SERVICIOS_V1: boton Agregar y drawer de Servicio */' + NCHAR(10) + N'    SET @ERR_SERV=CASE WHEN @VFORM_ENTITY=''SERVICIO'' THEN @VFORM_ERROR ELSE '''' END;' + NCHAR(10) + N'    SET @OPEN_SERV=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY=''SERVICIO'' THEN 1 ELSE 0 END;' + NCHAR(10) + N'' + NCHAR(10) + N'    IF @CAN_EDIT=1' + NCHAR(10) + N'    BEGIN' + NCHAR(10) + N'        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION' + NCHAR(10) + N'             @MODE=''CREATE'',' + NCHAR(10) + N'             @TARGET_FORM=''vctDrawerConsultorServicio'',' + NCHAR(10) + N'             @FORM_TITLE=''Nuevo servicio'',' + NCHAR(10) + N'             @FORM_SUBTITLE=''Agregue un servicio que presta el consultor.'',' + NCHAR(10) + N'             @FORM_ICON=''briefcase'',' + NCHAR(10) + N'             @BUTTON_TEXT=''Agregar'',' + NCHAR(10) + N'             @BUTTON_ICON=''briefcase'',' + NCHAR(10) + N'             @BUTTON_CLASS=''vct-btn vct-btn-new vct-btn-sm'',' + NCHAR(10) + N'             @TOOLTIP=''Agregar servicio'',' + NCHAR(10) + N'             @OUTHTML=@BTN_ADD_SERV OUTPUT;' + NCHAR(10) + N'    END;' + NCHAR(10) + N'' + NCHAR(10) + N'    DELETE FROM #VCT_FORM_FIELDS;' + NCHAR(10) + N'' + NCHAR(10) + N'    INSERT INTO #VCT_FORM_FIELDS VALUES' + NCHAR(10) + N'    (1,''TEXTO11'',''Servicio'',''TEXT'',12,1,100,''Seleccione un servicio'',NULL,' + NCHAR(10) + N'        CASE WHEN @OPEN_SERV=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,''idservicio''),' + NCHAR(10) + N'    (2,''TEXTO12'',''Observaciones'',''TEXTAREA'',12,0,250,''Observaciones'',NULL,' + NCHAR(10) + N'        CASE WHEN @OPEN_SERV=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,''observaciones''),' + NCHAR(10) + N'    (3,''IDSELEC02'',''ID'',''HIDDEN'',12,0,NULL,NULL,NULL,' + NCHAR(10) + N'        CASE WHEN @OPEN_SERV=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,''id''),' + NCHAR(10) + N'    (4,''TEXTO30'',''Entidad'',''HIDDEN'',12,0,NULL,NULL,NULL,''SERVICIO'',0,1,NULL,NULL),' + NCHAR(10) + N'    (5,''FLAG01'',''Guardar'',''HIDDEN'',12,0,NULL,NULL,NULL,''1'',0,1,NULL,NULL),' + NCHAR(10) + N'    (6,''FLAG03'',''Eliminar'',''HIDDEN'',12,0,NULL,NULL,NULL,''0'',0,1,NULL,NULL),' + NCHAR(10) + N'    (7,''FLAG04'',''PrincipalCmd'',''HIDDEN'',12,0,NULL,NULL,NULL,''0'',0,1,NULL,NULL),' + NCHAR(10) + N'    (8,''ACTIVE_TAB'',''Tab'',''HIDDEN'',12,0,NULL,NULL,NULL,''servicios'',0,1,NULL,NULL);' + NCHAR(10) + N'' + NCHAR(10) + N'    EXEC dbo.VCT_MAIN_RENDER_FORM' + NCHAR(10) + N'         @FORM_ID=''vctDrawerConsultorServicio'',' + NCHAR(10) + N'         @TITLE=''Servicio'',' + NCHAR(10) + N'         @SUBTITLE=''Servicio que presta el consultor (Consultoría, Auditoría, Capacitación).'',' + NCHAR(10) + N'         @ICON=''briefcase'',' + NCHAR(10) + N'         @LAYOUT=''DRAWER'',' + NCHAR(10) + N'         @SAVE_LABEL=''Guardar'',' + NCHAR(10) + N'         @CANCEL_LABEL=''Cancelar'',' + NCHAR(10) + N'         @ERROR_MESSAGE=@ERR_SERV,' + NCHAR(10) + N'         @OPEN_ON_RENDER=@OPEN_SERV,' + NCHAR(10) + N'         @OUTHTML=@HTML_DRAWER_SERV OUTPUT;' + NCHAR(10) + N'' + NCHAR(10) + N'    SELECT @HTML_SERV_OPTIONS=ISNULL((' + NCHAR(10) + N'        SELECT' + NCHAR(10) + N'            ''<option value="''+CONVERT(VARCHAR(30),S.ID)+''">''+' + NCHAR(10) + N'            REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.DESCRIPCION,''''),S.CODIGO),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'')+' + NCHAR(10) + N'            CASE WHEN UPPER(ISNULL(S.ESTADO,''''))<>''ACTIVO'' THEN '' - ''+REPLACE(REPLACE(REPLACE(ISNULL(S.ESTADO,''''),''&'',''&amp;''),''<'',''&lt;''),''>'',''&gt;'') ELSE '''' END+' + NCHAR(10) + N'            ''</option>''' + NCHAR(10) + N'        FROM dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK)' + NCHAR(10) + N'        ORDER BY CASE WHEN UPPER(ISNULL(S.ESTADO,''''))=''ACTIVO'' THEN 0 ELSE 1 END,S.ID' + NCHAR(10) + N'        FOR XML PATH(''''),TYPE' + NCHAR(10) + N'    ).value(''.'',''VARCHAR(MAX)''),'''');' + NCHAR(10) + N'' + NCHAR(10) + N'    SET @HTML_DRAWER_SERV=ISNULL(@HTML_DRAWER_SERV,'''')+' + NCHAR(10) + N'        ''<template data-vct-field-options ''+' + NCHAR(10) + N'        ''data-vct-target="vctDrawerConsultorServicio" ''+' + NCHAR(10) + N'        ''data-vct-field="TEXTO11" data-vct-placeholder="Seleccione un servicio">''+' + NCHAR(10) + N'        ISNULL(@HTML_SERV_OPTIONS,'''')+' + NCHAR(10) + N'        ''</template>'';' + NCHAR(10) + N'' + NCHAR(10) + N'    /* Días mensuales */' + NCHAR(10) + N'    DELETE FROM #VCT_FORM_FIELDS;';
SET @D = REPLACE(@D, @a, @n);

/* ---- 24. solapa Servicios ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'<button type="button" data-vct-tab="normas">';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'<button type="button" data-vct-tab="servicios"><span data-vct-icon="briefcase"></span><span>Servicios</span></button>' + NCHAR(10) + N'            <button type="button" data-vct-tab="normas">';
SET @D = REPLACE(@D, @a, @n);

/* ---- 25. panel Servicios ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="normas">';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="servicios">' + NCHAR(10) + N'            <div class="vct-360-box vct-360-box-grid-auto">' + NCHAR(10) + N'                <div class="vct-360-box-head vct-360-section-head">' + NCHAR(10) + N'                    <div><h3><span class="vct-360-title-icon" data-vct-icon="briefcase"></span>Servicios (''+CONVERT(VARCHAR(10),@ServiciosCount)+'')</h3></div>' + NCHAR(10) + N'                    <div class="vct-360-box-actions">''+ISNULL(@BTN_ADD_SERV,'''')+''</div>' + NCHAR(10) + N'                </div>' + NCHAR(10) + N'                ''+@HTML_SERVICIOS+''' + NCHAR(10) + N'            </div>' + NCHAR(10) + N'        </div>' + NCHAR(10) + N'' + NCHAR(10) + N'        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="normas">';
SET @D = REPLACE(@D, @a, @n);

/* ---- 26. salida de drawers ---- */
SET @a = CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_DRAWER_NORMA,'''')+' + NCHAR(10) + N'        ISNULL(@HTML_DRAWER_HIST,'''');';
SET @n = CONVERT(NVARCHAR(MAX),N'')+N'        ISNULL(@HTML_DRAWER_SERV,'''')+' + NCHAR(10) + N'        ISNULL(@HTML_DRAWER_NORMA,'''')+' + NCHAR(10) + N'        ISNULL(@HTML_DRAWER_HIST,'''');';
SET @D = REPLACE(@D, @a, @n);

/* ---- CREATE -> ALTER en el encabezado ---- */
DECLARE @p INT = CHARINDEX(N'PROCEDURE', @D), @pre NVARCHAR(60);
IF @p > 0
BEGIN
    SET @pre = SUBSTRING(@D, CASE WHEN @p > 40 THEN @p - 40 ELSE 1 END, CASE WHEN @p > 40 THEN 40 ELSE @p - 1 END);
    IF CHARINDEX(N'CREATE', @pre) > 0 AND CHARINDEX(N'OR ALTER', @pre) = 0
    BEGIN
        SET @s = (CASE WHEN @p > 40 THEN @p - 40 ELSE 1 END) + CHARINDEX(N'CREATE', @pre) - 1;
        SET @D = STUFF(@D, @s, 6, N'ALTER ');
    END;
END;

IF PATINDEX(N'%ALTER%PROC%', @D) = 0 OR CHARINDEX(N'SERVICIOS_V1', @D) = 0
BEGIN
    RAISERROR('La definicion resultante no es valida. No se aplico nada.',16,1);
    RETURN;
END;

BEGIN TRY
    EXEC sp_executesql @D;
    PRINT 'OK: VCT_MAIN_CONSULTORES_V360 con Servicios del consultor y normas por servicio (SERVICIOS_V1).';
END TRY
BEGIN CATCH
    DECLARE @err NVARCHAR(2000) = N'No se pudo aplicar el parche: ' + ERROR_MESSAGE() + N' (linea ' + CONVERT(NVARCHAR(10), ERROR_LINE()) + N'). El SP quedo como estaba.';
    RAISERROR(@err,16,1);
END CATCH;
GO
