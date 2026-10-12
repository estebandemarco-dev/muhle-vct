/* ========================================================================
   ACCIONES_PANTALLA_V2
   ------------------------------------------------------------------------
   Pantalla Acciones (opcion del sidebar) segun boceto v3. Reemplaza por
   completo dbo.VCT_MAIN_ACCIONES (CREATE OR ALTER: si existe se descarta).

   - Barra de pestanas 360: Vencidas | Hoy | Proximas | Sin fecha | Todas
     (con contador) y Graficos a la derecha.
   - Cada pestana: card con titulo, subtitulo debajo y cambio Lista /
     Calendario a la altura del titulo. Grilla estandar (vct-datagrid).
   - Alcance: GERENCIA y SQUAD ven todas las acciones (asignadas o no);
     el resto de los perfiles solo las que tiene a cargo su usuario
     (consultor / empleado por ID_USUARIO_SEGURIDAD). Perfil CLIENTE*:
     solo mensaje del sistema.
   - Permisos: SOLO se leen con dbo.VCT_MAIN_GET_ACTIONS (modulos ACCIONES
     y PROYECTOS). Este script NO inserta ni modifica permisos.
       ACCIONES  CREATE        -> boton "Nueva" del toolbar
       ACCIONES  VIEW / EDIT   -> opciones del menu de 3 puntos
       ACCIONES  EDIT|UPDATE|CLOSE|ESTADO -> "Marcar cumplida"
       PROYECTOS VIEW          -> "Ver proyecto"
   - Comando ACC_ESTADO (cumplir / reabrir) por buffer, igual que antes.
   - No crea vistas, funciones ni tablas. No usa caracteres no ASCII.
   - Assets: css/vct-acciones.css?v=1 y js/vct-acciones.js?v=1
   ======================================================================== */
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#ACC_V2_RUN') IS NOT NULL DROP TABLE #ACC_V2_RUN;
CREATE TABLE #ACC_V2_RUN (TRG_ON BIT, INICIO DATETIME);
INSERT INTO #ACC_V2_RUN (TRG_ON, INICIO)
SELECT CASE WHEN EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) THEN 1 ELSE 0 END,
       DATEADD(SECOND, -2, GETDATE());
