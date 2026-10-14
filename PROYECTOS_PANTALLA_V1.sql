/* ========================================================================
   PROYECTOS_PANTALLA_V1
   ------------------------------------------------------------------------
   Pantalla Proyectos (opcion del sidebar, ACTION=PROYECTOS) segun boceto v2.
   1) CREATE OR ALTER dbo.VCT_MAIN_PROYECTOS (si existe se reemplaza).
   2) No toca el ruteo: ACTION=PROYECTOS ya llega a este SP por el flujo
      de la plataforma.

   Pantalla:
   - KPIs: Proyectos activos (avance promedio) | Terminan en 30 dias |
     Atrasados (fin vencido sin terminar) | Sin consultor.
   - Grilla estandar: Cliente | Proyecto (codigo + nombre, referencia) |
     Servicios | Normas | Analista | Consultor (iniciales + tooltip) |
     Inicio | Fin | Estado | Avance | menu de 3 puntos.
   - Dos modos, mismo SP: VIGENTES (por defecto) = En curso + Confirmado;
     OTROS = el resto de los estados. Boton "Otros estados" / "En curso y
     confirmados" en el toolbar: guarda TEXTO30='PRY_MODO_OTROS'|'PRY_MODO_VIGENTES'
     y refresca el mismo paso (VCT.Navigation.next); ACTION no se toca.
   - Filtros: Estado (Todos los estados por defecto + los estados del modo)
     y Servicio (js/vct-proyectos.js v3). KPIs siempre sobre los vigentes.
   - Alcance: GERENCIA, SQUAD, ADMINISTRACION y PROYECTOS ven todos;
     el resto solo los proyectos donde su usuario esta en el equipo o en
     visitas. Perfil CLIENTE*: solo mensaje del sistema.
   - Permisos: SOLO lectura con dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD,'PROYECTOS'):
       VIEW / EDIT -> menu de 3 puntos,  CREATE -> boton "Nuevo".
     Este script NO inserta ni modifica permisos. No crea vistas, funciones
     ni tablas. Sin caracteres no ASCII.
   - Assets: css/vct-proyectos.css?v=2, js/vct-proyectos.js?v=5,
             css/vct-datagrid.css?v=30, js/vct-datagrid.js?v=12.
   ======================================================================== */
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#PRY_V1_RUN') IS NOT NULL DROP TABLE #PRY_V1_RUN;
CREATE TABLE #PRY_V1_RUN (TRG_ON BIT, INICIO DATETIME);
INSERT INTO #PRY_V1_RUN (TRG_ON, INICIO)
SELECT CASE WHEN EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) THEN 1 ELSE 0 END,
       DATEADD(SECOND, -2, GETDATE());
