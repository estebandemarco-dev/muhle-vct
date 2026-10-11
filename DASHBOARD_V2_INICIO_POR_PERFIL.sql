/* ========================================================================
   DASHBOARD_V2_INICIO_POR_PERFIL  (boceto con los datos actuales)
   ------------------------------------------------------------------------
   Reescribe dbo.VCT_MAIN_DASHBOARD (Inicio) desde cero, por perfil:
     GERENCIA (y SQUAD) : Comercial (ventas, presupuestado, viaticos,
                          honorarios, top clientes) + Operacion (proyectos,
                          visitas, horas, acciones).
     ADMINISTRACION     : Administracion (altas, en curso, sin monto,
                          viaticos) + Comercial.
     PROYECTOS          : analista -> sus proyectos (equipo EMPLEADO); si el
                          usuario es consultor -> vista consultor.
     CONSULTORES        : sus proyectos, visitas, horas.
     CLIENTES           : aviso (falta vincular el usuario con un cliente).
   - Todo el calculo dentro del SP: sin vistas ni funciones nuevas.
     Usa solo VCT_MAIN_GET_ACTIONS (permisos) y el shell/sidebar existentes.
   - Montos solo si el perfil tiene RENTABILIDAD.VIEW segun
     VCT_MAIN_GET_ACTIONS (requiere fila en PrmActions: ver paso 1).
   - Solo KPIs y graficos (sin grillas de proyectos ni visitas).
   - Graficos en HTML/CSS (barras y anillos), estilo de la 360, con la
     paleta estandar (tonos del bordo y gris del Manual de Identidad):
     4 colores base y 10 para anillos de mas de 4 partes.
   - Se mantiene el ruteo del menu Acciones (ACTION=PLANIFICACION).
   Paso 1 (opcional): agrega RENTABILIDAD.VIEW a PrmActions si no esta.
   Paso 2: ALTER del SP. Re-ejecutable. Compat 100 y 140 (sin FORMAT,
           STRING_AGG, IIF ni funciones de ventana con ORDER BY).
   ======================================================================== */
USE [MuhlePROD];
GO
SET NOCOUNT ON;