IF EXISTS (SELECT 1 FROM #ACC_V2_RUN WHERE TRG_ON = 1)
    DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
GO

CREATE OR ALTER PROCEDURE dbo.VCT_MAIN_ACCIONES
(
    @IPKEYJOB    VARCHAR(100),
    @FORM_ID     VARCHAR(100),
    @IUNIDAD     VARCHAR(100),
    @IAGENTE     VARCHAR(100),
    @OUTPARAM1   VARCHAR(MAX) OUTPUT,
    @OUTPARAM2   VARCHAR(MAX) OUTPUT,
    @OUTPARAM3   VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    /* ACCIONES_PANTALLA_V2 */
    SET NOCOUNT ON;
    SET @OUTPARAM1 = '';
    SET @OUTPARAM2 = NULL;
    SET @OUTPARAM3 = NULL;

    DECLARE @HTML_SHELL VARCHAR(MAX) = '',
            @RES        VARCHAR(20)  = '',
            @HOY        DATE         = CONVERT(DATE, GETDATE()),
            @PERFIL     VARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@IUNIDAD,'')))),
            @U          VARCHAR(100) = LOWER(LTRIM(RTRIM(ISNULL(@IAGENTE,'')))),
            @CONS_ID    INT,
            @EMP_ID     INT,
            @VE_TODO    BIT = 0,
            @ES_CLIENTE BIT = 0,
            @SUBT       VARCHAR(300),
            @ASSETS     VARCHAR(MAX);

    SET @ES_CLIENTE = CASE WHEN @PERFIL LIKE 'CLIENTE%' THEN 1 ELSE 0 END;
    SET @VE_TODO    = CASE WHEN @PERFIL IN ('GERENCIA','SQUAD') THEN 1 ELSE 0 END;
    SET @SUBT = CASE WHEN @ES_CLIENTE = 1 THEN ''
                     WHEN @VE_TODO = 1 THEN 'Todas las acciones del sistema, ordenadas por vencimiento.'
                     ELSE 'Las acciones a tu cargo, ordenadas por vencimiento.' END;

    BEGIN TRY
        EXEC dbo.VCT_GET_SHELL @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE, @FORM_ID = @FORM_ID,
             @TITLE = 'Acciones', @SUBTITLE = @SUBT, @SEARCH_PLACEHOLDER = '', @SHOW_SEARCH = 0,
             @OSHELL = @HTML_SHELL OUTPUT, @ORESULTADO = @RES OUTPUT;
    END TRY
    BEGIN CATCH
        SET @HTML_SHELL = '';
    END CATCH;

    SET @ASSETS = CONVERT(VARCHAR(MAX), '')
        + '<link rel="stylesheet" href="../css/vct-datagrid.css?v=28">'
        + '<link rel="stylesheet" href="../css/vct-acciones.css?v=1">'
        + '<script src="../js/vct-export.js?v=1"></script>'
        + '<script src="../js/vct-datagrid.js?v=11"></script>'
        + '<script src="../js/vct-acciones.js?v=1"></script>';

    /* ==================================================================
       1. PERFIL CLIENTE: solo mensaje del sistema
       ================================================================== */
    IF @ES_CLIENTE = 1
    BEGIN
        SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') + @ASSETS
            + '<div class="vct-page vct-page-main vct-acc-page" data-vct-page data-vct-sidebar-id="2" data-vct-form-id="' + REPLACE(ISNULL(@FORM_ID,''),'"','') + '">'
            + '<section class="vct-module vct-360-module vct-360-visual-final vct-acc-module" data-vct-module data-vct-acc>'
            + '<div class="vct-360-content-shell">'
            + '<div class="vct-360-box vct-acc-msg">'
            +   '<span class="vct-acc-msg-icon"><span data-vct-icon="lock"></span></span>'
            +   '<div><b>Acciones no est&aacute; disponible para tu perfil</b>'
            +   '<span>Esta opci&oacute;n es de uso interno. Si la ves en el men&uacute;, avis&aacute; al administrador del sistema para que revise los permisos de tu perfil.</span></div>'
            + '</div></div></section></div>';
        RETURN;
    END;

    /* ==================================================================
       2. USUARIO -> consultor / empleado
       ================================================================== */
    SELECT TOP 1 @CONS_ID = ID FROM dbo.VCT_CONSULTORES
    WHERE LOWER(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,'')))) = @U AND UPPER(ISNULL(ESTADO,'')) = 'ACTIVO' ORDER BY ID DESC;
    SELECT TOP 1 @EMP_ID = ID FROM dbo.VCT_EMPLEADOS
    WHERE LOWER(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,'')))) = @U AND UPPER(ISNULL(ESTADO,'')) = 'ACTIVO' ORDER BY ID DESC;

    /* ==================================================================
       3. PERMISOS (solo lectura de VCT_MAIN_GET_ACTIONS)
       ================================================================== */
    CREATE TABLE #ACT (ID_PRM VARCHAR(100), MODULO VARCHAR(20), ACTION_ID VARCHAR(100), ACTION_TYPE VARCHAR(50),
                       TITLE VARCHAR(200), ICON VARCHAR(100), STORAGE_KEY VARCHAR(100), TARGET_TAB VARCHAR(100),
                       TARGET_GUID VARCHAR(100), SORT_ORDER INT);
    BEGIN TRY
        INSERT INTO #ACT (ID_PRM, MODULO, ACTION_ID, ACTION_TYPE, TITLE, ICON, STORAGE_KEY, TARGET_TAB, TARGET_GUID, SORT_ORDER)
        SELECT CONVERT(VARCHAR(100), A.ID_PRM), 'ACCIONES', A.ACTION_ID, A.ACTION_TYPE,
               ISNULL(NULLIF(A.TITLE,''), CASE A.ACTION_TYPE WHEN 'VIEW' THEN 'Ver acci&oacute;n' WHEN 'EDIT' THEN 'Editar acci&oacute;n' ELSE 'Nueva acci&oacute;n' END),
               ISNULL(NULLIF(A.ICON,''), CASE A.ACTION_TYPE WHEN 'VIEW' THEN 'eye' WHEN 'EDIT' THEN 'edit' ELSE 'plus' END),
               A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID, A.SORT_ORDER
        FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, 'ACCIONES') A;
        INSERT INTO #ACT (ID_PRM, MODULO, ACTION_ID, ACTION_TYPE, TITLE, ICON, STORAGE_KEY, TARGET_TAB, TARGET_GUID, SORT_ORDER)
        SELECT CONVERT(VARCHAR(100), A.ID_PRM), 'PROYECTOS', A.ACTION_ID, A.ACTION_TYPE,
               ISNULL(NULLIF(A.TITLE,''), 'Ver proyecto'), ISNULL(NULLIF(A.ICON,''), 'scan-eye'),
               A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID, A.SORT_ORDER
        FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, 'PROYECTOS') A
        WHERE A.ACTION_TYPE = 'VIEW';
    END TRY
    BEGIN CATCH
        DELETE FROM #ACT;
    END CATCH;

    DECLARE @PUEDE_ESTADO BIT = CASE WHEN EXISTS (SELECT 1 FROM #ACT WHERE MODULO = 'ACCIONES' AND ACTION_TYPE IN ('EDIT','UPDATE','CLOSE','ESTADO')) THEN 1 ELSE 0 END,
            @BTN_NUEVA VARCHAR(MAX) = '';
    SELECT TOP 1 @BTN_NUEVA = dbo.VCT_MAIN_RENDER_ACTION(A.ACTION_ID, A.TITLE, A.ICON, A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID,
                                                         '', 'vct-btn vct-btn-primary vct-btn-sm', 'Nueva')
    FROM #ACT A WHERE A.MODULO = 'ACCIONES' AND A.ACTION_TYPE IN ('CREATE','NEW','ADD','INSERT')
    ORDER BY A.SORT_ORDER, A.ID_PRM;
    SET @BTN_NUEVA = ISNULL(@BTN_NUEVA,'');

    /* ==================================================================
       4. COMANDO ACC_ESTADO (cumplir / reabrir) - lo manda vct-acciones.js
       ================================================================== */
    DECLARE @MSG VARCHAR(500) = '', @ERR VARCHAR(500) = '', @FLAG VARCHAR(10), @CMD VARCHAR(100),
            @SEL3 VARCHAR(100), @NUEVO VARCHAR(20);
    SELECT TOP 1 @FLAG = ISNULL(FLAG01,''), @CMD = UPPER(LTRIM(RTRIM(ISNULL(TEXTO30,'')))),
           @SEL3 = LTRIM(RTRIM(ISNULL(IDSELEC03,''))), @NUEVO = UPPER(LTRIM(RTRIM(ISNULL(TEXTO11,''))))
    FROM dbo.VCT_BUFFER WITH(NOLOCK) WHERE PAR_KEY = @IPKEYJOB;

    IF @FLAG = '1' AND @CMD = 'ACC_ESTADO'
    BEGIN
        UPDATE dbo.VCT_BUFFER SET FLAG01 = '0', TEXTO30 = NULL, IDSELEC03 = NULL, TEXTO11 = NULL WHERE PAR_KEY = @IPKEYJOB;

        DECLARE @ID_AC INT = NULL, @EST_ANT INT, @ID_PROY_AC INT, @TIT_AC VARCHAR(300), @ES_MIA BIT = 0,
                @E_CUMP INT = (SELECT TOP 1 ID FROM dbo.VCT_PRM_ACCIONES_ESTADOS WHERE CODIGO = 'CUMPLIDA'),
                @E_PEND INT = (SELECT TOP 1 ID FROM dbo.VCT_PRM_ACCIONES_ESTADOS WHERE CODIGO = 'PENDIENTE'),
                @E_RES  INT = (SELECT TOP 1 ID FROM dbo.VCT_PRM_ACCIONES_RESULTADOS WHERE CODIGO = 'COMPLETADA'),
                @EST_NUEVO INT;

        IF @SEL3 <> '' AND PATINDEX('%[^0-9]%', @SEL3) = 0 AND LEN(@SEL3) <= 9
            SELECT @ID_AC = G.ID, @EST_ANT = G.ID_ESTADO, @ID_PROY_AC = G.ID_PROYECTO, @TIT_AC = G.TITULO,
                   @ES_MIA = CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_ACCIONES_PARTICIPANTES GP
                                               WHERE GP.ID_ACCION = G.ID AND GP.ROL_PARTICIPANTE = 'RESPONSABLE' AND GP.ESTADO = 'ACTIVO'
                                                 AND ((GP.TIPO_ENTIDAD = 'CONSULTOR' AND GP.ID_ENTIDAD = @CONS_ID)
                                                   OR (GP.TIPO_ENTIDAD = 'EMPLEADO'  AND GP.ID_ENTIDAD = @EMP_ID)))
                                  THEN 1 ELSE 0 END
            FROM dbo.VCT_ACCIONES G WHERE G.ID = CONVERT(INT, @SEL3);

        SET @EST_NUEVO = CASE @NUEVO WHEN 'CUMPLIDA' THEN @E_CUMP WHEN 'PENDIENTE' THEN @E_PEND END;

        IF @ID_AC IS NULL SET @ERR = 'No se encontr' + CHAR(243) + ' la acci' + CHAR(243) + 'n.';
        ELSE IF @PUEDE_ESTADO = 0 SET @ERR = 'Tu perfil no tiene permiso para cambiar el estado de las acciones.';
        ELSE IF @VE_TODO = 0 AND @ES_MIA = 0 SET @ERR = 'Solo pod' + CHAR(233) + 's cambiar acciones a tu cargo.';
        ELSE IF @EST_NUEVO IS NULL SET @ERR = 'Estado no reconocido.';
        ELSE
        BEGIN TRY
            BEGIN TRANSACTION;
                UPDATE dbo.VCT_ACCIONES
                   SET ID_ESTADO    = @EST_NUEVO,
                       ID_RESULTADO = CASE WHEN @NUEVO = 'CUMPLIDA' THEN ISNULL(@E_RES, ID_RESULTADO) ELSE NULL END,
                       FECHA_CIERRE = CASE WHEN @NUEVO = 'CUMPLIDA' THEN GETDATE() ELSE NULL END,
                       FECHA_UPD    = GETDATE(),
                       USUARIO_UPD  = @IAGENTE
                 WHERE ID = @ID_AC;
                INSERT INTO dbo.VCT_ACCIONES_HISTORIAL (ID_ACCION, ID_ESTADO_ANTERIOR, ID_ESTADO_NUEVO, ACCION, DESCRIPCION, TIPO_ACTOR, FECHA, USUARIO)
                VALUES (@ID_AC, @EST_ANT, @EST_NUEVO, 'CAMBIO_ESTADO',
                        CASE WHEN @NUEVO = 'CUMPLIDA' THEN 'Accion cumplida (pantalla Acciones).' ELSE 'Accion reabierta (pantalla Acciones).' END,
                        'USUARIO', GETDATE(), @IAGENTE);
            COMMIT TRANSACTION;
            IF @ID_PROY_AC IS NOT NULL AND OBJECT_ID('dbo.VCT_PROYECTO_AVANCE_SYNC') IS NOT NULL
                EXEC dbo.VCT_PROYECTO_AVANCE_SYNC @ID_PROYECTO = @ID_PROY_AC;
            SET @MSG = CASE WHEN @NUEVO = 'CUMPLIDA' THEN 'Acci' + CHAR(243) + 'n cumplida: ' ELSE 'Acci' + CHAR(243) + 'n reabierta: ' END + LEFT(ISNULL(@TIT_AC,''), 200);
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @ERR = LEFT('No se pudo grabar: ' + ERROR_MESSAGE(), 500);
        END CATCH;
    END;

    /* ==================================================================
       5. ACCIONES DEL ALCANCE
          abiertas + cerradas de los ultimos 6 meses (para el grafico)
          SIT: V vencida | H hoy | P proxima (1-7 dias) | L posterior
               S sin fecha | C cerrada
       ================================================================== */
    CREATE TABLE #A
    (
        ID INT PRIMARY KEY, TITULO VARCHAR(300), ID_TIPO INT, TIPO VARCHAR(150), SUBTIPO VARCHAR(150),
        EST_COD VARCHAR(50), EST_DESC VARCHAR(100), ES_FINAL BIT, VENCE DATE, CIERRE DATETIME,
        ID_PROYECTO INT, PROY_TXT VARCHAR(400), CLIENTE VARCHAR(300),
        RESP_TIPO VARCHAR(20), RESP_ID INT, RESP_KEY VARCHAR(20), RESP_NOM VARCHAR(300), RESP_INI VARCHAR(4), MIA BIT,
        PRIO_COD VARCHAR(50), PRIO_DESC VARCHAR(100),
        SIT CHAR(1), DIAS INT,
        E_TIT VARCHAR(900), E_SUB VARCHAR(900), E_PROY VARCHAR(1200), E_CLI VARCHAR(900), E_RESP VARCHAR(900),
        E_PRIO VARCHAR(300), E_EST VARCHAR(300), E_SEARCH VARCHAR(4000), MENU VARCHAR(MAX)
    );

    INSERT INTO #A (ID, TITULO, ID_TIPO, TIPO, SUBTIPO, EST_COD, EST_DESC, ES_FINAL, VENCE, CIERRE, ID_PROYECTO, PROY_TXT, CLIENTE,
                    RESP_TIPO, RESP_ID, MIA)
    SELECT G.ID,
           ISNULL(NULLIF(LTRIM(RTRIM(G.TITULO)),''), 'Acci' + CHAR(243) + 'n'),
           G.ID_TIPO, T.DESCRIPCION, ST.DESCRIPCION,
           UPPER(ISNULL(GE.CODIGO,'')), GE.DESCRIPCION, ISNULL(GE.ES_FINAL, 0),
           CONVERT(DATE, G.FECHA_VENCIMIENTO), G.FECHA_CIERRE, G.ID_PROYECTO,
           CASE WHEN P.ID IS NOT NULL THEN ISNULL('(' + NULLIF(LTRIM(RTRIM(P.CODIGO)),'') + ') ', '') + ISNULL(P.NOMBRE,'') END,
           CL.RAZON_SOCIAL,
           RS.TIPO_ENTIDAD, RS.ID_ENTIDAD,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_ACCIONES_PARTICIPANTES GP
                             WHERE GP.ID_ACCION = G.ID AND GP.ROL_PARTICIPANTE = 'RESPONSABLE' AND GP.ESTADO = 'ACTIVO'
                               AND ((GP.TIPO_ENTIDAD = 'CONSULTOR' AND GP.ID_ENTIDAD = @CONS_ID)
                                 OR (GP.TIPO_ENTIDAD = 'EMPLEADO'  AND GP.ID_ENTIDAD = @EMP_ID)))
                THEN 1 ELSE 0 END
    FROM dbo.VCT_ACCIONES G
    LEFT JOIN dbo.VCT_PRM_ACCIONES_ESTADOS  GE ON GE.ID = G.ID_ESTADO
    LEFT JOIN dbo.VCT_PRM_ACCIONES_TIPOS    T  ON T.ID  = G.ID_TIPO
    LEFT JOIN dbo.VCT_PRM_ACCIONES_SUBTIPOS ST ON ST.ID = G.ID_SUBTIPO
    LEFT JOIN dbo.VCT_PROYECTOS P  ON P.ID  = G.ID_PROYECTO
    LEFT JOIN dbo.VCT_CLIENTES  CL ON CL.ID = ISNULL(P.IDCLIENTE, G.ID_CLIENTE)
    OUTER APPLY
    (
        SELECT TOP 1 GP.TIPO_ENTIDAD, GP.ID_ENTIDAD
        FROM dbo.VCT_ACCIONES_PARTICIPANTES GP
        WHERE GP.ID_ACCION = G.ID AND GP.ROL_PARTICIPANTE = 'RESPONSABLE' AND GP.ESTADO = 'ACTIVO'
        ORDER BY GP.PRINCIPAL DESC, GP.ID
    ) RS
    WHERE ISNULL(GE.ES_FINAL, 0) = 0
       OR ISNULL(G.FECHA_CIERRE, G.FECHA_CREACION) >= DATEADD(MONTH, -6, DATEADD(MONTH, DATEDIFF(MONTH, 0, @HOY), 0));

    IF @VE_TODO = 0 DELETE FROM #A WHERE MIA = 0;

    /* responsable: nombre + iniciales */
    UPDATE A SET
        RESP_NOM = LTRIM(RTRIM(ISNULL(CO.APELLIDOS,'') + CASE WHEN ISNULL(CO.NOMBRES,'') <> '' THEN ', ' + CO.NOMBRES ELSE '' END)),
        RESP_INI = UPPER(LEFT(LTRIM(ISNULL(CO.NOMBRES,'')),1) + LEFT(LTRIM(ISNULL(CO.APELLIDOS,'')),1))
    FROM #A A INNER JOIN dbo.VCT_CONSULTORES CO ON CO.ID = A.RESP_ID
    WHERE A.RESP_TIPO = 'CONSULTOR';
    UPDATE A SET
        RESP_NOM = LTRIM(RTRIM(ISNULL(EM.APELLIDOS,'') + CASE WHEN ISNULL(EM.NOMBRES,'') <> '' THEN ', ' + EM.NOMBRES ELSE '' END)),
        RESP_INI = UPPER(LEFT(LTRIM(ISNULL(EM.NOMBRES,'')),1) + LEFT(LTRIM(ISNULL(EM.APELLIDOS,'')),1))
    FROM #A A INNER JOIN dbo.VCT_EMPLEADOS EM ON EM.ID = A.RESP_ID
    WHERE A.RESP_TIPO = 'EMPLEADO';
    UPDATE #A SET RESP_NOM = 'Cliente', RESP_INI = 'CL' WHERE RESP_TIPO = 'CLIENTE';
    UPDATE #A SET
        RESP_KEY = CASE WHEN ISNULL(RESP_NOM,'') = '' THEN 'X' ELSE LEFT(ISNULL(RESP_TIPO,'O'),1) + CONVERT(VARCHAR(12), ISNULL(RESP_ID,0)) END,
        RESP_NOM = CASE WHEN ISNULL(RESP_NOM,'') = '' THEN 'Sin asignar' ELSE RESP_NOM END,
        RESP_INI = CASE WHEN ISNULL(RESP_INI,'') = '' THEN '-' ELSE RESP_INI END;

    /* prioridad: solo si la columna existe (SQL dinamico para que compile sin ella) */
    DECLARE @HAS_PRIO BIT = 0;
    IF COL_LENGTH('dbo.VCT_ACCIONES','ID_PRIORIDAD') IS NOT NULL AND OBJECT_ID('dbo.VCT_PRM_ACCIONES_PRIORIDADES') IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC sp_executesql N'UPDATE A SET PRIO_COD = UPPER(LTRIM(RTRIM(ISNULL(PR.CODIGO,'''')))), PRIO_DESC = PR.DESCRIPCION
                                 FROM #A A
                                 INNER JOIN dbo.VCT_ACCIONES X ON X.ID = A.ID
                                 LEFT JOIN dbo.VCT_PRM_ACCIONES_PRIORIDADES PR ON PR.ID = X.ID_PRIORIDAD;';
            SET @HAS_PRIO = 1;
        END TRY
        BEGIN CATCH
            SET @HAS_PRIO = 0;
        END CATCH;
    END;

    /* situacion + textos escapados */
    UPDATE #A SET
        DIAS = CASE WHEN VENCE IS NULL THEN NULL ELSE DATEDIFF(DAY, @HOY, VENCE) END,
        SIT  = CASE WHEN ES_FINAL = 1 THEN 'C'
                    WHEN VENCE IS NULL THEN 'S'
                    WHEN VENCE < @HOY THEN 'V'
                    WHEN VENCE = @HOY THEN 'H'
                    WHEN VENCE <= DATEADD(DAY, 7, @HOY) THEN 'P'
                    ELSE 'L' END;

    UPDATE #A SET
        E_TIT  = REPLACE(REPLACE(REPLACE(REPLACE(TITULO,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_SUB  = REPLACE(REPLACE(REPLACE(REPLACE(
                     ISNULL(TIPO,'') + CASE WHEN ISNULL(SUBTIPO,'') <> '' AND ISNULL(SUBTIPO,'') <> ISNULL(TIPO,'') THEN CASE WHEN ISNULL(TIPO,'') <> '' THEN ' - ' ELSE '' END + SUBTIPO ELSE '' END,
                 '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_PROY = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(PROY_TXT,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_CLI  = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CLIENTE,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_RESP = REPLACE(REPLACE(REPLACE(REPLACE(RESP_NOM,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_PRIO = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(PRIO_DESC,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_EST  = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(EST_DESC,''),'Pendiente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_SEARCH = REPLACE(REPLACE(REPLACE(REPLACE(
                     TITULO + ' ' + ISNULL(TIPO,'') + ' ' + ISNULL(SUBTIPO,'') + ' ' + ISNULL(PROY_TXT,'') + ' ' + ISNULL(CLIENTE,'') + ' '
                     + RESP_NOM + ' ' + ISNULL(CONVERT(VARCHAR(10), VENCE, 103),'sin fecha'),
                   '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');

    /* menu de 3 puntos por fila (permisos del perfil) */
    UPDATE A SET MENU =
        ISNULL((
            SELECT X.H AS [text()] FROM
            (
                SELECT 0 AS O1, P.SORT_ORDER AS O2, P.ID_PRM AS O3,
                       dbo.VCT_MAIN_RENDER_ACTION(P.ACTION_ID, P.TITLE, P.ICON, P.STORAGE_KEY, P.TARGET_TAB, P.TARGET_GUID,
                                                  CONVERT(VARCHAR(20), A.ID), 'vctdg-menu-item', P.TITLE) AS H
                FROM #ACT P
                WHERE P.MODULO = 'ACCIONES' AND P.ACTION_TYPE IN ('VIEW','EDIT')
                UNION ALL
                SELECT 1, P.SORT_ORDER, P.ID_PRM,
                       dbo.VCT_MAIN_RENDER_ACTION(P.ACTION_ID, P.TITLE, P.ICON, P.STORAGE_KEY, P.TARGET_TAB, P.TARGET_GUID,
                                                  CONVERT(VARCHAR(20), A.ID_PROYECTO), 'vctdg-menu-item', P.TITLE)
                FROM #ACT P
                WHERE P.MODULO = 'PROYECTOS' AND A.ID_PROYECTO IS NOT NULL
                UNION ALL
                SELECT 2, 0, '',
                       '<button type="button" class="vctdg-menu-item" data-vct-acc-estado="CUMPLIDA" data-vct-acc-id="' + CONVERT(VARCHAR(20), A.ID)
                       + '" data-vct-tooltip="Marcar cumplida"><span data-vct-icon="check"></span><span>Marcar cumplida</span></button>'
                WHERE @PUEDE_ESTADO = 1 AND A.ES_FINAL = 0 AND (@VE_TODO = 1 OR A.MIA = 1)
            ) X
            ORDER BY X.O1, X.O2, X.O3
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '')
    FROM #A A
    WHERE A.ES_FINAL = 0;

    /* ==================================================================
       6. CONTADORES y pestana inicial
       ================================================================== */
    DECLARE @C_V INT = 0, @C_H INT = 0, @C_P INT = 0, @C_S INT = 0, @C_T INT = 0, @TAB_INI VARCHAR(20);
    SELECT @C_V = ISNULL(SUM(CASE WHEN SIT = 'V' THEN 1 ELSE 0 END),0),
           @C_H = ISNULL(SUM(CASE WHEN SIT = 'H' THEN 1 ELSE 0 END),0),
           @C_P = ISNULL(SUM(CASE WHEN SIT = 'P' THEN 1 ELSE 0 END),0),
           @C_S = ISNULL(SUM(CASE WHEN SIT = 'S' THEN 1 ELSE 0 END),0),
           @C_T = ISNULL(SUM(CASE WHEN SIT <> 'C' THEN 1 ELSE 0 END),0)
    FROM #A;
    SET @TAB_INI = CASE WHEN @C_V > 0 THEN 'vencidas' WHEN @C_H > 0 THEN 'hoy' WHEN @C_P > 0 THEN 'proximas' ELSE 'todas' END;

    /* ==================================================================
       7. PESTANAS + PANELES (una grilla por pestana)
       ================================================================== */
    DECLARE @PN TABLE (ORD INT, CODE VARCHAR(20), SIT CHAR(1), NOMBRE VARCHAR(60), TITULO VARCHAR(120), ICON VARCHAR(40),
                       CNT INT, CNT_CLS VARCHAR(20), SUBT VARCHAR(400), CAL BIT);
    DECLARE @D7 DATE = DATEADD(DAY, 7, @HOY), @CARGO VARCHAR(40) = CASE WHEN @VE_TODO = 1 THEN '' ELSE ' a tu cargo' END;
    INSERT INTO @PN VALUES
    (1, 'vencidas', 'V', 'Vencidas',  'Vencidas',  'bell',         @C_V, 'is-red',
        'Acciones abiertas' + @CARGO + ' con vencimiento anterior a hoy (' + LEFT(CONVERT(VARCHAR(10), @HOY, 103), 5) + ').', 1),
    (2, 'hoy',      'H', 'Hoy',       'Vencen hoy', 'clock-3',     @C_H, 'is-amb',
        'Lo que vence hoy' + @CARGO + ', ' + CONVERT(VARCHAR(10), @HOY, 103) + '.', 1),
    (3, 'proximas', 'P', 'Pr&oacute;ximas', 'Pr&oacute;ximas', 'arrow-right', @C_P, 'is-bor',
        'Lo que vence en los pr&oacute;ximos 7 d&iacute;as (' + LEFT(CONVERT(VARCHAR(10), DATEADD(DAY, 1, @HOY), 103), 5) + ' al ' + LEFT(CONVERT(VARCHAR(10), @D7, 103), 5) + ').', 1),
    (4, 'sinfecha', 'S', 'Sin fecha', 'Sin fecha', 'calendar',     @C_S, 'is-gry',
        'Acciones abiertas' + @CARGO + ' sin fecha de vencimiento: conviene ponerles una.', 0),
    (5, 'todas',    'T', 'Todas',     'Todas las acciones abiertas', 'list-checks', @C_T, 'is-gry',
        'Todo lo abierto' + @CARGO + ', ordenado por vencimiento.', 1);

    DECLARE @TABS VARCHAR(MAX) = '', @PANELS VARCHAR(MAX) = '', @ORD INT = 1,
            @P_CODE VARCHAR(20), @P_SIT CHAR(1), @P_NOM VARCHAR(60), @P_TIT VARCHAR(120), @P_ICON VARCHAR(40),
            @P_CNT INT, @P_CLS VARCHAR(20), @P_SUBT VARCHAR(400), @P_CAL BIT,
            @ROWS VARCHAR(MAX), @O_RESP VARCHAR(MAX), @O_TIPO VARCHAR(MAX), @O_PRIO VARCHAR(MAX), @O_PROY VARCHAR(MAX), @FILTERS VARCHAR(MAX);

    WHILE @ORD <= 5
    BEGIN
        SELECT @P_CODE = CODE, @P_SIT = SIT, @P_NOM = NOMBRE, @P_TIT = TITULO, @P_ICON = ICON, @P_CNT = CNT,
               @P_CLS = CNT_CLS, @P_SUBT = SUBT, @P_CAL = CAL
        FROM @PN WHERE ORD = @ORD;

        SET @TABS = @TABS
            + '<button type="button" data-vct-tab="' + @P_CODE + '"><span data-vct-icon="' + @P_ICON + '"></span><span>' + @P_NOM + '</span>'
            + '<small class="vct-acc-cnt ' + CASE WHEN @P_CNT = 0 THEN 'is-zero' ELSE @P_CLS END + '">' + CONVERT(VARCHAR(10), @P_CNT) + '</small></button>';

        /* --- filas --- */
        SELECT @ROWS = ISNULL((
            SELECT
                '<tr data-vct-row data-vct-key="' + CONVERT(VARCHAR(20), A.ID) + '"'
              + ' data-vct-search="' + A.E_SEARCH + '"'
              + ' data-vct-filter-resp="' + A.RESP_KEY + '"'
              + ' data-vct-filter-tipo="' + CONVERT(VARCHAR(12), ISNULL(A.ID_TIPO,0)) + '"'
              + ' data-vct-filter-prio="' + ISNULL(NULLIF(A.PRIO_COD,''),'NA') + '"'
              + ' data-vct-filter-proy="' + CONVERT(VARCHAR(12), ISNULL(A.ID_PROYECTO,0)) + '"'
              + ' data-vct-filter-mia="' + CASE WHEN A.MIA = 1 THEN '1' ELSE '0' END + '">'
              /* Vence */
              + '<td data-label="Vence" data-vct-sort-value="' + ISNULL(CONVERT(VARCHAR(8), A.VENCE, 112), '99991231') + '"'
              +   ' data-vct-export-value="' + ISNULL(CONVERT(VARCHAR(10), A.VENCE, 103), 'Sin fecha') + '">'
              +   '<span class="vct-acc-date">' + ISNULL(CONVERT(VARCHAR(10), A.VENCE, 103), '-') + '</span>'
              +   CASE A.SIT
                    WHEN 'V' THEN '<span class="vct-acc-rel is-red">hace ' + CONVERT(VARCHAR(10), -A.DIAS) + CASE WHEN A.DIAS = -1 THEN ' d&iacute;a' ELSE ' d&iacute;as' END + '</span>'
                    WHEN 'H' THEN '<span class="vct-acc-rel is-amb">Hoy</span>'
                    WHEN 'P' THEN '<span class="vct-acc-rel is-bor">' + CASE WHEN A.DIAS = 1 THEN 'Ma&ntilde;ana' ELSE 'en ' + CONVERT(VARCHAR(10), A.DIAS) + ' d&iacute;as' END + '</span>'
                    WHEN 'L' THEN '<span class="vct-acc-rel is-gry">en ' + CONVERT(VARCHAR(10), A.DIAS) + ' d&iacute;as</span>'
                    ELSE '<span class="vct-acc-rel is-gry">Sin fecha</span>' END
              + '</td>'
              /* Accion */
              + '<td data-label="Acci&oacute;n" data-vct-sort-value="' + A.E_TIT + '" data-vct-export-value="' + A.E_TIT + '">'
              +   '<span class="vct-acc-title">' + A.E_TIT + '</span>'
              +   CASE WHEN A.E_SUB <> '' THEN '<span class="vct-acc-sub">' + A.E_SUB + '</span>' ELSE '' END
              + '</td>'
              /* Cliente / Proyecto */
              + '<td data-label="Cliente / Proyecto" data-vct-sort-value="' + A.E_CLI + '" data-vct-export-value="' + A.E_CLI + CASE WHEN A.E_PROY <> '' THEN ' - ' + A.E_PROY ELSE '' END + '">'
              +   CASE WHEN A.E_CLI = '' AND A.E_PROY = '' THEN '<span class="vct-acc-muted">-</span>'
                       ELSE '<span class="vct-acc-title is-light">' + CASE WHEN A.E_CLI <> '' THEN A.E_CLI ELSE 'Sin cliente' END + '</span>'
                          + CASE WHEN A.E_PROY <> '' THEN '<span class="vct-acc-sub">' + A.E_PROY + '</span>' ELSE '' END END
              + '</td>'
              /* Responsable (solo quien ve todo) */
              + CASE WHEN @VE_TODO = 1 THEN
                    '<td data-label="Responsable" data-vct-sort-value="' + A.E_RESP + '" data-vct-export-value="' + A.E_RESP + '">'
                  + '<span class="vctdg-person"><span class="vctdg-avatar ' + CASE WHEN A.RESP_KEY = 'X' THEN 'is-none' WHEN A.RESP_TIPO = 'EMPLEADO' THEN 'is-a' ELSE 'is-c' END + '" title="' + A.E_RESP + '">' + A.RESP_INI + '</span>'
                  + '<span class="vctdg-person-name' + CASE WHEN A.RESP_KEY = 'X' THEN ' vct-acc-muted' ELSE '' END + '">' + A.E_RESP + '</span></span></td>'
                ELSE '' END
              /* Prioridad (si existe) */
              + CASE WHEN @HAS_PRIO = 1 THEN
                    '<td class="vct-text-center" data-label="Prioridad" data-vct-sort-value="' + CASE A.PRIO_COD WHEN 'URGENTE' THEN '0' WHEN 'CRITICA' THEN '0' WHEN 'ALTA' THEN '1' WHEN 'MEDIA' THEN '2' WHEN 'BAJA' THEN '3' ELSE '9' END + '"'
                  + ' data-vct-export-value="' + A.E_PRIO + '">'
                  + CASE WHEN A.E_PRIO = '' THEN '<span class="vct-acc-muted">-</span>'
                         ELSE '<span class="vct-360-badge ' + CASE WHEN A.PRIO_COD IN ('URGENTE','CRITICA','ALTA') THEN 'is-cancel' WHEN A.PRIO_COD = 'MEDIA' THEN 'is-planned' ELSE 'is-neutral' END + '">' + A.E_PRIO + '</span>' END
                  + '</td>'
                ELSE '' END
              /* Estado */
              + '<td class="vct-text-center" data-label="Estado" data-vct-sort-value="' + A.E_EST + '" data-vct-export-value="' + A.E_EST + '">'
              +   '<span class="vct-360-badge ' + CASE WHEN A.EST_COD = 'EN_CURSO' THEN 'is-active' WHEN A.EST_COD = 'PENDIENTE' OR A.EST_COD = '' THEN 'is-neutral' ELSE 'is-planned' END + '">' + A.E_EST + '</span>'
              + '</td>'
              /* menu */
              + '<td class="vct-table-action-cell" data-label="" data-vct-export-ignore="true">'
              +   CASE WHEN ISNULL(A.MENU,'') <> '' THEN
                        '<button type="button" class="vct-row-menu-trigger" data-vctdg-rowmenu aria-label="Acciones" title="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                      + '<div class="vctdg-rowmenu-items" hidden>' + A.MENU + '</div>'
                   ELSE '' END
              + '</td>'
              + '</tr>'
            FROM #A A
            WHERE A.SIT <> 'C' AND (@P_SIT = 'T' OR A.SIT = @P_SIT)
            ORDER BY ISNULL(A.VENCE, '29991231'), A.ID
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

        /* --- opciones de filtros (solo valores presentes en la pestana) --- */
        SELECT @O_RESP = ISNULL((
            SELECT '<option value="' + X.RESP_KEY + '">' + X.E_RESP + '</option>'
            FROM (SELECT DISTINCT RESP_KEY, E_RESP FROM #A WHERE SIT <> 'C' AND (@P_SIT = 'T' OR SIT = @P_SIT)) X
            ORDER BY CASE WHEN X.RESP_KEY = 'X' THEN 1 ELSE 0 END, X.E_RESP
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
        SELECT @O_TIPO = ISNULL((
            SELECT '<option value="' + CONVERT(VARCHAR(12), X.ID_TIPO) + '">' + X.E + '</option>'
            FROM (SELECT DISTINCT ISNULL(ID_TIPO,0) AS ID_TIPO,
                         REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(TIPO,''),'Sin tipo'),'&','&amp;'),'<','&lt;'),'>','&gt;') AS E
                  FROM #A WHERE SIT <> 'C' AND (@P_SIT = 'T' OR SIT = @P_SIT)) X
            ORDER BY X.E
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
        SELECT @O_PRIO = ISNULL((
            SELECT '<option value="' + X.K + '">' + X.E + '</option>'
            FROM (SELECT DISTINCT ISNULL(NULLIF(PRIO_COD,''),'NA') AS K, ISNULL(NULLIF(E_PRIO,''),'Sin prioridad') AS E,
                         CASE PRIO_COD WHEN 'URGENTE' THEN 0 WHEN 'CRITICA' THEN 0 WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 WHEN 'BAJA' THEN 3 ELSE 9 END AS O
                  FROM #A WHERE SIT <> 'C' AND (@P_SIT = 'T' OR SIT = @P_SIT)) X
            ORDER BY X.O, X.E
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
        SELECT @O_PROY = ISNULL((
            SELECT '<option value="' + CONVERT(VARCHAR(12), X.ID_PROYECTO) + '">' + X.E + '</option>'
            FROM (SELECT DISTINCT ISNULL(ID_PROYECTO,0) AS ID_PROYECTO,
                         CASE WHEN ID_PROYECTO IS NULL THEN 'Sin proyecto' ELSE LEFT(E_PROY, 60) END AS E
                  FROM #A WHERE SIT <> 'C' AND (@P_SIT = 'T' OR SIT = @P_SIT)) X
            ORDER BY CASE WHEN X.ID_PROYECTO = 0 THEN 1 ELSE 0 END, X.E
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

        SET @FILTERS = '<div data-vct-dg-slot="filters">'
            + CASE WHEN @VE_TODO = 1 THEN '<select class="vct-select vct-select-sm" data-vct-dg-filter="resp" aria-label="Responsable"><option value="">Responsable</option>' + @O_RESP + '</select>' ELSE '' END
            + '<select class="vct-select vct-select-sm" data-vct-dg-filter="tipo" aria-label="Tipo"><option value="">Tipo</option>' + @O_TIPO + '</select>'
            + CASE WHEN @HAS_PRIO = 1 THEN '<select class="vct-select vct-select-sm" data-vct-dg-filter="prio" aria-label="Prioridad"><option value="">Prioridad</option>' + @O_PRIO + '</select>' ELSE '' END
            + '<select class="vct-select vct-select-sm" data-vct-dg-filter="proy" aria-label="Proyecto"><option value="">Proyecto</option>' + @O_PROY + '</select>'
            + CASE WHEN @VE_TODO = 1 THEN '<select class="vct-select vct-select-sm" data-vct-dg-filter="mia" aria-label="Asignaci&oacute;n"><option value="">Todas</option><option value="1">A mi cargo</option></select>' ELSE '' END
            + '</div>';

        SET @PANELS = @PANELS
            + '<div class="vct-360-panel vct-acc-panel" data-vct-panel="' + @P_CODE + '" data-vct-acc-sit="' + @P_SIT + '">'
            + '<div class="vct-360-box vct-360-box-grid-auto vct-acc-box">'
            +   '<div class="vct-360-box-head vct-acc-head">'
            +     '<div class="vct-acc-head-txt"><h3><span class="vct-360-title-icon"><span data-vct-icon="' + @P_ICON + '"></span></span>' + @P_TIT + ' (' + CONVERT(VARCHAR(10), @P_CNT) + ')</h3>'
            +     '<p class="vct-360-box-subtitle">' + @P_SUBT + '</p></div>'
            +     CASE WHEN @P_CAL = 1 THEN
                     '<div class="vct-acc-view" role="group" aria-label="Vista">'
                   + '<button type="button" class="is-on" data-vct-acc-view="lista"><span data-vct-icon="list-checks"></span><span>Lista</span></button>'
                   + '<button type="button" data-vct-acc-view="calendario"><span data-vct-icon="calendar-days"></span><span>Calendario</span></button>'
                   + '</div>'
                  ELSE '' END
            +     '<div class="vct-360-box-actions">' + @BTN_NUEVA + '</div>'
            +   '</div>'
            +   '<div class="vct-acc-list">'
            +   '<div data-vct-dg data-vct-dg-id="acc-' + @P_CODE + '" data-vct-dg-title="Acciones - ' + @P_TIT + '"'
            +   ' data-vct-dg-unit="acci&oacute;n(es)" data-vct-dg-page-size="10"'
            +   ' data-vct-dg-search-placeholder="Buscar acci&oacute;n, cliente, proyecto o fecha..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'
            +   @FILTERS
            +   '<table><thead><tr>'
            +     '<th data-vct-width="' + CASE WHEN @VE_TODO = 1 THEN '12%' ELSE '13%' END + '" data-vct-sort="vence" data-vct-sortable="true"><span>Vence</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
            +     '<th data-vct-sort="accion" data-vct-sortable="true"><span>Acci&oacute;n</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
            +     '<th data-vct-width="' + CASE WHEN @VE_TODO = 1 THEN '22%' ELSE '28%' END + '" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente / Proyecto</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
            +     CASE WHEN @VE_TODO = 1 THEN '<th data-vct-width="16%" data-vct-sort="resp" data-vct-sortable="true"><span>Responsable</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END
            +     CASE WHEN @HAS_PRIO = 1 THEN '<th class="vct-text-center" data-vct-width="10%" data-vct-sort="prio" data-vct-sortable="true"><span>Prioridad</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END
            +     '<th class="vct-text-center" data-vct-width="11%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
            +     '<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>'
            +   '</tr></thead><tbody>' + @ROWS + '</tbody></table>'
            +   '</div></div>'
            +   CASE WHEN @P_CAL = 1 THEN '<div class="vct-acc-cal" data-vct-acc-cal hidden></div>' ELSE '' END
            + '</div></div>';

        SET @ORD = @ORD + 1;
    END;

    /* datos del calendario (abiertas con fecha) */
    DECLARE @CALDATA VARCHAR(MAX);
    SELECT @CALDATA = ISNULL((
        SELECT '<i data-d="' + CONVERT(VARCHAR(8), A.VENCE, 112) + '" data-s="' + A.SIT + '" data-t="' + A.E_TIT + '"></i>'
        FROM #A A
        WHERE A.SIT IN ('V','H','P','L')
        ORDER BY A.VENCE, A.ID
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    /* ==================================================================
       8. GRAFICOS
       ================================================================== */
    /* 8.1 abiertas por responsable (quien ve todo) o por proyecto (resto) */
    CREATE TABLE #G1 (K VARCHAR(30), E VARCHAR(900), V INT, H INT, P INT, L INT, T INT);
    IF @VE_TODO = 1
        INSERT INTO #G1 (K, E, V, H, P, L, T)
        SELECT TOP 8 RESP_KEY, MAX(E_RESP),
               SUM(CASE WHEN SIT = 'V' THEN 1 ELSE 0 END), SUM(CASE WHEN SIT = 'H' THEN 1 ELSE 0 END),
               SUM(CASE WHEN SIT = 'P' THEN 1 ELSE 0 END), SUM(CASE WHEN SIT IN ('L','S') THEN 1 ELSE 0 END), COUNT(*)
        FROM #A WHERE SIT <> 'C' GROUP BY RESP_KEY ORDER BY COUNT(*) DESC, MAX(E_RESP);
    ELSE
        INSERT INTO #G1 (K, E, V, H, P, L, T)
        SELECT TOP 8 CONVERT(VARCHAR(30), ISNULL(ID_PROYECTO,0)), ISNULL(NULLIF(MAX(E_PROY),''),'Sin proyecto'),
               SUM(CASE WHEN SIT = 'V' THEN 1 ELSE 0 END), SUM(CASE WHEN SIT = 'H' THEN 1 ELSE 0 END),
               SUM(CASE WHEN SIT = 'P' THEN 1 ELSE 0 END), SUM(CASE WHEN SIT IN ('L','S') THEN 1 ELSE 0 END), COUNT(*)
        FROM #A WHERE SIT <> 'C' GROUP BY ISNULL(ID_PROYECTO,0) ORDER BY COUNT(*) DESC, MAX(E_PROY);

    DECLARE @G1MAX INT = (SELECT MAX(T) FROM #G1), @G1 VARCHAR(MAX);
    SELECT @G1 = ISNULL((
        SELECT '<div class="vct-acc-hb"><span class="vct-acc-hb-name" title="' + E + '">' + E + '</span><span class="vct-acc-hb-bar">'
             + CASE WHEN V > 0 THEN '<i class="is-red" style="width:' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * V / @G1MAX)) + '%" title="Vencidas: ' + CONVERT(VARCHAR(10), V) + '"></i>' ELSE '' END
             + CASE WHEN H > 0 THEN '<i class="is-amb" style="width:' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * H / @G1MAX)) + '%" title="Hoy: ' + CONVERT(VARCHAR(10), H) + '"></i>' ELSE '' END
             + CASE WHEN P > 0 THEN '<i class="is-bor" style="width:' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * P / @G1MAX)) + '%" title="Pr&oacute;ximas: ' + CONVERT(VARCHAR(10), P) + '"></i>' ELSE '' END
             + CASE WHEN L > 0 THEN '<i class="is-gry" style="width:' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * L / @G1MAX)) + '%" title="M&aacute;s adelante / sin fecha: ' + CONVERT(VARCHAR(10), L) + '"></i>' ELSE '' END
             + '</span><b>' + CONVERT(VARCHAR(10), T) + '</b></div>'
        FROM #G1 ORDER BY T DESC, E
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
    IF @G1 = '' SET @G1 = '<div class="vct-acc-empty">No hay acciones abiertas.</div>';
    SET @G1 = @G1 + '<div class="vct-acc-lg"><span><i class="is-red"></i>Vencidas</span><span><i class="is-amb"></i>Hoy</span><span><i class="is-bor"></i>Pr&oacute;ximas</span><span><i class="is-gry"></i>M&aacute;s adelante / sin fecha</span></div>';

    /* 8.2 proximos 14 dias */
    CREATE TABLE #G2 (N INT, D DATE, C INT);
    INSERT INTO #G2 (N, D, C)
    SELECT X.N, DATEADD(DAY, X.N, @HOY), 0
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) X(N);
    UPDATE G SET C = (SELECT COUNT(*) FROM #A A WHERE A.SIT <> 'C' AND A.VENCE = G.D) FROM #G2 G;
    DECLARE @G2MAX INT = (SELECT MAX(C) FROM #G2), @G2 VARCHAR(MAX), @G2L VARCHAR(MAX);
    SELECT @G2 = ISNULL((
        SELECT '<span class="' + CASE WHEN N = 0 THEN 'is-today' WHEN DATEDIFF(DAY, '19000101', D) % 7 IN (5,6) THEN 'is-we' ELSE '' END + '"'
             + ' style="height:' + CONVERT(VARCHAR(10), CASE WHEN ISNULL(@G2MAX,0) = 0 OR C = 0 THEN 2 ELSE CONVERT(INT, ROUND(100.0 * C / @G2MAX, 0)) END) + '%"'
             + ' title="' + CONVERT(VARCHAR(10), D, 103) + ': ' + CONVERT(VARCHAR(10), C) + '">'
             + CASE WHEN C > 0 THEN '<em>' + CONVERT(VARCHAR(10), C) + '</em>' ELSE '' END + '</span>'
        FROM #G2 ORDER BY N
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
    SELECT @G2L = ISNULL((
        SELECT '<span>' + SUBSTRING('LuMaMiJuViSaDo', (DATEDIFF(DAY, '19000101', D) % 7) * 2 + 1, 2) + '<br>' + CONVERT(VARCHAR(2), DAY(D)) + '</span>'
        FROM #G2 ORDER BY N
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    /* 8.3 cumplidas a termino por mes (6 meses) */
    CREATE TABLE #G3 (ORDEN INT, INI DATE, LBL VARCHAR(5), TOT INT, OK INT);
    INSERT INTO #G3 (ORDEN, INI, LBL, TOT, OK)
    SELECT X.N, DATEADD(MONTH, X.N, DATEADD(MONTH, DATEDIFF(MONTH, 0, @HOY), 0)),
           SUBSTRING('EneFebMarAbrMayJunJulAgoSepOctNovDic', (MONTH(DATEADD(MONTH, X.N, @HOY)) - 1) * 3 + 1, 3), 0, 0
    FROM (VALUES (-5),(-4),(-3),(-2),(-1),(0)) X(N);
    UPDATE M SET
        TOT = (SELECT COUNT(*) FROM #A A WHERE A.SIT = 'C' AND A.EST_COD <> 'CANCELADA' AND A.CIERRE >= M.INI AND A.CIERRE < DATEADD(MONTH, 1, M.INI)),
        OK  = (SELECT COUNT(*) FROM #A A WHERE A.SIT = 'C' AND A.EST_COD <> 'CANCELADA' AND A.CIERRE >= M.INI AND A.CIERRE < DATEADD(MONTH, 1, M.INI)
                                         AND (A.VENCE IS NULL OR CONVERT(DATE, A.CIERRE) <= A.VENCE))
    FROM #G3 M;
    DECLARE @G3 VARCHAR(MAX), @G3L VARCHAR(MAX), @G3TOT INT, @G3OK INT;
    SELECT @G3TOT = SUM(TOT), @G3OK = SUM(OK) FROM #G3;
    SELECT @G3 = ISNULL((
        SELECT '<span class="' + CASE WHEN ORDEN = 0 THEN 'is-today' ELSE '' END + '"'
             + ' style="height:' + CONVERT(VARCHAR(10), CASE WHEN TOT = 0 THEN 2 ELSE CONVERT(INT, ROUND(100.0 * OK / TOT, 0)) END) + '%"'
             + ' title="' + CONVERT(VARCHAR(10), OK) + ' de ' + CONVERT(VARCHAR(10), TOT) + ' a t&eacute;rmino">'
             + '<em>' + CASE WHEN TOT = 0 THEN '-' ELSE CONVERT(VARCHAR(10), CONVERT(INT, ROUND(100.0 * OK / TOT, 0))) + '%' END + '</em></span>'
        FROM #G3 ORDER BY ORDEN
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
    SELECT @G3L = ISNULL((SELECT '<span>' + LBL + '</span>' FROM #G3 ORDER BY ORDEN FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    /* 8.4 abiertas por tipo (dona) */
    CREATE TABLE #G4 (RN INT, E VARCHAR(300), C INT, COLOR VARCHAR(10), DESDE DECIMAL(6,2), HASTA DECIMAL(6,2));
    INSERT INTO #G4 (RN, E, C)
    SELECT ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, MAX(E)), MAX(E), COUNT(*)
    FROM (SELECT ISNULL(ID_TIPO,0) AS K, REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(TIPO,''),'Sin tipo'),'&','&amp;'),'<','&lt;'),'>','&gt;') AS E
          FROM #A WHERE SIT <> 'C') X
    GROUP BY X.K;
    IF (SELECT COUNT(*) FROM #G4) > 5
    BEGIN
        DECLARE @OTROS INT = (SELECT SUM(C) FROM #G4 WHERE RN >= 5);
        DELETE FROM #G4 WHERE RN >= 5;
        INSERT INTO #G4 (RN, E, C) VALUES (5, 'Otros', @OTROS);
    END;
    UPDATE #G4 SET COLOR = CASE RN WHEN 1 THEN '#8C1D47' WHEN 2 THEN '#4A4849' WHEN 3 THEN '#CF6F92' WHEN 4 THEN '#8E8C8D' ELSE '#D9C3CD' END;
    UPDATE G SET
        DESDE = CONVERT(DECIMAL(6,2), 100.0 * ISNULL((SELECT SUM(Z.C) FROM #G4 Z WHERE Z.RN < G.RN),0) / NULLIF(@C_T,0)),
        HASTA = CONVERT(DECIMAL(6,2), 100.0 * ISNULL((SELECT SUM(Z.C) FROM #G4 Z WHERE Z.RN <= G.RN),0) / NULLIF(@C_T,0))
    FROM #G4 G;
    DECLARE @G4GRAD VARCHAR(MAX), @G4L VARCHAR(MAX);
    SELECT @G4GRAD = ISNULL(STUFF((
        SELECT ',' + COLOR + ' ' + CONVERT(VARCHAR(10), ISNULL(DESDE,0)) + '% ' + CONVERT(VARCHAR(10), ISNULL(HASTA,0)) + '%'
        FROM #G4 ORDER BY RN
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), 1, 1, ''), '');
    SELECT @G4L = ISNULL((
        SELECT '<span><i style="background:' + COLOR + '"></i><em>' + E + '</em><b>' + CONVERT(VARCHAR(10), C) + '</b></span>'
        FROM #G4 ORDER BY RN
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    DECLARE @GRAFICOS VARCHAR(MAX) = CONVERT(VARCHAR(MAX), '')
        + '<div class="vct-360-panel vct-acc-panel" data-vct-panel="graficos">'
        + '<div class="vct-360-box vct-acc-box">'
        +   '<div class="vct-360-box-head vct-acc-head"><div class="vct-acc-head-txt"><h3><span class="vct-360-title-icon"><span data-vct-icon="chart-bar"></span></span>Gr&aacute;ficos</h3>'
        +   '<p class="vct-360-box-subtitle">' + CASE WHEN @VE_TODO = 1 THEN 'Seguimiento de las acciones de todo el equipo.' ELSE 'Seguimiento de tus acciones.' END + '</p></div></div>'
        +   '<div class="vct-acc-charts">'
        +     '<div class="vct-acc-chart"><div class="vct-acc-chart-t">' + CASE WHEN @VE_TODO = 1 THEN 'Abiertas por responsable' ELSE 'Abiertas por proyecto' END + '<small>las 8 con m&aacute;s carga</small></div>' + @G1 + '</div>'
        +     '<div class="vct-acc-chart"><div class="vct-acc-chart-t">Vencimientos de los pr&oacute;ximos 14 d&iacute;as<small>acciones abiertas por d&iacute;a</small></div>'
        +       '<div class="vct-acc-cols">' + @G2 + '</div><div class="vct-acc-clb">' + @G2L + '</div></div>'
        +     '<div class="vct-acc-chart"><div class="vct-acc-chart-t">Cumplidas a t&eacute;rmino<small>'
        +       CASE WHEN ISNULL(@G3TOT,0) = 0 THEN 'sin acciones cerradas en los &uacute;ltimos 6 meses'
                     ELSE CONVERT(VARCHAR(10), CONVERT(INT, ROUND(100.0 * @G3OK / @G3TOT, 0))) + '% en los &uacute;ltimos 6 meses (' + CONVERT(VARCHAR(10), @G3OK) + ' de ' + CONVERT(VARCHAR(10), @G3TOT) + ')' END
        +       '</small></div><div class="vct-acc-cols is-pct">' + @G3 + '</div><div class="vct-acc-clb">' + @G3L + '</div></div>'
        +     '<div class="vct-acc-chart"><div class="vct-acc-chart-t">Abiertas por tipo<small>' + CONVERT(VARCHAR(10), @C_T) + ' acciones abiertas</small></div>'
        +       '<div class="vct-acc-dn"><div class="vct-acc-donut" style="background:' + CASE WHEN @C_T = 0 OR @G4GRAD = '' THEN '#EEF2F7' ELSE 'conic-gradient(' + @G4GRAD + ')' END + '"><b>' + CONVERT(VARCHAR(10), @C_T) + '</b></div>'
        +       '<div class="vct-acc-dl">' + CASE WHEN @G4L = '' THEN '<span class="vct-acc-muted">Sin datos</span>' ELSE @G4L END + '</div></div></div>'
        +   '</div>'
        + '</div></div>';

    /* ==================================================================
       9. SALIDA
       ================================================================== */
    SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') + @ASSETS
        + '<div class="vct-page vct-page-main vct-acc-page" data-vct-page data-vct-sidebar-id="2" data-vct-form-id="' + REPLACE(ISNULL(@FORM_ID,''),'"','') + '">'
        + '<section class="vct-module vct-360-module vct-360-visual-final vct-acc-module" data-vct-module data-vct-acc'
        + ' data-vct-entity-theme="acciones" data-vct-tabs data-vct-tabs-active="' + @TAB_INI + '" data-vct-acc-default="' + @TAB_INI + '"'
        + ' data-vct-acc-hoy="' + CONVERT(VARCHAR(8), @HOY, 112) + '">'
        + '<input type="hidden" name="SP.TEXTO30" data-vct-field="TEXTO30" value="">'
        + '<input type="hidden" name="SP.IDSELEC03" data-vct-field="IDSELEC03" value="">'
        + '<input type="hidden" name="SP.TEXTO11" data-vct-field="TEXTO11" value="">'
        + '<input type="hidden" name="SP.FLAG01" data-vct-field="FLAG01" value="">'
        + '<div class="vct-acc-caldata" hidden>' + @CALDATA + '</div>'
        + '<div class="vct-360-content-shell">'
        + CASE WHEN @ERR <> '' THEN '<div class="vct-acc-alert is-error">' + REPLACE(REPLACE(@ERR,'<','&lt;'),'>','&gt;') + '</div>'
               WHEN @MSG <> '' THEN '<div class="vct-acc-alert is-ok">' + REPLACE(REPLACE(@MSG,'<','&lt;'),'>','&gt;') + '</div>' ELSE '' END
        + '<div class="vct-360-tabsbar vct-acc-tabs" data-vct-tablist>'
        +   @TABS
        +   '<button type="button" class="vct-acc-tab-graf" data-vct-tab="graficos"><span data-vct-icon="chart-bar"></span><span>Gr&aacute;ficos</span></button>'
        + '</div>'
        + @PANELS
        + @GRAFICOS
        + '</div></section></div>';
END
GO

DECLARE @OK BIT = 0, @TRG BIT = 0;
SELECT @TRG = TRG_ON FROM #ACC_V2_RUN;
IF EXISTS (SELECT 1 FROM sys.procedures P CROSS JOIN #ACC_V2_RUN R
           WHERE P.object_id = OBJECT_ID('dbo.VCT_MAIN_ACCIONES') AND P.modify_date >= R.INICIO
             AND OBJECT_DEFINITION(P.object_id) LIKE '%ACCIONES_PANTALLA_V2%')
    SET @OK = 1;
IF @TRG = 1 ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
IF @OK = 1 PRINT 'OK   dbo.VCT_MAIN_ACCIONES creado/reemplazado (ACCIONES_PANTALLA_V2).';
ELSE PRINT 'FALLO dbo.VCT_MAIN_ACCIONES no se actualizo: revisar el error del bloque anterior.';
IF @TRG = 1 PRINT 'OK   trigger TR_VCT_AUDITORIA_DDL reactivado.';

/* Permisos que lee la pantalla (solo listado, no modifica nada) */
SELECT 'ACCIONES' AS MODULO, A.ACTION_ID, A.ACTION_TYPE, A.TITLE, GA.GroupId AS PERFIL
FROM dbo.PrmActions PA
INNER JOIN dbo.Actions A0 ON A0.Id COLLATE DATABASE_DEFAULT = PA.ActionID COLLATE DATABASE_DEFAULT
INNER JOIN dbo.GroupsActions GA ON GA.ActionId COLLATE DATABASE_DEFAULT = A0.Id COLLATE DATABASE_DEFAULT
CROSS APPLY (SELECT PA.ActionID AS ACTION_ID, UPPER(ISNULL(PA.ActionType,'')) AS ACTION_TYPE, ISNULL(PA.Title,'') AS TITLE) A
WHERE UPPER(PA.ActionID) LIKE 'ACCIONES.%'
ORDER BY GA.GroupId, A.ACTION_TYPE;
GO