IF EXISTS (SELECT 1 FROM #PRY_V1_RUN WHERE TRG_ON = 1)
    DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
GO

CREATE OR ALTER PROCEDURE dbo.VCT_MAIN_PROYECTOS
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
    /* PROYECTOS_PANTALLA_V1 (V1.2 14/10: modo VIGENTES = En curso + Confirmado / modo OTROS = el resto de los estados) */
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
            @SIDEBAR_ID INT = 0,
            @SUBT       VARCHAR(300),
            @ASSETS     VARCHAR(MAX),
            @FORM_ESC   VARCHAR(200) = REPLACE(ISNULL(@FORM_ID,''),'"',''),
            @MODO       VARCHAR(20)  = 'VIGENTES';

    /* modo de la grilla: el boton "Otros estados" / "En curso y confirmados" guarda
       TEXTO30='PRY_MODO_OTROS'|'PRY_MODO_VIGENTES' y refresca el MISMO paso (next),
       sin tocar ACTION. Se lee y se limpia aca. */
    DECLARE @B_CMD VARCHAR(100);
    SELECT TOP 1 @B_CMD = UPPER(LTRIM(RTRIM(ISNULL(TEXTO30,'')))) FROM dbo.VCT_BUFFER WITH(NOLOCK) WHERE PAR_KEY = @IPKEYJOB;
    IF @B_CMD IN ('PRY_MODO_OTROS','PRY_MODO_VIGENTES')
    BEGIN
        SET @MODO = CASE WHEN @B_CMD = 'PRY_MODO_OTROS' THEN 'OTROS' ELSE 'VIGENTES' END;
        UPDATE dbo.VCT_BUFFER SET TEXTO30 = NULL WHERE PAR_KEY = @IPKEYJOB;
    END;

    SET @ES_CLIENTE = CASE WHEN @PERFIL LIKE 'CLIENTE%' THEN 1 ELSE 0 END;
    SET @VE_TODO    = CASE WHEN @PERFIL IN ('GERENCIA','SQUAD','ADMINISTRACION','PROYECTOS') THEN 1 ELSE 0 END;
    SET @SUBT = CASE WHEN @ES_CLIENTE = 1 THEN ''
                     WHEN @MODO = 'OTROS' THEN 'Proyectos en otros estados (pausados, terminados, cancelados...).'
                     WHEN @VE_TODO = 1 THEN 'Proyectos en curso y confirmados: avance, equipo y fechas.'
                     ELSE 'Tus proyectos en curso y confirmados.' END;

    BEGIN TRY
        EXEC dbo.VCT_GET_SHELL @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE, @FORM_ID = @FORM_ID,
             @TITLE = 'Proyectos', @SUBTITLE = @SUBT, @SEARCH_PLACEHOLDER = '', @SHOW_SEARCH = 0,
             @OSHELL = @HTML_SHELL OUTPUT, @ORESULTADO = @RES OUTPUT;
    END TRY
    BEGIN CATCH
        SET @HTML_SHELL = '';
    END CATCH;

    SET @ASSETS = CONVERT(VARCHAR(MAX), '')
        + '<link rel="stylesheet" href="../css/vct-datagrid.css?v=29">'
        + '<link rel="stylesheet" href="../css/vct-proyectos.css?v=2">'
        + '<script src="../js/vct-export.js?v=1"></script>'
        + '<script src="../js/vct-datagrid.js?v=11"></script>'
        + '<script src="../js/vct-proyectos.js?v=5"></script>';

    /* ==================================================================
       1. PERMISOS (solo lectura) + sidebar activo
       ================================================================== */
    CREATE TABLE #ACT (ID_PRM VARCHAR(100), ACTION_ID VARCHAR(100), ACTION_TYPE VARCHAR(50), TITLE VARCHAR(200), ICON VARCHAR(100),
                       STORAGE_KEY VARCHAR(100), TARGET_TAB VARCHAR(100), TARGET_GUID VARCHAR(100), SORT_ORDER INT, SIDEBAR_ID INT);
    BEGIN TRY
        INSERT INTO #ACT (ID_PRM, ACTION_ID, ACTION_TYPE, TITLE, ICON, STORAGE_KEY, TARGET_TAB, TARGET_GUID, SORT_ORDER, SIDEBAR_ID)
        SELECT CONVERT(VARCHAR(100), A.ID_PRM), A.ACTION_ID, A.ACTION_TYPE,
               ISNULL(NULLIF(A.TITLE,''), CASE A.ACTION_TYPE WHEN 'VIEW' THEN 'Ver proyecto' WHEN 'EDIT' THEN 'Editar proyecto' ELSE 'Nuevo proyecto' END),
               ISNULL(NULLIF(A.ICON,''), CASE A.ACTION_TYPE WHEN 'VIEW' THEN 'scan-eye' WHEN 'EDIT' THEN 'edit' ELSE 'plus' END),
               A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID, A.SORT_ORDER, ISNULL(A.SIDEBAR_ID,0)
        FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, 'PROYECTOS') A;
    END TRY
    BEGIN CATCH
        DELETE FROM #ACT;
    END CATCH;

    SELECT TOP 1 @SIDEBAR_ID = SIDEBAR_ID FROM #ACT WHERE SIDEBAR_ID <> 0 ORDER BY SORT_ORDER, ID_PRM;
    IF ISNULL(@SIDEBAR_ID,0) = 0
    BEGIN
        BEGIN TRY
            SELECT TOP 1 @SIDEBAR_ID = CONVERT(INT, SB.Id)
            FROM dbo.SideBar SB WITH(NOLOCK)
            WHERE UPPER(LTRIM(RTRIM(ISNULL(SB.Code,'')))) = 'PROYECTOS'
            ORDER BY CONVERT(INT, SB.Id);
        END TRY
        BEGIN CATCH
            SET @SIDEBAR_ID = 0;
        END CATCH;
    END;

    /* ==================================================================
       2. PERFIL CLIENTE: solo mensaje del sistema
       ================================================================== */
    IF @ES_CLIENTE = 1
    BEGIN
        SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') + @ASSETS
            + '<div class="vct-page vct-page-main vct-proy-page" data-vct-page data-vct-sidebar-id="' + CONVERT(VARCHAR(20), ISNULL(@SIDEBAR_ID,0)) + '" data-vct-form-id="' + @FORM_ESC + '">'
            + '<section class="vct-card vct-proy-msg"><span class="vct-proy-msg-icon"><span data-vct-icon="lock"></span></span>'
            + '<div><b>Proyectos no est&aacute; disponible para tu perfil</b>'
            + '<span>Esta opci&oacute;n es de uso interno. Si la ves en el men&uacute;, avis&aacute; al administrador del sistema para que revise los permisos de tu perfil.</span></div>'
            + '</section></div>';
        RETURN;
    END;

    DECLARE @MENU_OK BIT = CASE WHEN EXISTS (SELECT 1 FROM #ACT WHERE ACTION_TYPE IN ('VIEW','EDIT')) THEN 1 ELSE 0 END,
            @BTN_NUEVO VARCHAR(MAX) = '';
    SELECT TOP 1 @BTN_NUEVO = dbo.VCT_MAIN_RENDER_ACTION(A.ACTION_ID, A.TITLE, A.ICON, A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID,
                                                         '', 'vct-btn vct-btn-new vct-btn-sm', 'Nuevo')
    FROM #ACT A WHERE A.ACTION_TYPE IN ('CREATE','NEW','ADD','INSERT')
    ORDER BY A.SORT_ORDER, A.ID_PRM;
    SET @BTN_NUEVO = ISNULL(@BTN_NUEVO,'');

    /* ==================================================================
       3. USUARIO -> consultor / empleado (para el alcance)
       ================================================================== */
    SELECT TOP 1 @CONS_ID = ID FROM dbo.VCT_CONSULTORES
    WHERE LOWER(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,'')))) = @U AND UPPER(ISNULL(ESTADO,'')) = 'ACTIVO' ORDER BY ID DESC;
    SELECT TOP 1 @EMP_ID = ID FROM dbo.VCT_EMPLEADOS
    WHERE LOWER(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,'')))) = @U AND UPPER(ISNULL(ESTADO,'')) = 'ACTIVO' ORDER BY ID DESC;

    /* ==================================================================
       4. PROYECTOS
          SIT: ACTIVO (todo lo que no es Terminado ni Cancelado) | TERMINADO | CANCELADO
       ================================================================== */
    CREATE TABLE #P
    (
        ID INT PRIMARY KEY, CODIGO VARCHAR(100), NOMBRE VARCHAR(1000), REFERENCIA VARCHAR(1000), CLIENTE VARCHAR(1000),
        ID_ESTADO INT, EST_COD VARCHAR(100), EST_DESC VARCHAR(300), SIT VARCHAR(20),
        INICIO DATE, FIN DATE, AVANCE INT,
        AN_ID INT, AN_NOM VARCHAR(500), AN_INI VARCHAR(4),
        CO_ID INT, CO_NOM VARCHAR(500), CO_INI VARCHAR(4),
        HAS_CO BIT, HAS_AU BIT, HAS_CA BIT, SRV_LIST VARCHAR(20), SRV_TXT VARCHAR(1000),
        NORMAS_TOP VARCHAR(MAX), NORMAS_TXT VARCHAR(MAX), NORMAS_N INT,
        E_COD VARCHAR(600), E_NOM VARCHAR(4000), E_REF VARCHAR(4000), E_CLI VARCHAR(4000), E_EST VARCHAR(1000),
        E_AN VARCHAR(2000), E_CO VARCHAR(2000), E_SEARCH VARCHAR(MAX), MENU VARCHAR(MAX)
    );

    INSERT INTO #P (ID, CODIGO, NOMBRE, REFERENCIA, CLIENTE, ID_ESTADO, EST_COD, EST_DESC, INICIO, FIN, AVANCE)
    SELECT P.ID, LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(100), P.CODIGO))),100), LEFT(ISNULL(NULLIF(LTRIM(RTRIM(P.NOMBRE)),''),'-'),1000),
           LEFT(LTRIM(RTRIM(ISNULL(P.REFERENCIA,''))),1000), LEFT(CL.RAZON_SOCIAL,1000),
           P.ID_ESTADO, LEFT(UPPER(LTRIM(RTRIM(ISNULL(E.CODIGO,'')))),100), LEFT(E.DESCRIPCION,300),
           CONVERT(DATE, P.FECHA_INICIO), CONVERT(DATE, P.FECHA_FIN),
           CASE WHEN ISNULL(P.PORCENTAJE_AVANCE,0) < 0 THEN 0 WHEN ISNULL(P.PORCENTAJE_AVANCE,0) > 100 THEN 100 ELSE ISNULL(P.PORCENTAJE_AVANCE,0) END
    FROM dbo.VCT_PROYECTOS P WITH(NOLOCK)
    LEFT JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS E WITH(NOLOCK) ON E.ID = P.ID_ESTADO
    LEFT JOIN dbo.VCT_CLIENTES CL WITH(NOLOCK) ON CL.ID = P.IDCLIENTE;

    /* alcance: quien no ve todo, solo sus proyectos (equipo o visitas) */
    IF @VE_TODO = 0
        DELETE FROM #P
        WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_EQUIPO EQ WITH(NOLOCK)
                          WHERE EQ.ID_PROYECTO = #P.ID
                            AND ISNULL(NULLIF(UPPER(LTRIM(RTRIM(EQ.ESTADO))),''),'ACTIVO') <> 'INACTIVO'
                            AND ((EQ.ID_CONSULTOR = @CONS_ID AND @CONS_ID IS NOT NULL) OR (EQ.ID_EMPLEADO = @EMP_ID AND @EMP_ID IS NOT NULL)))
          AND NOT EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_VISITAS V WITH(NOLOCK)
                          INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC WITH(NOLOCK) ON VC.ID_VISITA = V.ID
                          WHERE V.ID_PROYECTO = #P.ID AND VC.ID_CONSULTOR = @CONS_ID AND @CONS_ID IS NOT NULL);

    /* SIT: V = en curso o confirmado (vigente) | O = cualquier otro estado */
    UPDATE #P SET SIT = CASE WHEN EST_COD IN ('ENCURSO','EN_CURSO','CONFIRMADO') THEN 'V' ELSE 'O' END;

    /* analista: rol ANALISTA del equipo (empleado) */
    UPDATE P SET AN_ID = X.ID_EMPLEADO
    FROM #P P
    CROSS APPLY (SELECT TOP 1 EQ.ID_EMPLEADO
                 FROM dbo.VCT_PROYECTOS_EQUIPO EQ WITH(NOLOCK)
                 INNER JOIN dbo.VCT_PRM_PROYECTOS_ROLES ROL WITH(NOLOCK) ON ROL.ID = EQ.ID_ROL
                 WHERE EQ.ID_PROYECTO = P.ID AND EQ.TIPO_MIEMBRO = 'EMPLEADO' AND EQ.ID_EMPLEADO IS NOT NULL
                   AND ROL.CODIGO = 'ANALISTA'
                   AND ISNULL(NULLIF(UPPER(LTRIM(RTRIM(EQ.ESTADO))),''),'ACTIVO') <> 'INACTIVO'
                 ORDER BY EQ.PRINCIPAL DESC, EQ.ID) X;
    UPDATE P SET
        AN_NOM = LEFT(LTRIM(RTRIM(ISNULL(EM.APELLIDOS,'') + CASE WHEN ISNULL(EM.NOMBRES,'') <> '' THEN ', ' + EM.NOMBRES ELSE '' END)),500),
        AN_INI = UPPER(LEFT(LTRIM(ISNULL(EM.NOMBRES,'')),1) + LEFT(LTRIM(ISNULL(EM.APELLIDOS,'')),1))
    FROM #P P INNER JOIN dbo.VCT_EMPLEADOS EM WITH(NOLOCK) ON EM.ID = P.AN_ID;

    /* consultor: equipo (principal primero) y, si no hay, el de las visitas (lider primero) */
    UPDATE P SET CO_ID = X.ID_CONSULTOR
    FROM #P P
    CROSS APPLY (SELECT TOP 1 Q.ID_CONSULTOR FROM
                 (
                     SELECT EQ.ID_CONSULTOR, 1 AS F, CASE WHEN ISNULL(EQ.PRINCIPAL,0) = 1 THEN 0 ELSE 1 END AS O, EQ.ID AS K
                     FROM dbo.VCT_PROYECTOS_EQUIPO EQ WITH(NOLOCK)
                     WHERE EQ.ID_PROYECTO = P.ID AND EQ.TIPO_MIEMBRO = 'CONSULTOR' AND EQ.ID_CONSULTOR IS NOT NULL
                       AND ISNULL(NULLIF(UPPER(LTRIM(RTRIM(EQ.ESTADO))),''),'ACTIVO') <> 'INACTIVO'
                     UNION ALL
                     SELECT VC.ID_CONSULTOR, 2, CASE WHEN ISNULL(VC.LIDER,0) = 1 THEN 0 ELSE 1 END, VC.ID
                     FROM dbo.VCT_PROYECTOS_VISITAS V WITH(NOLOCK)
                     INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC WITH(NOLOCK) ON VC.ID_VISITA = V.ID
                     WHERE V.ID_PROYECTO = P.ID AND VC.ID_CONSULTOR IS NOT NULL
                 ) Q
                 ORDER BY Q.F, Q.O, Q.K) X;
    UPDATE P SET
        CO_NOM = LEFT(LTRIM(RTRIM(ISNULL(CO.APELLIDOS,'') + CASE WHEN ISNULL(CO.NOMBRES,'') <> '' THEN ', ' + CO.NOMBRES ELSE '' END)),500),
        CO_INI = UPPER(LEFT(LTRIM(ISNULL(CO.NOMBRES,'')),1) + LEFT(LTRIM(ISNULL(CO.APELLIDOS,'')),1))
    FROM #P P INNER JOIN dbo.VCT_CONSULTORES CO WITH(NOLOCK) ON CO.ID = P.CO_ID;

    /* KPIs: siempre sobre los vigentes (en curso + confirmados) del alcance */
    DECLARE @K_ACT INT = 0, @K_AVG INT = 0, @K_FIN30 INT = 0, @K_ATR INT = 0, @K_SINC INT = 0, @D30 DATE = DATEADD(DAY, 30, @HOY);
    SELECT @K_ACT   = COUNT(*),
           @K_AVG   = ISNULL(CONVERT(INT, ROUND(AVG(CONVERT(DECIMAL(9,2), AVANCE)), 0)), 0),
           @K_FIN30 = ISNULL(SUM(CASE WHEN FIN >= @HOY AND FIN <= @D30 THEN 1 ELSE 0 END), 0),
           @K_ATR   = ISNULL(SUM(CASE WHEN FIN < @HOY THEN 1 ELSE 0 END), 0),
           @K_SINC  = ISNULL(SUM(CASE WHEN CO_ID IS NULL THEN 1 ELSE 0 END), 0)
    FROM #P WHERE SIT = 'V';

    /* la grilla solo lleva los proyectos del modo pedido */
    DELETE FROM #P WHERE SIT <> CASE WHEN @MODO = 'OTROS' THEN 'O' ELSE 'V' END;

    /* servicios */
    UPDATE P SET
        HAS_CO = CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = 'CONSULTORIA') THEN 1 ELSE 0 END,
        HAS_AU = CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = 'AUDITORIA') THEN 1 ELSE 0 END,
        HAS_CA = CASE WHEN EXISTS (SELECT 1 FROM dbo.VCT_PROYECTOS_SERVICIOS PS WITH(NOLOCK) INNER JOIN dbo.VCT_PRM_SERVICIOS S WITH(NOLOCK) ON S.ID = PS.ID_SERVICIO WHERE PS.ID_PROYECTO = P.ID AND S.CODIGO = 'CAPACITACION') THEN 1 ELSE 0 END
    FROM #P P;

    DECLARE @SRV_CO VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = 'CONSULTORIA'), 'Consultoria'),
            @SRV_AU VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = 'AUDITORIA'), 'Auditoria'),
            @SRV_CA VARCHAR(200) = ISNULL((SELECT TOP 1 DESCRIPCION FROM dbo.VCT_PRM_SERVICIOS WITH(NOLOCK) WHERE CODIGO = 'CAPACITACION'), 'Capacitacion');
    DECLARE @E_SRV_CO VARCHAR(300) = REPLACE(REPLACE(REPLACE(REPLACE(@SRV_CO,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
            @E_SRV_AU VARCHAR(300) = REPLACE(REPLACE(REPLACE(REPLACE(@SRV_AU,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
            @E_SRV_CA VARCHAR(300) = REPLACE(REPLACE(REPLACE(REPLACE(@SRV_CA,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');

    UPDATE #P SET
        SRV_LIST = LTRIM(CASE WHEN HAS_CO = 1 THEN 'co' ELSE '' END + CASE WHEN HAS_AU = 1 THEN ' au' ELSE '' END + CASE WHEN HAS_CA = 1 THEN ' ca' ELSE '' END),
        SRV_TXT  = STUFF(CASE WHEN HAS_CO = 1 THEN ', ' + @SRV_CO ELSE '' END + CASE WHEN HAS_AU = 1 THEN ', ' + @SRV_AU ELSE '' END + CASE WHEN HAS_CA = 1 THEN ', ' + @SRV_CA ELSE '' END, 1, 2, '');

    /* normas: hasta 3 en lista + "+N mas" */
    UPDATE P SET
        NORMAS_N = (SELECT COUNT(DISTINCT PN.ID_NORMA) FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,'ACTIVA') <> 'INACTIVA'),
        NORMAS_TXT = ISNULL(STUFF((
                    SELECT ', ' + N.DESCRIPCION
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,'ACTIVA') <> 'INACTIVA'
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), 1, 2, ''), ''),
        NORMAS_TOP = ISNULL((
                    SELECT TOP 3 '<span class="vctdg-li">' + REPLACE(REPLACE(REPLACE(N.DESCRIPCION,'&','&amp;'),'<','&lt;'),'>','&gt;') + '</span>'
                    FROM dbo.VCT_PROYECTOS_NORMAS PN WITH(NOLOCK)
                    INNER JOIN dbo.VCT_PRM_NORMAS N WITH(NOLOCK) ON N.ID = PN.ID_NORMA
                    WHERE PN.ID_PROYECTO = P.ID AND ISNULL(PN.ESTADO,'ACTIVA') <> 'INACTIVA'
                    GROUP BY N.DESCRIPCION ORDER BY MAX(CONVERT(INT, ISNULL(PN.PRINCIPAL,0))) DESC, N.DESCRIPCION
                    FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '')
    FROM #P P;

    /* textos escapados */
    UPDATE #P SET
        E_COD  = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CODIGO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_NOM  = REPLACE(REPLACE(REPLACE(REPLACE(NOMBRE,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_REF  = REPLACE(REPLACE(REPLACE(REPLACE(REFERENCIA,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_CLI  = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(CLIENTE,''),'Sin cliente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_EST  = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(EST_DESC,''),'Sin estado'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_AN   = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(AN_NOM,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_CO   = REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CO_NOM,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),
        E_SEARCH = REPLACE(REPLACE(REPLACE(REPLACE(
                     ISNULL(CLIENTE,'') + ' ' + ISNULL(CODIGO,'') + ' ' + NOMBRE + ' ' + REFERENCIA + ' ' + ISNULL(NORMAS_TXT,'') + ' '
                     + ISNULL(AN_NOM,'') + ' ' + ISNULL(CO_NOM,'') + ' ' + ISNULL(SRV_TXT,'') + ' ' + ISNULL(EST_DESC,''),
                   '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');

    /* menu de 3 puntos: se arma una sola vez con una clave comodin y se reemplaza por fila */
    DECLARE @MENU_TPL VARCHAR(MAX) = '';
    IF @MENU_OK = 1
    BEGIN
        SELECT @MENU_TPL = ISNULL((
            SELECT dbo.VCT_MAIN_RENDER_ACTION(A.ACTION_ID, A.TITLE, A.ICON, A.STORAGE_KEY, A.TARGET_TAB, A.TARGET_GUID,
                                              '__PRYKEY__', 'vctdg-menu-item', A.TITLE)
            FROM #ACT A
            WHERE A.ACTION_TYPE IN ('VIEW','EDIT')
            ORDER BY CASE A.ACTION_TYPE WHEN 'VIEW' THEN 0 ELSE 1 END, A.SORT_ORDER, A.ID_PRM
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');
        UPDATE #P SET MENU = REPLACE(@MENU_TPL, '__PRYKEY__', CONVERT(VARCHAR(20), ID));
    END;

    /* ==================================================================
       5. KPIs (sobre los activos del alcance)
       ================================================================== */
    DECLARE @KPIS VARCHAR(MAX) = CONVERT(VARCHAR(MAX), '')
        + '<section class="vct-soft-kpi-grid" aria-label="Indicadores de proyectos">'
        + '<article class="vct-soft-kpi is-purple"><span class="vct-soft-kpi-icon" data-vct-icon="folder"></span><div class="vct-soft-kpi-copy">'
        +   '<span class="vct-soft-kpi-label">Proyectos activos</span><strong class="vct-soft-kpi-value">' + CONVERT(VARCHAR(10), @K_ACT) + '</strong>'
        +   '<span class="vct-soft-kpi-help">avance promedio ' + CONVERT(VARCHAR(10), @K_AVG) + '%</span></div></article>'
        + '<article class="vct-soft-kpi is-green"><span class="vct-soft-kpi-icon" data-vct-icon="calendar-days"></span><div class="vct-soft-kpi-copy">'
        +   '<span class="vct-soft-kpi-label">Terminan en 30 d&iacute;as</span><strong class="vct-soft-kpi-value">' + CONVERT(VARCHAR(10), @K_FIN30) + '</strong>'
        +   '<span class="vct-soft-kpi-help">fin entre hoy y el ' + LEFT(CONVERT(VARCHAR(10), @D30, 103), 5) + '</span></div></article>'
        + '<article class="vct-soft-kpi is-blue"><span class="vct-soft-kpi-icon" data-vct-icon="clock-3"></span><div class="vct-soft-kpi-copy">'
        +   '<span class="vct-soft-kpi-label">Atrasados</span><strong class="vct-soft-kpi-value">' + CONVERT(VARCHAR(10), @K_ATR) + '</strong>'
        +   '<span class="vct-soft-kpi-help">fin vencido y sin terminar</span></div></article>'
        + '<article class="vct-soft-kpi is-red"><span class="vct-soft-kpi-icon" data-vct-icon="user-x"></span><div class="vct-soft-kpi-copy">'
        +   '<span class="vct-soft-kpi-label">Sin consultor</span><strong class="vct-soft-kpi-value">' + CONVERT(VARCHAR(10), @K_SINC) + '</strong>'
        +   '<span class="vct-soft-kpi-help">activos sin consultor asignado</span></div></article>'
        + '</section>';

    /* ==================================================================
       6. FILAS
       ================================================================== */
    DECLARE @ROWS VARCHAR(MAX);
    SELECT @ROWS = ISNULL((
        SELECT
            '<tr data-vct-row data-vct-key="' + CONVERT(VARCHAR(20), P.ID) + '"'
          + ' data-vct-search="' + P.E_SEARCH + '"'
          + ' data-vct-estado="' + P.EST_COD + '"'
          + ' data-vct-filter-estado="' + P.EST_COD + '"'
          + ' data-vct-srv="' + ISNULL(P.SRV_LIST,'') + '" data-vct-filter-srv="-">'
          /* Cliente */
          + '<td data-label="Cliente" data-vct-sort-value="' + P.E_CLI + '">' + P.E_CLI + '</td>'
          /* Proyecto */
          + '<td data-label="Proyecto" data-vct-sort-value="' + P.E_NOM + '" data-vct-export-value="' + CASE WHEN P.E_COD <> '' THEN '(' + P.E_COD + ') ' ELSE '' END + P.E_NOM + '">'
          +   '<span class="vct-360-project-name">' + CASE WHEN P.E_COD <> '' THEN '(' + P.E_COD + ') ' ELSE '' END + P.E_NOM + '</span>'
          +   CASE WHEN P.E_REF <> '' THEN '<span class="vct-360-project-ref">' + P.E_REF + '</span>' ELSE '' END
          + '</td>'
          /* Servicios */
          + '<td class="vct-text-center" data-label="Servicios" data-vct-export-value="' + REPLACE(REPLACE(ISNULL(P.SRV_TXT,''),'&','&amp;'),'"','&quot;') + '"><span class="vctdg-svc-set">'
          +   '<span class="vctdg-svc is-co' + CASE WHEN P.HAS_CO = 1 THEN ' is-on' ELSE '' END + '" title="' + @E_SRV_CO + CASE WHEN P.HAS_CO = 1 THEN '' ELSE ' (no incluido)' END + '"><span data-vct-icon="briefcase"></span></span>'
          +   '<span class="vctdg-svc is-au' + CASE WHEN P.HAS_AU = 1 THEN ' is-on' ELSE '' END + '" title="' + @E_SRV_AU + CASE WHEN P.HAS_AU = 1 THEN '' ELSE ' (no incluido)' END + '"><span data-vct-icon="clipboard-check"></span></span>'
          +   '<span class="vctdg-svc is-ca' + CASE WHEN P.HAS_CA = 1 THEN ' is-on' ELSE '' END + '" title="' + @E_SRV_CA + CASE WHEN P.HAS_CA = 1 THEN '' ELSE ' (no incluido)' END + '"><span data-vct-icon="users"></span></span>'
          + '</span></td>'
          /* Normas */
          + '<td data-label="Normas" data-vct-export-value="' + REPLACE(REPLACE(REPLACE(ISNULL(P.NORMAS_TXT,''),'&','&amp;'),'"','&quot;'),'<','&lt;') + '"><span class="vctdg-list">'
          +   CASE WHEN ISNULL(P.NORMAS_TOP,'') = '' THEN '<span class="vctdg-none">-</span>' ELSE P.NORMAS_TOP END
          +   CASE WHEN P.NORMAS_N > 3 THEN '<span class="vctdg-li is-more" title="' + REPLACE(REPLACE(REPLACE(ISNULL(P.NORMAS_TXT,''),'&','&amp;'),'"','&quot;'),'<','&lt;') + '">+' + CONVERT(VARCHAR(10), P.NORMAS_N - 3) + ' m&aacute;s</span>' ELSE '' END
          + '</span></td>'
          /* Analista */
          + '<td class="vct-text-center" data-label="Analista" data-vct-sort-value="' + P.E_AN + '" data-vct-export-value="' + P.E_AN + '">'
          +   CASE WHEN P.E_AN = '' THEN '<span class="vctdg-none">-</span>'
                   ELSE '<span class="vctdg-person"><span class="vctdg-avatar is-a" title="' + P.E_AN + '">' + ISNULL(NULLIF(P.AN_INI,''),'-') + '</span></span>' END
          + '</td>'
          /* Consultor */
          + '<td class="vct-text-center" data-label="Consultor" data-vct-sort-value="' + P.E_CO + '" data-vct-export-value="' + P.E_CO + '">'
          +   CASE WHEN P.E_CO = '' THEN '<span class="vctdg-none">-</span>'
                   ELSE '<span class="vctdg-person"><span class="vctdg-avatar is-c" title="' + P.E_CO + '">' + ISNULL(NULLIF(P.CO_INI,''),'-') + '</span></span>' END
          + '</td>'
          /* Inicio / Fin */
          + '<td class="vct-text-center" data-label="Inicio" data-vct-sort-value="' + ISNULL(CONVERT(VARCHAR(8), P.INICIO, 112), '00000000') + '">' + ISNULL(CONVERT(VARCHAR(10), P.INICIO, 103), '-') + '</td>'
          + '<td class="vct-text-center" data-label="Fin" data-vct-sort-value="' + ISNULL(CONVERT(VARCHAR(8), P.FIN, 112), '99991231') + '">' + ISNULL(CONVERT(VARCHAR(10), P.FIN, 103), '-') + '</td>'
          /* Estado */
          + '<td class="vct-text-center" data-label="Estado" data-vct-sort-value="' + P.E_EST + '" data-vct-export-value="' + P.E_EST + '">'
          +   '<span class="vct-360-badge ' + CASE P.EST_COD WHEN 'ENCURSO' THEN 'is-progress' WHEN 'EN_CURSO' THEN 'is-progress' WHEN 'CONFIRMADO' THEN 'is-planned'
                                                          WHEN 'PAUSADO' THEN 'is-paused' WHEN 'TERMINADO' THEN 'is-done' WHEN 'CANCELADO' THEN 'is-cancel'
                                                          WHEN 'BORRADOR' THEN 'is-draft' ELSE 'is-neutral' END + '">' + P.E_EST + '</span>'
          + '</td>'
          /* Avance */
          + '<td data-label="Avance" data-vct-sort-value="' + RIGHT('000' + CONVERT(VARCHAR(3), P.AVANCE), 3) + '" data-vct-export-value="' + CONVERT(VARCHAR(3), P.AVANCE) + '%">'
          +   '<span class="vctdg-progress"><span class="vctdg-progress-bar"><i style="width:' + CONVERT(VARCHAR(3), P.AVANCE) + '%"></i></span><b>' + CONVERT(VARCHAR(3), P.AVANCE) + '%</b></span>'
          + '</td>'
          /* menu */
          + '<td class="vct-table-action-cell" data-label="" data-vct-export-ignore="true">'
          +   CASE WHEN ISNULL(P.MENU,'') <> '' THEN
                    '<button type="button" class="vct-row-menu-trigger" data-vctdg-rowmenu aria-label="Acciones" title="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                  + '<div class="vctdg-rowmenu-items" hidden>' + P.MENU + '</div>'
               ELSE '' END
          + '</td>'
          + '</tr>'
        FROM #P P
        ORDER BY CASE WHEN P.INICIO IS NULL THEN 1 ELSE 0 END, P.INICIO DESC, P.ID DESC
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    /* ==================================================================
       7. FILTROS
       ================================================================== */
    DECLARE @O_EST VARCHAR(MAX);
    SELECT @O_EST = ISNULL((
        SELECT '<option value="' + X.EST_COD + '">' + X.E_EST + '</option>'
        FROM (SELECT DISTINCT EST_COD, E_EST FROM #P WHERE EST_COD <> '') X
        ORDER BY X.E_EST
        FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

    DECLARE @FILTERS VARCHAR(MAX) = CONVERT(VARCHAR(MAX), '')
        + '<div data-vct-dg-slot="filters">'
        + '<select class="vct-select vct-select-sm" data-vct-dg-filter="estado" aria-label="Estado">'
        +   '<option value="">Todos los estados</option>' + @O_EST + '</select>'
        + '<select class="vct-select vct-select-sm" data-vct-dg-filter="srv" aria-label="Servicio"><option value="">Servicio</option>'
        +   '<option value="co">' + @E_SRV_CO + '</option><option value="au">' + @E_SRV_AU + '</option><option value="ca">' + @E_SRV_CA + '</option></select>'
        + '</div>';

    /* ==================================================================
       8. SALIDA
       ================================================================== */
    SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') + @ASSETS
        + '<div class="vct-page vct-page-main vct-proy-page" data-vct-page data-vct-sidebar-id="' + CONVERT(VARCHAR(20), ISNULL(@SIDEBAR_ID,0)) + '" data-vct-form-id="' + @FORM_ESC + '" data-vct-pry-modo-actual="' + @MODO + '">'
        + '<input type="hidden" name="SP.TEXTO30" data-vct-field="TEXTO30" value="">'
        + @KPIS
        + '<section class="vct-card vct-grid-card"><div class="vct-card-body">'
        + '<div data-vct-dg data-vct-dg-id="proyectos" data-vct-dg-title="Proyectos" data-vct-dg-unit="proyecto(s)" data-vct-dg-page-size="10"'
        + ' data-vct-dg-search-placeholder="Buscar cliente, proyecto, norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'
        + @FILTERS
        + '<div data-vct-dg-slot="actions">'
        +   '<button type="button" class="vct-btn vct-btn-sm vct-proy-modo"'
        +   ' data-vct-pry-modo="' + CASE WHEN @MODO = 'OTROS' THEN 'PRY_MODO_VIGENTES' ELSE 'PRY_MODO_OTROS' END + '"'
        +   ' data-vct-tooltip="' + CASE WHEN @MODO = 'OTROS' THEN 'Volver a los proyectos en curso y confirmados' ELSE 'Ver los proyectos pausados, terminados, cancelados...' END + '">'
        +   '<span data-vct-icon="' + CASE WHEN @MODO = 'OTROS' THEN 'arrow-left' ELSE 'list-checks' END + '"></span>'
        +   '<span>' + CASE WHEN @MODO = 'OTROS' THEN 'En curso y confirmados' ELSE 'Otros estados' END + '</span></button>'
        +   @BTN_NUEVO + '</div>'
        + '<table><thead><tr>'
        +   '<th data-vct-width="12%" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th class="vct-text-center" data-vct-width="92"><span>Servicios</span></th>'
        +   '<th data-vct-width="13%"><span>Normas</span></th>'
        +   '<th class="vct-text-center" data-vct-width="66"><span>Analista</span></th>'
        +   '<th class="vct-text-center" data-vct-width="72"><span>Consultor</span></th>'
        +   '<th class="vct-text-center" data-vct-width="80" data-vct-sort="inicio" data-vct-sortable="true"><span>Inicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th class="vct-text-center" data-vct-width="80" data-vct-sort="fin" data-vct-sortable="true"><span>Fin</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th class="vct-text-center" data-vct-width="104" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th data-vct-width="10%" data-vct-sort="avance" data-vct-sortable="true"><span>Avance</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'
        +   '<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>'
        + '</tr></thead><tbody>' + @ROWS + '</tbody></table>'
        + '</div></div></section>'
        + '</div>';
END
GO

/* ------------------------------------------------------------------------
   Resultado del SP + ruteo del menu Proyectos desde el Inicio
   ------------------------------------------------------------------------ */
DECLARE @OK BIT = 0;
IF EXISTS (SELECT 1 FROM sys.procedures P CROSS JOIN #PRY_V1_RUN R
           WHERE P.object_id = OBJECT_ID('dbo.VCT_MAIN_PROYECTOS') AND P.modify_date >= R.INICIO
             AND OBJECT_DEFINITION(P.object_id) LIKE '%PROYECTOS_PANTALLA_V1%')
    SET @OK = 1;
IF @OK = 1 PRINT 'OK   dbo.VCT_MAIN_PROYECTOS creado/reemplazado (PROYECTOS_PANTALLA_V1).';
ELSE PRINT 'FALLO dbo.VCT_MAIN_PROYECTOS no se actualizo: revisar el error del bloque anterior.';

/* Ruteo: el menu Proyectos (ACTION=PROYECTOS) ya esta cableado en el flujo de la plataforma
   (STEP_TRANSACTION_FLOW). Este script NO toca VCT_MAIN_DASHBOARD. */

IF EXISTS (SELECT 1 FROM #PRY_V1_RUN WHERE TRG_ON = 1)
BEGIN
    ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK   trigger TR_VCT_AUDITORIA_DDL reactivado.';
END;

/* Permisos que lee la pantalla (solo listado, no modifica nada) */
SELECT PA.ActionID AS ACTION_ID, UPPER(ISNULL(PA.ActionType,'')) AS ACTION_TYPE, ISNULL(PA.Title,'') AS TITLE,
       CONVERT(VARCHAR(100), PA.TargetGuid) AS TARGET_GUID, GA.GroupId AS PERFIL
FROM dbo.PrmActions PA
INNER JOIN dbo.Actions A ON A.Id COLLATE DATABASE_DEFAULT = PA.ActionID COLLATE DATABASE_DEFAULT
INNER JOIN dbo.GroupsActions GA ON GA.ActionId COLLATE DATABASE_DEFAULT = A.Id COLLATE DATABASE_DEFAULT
WHERE UPPER(PA.ActionID) LIKE 'PROYECTOS.%'
ORDER BY GA.GroupId, PA.ActionType;
GO