/* ---------------- Paso 1: RENTABILIDAD.VIEW en PrmActions ---------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.PrmActions WHERE UPPER(ActionID) = 'RENTABILIDAD.VIEW')
BEGIN
    BEGIN TRY
        INSERT INTO dbo.PrmActions (ActionID, ActionType, Title, SortOrder)
        VALUES ('RENTABILIDAD.VIEW', 'VIEW', 'Ver rentabilidad', 999);
        PRINT 'OK: RENTABILIDAD.VIEW agregado a PrmActions.';
    END TRY
    BEGIN CATCH
        PRINT 'AVISO: no se pudo agregar RENTABILIDAD.VIEW a PrmActions (' + ERROR_MESSAGE() + '). Cargarlo a mano: sin esa fila el Inicio no muestra montos.';
    END CATCH;
END
ELSE
    PRINT 'RENTABILIDAD.VIEW ya estaba en PrmActions.';
GO

IF OBJECT_ID('dbo.VCT_MAIN_DASHBOARD','P') IS NULL
    EXEC ('CREATE PROCEDURE dbo.VCT_MAIN_DASHBOARD AS RETURN;');
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[VCT_MAIN_DASHBOARD]
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
    /* DASHBOARD_V2 */
    /* ACCIONES_RUTEO_V1: el menu Acciones (ACTION=PLANIFICACION) no tiene paso propio en la plataforma */
    IF OBJECT_ID('dbo.VCT_MAIN_ACCIONES') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.VCT_BUFFER WITH(NOLOCK) WHERE PAR_KEY = @IPKEYJOB AND UPPER(LTRIM(RTRIM(ISNULL(ACTION,'')))) = 'PLANIFICACION')
    BEGIN
        EXEC dbo.VCT_MAIN_ACCIONES @IPKEYJOB = @IPKEYJOB, @FORM_ID = @FORM_ID, @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE,
             @OUTPARAM1 = @OUTPARAM1 OUTPUT, @OUTPARAM2 = @OUTPARAM2 OUTPUT, @OUTPARAM3 = @OUTPARAM3 OUTPUT;
        RETURN;
    END;

    SET NOCOUNT ON;
    SET @OUTPARAM1 = '';
    SET @OUTPARAM2 = NULL;
    SET @OUTPARAM3 = NULL;

    DECLARE @HTML_SHELL VARCHAR(MAX) = '', @RESULTADO_SHELL VARCHAR(20) = '', @SIDEBAR_ID INT = 0,
            @HOY DATE = CONVERT(DATE, GETDATE()),
            @PERFIL VARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@IUNIDAD,'')))),
            @CONS_ID INT = NULL, @EMP_ID INT = NULL, @NOMBRE VARCHAR(300) = '',
            @LINK BIT = 0, @VER_DINERO BIT = 0, @VISTA VARCHAR(20) = '',
            @GUID_P VARCHAR(50) = '330B876D-4E57-4E2E-BFC3-D7B998D09725',
            @TABS VARCHAR(MAX) = '', @PANELS VARCHAR(MAX) = '', @NTABS INT = 0,
            @AVISO VARCHAR(1000) = '', @BELL VARCHAR(MAX) = '';

    DECLARE @MES_INI DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, @HOY), 0);
    DECLARE @MES_ANT DATE = DATEADD(MONTH, -1, @MES_INI);
    DECLARE @ANIO_INI DATE = DATEADD(YEAR, DATEDIFF(YEAR, 0, @HOY), 0);
    DECLARE @DESDE12 DATE = DATEADD(MONTH, -11, @MES_INI);
    DECLARE @DESDE6 DATE = DATEADD(MONTH, -5, @MES_INI);
    DECLARE @PER_ACT CHAR(7) = CONVERT(CHAR(7), @MES_INI, 126);
    DECLARE @PER_ANT CHAR(7) = CONVERT(CHAR(7), @MES_ANT, 126);
    DECLARE @PER_ANIO CHAR(7) = CONVERT(CHAR(4), YEAR(@HOY)) + '-01';
    DECLARE @PER_12 CHAR(7) = CONVERT(CHAR(7), @DESDE12, 126);

    /* ---------- shell y sidebar ---------- */
    BEGIN TRY
        EXEC dbo.VCT_GET_SHELL @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE, @FORM_ID = @FORM_ID,
             @TITLE = 'Inicio', @SUBTITLE = 'Indicadores seg&uacute;n tu perfil.',
             @SEARCH_PLACEHOLDER = '', @SHOW_SEARCH = 0,
             @OSHELL = @HTML_SHELL OUTPUT, @ORESULTADO = @RESULTADO_SHELL OUTPUT;
    END TRY
    BEGIN CATCH
        SET @HTML_SHELL = '';
    END CATCH;

    BEGIN TRY
        SELECT TOP 1 @SIDEBAR_ID = CONVERT(INT, SB.Id)
        FROM dbo.SideBar SB WITH(NOLOCK)
        INNER JOIN dbo.SideBarGroups SBG WITH(NOLOCK) ON CONVERT(VARCHAR(50), SBG.SideBarId) = CONVERT(VARCHAR(50), SB.Id)
        WHERE UPPER(LTRIM(RTRIM(SBG.GroupId))) = @PERFIL AND UPPER(LTRIM(RTRIM(ISNULL(SB.Code,'')))) = 'INICIO'
        ORDER BY CONVERT(INT, SB.Id);
    END TRY
    BEGIN CATCH
        SET @SIDEBAR_ID = 0;
    END CATCH;

    /* ---------- permisos (unica fuente: VCT_MAIN_GET_ACTIONS) ---------- */
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, 'CLIENTES') A WHERE A.ACTION_TYPE = 'VIEW') SET @LINK = 1;
        IF EXISTS (SELECT 1 FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, 'RENTABILIDAD') A WHERE A.ACTION_ID = 'RENTABILIDAD.VIEW') SET @VER_DINERO = 1;
    END TRY
    BEGIN CATCH
        SET @LINK = 0;
        SET @VER_DINERO = 0;
    END CATCH;

    /* ---------- campanita (si sus SP fallan, el Inicio sigue) ---------- */
    BEGIN TRY
        IF OBJECT_ID('dbo.VCT_NOTIF_RENDER') IS NOT NULL
        BEGIN
            IF OBJECT_ID('dbo.VCT_NOTIF_ACCION') IS NOT NULL EXEC dbo.VCT_NOTIF_ACCION @IPKEYJOB = @IPKEYJOB, @IAGENTE = @IAGENTE;
            IF OBJECT_ID('dbo.VCT_NOTIF_GENERAR') IS NOT NULL EXEC dbo.VCT_NOTIF_GENERAR @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE;
            EXEC dbo.VCT_NOTIF_RENDER @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE, @LINK = @LINK, @HTML = @BELL OUTPUT;
        END;
    END TRY
    BEGIN CATCH
        SET @BELL = '';
    END CATCH;

    /* ---------- quien es ---------- */
    SELECT TOP 1 @CONS_ID = C.ID, @NOMBRE = LTRIM(RTRIM(ISNULL(C.NOMBRES,'')))
    FROM dbo.VCT_CONSULTORES C
    WHERE LTRIM(RTRIM(ISNULL(C.ID_USUARIO_SEGURIDAD,''))) = LTRIM(RTRIM(@IAGENTE)) AND UPPER(ISNULL(C.ESTADO,'')) = 'ACTIVO'
    ORDER BY C.ID DESC;

    SELECT TOP 1 @EMP_ID = E.ID, @NOMBRE = CASE WHEN @NOMBRE = '' THEN LTRIM(RTRIM(ISNULL(E.NOMBRES,''))) ELSE @NOMBRE END
    FROM dbo.VCT_EMPLEADOS E
    WHERE LTRIM(RTRIM(ISNULL(E.ID_USUARIO_SEGURIDAD,''))) = LTRIM(RTRIM(@IAGENTE)) AND UPPER(ISNULL(E.ESTADO,'')) = 'ACTIVO'
    ORDER BY E.ID DESC;

    IF @NOMBRE = ''
        SELECT TOP 1 @NOMBRE = LTRIM(RTRIM(ISNULL(U.Name,''))) FROM dbo.Users U WITH(NOLOCK) WHERE U.Id = @IAGENTE;

    SET @VISTA = CASE
        WHEN @PERFIL IN ('GERENCIA','SQUAD') THEN 'GERENCIA'
        WHEN @PERFIL = 'ADMINISTRACION' THEN 'ADMIN'
        WHEN @PERFIL = 'CLIENTES' THEN 'CLIENTE'
        WHEN @PERFIL = 'CONSULTORES' OR (@CONS_ID IS NOT NULL AND @EMP_ID IS NULL) THEN 'CONSULTOR'
        ELSE 'ANALISTA' END;

    /* ---------- meses (12) ---------- */
    CREATE TABLE #DM (ORD INT PRIMARY KEY, MES DATE, PER CHAR(7), LBL VARCHAR(10));
    INSERT INTO #DM (ORD, MES)
    SELECT N, DATEADD(MONTH, N - 1, @DESDE12)
    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) X(N);
    UPDATE #DM SET PER = CONVERT(CHAR(7), MES, 126),
                   LBL = CASE MONTH(MES) WHEN 1 THEN 'ene' WHEN 2 THEN 'feb' WHEN 3 THEN 'mar' WHEN 4 THEN 'abr' WHEN 5 THEN 'may' WHEN 6 THEN 'jun'
                                         WHEN 7 THEN 'jul' WHEN 8 THEN 'ago' WHEN 9 THEN 'sep' WHEN 10 THEN 'oct' WHEN 11 THEN 'nov' ELSE 'dic' END
                         + ' ' + RIGHT(CONVERT(CHAR(4), YEAR(MES)), 2);

    /* ---------- alcance de proyectos segun vista ---------- */
    CREATE TABLE #SC (ID INT PRIMARY KEY);
    IF @VISTA = 'ANALISTA' AND @EMP_ID IS NOT NULL
        INSERT INTO #SC (ID)
        SELECT DISTINCT EQ.ID_PROYECTO FROM dbo.VCT_PROYECTOS_EQUIPO EQ
        WHERE EQ.TIPO_MIEMBRO = 'EMPLEADO' AND EQ.ID_EMPLEADO = @EMP_ID AND EQ.ESTADO = 'ACTIVO';
    ELSE IF @VISTA = 'CONSULTOR' AND @CONS_ID IS NOT NULL
        INSERT INTO #SC (ID)
        SELECT EQ.ID_PROYECTO FROM dbo.VCT_PROYECTOS_EQUIPO EQ
        WHERE EQ.TIPO_MIEMBRO = 'CONSULTOR' AND EQ.ID_CONSULTOR = @CONS_ID AND EQ.ESTADO = 'ACTIVO'
        UNION
        SELECT V.ID_PROYECTO FROM dbo.VCT_PROYECTOS_VISITAS V
        INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
        WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= @DESDE12;

    IF @VISTA IN ('GERENCIA','ADMIN') OR (@VISTA = 'ANALISTA' AND NOT EXISTS (SELECT 1 FROM #SC))
    BEGIN
        IF @VISTA = 'ANALISTA'
            SET @AVISO = CASE WHEN @EMP_ID IS NULL
                              THEN 'Tu usuario no est&aacute; vinculado a un empleado: se muestran todos los proyectos. Vincularlo en la ficha del empleado.'
                              ELSE 'No ten&eacute;s proyectos asignados como analista: se muestran todos los proyectos.' END;
        DELETE FROM #SC;
        INSERT INTO #SC (ID) SELECT ID FROM dbo.VCT_PROYECTOS;
    END;

    /* ---------- proyectos activos (en curso / confirmados) del alcance ---------- */
    CREATE TABLE #DP (ID INT PRIMARY KEY, IDCLIENTE INT, CODIGO VARCHAR(100), NOMBRE VARCHAR(300), CLIENTE VARCHAR(300),
                      EST VARCHAR(30), AVANCE INT, INICIO DATETIME, MONTO DECIMAL(18,2), HPROY DECIMAL(18,2), HEJEC DECIMAL(18,2));
    INSERT INTO #DP (ID, IDCLIENTE, CODIGO, NOMBRE, CLIENTE, EST, AVANCE, INICIO, MONTO, HPROY, HEJEC)
    SELECT P.ID, P.IDCLIENTE, P.CODIGO, P.NOMBRE, CL.RAZON_SOCIAL, E.CODIGO, ISNULL(P.PORCENTAJE_AVANCE, 0),
           ISNULL(P.FECHA_INICIO_REAL, P.FECHA_INICIO), P.MONTO_TOTAL,
           NULLIF(CONVERT(DECIMAL(18,2), P.TOTAL_HORAS_PROYECTADAS), 0),
           ISNULL((SELECT SUM(V.TOTAL_HORAS_EJECUTADAS) FROM dbo.VCT_PROYECTOS_VISITAS V WHERE V.ID_PROYECTO = P.ID AND V.FECHA_DESDE <= GETDATE()), 0)
    FROM dbo.VCT_PROYECTOS P
    INNER JOIN #SC S ON S.ID = P.ID
    INNER JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS E ON E.ID = P.ID_ESTADO
    LEFT JOIN dbo.VCT_CLIENTES CL ON CL.ID = P.IDCLIENTE
    WHERE E.CODIGO IN ('ENCURSO','CONFIRMADO');

    /* ---------- tablas de trabajo: tarjetas (#K), graficos (#C/#S) ---------- */
    CREATE TABLE #K (PANEL VARCHAR(20), ORD INT, LBL VARCHAR(100), VAL DECIMAL(18,2), FMT CHAR(1), TXT VARCHAR(100), SUB VARCHAR(200), TONE VARCHAR(10), ICON VARCHAR(40));
    CREATE TABLE #C (CH INT PRIMARY KEY, PANEL VARCHAR(20), ORD INT, TIPO CHAR(1), TITULO VARCHAR(150), SUB VARCHAR(200), ICON VARCHAR(40), FMT CHAR(1), ANCHO CHAR(1), COFF INT DEFAULT 0, HTML VARCHAR(MAX));
    CREATE TABLE #S (CH INT, ORD INT, LBL VARCHAR(300), VAL DECIMAL(18,2), TXT VARCHAR(60));
    /* FMT: M = dinero, N = numero, H = horas, P = porcentaje, T = texto (usa TXT) | TIPO: V barras verticales, H horizontales, D anillo | ANCHO: W ancho completo */

    DECLARE @NOTA_DINERO VARCHAR(500) =
            '<div class="vct-dash-note">Los montos se muestran con el permiso <b>RENTABILIDAD.VIEW</b> (perfil + fila en PrmActions). Hoy este perfil no lo tiene.</div>';

    /* ===================================================================
       COMERCIAL (GERENCIA y ADMINISTRACION)
       =================================================================== */
    IF @VISTA IN ('GERENCIA','ADMIN') AND @VER_DINERO = 1
    BEGIN
        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'comercial', 1, 'Ventas del mes',
               ISNULL((SELECT SUM(R.VENTAS) FROM dbo.VCT_PROYECTOS_RENTABILIDAD R WHERE R.PERIODO = @PER_ACT), 0), 'M',
               'mes anterior {ANT}', 'blue', 'circle-dollar-sign';
        UPDATE #K SET SUB = REPLACE(SUB, '{ANT}',
               '$ ' + REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(ISNULL((SELECT SUM(R.VENTAS) FROM dbo.VCT_PROYECTOS_RENTABILIDAD R WHERE R.PERIODO = @PER_ANT), 0), 0) AS MONEY), 1), '.00', ''), ',', '.'))
        WHERE PANEL = 'comercial' AND ORD = 1;

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'comercial', 2, 'Ventas del a&ntilde;o',
               ISNULL((SELECT SUM(R.VENTAS) FROM dbo.VCT_PROYECTOS_RENTABILIDAD R WHERE R.PERIODO >= @PER_ANIO AND R.PERIODO <= @PER_ACT), 0), 'M',
               'desde enero', 'violet', 'chart-bar';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'comercial', 3, 'Presupuestado',
               ISNULL((SELECT SUM(P.MONTO_TOTAL) FROM dbo.VCT_PROYECTOS P WHERE P.FECHA_PRESUPUESTO >= @ANIO_INI), 0), 'M',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS P WHERE P.FECHA_PRESUPUESTO >= @ANIO_INI)) + ' presupuestos en el a&ntilde;o', 'mint', 'file-text';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'comercial', 4, 'Vi&aacute;ticos del a&ntilde;o',
               ISNULL((SELECT SUM(V.PRECIO_FINAL) FROM dbo.VCT_PROYECTOS_VIATICOS V WHERE V.FECHA_FC >= @ANIO_INI), 0), 'M',
               'honorarios {HON}', 'amber', 'truck';
        UPDATE #K SET SUB = REPLACE(SUB, '{HON}',
               '$ ' + REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(ISNULL((SELECT SUM(H.IMPORTE_NUMERICO) FROM dbo.VCT_PROYECTOS_HONORARIOS H WHERE H.FECHA >= @ANIO_INI), 0), 0) AS MONEY), 1), '.00', ''), ',', '.'))
        WHERE PANEL = 'comercial' AND ORD = 4;

        /* ventas por mes (12) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (1, 'comercial', 1, 'V', 'Ventas por mes', '&uacute;ltimos 12 meses (rentabilidad)', 'chart-bar', 'M', 'W');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 1, M.ORD, M.LBL, ISNULL((SELECT SUM(R.VENTAS) FROM dbo.VCT_PROYECTOS_RENTABILIDAD R WHERE R.PERIODO = M.PER), 0) FROM #DM M;

        /* top 5 clientes por ventas (12 meses) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (2, 'comercial', 2, 'H', 'Top 5 clientes', 'ventas de los &uacute;ltimos 12 meses', 'users', 'M', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT TOP 5 2, 0, ISNULL(CL.RAZON_SOCIAL, 'Sin cliente'), SUM(R.VENTAS)
        FROM dbo.VCT_PROYECTOS_RENTABILIDAD R
        INNER JOIN dbo.VCT_PROYECTOS P ON P.ID = R.ID_PROYECTO
        LEFT JOIN dbo.VCT_CLIENTES CL ON CL.ID = P.IDCLIENTE
        WHERE R.PERIODO >= @PER_12 AND R.PERIODO <= @PER_ACT
        GROUP BY CL.RAZON_SOCIAL
        HAVING SUM(R.VENTAS) > 0
        ORDER BY SUM(R.VENTAS) DESC;

        /* viaticos por tipo (12 meses) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (3, 'comercial', 3, 'H', 'Vi&aacute;ticos por tipo', '&uacute;ltimos 12 meses', 'truck', 'M', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT TOP 6 3, 0, ISNULL(T.DESCRIPCION, 'Sin tipo'), SUM(V.PRECIO_FINAL)
        FROM dbo.VCT_PROYECTOS_VIATICOS V
        LEFT JOIN dbo.VCT_PRM_VIATICOS_TIPOS T ON T.ID = V.ID_TIPO_VIATICO
        WHERE V.FECHA_FC >= @DESDE12
        GROUP BY T.DESCRIPCION
        HAVING SUM(V.PRECIO_FINAL) > 0
        ORDER BY SUM(V.PRECIO_FINAL) DESC;

        /* honorarios por mes (12) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (4, 'comercial', 4, 'V', 'Honorarios por mes', '&uacute;ltimos 12 meses', 'circle-dollar-sign', 'M', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 4, M.ORD, M.LBL, ISNULL((SELECT SUM(H.IMPORTE_NUMERICO) FROM dbo.VCT_PROYECTOS_HONORARIOS H
                                        WHERE H.FECHA >= M.MES AND H.FECHA < DATEADD(MONTH, 1, M.MES)), 0) FROM #DM M;

        /* viaticos por mes (12) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (5, 'comercial', 5, 'V', 'Vi&aacute;ticos por mes', '&uacute;ltimos 12 meses', 'truck', 'M', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 5, M.ORD, M.LBL, ISNULL((SELECT SUM(V.PRECIO_FINAL) FROM dbo.VCT_PROYECTOS_VIATICOS V
                                        WHERE V.FECHA_FC >= M.MES AND V.FECHA_FC < DATEADD(MONTH, 1, M.MES)), 0) FROM #DM M;
    END;

    /* ===================================================================
       OPERACION (GERENCIA) / MIS PROYECTOS (ANALISTA)
       =================================================================== */
    IF @VISTA IN ('GERENCIA','ANALISTA')
    BEGIN
        DECLARE @PNL VARCHAR(20) = CASE WHEN @VISTA = 'GERENCIA' THEN 'operacion' ELSE 'proyectos' END;

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT @PNL, 1, 'En curso', (SELECT COUNT(*) FROM #DP WHERE EST = 'ENCURSO'), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM #DP WHERE EST = 'CONFIRMADO')) + ' por iniciar', 'blue', 'folder';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT @PNL, 2, 'Visitas del mes',
               (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN #SC S ON S.ID = V.ID_PROYECTO
                WHERE V.FECHA_DESDE >= @MES_INI AND V.FECHA_DESDE < DATEADD(MONTH, 1, @MES_INI)), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN #SC S ON S.ID = V.ID_PROYECTO
                                     WHERE V.FECHA_DESDE >= GETDATE() AND V.FECHA_DESDE < DATEADD(DAY, 14, @HOY))) + ' en 14 d&iacute;as', 'violet', 'calendar';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT @PNL, 3, 'Horas del mes',
               ISNULL((SELECT SUM(V.TOTAL_HORAS_EJECUTADAS) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN #SC S ON S.ID = V.ID_PROYECTO
                       WHERE V.FECHA_DESDE >= @MES_INI AND V.FECHA_DESDE < DATEADD(MONTH, 1, @MES_INI)), 0), 'H',
               'en visitas', 'mint', 'clock-3';

        /* acciones abiertas: todas (gerencia) o las mias (analista con empleado) */
        CREATE TABLE #AC (ID INT PRIMARY KEY, VENCIDA BIT);
        INSERT INTO #AC (ID, VENCIDA)
        SELECT A.ID, CASE WHEN A.FECHA_VENCIMIENTO < @HOY THEN 1 ELSE 0 END
        FROM dbo.VCT_ACCIONES A
        INNER JOIN dbo.VCT_PRM_ACCIONES_ESTADOS E ON E.ID = A.ID_ESTADO
        WHERE E.ES_FINAL = 0
          AND (@VISTA = 'GERENCIA' OR @EMP_ID IS NULL
               OR EXISTS (SELECT 1 FROM dbo.VCT_ACCIONES_PARTICIPANTES AP WHERE AP.ID_ACCION = A.ID AND AP.ESTADO = 'ACTIVO'
                          AND AP.TIPO_ENTIDAD = 'EMPLEADO' AND AP.ID_ENTIDAD = @EMP_ID));

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT @PNL, 4, CASE WHEN @VISTA = 'GERENCIA' OR @EMP_ID IS NULL THEN 'Acciones abiertas' ELSE 'Mis acciones' END,
               (SELECT COUNT(*) FROM #AC), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM #AC WHERE VENCIDA = 1)) + ' vencida(s)',
               'amber', 'list-checks';

        /* proyectos activos por servicio */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (11, @PNL, 1, 'D', 'Proyectos activos por servicio', 'en curso y confirmados', 'folder', 'N', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 11, MIN(S.ID), S.DESCRIPCION, COUNT(DISTINCT PS.ID_PROYECTO)
        FROM dbo.VCT_PROYECTOS_SERVICIOS PS
        INNER JOIN #DP D ON D.ID = PS.ID_PROYECTO
        INNER JOIN dbo.VCT_PRM_SERVICIOS S ON S.ID = PS.ID_SERVICIO
        GROUP BY S.DESCRIPCION;

        /* visitas por mes */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (12, @PNL, 2, 'V', 'Visitas por mes', '&uacute;ltimos 12 meses', 'calendar', 'N', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 12, M.ORD, M.LBL, (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN #SC S ON S.ID = V.ID_PROYECTO
                                  WHERE V.FECHA_DESDE >= M.MES AND V.FECHA_DESDE < DATEADD(MONTH, 1, M.MES))
        FROM #DM M;

        /* consumo de horas */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (13, @PNL, 3, 'H', 'Consumo de horas', 'proyectos activos con m&aacute;s horas usadas (% de lo proyectado)', 'clock-3', 'P', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT TOP 8 13, 0, ISNULL('(' + CODIGO + ') ', '') + NOMBRE, ROUND(100.0 * HEJEC / HPROY, 0)
        FROM #DP WHERE HPROY > 0 AND HEJEC > 0
        ORDER BY HEJEC / HPROY DESC;

        /* acciones por estado (gerencia) / horas por mes (analista) */
        IF @VISTA = 'GERENCIA'
        BEGIN
            INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (14, @PNL, 4, 'D', 'Acciones por estado', 'todas las acciones cargadas', 'list-checks', 'N', 'N');
            INSERT INTO #S (CH, ORD, LBL, VAL)
            SELECT 14, E.ORDEN, E.DESCRIPCION, COUNT(*)
            FROM dbo.VCT_ACCIONES A INNER JOIN dbo.VCT_PRM_ACCIONES_ESTADOS E ON E.ID = A.ID_ESTADO
            GROUP BY E.ORDEN, E.DESCRIPCION;
        END
        ELSE
        BEGIN
            INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (14, @PNL, 4, 'V', 'Horas ejecutadas por mes', '&uacute;ltimos 6 meses', 'clock-3', 'H', 'N');
            INSERT INTO #S (CH, ORD, LBL, VAL)
            SELECT 14, M.ORD, M.LBL, ISNULL((SELECT SUM(V.TOTAL_HORAS_EJECUTADAS) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN #SC S ON S.ID = V.ID_PROYECTO
                                             WHERE V.FECHA_DESDE >= M.MES AND V.FECHA_DESDE < DATEADD(MONTH, 1, M.MES)), 0)
            FROM #DM M WHERE M.MES >= @DESDE6;
        END;
    END;

    /* ===================================================================
       ADMINISTRACION
       =================================================================== */
    IF @VISTA = 'ADMIN'
    BEGIN
        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'admin', 1, 'Altas del mes',
               (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS P WHERE P.FECHA_ALTA >= @MES_INI), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS P WHERE P.FECHA_ALTA >= @ANIO_INI)) + ' en el a&ntilde;o', 'blue', 'folder';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'admin', 2, 'En curso', (SELECT COUNT(*) FROM #DP WHERE EST = 'ENCURSO'), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM #DP WHERE EST = 'CONFIRMADO')) + ' por iniciar', 'violet', 'chart-no-axes-column-increasing';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'admin', 3, 'Sin monto cargado',
               (SELECT COUNT(*) FROM #DP WHERE ISNULL(MONTO, 0) = 0), 'N',
               'proyectos activos', 'amber', 'circle-dollar-sign';

        IF @VER_DINERO = 1
            INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
            SELECT 'admin', 4, 'Vi&aacute;ticos del mes',
                   ISNULL((SELECT SUM(V.PRECIO_FINAL) FROM dbo.VCT_PROYECTOS_VIATICOS V WHERE V.FECHA_FC >= @MES_INI AND V.FECHA_FC < DATEADD(MONTH, 1, @MES_INI)), 0), 'M',
                   CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VIATICOS V WHERE V.FECHA_FC >= @MES_INI AND V.FECHA_FC < DATEADD(MONTH, 1, @MES_INI))) + ' comprobantes', 'mint', 'truck';
        ELSE
            INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
            SELECT 'admin', 4, 'Visitas del mes',
                   (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VISITAS V WHERE V.FECHA_DESDE >= @MES_INI AND V.FECHA_DESDE < DATEADD(MONTH, 1, @MES_INI)), 'N',
                   'agendadas', 'mint', 'calendar';

        /* proyectos por estado (todos) */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (21, 'admin', 1, 'D', 'Proyectos por estado', 'todos los proyectos', 'folder', 'N', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 21, E.ORDEN, E.DESCRIPCION, COUNT(*)
        FROM dbo.VCT_PROYECTOS P INNER JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS E ON E.ID = P.ID_ESTADO
        GROUP BY E.ORDEN, E.DESCRIPCION;

        /* altas por mes */
        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (22, 'admin', 2, 'V', 'Altas de proyecto por mes', '&uacute;ltimos 12 meses', 'calendar-days', 'N', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 22, M.ORD, M.LBL, (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS P WHERE P.FECHA_ALTA >= M.MES AND P.FECHA_ALTA < DATEADD(MONTH, 1, M.MES))
        FROM #DM M;

    END;

    /* ===================================================================
       CONSULTOR
       =================================================================== */
    IF @VISTA = 'CONSULTOR'
    BEGIN
        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'consultor', 1, 'Mis proyectos', (SELECT COUNT(*) FROM #DP), 'N',
               CONVERT(VARCHAR(10), (SELECT COUNT(*) FROM #DP WHERE EST = 'CONFIRMADO')) + ' por iniciar', 'blue', 'folder';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'consultor', 2, 'Visitas del mes',
               (SELECT COUNT(*) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
                WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= @MES_INI AND V.FECHA_DESDE < DATEADD(MONTH, 1, @MES_INI)), 'N',
               'pr&oacute;xima: ' + ISNULL((SELECT TOP 1 CONVERT(VARCHAR(10), V.FECHA_DESDE, 103)
                                         FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
                                         WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= GETDATE() ORDER BY V.FECHA_DESDE), 'sin agendar'),
               'violet', 'calendar';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'consultor', 3, 'Horas del mes',
               ISNULL((SELECT SUM(ISNULL(VC.HORAS_EJECUTADAS, 0)) FROM dbo.VCT_PROYECTOS_VISITAS V INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
                       WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= @MES_INI AND V.FECHA_DESDE < DATEADD(MONTH, 1, @MES_INI)), 0), 'H',
               'ejecutadas', 'mint', 'clock-3';

        INSERT INTO #K (PANEL, ORD, LBL, VAL, FMT, SUB, TONE, ICON)
        SELECT 'consultor', 4, 'Mis acciones',
               (SELECT COUNT(*) FROM dbo.VCT_ACCIONES A INNER JOIN dbo.VCT_PRM_ACCIONES_ESTADOS E ON E.ID = A.ID_ESTADO
                WHERE E.ES_FINAL = 0 AND EXISTS (SELECT 1 FROM dbo.VCT_ACCIONES_PARTICIPANTES AP WHERE AP.ID_ACCION = A.ID AND AP.ESTADO = 'ACTIVO'
                                                 AND AP.TIPO_ENTIDAD = 'CONSULTOR' AND AP.ID_ENTIDAD = @CONS_ID)), 'N',
               'abiertas', 'amber', 'list-checks';

        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (31, 'consultor', 1, 'V', 'Mis horas por mes', '&uacute;ltimos 6 meses', 'clock-3', 'H', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT 31, M.ORD, M.LBL, ISNULL((SELECT SUM(ISNULL(VC.HORAS_EJECUTADAS, 0)) FROM dbo.VCT_PROYECTOS_VISITAS V
                                         INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
                                         WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= M.MES AND V.FECHA_DESDE < DATEADD(MONTH, 1, M.MES)), 0)
        FROM #DM M WHERE M.MES >= @DESDE6;

        INSERT INTO #C (CH, PANEL, ORD, TIPO, TITULO, SUB, ICON, FMT, ANCHO) VALUES (32, 'consultor', 2, 'H', 'Mis horas por proyecto', '&uacute;ltimos 12 meses', 'folder', 'H', 'N');
        INSERT INTO #S (CH, ORD, LBL, VAL)
        SELECT TOP 6 32, 0, ISNULL('(' + P.CODIGO + ') ', '') + P.NOMBRE, SUM(ISNULL(VC.HORAS_EJECUTADAS, 0))
        FROM dbo.VCT_PROYECTOS_VISITAS V
        INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC ON VC.ID_VISITA = V.ID
        INNER JOIN dbo.VCT_PROYECTOS P ON P.ID = V.ID_PROYECTO
        WHERE VC.ID_CONSULTOR = @CONS_ID AND V.FECHA_DESDE >= @DESDE12
        GROUP BY P.CODIGO, P.NOMBRE
        HAVING SUM(ISNULL(VC.HORAS_EJECUTADAS, 0)) > 0
        ORDER BY SUM(ISNULL(VC.HORAS_EJECUTADAS, 0)) DESC;
    END;

    /* ===================================================================
       FORMATO DE VALORES Y ARMADO DE GRAFICOS
       =================================================================== */
    UPDATE #K SET TXT =
        CASE FMT
            WHEN 'M' THEN CASE WHEN ABS(VAL) >= 1000000
                               THEN '$ ' + REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(VAL / 1000000.0, 1) AS DECIMAL(18,1))), '.', ',') + ' M'
                               ELSE '$ ' + REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') END
            WHEN 'H' THEN REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') + ' h'
            WHEN 'P' THEN CONVERT(VARCHAR(20), CONVERT(INT, ROUND(VAL, 0))) + '%'
            ELSE REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') END
    WHERE TXT IS NULL;

    UPDATE S SET TXT =
        CASE C.FMT
            WHEN 'M' THEN CASE WHEN ABS(S.VAL) >= 1000000
                               THEN '$ ' + REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL / 1000000.0, 1) AS DECIMAL(18,1))), '.', ',') + ' M'
                               WHEN ABS(S.VAL) >= 1000
                               THEN '$ ' + CONVERT(VARCHAR(30), CONVERT(INT, ROUND(S.VAL / 1000.0, 0))) + ' k'
                               ELSE '$ ' + CONVERT(VARCHAR(30), CONVERT(INT, ROUND(S.VAL, 0))) END
            WHEN 'H' THEN REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') + ' h'
            WHEN 'P' THEN CONVERT(VARCHAR(20), CONVERT(INT, ROUND(S.VAL, 0))) + '%'
            ELSE REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') END
    FROM #S S INNER JOIN #C C ON C.CH = S.CH;

    /* orden de las series horizontales: de mayor a menor */
    UPDATE S SET ORD = X.RN
    FROM #S S
    INNER JOIN (SELECT S2.CH, S2.LBL, ROW_NUMBER() OVER (PARTITION BY S2.CH ORDER BY S2.VAL DESC, S2.LBL) AS RN
                FROM #S S2 INNER JOIN #C C2 ON C2.CH = S2.CH WHERE C2.TIPO = 'H') X ON X.CH = S.CH AND X.LBL = S.LBL;

    /* ---------- paleta de graficos (estandar del sistema) ----------
       Basada en el Manual de Identidad Vocaturo (bordo Pantone 7421 C #66062D y gris
       Pantone Black 7 C #333233): tonalidades de esos dos colores, alternadas.
       1..4  = paleta base: graficos de un solo color (rota al azar sin repetir dentro del panel)
               y anillos de hasta 4 partes.
       1..10 = paleta extendida: anillos de 5 a 10 partes, siempre en este orden; si hay mas de
               10 partes se dejan las 9 mayores y el resto se agrupa en "Otros" (gris medio, el 10). */
    CREATE TABLE #PAL (ID INT PRIMARY KEY, COLOR VARCHAR(10));
    INSERT INTO #PAL VALUES (1, '#8C1D47'), (2, '#4A4849'), (3, '#CF6F92'), (4, '#8E8C8D'),   /* bordo medio, grafito, bordo claro, gris medio */
                            (5, '#66062D'), (6, '#C4C2C3'), (7, '#B23E68'), (8, '#2B2A2B'),   /* bordo institucional, gris claro, bordo vivo, grafito oscuro */
                            (9, '#E8A9C0'), (10, '#6E6C6D');                                  /* bordo palido, gris (Otros) */

    /* anillos con mas de 10 partes: 9 mayores + Otros */
    INSERT INTO #S (CH, ORD, LBL, VAL)
    SELECT X.CH, 999, 'Otros', SUM(X.VAL)
    FROM (SELECT S.CH, S.VAL, ROW_NUMBER() OVER (PARTITION BY S.CH ORDER BY S.VAL DESC, S.LBL) AS RN
          FROM #S S INNER JOIN #C C ON C.CH = S.CH WHERE C.TIPO = 'D' AND S.VAL > 0) X
    WHERE X.RN > 9 AND X.CH IN (SELECT S2.CH FROM #S S2 WHERE S2.VAL > 0 GROUP BY S2.CH HAVING COUNT(*) > 10)
    GROUP BY X.CH;
    DELETE S
    FROM #S S
    INNER JOIN (SELECT S3.CH, S3.LBL, S3.ORD, ROW_NUMBER() OVER (PARTITION BY S3.CH ORDER BY S3.VAL DESC, S3.LBL) AS RN
                FROM #S S3 INNER JOIN #C C3 ON C3.CH = S3.CH WHERE C3.TIPO = 'D' AND S3.VAL > 0 AND S3.ORD <> 999) X
            ON X.CH = S.CH AND X.LBL = S.LBL AND X.ORD = S.ORD
    WHERE X.RN > 9 AND EXISTS (SELECT 1 FROM #S O WHERE O.CH = S.CH AND O.ORD = 999);
    UPDATE S SET TXT =
        CASE C.FMT WHEN 'M' THEN CASE WHEN ABS(S.VAL) >= 1000000 THEN '$ ' + REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL / 1000000.0, 1) AS DECIMAL(18,1))), '.', ',') + ' M'
                                      WHEN ABS(S.VAL) >= 1000 THEN '$ ' + CONVERT(VARCHAR(30), CONVERT(INT, ROUND(S.VAL / 1000.0, 0))) + ' k'
                                      ELSE '$ ' + CONVERT(VARCHAR(30), CONVERT(INT, ROUND(S.VAL, 0))) END
                   WHEN 'H' THEN REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') + ' h'
                   ELSE REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(S.VAL, 0) AS MONEY), 1), '.00', ''), ',', '.') END
    FROM #S S INNER JOIN #C C ON C.CH = S.CH
    WHERE S.ORD = 999;

    /* color de arranque de cada grafico: al azar entre los 4 base, el siguiente para cada grafico del panel */
    DECLARE @OFF INT = ABS(CHECKSUM(NEWID())) % 4, @NPART INT;
    UPDATE C SET COFF = (@OFF + X.RN) % 4
    FROM #C C INNER JOIN (SELECT CH, ROW_NUMBER() OVER (PARTITION BY PANEL ORDER BY ORD) - 1 AS RN FROM #C) X ON X.CH = C.CH;

    DECLARE @ch INT, @tipo CHAR(1), @coff INT, @col VARCHAR(10), @mx DECIMAL(18,2), @tot DECIMAL(18,2), @body VARCHAR(MAX), @grad VARCHAR(MAX), @leg VARCHAR(MAX);
    DECLARE cch CURSOR LOCAL FAST_FORWARD FOR SELECT CH, TIPO, COFF FROM #C;
    OPEN cch;
    FETCH NEXT FROM cch INTO @ch, @tipo, @coff;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @mx = MAX(VAL), @tot = SUM(VAL) FROM #S WHERE CH = @ch;
        SET @body = '';
        SELECT @col = COLOR FROM #PAL WHERE ID = (@coff % 4) + 1;
        SELECT @NPART = COUNT(*) FROM #S WHERE CH = @ch AND VAL > 0;

        IF ISNULL(@tot, 0) <= 0
            SET @body = '<div class="vct-dash-empty">Sin datos para mostrar.</div>';
        ELSE IF @tipo = 'V'
            SET @body = '<div class="vct-dash-vbars">' + ISNULL((
                SELECT '<div class="vct-dash-vcol" title="' + REPLACE(S.LBL, '"', '') + ': ' + S.TXT + '">'
                       + '<span class="vct-dash-vval">' + CASE WHEN S.VAL > 0 THEN S.TXT ELSE '' END + '</span>'
                       + '<span class="vct-dash-vbar" style="background:' + @col + ';height:' + CONVERT(VARCHAR(10), CONVERT(INT, ROUND(CASE WHEN @mx > 0 THEN 100.0 * S.VAL / @mx ELSE 0 END, 0))) + '%"></span>'
                       + '<span class="vct-dash-vlbl">' + REPLACE(REPLACE(REPLACE(S.LBL, '&', '&amp;'), '<', '&lt;'), '>', '&gt;') + '</span></div>'
                FROM #S S WHERE S.CH = @ch ORDER BY S.ORD
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '') + '</div>';
        ELSE IF @tipo = 'H'
            SET @body = '<div class="vct-dash-hbars">' + ISNULL((
                SELECT '<div class="vct-dash-hrow"><span class="vct-dash-hlbl" title="' + REPLACE(REPLACE(S.LBL, '"', ''), '&', '&amp;') + '">'
                       + REPLACE(REPLACE(REPLACE(S.LBL, '&', '&amp;'), '<', '&lt;'), '>', '&gt;') + '</span>'
                       + '<span class="vct-dash-htrack"><span class="vct-dash-hbar' + CASE WHEN C.FMT = 'P' AND S.VAL > 100 THEN ' is-over' ELSE '' END + '" style="' + CASE WHEN C.FMT = 'P' AND S.VAL > 100 THEN '' ELSE 'background:' + @col + ';' END + 'width:'
                       + CONVERT(VARCHAR(10), CONVERT(INT, ROUND(CASE WHEN C.FMT = 'P' THEN CASE WHEN S.VAL > 100 THEN 100 ELSE S.VAL END
                                                                      WHEN @mx > 0 THEN 100.0 * S.VAL / @mx ELSE 0 END, 0))) + '%"></span></span>'
                       + '<span class="vct-dash-hval">' + S.TXT + '</span></div>'
                FROM #S S INNER JOIN #C C ON C.CH = S.CH WHERE S.CH = @ch ORDER BY S.ORD
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '') + '</div>';
        ELSE
        BEGIN
            /* anillo: conic-gradient con porcentajes acumulados */
            SELECT @grad = ISNULL((
                SELECT ',' + (SELECT P.COLOR FROM #PAL P WHERE P.ID = CASE WHEN @NPART <= 4 THEN ((S.RN - 1 + @coff) % 4) + 1 WHEN S.LBL = 'Otros' AND S.ORD = 999 THEN 10 ELSE ((S.RN - 1) % 10) + 1 END)
                       + ' ' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * S.ACUM_ANT / @tot)) + '% '
                       + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,2), 100.0 * (S.ACUM_ANT + S.VAL) / @tot)) + '%'
                FROM (SELECT S1.ORD, S1.VAL, S1.LBL,
                             (SELECT COUNT(*) FROM #S S2 WHERE S2.CH = @ch AND (S2.ORD < S1.ORD OR (S2.ORD = S1.ORD AND S2.LBL <= S1.LBL))) AS RN,
                             ISNULL((SELECT SUM(S2.VAL) FROM #S S2 WHERE S2.CH = @ch AND (S2.ORD < S1.ORD OR (S2.ORD = S1.ORD AND S2.LBL < S1.LBL))), 0) AS ACUM_ANT
                      FROM #S S1 WHERE S1.CH = @ch AND S1.VAL > 0) S
                ORDER BY S.RN
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '');

            SELECT @leg = ISNULL((
                SELECT '<li><i style="background:' + (SELECT P.COLOR FROM #PAL P WHERE P.ID = CASE WHEN @NPART <= 4 THEN ((S.RN - 1 + @coff) % 4) + 1 WHEN S.LBL = 'Otros' AND S.ORD = 999 THEN 10 ELSE ((S.RN - 1) % 10) + 1 END) + '"></i>'
                       + REPLACE(REPLACE(REPLACE(S.LBL, '&', '&amp;'), '<', '&lt;'), '>', '&gt;') + ' <b>' + S.TXT + '</b> <small>('
                       + CONVERT(VARCHAR(10), CONVERT(INT, ROUND(100.0 * S.VAL / @tot, 0))) + '%)</small></li>'
                FROM (SELECT S1.ORD, S1.VAL, S1.LBL, S1.TXT,
                             (SELECT COUNT(*) FROM #S S2 WHERE S2.CH = @ch AND (S2.ORD < S1.ORD OR (S2.ORD = S1.ORD AND S2.LBL <= S1.LBL))) AS RN
                      FROM #S S1 WHERE S1.CH = @ch AND S1.VAL > 0) S
                ORDER BY S.RN
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '');

            SET @body = '<div class="vct-dash-donut-wrap"><div class="vct-dash-donut" style="background:conic-gradient(' + STUFF(@grad, 1, 1, '') + ')"><b>'
                      + REPLACE(REPLACE(CONVERT(VARCHAR(30), CAST(ROUND(@tot, 0) AS MONEY), 1), '.00', ''), ',', '.') + '</b></div>'
                      + '<ul class="vct-dash-legend">' + @leg + '</ul></div>';
        END;

        UPDATE #C SET HTML =
            '<div class="vct-360-box vct-ini-box vct-dash-box' + CASE WHEN ANCHO = 'W' THEN ' vct-dash-wide' ELSE '' END + '">'
            + '<div class="vct-360-box-head"><div><h3><span class="vct-360-title-icon"><span data-vct-icon="' + ICON + '"></span></span>' + TITULO + '</h3>'
            + CASE WHEN ISNULL(SUB, '') <> '' THEN '<p class="vct-360-box-subtitle">' + SUB + '</p>' ELSE '' END + '</div></div>'
            + '<div class="vct-ini-box-body">' + @body + '</div></div>'
        WHERE CH = @ch;

        FETCH NEXT FROM cch INTO @ch, @tipo, @coff;
    END;
    CLOSE cch;
    DEALLOCATE cch;

    /* ===================================================================
       ARMADO DE PESTANIAS Y PANELES
       =================================================================== */
    DECLARE @pn VARCHAR(20), @plbl VARCHAR(100), @picon VARCHAR(40), @kpis VARCHAR(MAX), @charts VARCHAR(MAX), @extra VARCHAR(MAX);
    CREATE TABLE #PN (ORD INT, PANEL VARCHAR(20), LBL VARCHAR(100), ICON VARCHAR(40));

    IF @VISTA = 'GERENCIA'
        INSERT INTO #PN VALUES (1, 'comercial', 'Comercial', 'circle-dollar-sign'), (2, 'operacion', 'Operaci&oacute;n', 'folder');
    ELSE IF @VISTA = 'ADMIN'
        INSERT INTO #PN VALUES (1, 'admin', 'Administraci&oacute;n', 'briefcase'), (2, 'comercial', 'Comercial', 'circle-dollar-sign');
    ELSE IF @VISTA = 'ANALISTA'
        INSERT INTO #PN VALUES (1, 'proyectos', 'Mis proyectos', 'folder');
    ELSE IF @VISTA = 'CONSULTOR'
        INSERT INTO #PN VALUES (1, 'consultor', 'Mi trabajo', 'calendar');

    DECLARE cpn CURSOR LOCAL FAST_FORWARD FOR SELECT PANEL, LBL, ICON FROM #PN ORDER BY ORD;
    OPEN cpn;
    FETCH NEXT FROM cpn INTO @pn, @plbl, @picon;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NTABS = @NTABS + 1;
        SET @TABS = @TABS + '<button type="button" class="vct-ini-tab" data-vct-ini-tab="' + @pn + '"><span data-vct-icon="' + @picon + '"></span><span>' + @plbl + '</span></button>';

        SELECT @kpis = ISNULL((
            SELECT '<div class="vct-360-stat" data-vct-tone="' + K.TONE + '"><span><span class="vct-360-stat-label">' + K.LBL + '</span><b>' + K.TXT + '</b><small>'
                   + ISNULL(K.SUB, '') + '</small></span><span class="vct-360-stat-icon"><span data-vct-icon="' + K.ICON + '"></span></span></div>'
            FROM #K K WHERE K.PANEL = @pn ORDER BY K.ORD
            FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '');

        SELECT @charts = ISNULL((
            SELECT C.HTML FROM #C C WHERE C.PANEL = @pn ORDER BY C.ORD
            FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), '');

        SET @extra = '';
        IF @pn = 'comercial' AND @VER_DINERO = 0
            SET @extra = @NOTA_DINERO;

        SET @PANELS = @PANELS
            + '<div class="vct-ini-panel" data-vct-ini-panel="' + @pn + '">'
            + CASE WHEN @kpis <> '' THEN '<div class="vct-360-stats-row">' + @kpis + '</div>' ELSE '' END
            + CASE WHEN @pn = 'comercial' AND @VER_DINERO = 0 THEN @extra
                   ELSE '<div class="vct-dash-grid">' + @charts + @extra + '</div>' END
            + '</div>';

        FETCH NEXT FROM cpn INTO @pn, @plbl, @picon;
    END;
    CLOSE cpn;
    DEALLOCATE cpn;

    IF @VISTA = 'CLIENTE' OR @NTABS = 0
        SET @PANELS =
            '<div class="vct-ini-panel" data-vct-ini-panel="vacio"><div class="vct-360-box vct-ini-box"><div class="vct-ini-box-body"><div class="vct-ini-empty">'
          + CASE WHEN @VISTA = 'CLIENTE'
                 THEN 'Bienvenido. El tablero del cliente (avance de sus proyectos, pr&oacute;ximas visitas y acciones pendientes) se habilita cuando el usuario quede vinculado a su empresa.'
                 ELSE 'Tu usuario todav&iacute;a no tiene un inicio configurado.' END
          + '</div></div></div></div>';

    /* ===================================================================
       SALIDA
       =================================================================== */
    SET @OUTPARAM1 = ISNULL(@HTML_SHELL, '')
      + '<link rel="stylesheet" href="../css/vct-inicio.css?v=5"><script src="../js/vct-inicio.js?v=4"></script>'
      
      + '<style>'
      + '.vct-dash-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:16px}'
      + '.vct-dash-wide{grid-column:1/-1}'
      + '@media (max-width:900px){.vct-dash-grid{grid-template-columns:1fr}}'
      + '.vct-dash-box .vct-ini-box-body{padding:8px 16px 16px}'
      + '.vct-dash-vbars{display:flex;align-items:flex-end;gap:6px;height:200px;padding-top:18px}'
      + '.vct-dash-vcol{flex:1 1 0;min-width:0;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:flex-end}'
      + '.vct-dash-vbar{display:block;width:70%;max-width:38px;min-height:2px;background:#66062D;border-radius:4px 4px 0 0}'
      + '.vct-dash-vcol:hover .vct-dash-vbar{opacity:.8}'
      + '.vct-dash-vval{font-size:10px;color:#475569;margin-bottom:4px;white-space:nowrap}'
      + '.vct-dash-vlbl{font-size:11px;color:#64748b;margin-top:6px;white-space:nowrap}'
      + '.vct-dash-hrow{display:grid;grid-template-columns:minmax(0,40%) minmax(0,1fr) auto;gap:10px;align-items:center;padding:6px 0;font-size:13px}'
      + '.vct-dash-hlbl{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#334155}'
      + '.vct-dash-htrack{display:block;background:#f1f5f9;border-radius:6px;height:10px;overflow:hidden}'
      + '.vct-dash-hbar{display:block;height:100%;background:#66062D;border-radius:6px}'
      + '.vct-dash-hbar.is-over{background:#d97706}'
      + '.vct-dash-hval{font-size:12px;color:#475569;white-space:nowrap}'
      + '.vct-dash-donut-wrap{display:flex;gap:24px;align-items:center;flex-wrap:wrap;padding-top:8px}'
      + '.vct-dash-donut{width:150px;height:150px;border-radius:50%;position:relative;flex:0 0 auto}'
      + '.vct-dash-donut::after{content:"";position:absolute;inset:30px;background:#fff;border-radius:50%}'
      + '.vct-dash-donut b{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;z-index:1;font-size:22px;color:#0f172a}'
      + '.vct-dash-legend{list-style:none;margin:0;padding:0;font-size:13px;display:grid;gap:6px;color:#334155}'
      + '.vct-dash-legend i{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:8px;vertical-align:middle}'
      + '.vct-dash-legend small{color:#94a3b8}'
      + '.vct-dash-empty{color:#94a3b8;font-size:13px;padding:28px 0;text-align:center}'
      + '.vct-dash-note{background:#fdf2f6;border:1px solid #f3d4e0;color:#66062D;border-radius:8px;padding:12px 16px;font-size:13px;margin-top:16px}'
      + '.vct-dash-aviso{background:#fffbeb;border:1px solid #fde68a;color:#92400e;border-radius:8px;padding:10px 14px;font-size:13px;margin:0 0 12px}'
      + '@media (max-width:640px){.vct-dash-vval{display:none}.vct-dash-hrow{grid-template-columns:minmax(0,45%) minmax(0,1fr) auto}}'
      + '</style>'
      + '<div class="vct-page vct-360-module vct-360-visual-final vct-inicio" data-vct-page data-vct-inicio data-vct-dashboard="v2"'
      + ' data-vct-sidebar-id="' + CONVERT(VARCHAR(20), ISNULL(@SIDEBAR_ID, 0)) + '" data-vct-form-id="' + ISNULL(@FORM_ID, '') + '"'
      + ' data-vct-ini-guid="' + @GUID_P + '" data-vct-ini-user="' + REPLACE(REPLACE(REPLACE(LOWER(ISNULL(@IAGENTE, '')), '&', '&amp;'), '<', '&lt;'), '"', '&quot;') + '">'
      + '<input type="hidden" name="SP.IDSELEC01" data-vct-field="IDSELEC01" value="">'
      + '<input type="hidden" name="SP.IDSELEC02" data-vct-field="IDSELEC02" value="">'
      + '<div class="vct-360-content-shell">'
      + CASE WHEN ISNULL(@BELL, '') <> '' THEN '<div class="vct-ini-top">' + @BELL + '</div>' ELSE '' END
      + CASE WHEN @AVISO <> '' THEN '<div class="vct-dash-aviso">' + @AVISO + '</div>' ELSE '' END
      + CASE WHEN @NTABS > 1 THEN '<div class="vct-360-tabsbar vct-ini-tabs" data-vct-ini-tabs>' + @TABS + '</div>' ELSE '' END
      + @PANELS
      + '</div></div>';
END
GO

PRINT 'OK: VCT_MAIN_DASHBOARD (DASHBOARD_V2) aplicado.';
GO
