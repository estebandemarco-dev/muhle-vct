/* ============================================================================
   AGENDA_CONSULTOR_3_PANTALLA
   ----------------------------------------------------------------------------
   Pantalla "Agenda del consultor" (SideBar Id=9, Code=AGENDA_CONSULTOR).
   Molde visual: shell + stats-row estilo Acciones + grilla de calendario
   (reusa las clases de vct-agenda.css) -> calendario y agenda unificados.

   Dos modos segun el perfil:
     - VE_TODO (GERENCIA/SQUAD/ADMINISTRACION/PROYECTOS): un <select> arriba
       para elegir CUALQUIER consultor y ver su disponibilidad (para decidir
       si le pueden asignar un proyecto). Al cambiar, guarda IDSELEC01 y
       recarga la misma pantalla (grid-action al guid de la pantalla).
     - CONSULTOR (perfil CONSULTORES): su propia agenda (resuelta por
       ID_USUARIO_SEGURIDAD), sin select.

   Datos: calcula una ventana amplia (hoy-3 meses .. hoy+12 meses) con
   dbo.VCT_FN_AGENDA_CONSULTOR_RANGO y la manda como JSON (armado con FOR XML
   PATH, compat 100-safe). El JS navega los meses offline.

   v1 = SOLO LECTURA (ver disponibilidad). El alta/edicion de bloqueos
   (DISPONIBLE=0) es el paso 2.

   Permisos: dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD,'AGENDA_CONSULTOR') -> .VIEW.
   Ruteo: ACTION='AGENDA_CONSULTOR' (lo asocia el designer; ademas se agrega
   fallback en VCT_MAIN_DASHBOARD al final de este script).
   Re-ejecutable. Compat 100/140 (sin OPENJSON / FOR JSON / STRING_AGG).
   ============================================================================ */
USE [MuhlePROD];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.VCT_MAIN_AGENDA_CONSULTOR
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
    SET NOCOUNT ON;
    SET @OUTPARAM1 = '';
    SET @OUTPARAM2 = NULL;
    SET @OUTPARAM3 = NULL;

    DECLARE @MODULE_CODE VARCHAR(50) = 'AGENDA_CONSULTOR';
    DECLARE @GUID_SELF   VARCHAR(50) = 'D2F5BD3A-86F0-4855-A0D8-18466AC7C4A9'; /* SideBar Id=9 */

    DECLARE @HTML_SHELL VARCHAR(MAX) = '', @RES VARCHAR(20) = '',
            @PERFIL VARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@IUNIDAD,'')))),
            @U VARCHAR(100) = LOWER(LTRIM(RTRIM(ISNULL(@IAGENTE,'')))),
            @VE_TODO BIT = 0, @CAN_EDIT BIT = 0, @SIDEBAR_ID INT = 0,
            @CONS_ID INT = NULL, @CONS_NOMBRE VARCHAR(320) = '',
            @SEL_RAW VARCHAR(100) = '',
            @HTML VARCHAR(MAX) = '', @MSG VARCHAR(MAX) = '',
            @SUBT VARCHAR(200) = '';

    SET @VE_TODO = CASE WHEN @PERFIL IN ('GERENCIA','SQUAD','ADMINISTRACION','PROYECTOS') THEN 1 ELSE 0 END;
    SET @SUBT = 'Disponibilidad por d' + CHAR(237) + 'a: libre, ocupado, bloqueado y feriados.';

    /* ---------- shell ---------- */
    BEGIN TRY
        EXEC dbo.VCT_GET_SHELL @IUNIDAD=@IUNIDAD, @IAGENTE=@IAGENTE, @FORM_ID=@FORM_ID,
             @TITLE='Agenda del consultor',
             @SUBTITLE=@SUBT,
             @SEARCH_PLACEHOLDER='', @SHOW_SEARCH=0,
             @OSHELL=@HTML_SHELL OUTPUT, @ORESULTADO=@RES OUTPUT;
    END TRY
    BEGIN CATCH
        SET @HTML_SHELL = '';
    END CATCH;

    /* ---------- permisos ---------- */
    IF OBJECT_ID('tempdb..#ACC') IS NOT NULL DROP TABLE #ACC;
    SELECT * INTO #ACC FROM dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, @MODULE_CODE);

    SELECT TOP 1 @SIDEBAR_ID = ISNULL(SIDEBAR_ID,0) FROM #ACC WHERE ISNULL(SIDEBAR_ID,0)<>0 ORDER BY SORT_ORDER, ID_PRM;
    SET @CAN_EDIT = CASE WHEN EXISTS(SELECT 1 FROM #ACC WHERE ACTION_TYPE='EDIT') THEN 1 ELSE 0 END;

    IF NOT EXISTS(SELECT 1 FROM #ACC WHERE ACTION_TYPE='VIEW')
    BEGIN
        SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') +
        '<div class="vct-page vct-page-main" data-vct-page data-vct-sidebar-id="'+CONVERT(VARCHAR(20),@SIDEBAR_ID)+'" data-vct-form-id="'+ISNULL(@FORM_ID,'')+'">'
        +'<section class="vct-card"><div class="vct-card-body"><h2 class="vct-card-title">Acceso restringido</h2>'
        +'<p class="vct-card-subtitle">No posee permisos para ver la Agenda del consultor.</p></div></section></div>';
        RETURN;
    END;

    /* ---------- resolver consultor ---------- */
    IF @VE_TODO = 1
    BEGIN
        SELECT TOP 1 @SEL_RAW = ISNULL(CONVERT(VARCHAR(100), IDSELEC01),'')
        FROM dbo.VCT_BUFFER WITH(NOLOCK) WHERE PAR_KEY = @IPKEYJOB;

        IF @SEL_RAW LIKE '%[0-9]%' AND @SEL_RAW NOT LIKE '%[^0-9]%'
            SET @CONS_ID = CONVERT(INT, @SEL_RAW);
    END
    ELSE
    BEGIN
        SELECT TOP 1 @CONS_ID = ID FROM dbo.VCT_CONSULTORES
        WHERE LOWER(LTRIM(RTRIM(ISNULL(ID_USUARIO_SEGURIDAD,'')))) = @U
          AND UPPER(ISNULL(ESTADO,'')) = 'ACTIVO'
        ORDER BY ID DESC;
    END;

    IF @CONS_ID IS NOT NULL
        SELECT @CONS_NOMBRE = LTRIM(RTRIM(ISNULL(APELLIDOS,'') + CASE WHEN ISNULL(NOMBRES,'')<>'' THEN ', '+NOMBRES ELSE '' END))
        FROM dbo.VCT_CONSULTORES WHERE ID = @CONS_ID;

    /* ---------- select de consultor (solo VE_TODO) ---------- */
    DECLARE @SELECT_CONS VARCHAR(MAX) = '';
    IF @VE_TODO = 1
    BEGIN
        DECLARE @OPTS VARCHAR(MAX) = ISNULL((
            SELECT '<option value="'+CONVERT(VARCHAR(10),C.ID)+'"'+CASE WHEN C.ID=@CONS_ID THEN ' selected' ELSE '' END+'>'
                 + REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(C.APELLIDOS,'')+CASE WHEN ISNULL(C.NOMBRES,'')<>'' THEN ', '+C.NOMBRES ELSE '' END)),'&','&amp;'),'<','&lt;'),'>','&gt;')
                 + '</option>'
            FROM dbo.VCT_CONSULTORES C
            WHERE UPPER(ISNULL(C.ESTADO,''))='ACTIVO'
            ORDER BY C.APELLIDOS, C.NOMBRES
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), '');

        SET @SELECT_CONS =
            '<div class="vct-agc-pick">'
          + '<label class="vct-agc-pick-label">Consultor</label>'
          + '<select class="vct-select vct-agc-select-cons" data-vct-agc-select-cons aria-label="Consultor">'
          + '<option value="">' + CHAR(8212) + ' Eleg' + CHAR(237) + ' un consultor ' + CHAR(8212) + '</option>'
          + @OPTS + '</select></div>';
    END;

    /* ---------- datos (JSON de dias) ---------- */
    DECLARE @HOY DATE = CONVERT(DATE, GETDATE());
    DECLARE @DESDE DATE = DATEADD(MONTH, -3, DATEFROMPARTS(YEAR(@HOY), MONTH(@HOY), 1));
    DECLARE @HASTA DATE = EOMONTH(@HOY, 12);
    DECLARE @DIAS_JSON VARCHAR(MAX) = '[]';

    IF @CONS_ID IS NOT NULL
    BEGIN
        SET @DIAS_JSON = '[' + ISNULL(STUFF((
            SELECT ',{"f":"' + CONVERT(VARCHAR(10), R.FECHA, 120)
                 + '","e":"' + R.ESTADO
                 + '","c":' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(5,1), R.HORAS_CAPACIDAD))
                 + ',"o":' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,1), R.HORAS_OCUPADAS))
                 + ',"d":' + CONVERT(VARCHAR(10), CONVERT(DECIMAL(6,1), R.HORAS_DISP))
                 + ',"m":"' + REPLACE(REPLACE(REPLACE(ISNULL(R.MOTIVO,''),'\','/'),'"',''''),CHAR(10),' ') + '"}'
            FROM dbo.VCT_FN_AGENDA_CONSULTOR_RANGO(@CONS_ID, @DESDE, @HASTA) R
            ORDER BY R.FECHA
            FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)'), 1, 1, ''), '') + ']';
    END;

    /* escape para atributo HTML (igual que el calendario de feriados) */
    SET @DIAS_JSON = REPLACE(REPLACE(@DIAS_JSON, '&', '&amp;'), '"', '&quot;');

    /* ---------- cuerpo ---------- */
    DECLARE @NEED_PICK BIT = CASE WHEN @CONS_ID IS NULL THEN 1 ELSE 0 END;

    SET @HTML =
        '<link rel="stylesheet" href="../css/vct-inicio.css?v=5">'
      + '<link rel="stylesheet" href="../css/vct-agenda.css?v=3">'
      + '<link rel="stylesheet" href="../css/vct-agenda-consultor.css?v=1">'
      + '<script src="../js/vct-agenda-consultor.js?v=1"></script>'
      + '<div class="vct-page vct-page-main vct-agc-page" data-vct-page'
      + ' data-vct-sidebar-id="' + CONVERT(VARCHAR(20),@SIDEBAR_ID) + '"'
      + ' data-vct-form-id="' + ISNULL(@FORM_ID,'') + '"'
      + ' data-vct-agc-root'
      + ' data-vct-agc-guid="' + @GUID_SELF + '"'
      + ' data-vct-agc-ve-todo="' + CASE WHEN @VE_TODO=1 THEN '1' ELSE '0' END + '"'
      + ' data-vct-agc-can-edit="' + CASE WHEN @CAN_EDIT=1 THEN '1' ELSE '0' END + '"'
      + ' data-vct-agc-cons="' + ISNULL(CONVERT(VARCHAR(10),@CONS_ID),'') + '"'
      + ' data-vct-agc-dias="' + @DIAS_JSON + '">'

      + '<section class="vct-card vct-agc-card">'
      + '<div class="vct-agenda-toolbar vct-agc-toolbar">'
      +   ISNULL(@SELECT_CONS,'')
      +   '<div class="vct-agenda-view-toggle" data-vct-agc-view-toggle>'
      +     '<button type="button" class="vct-agenda-view-btn is-active" data-vct-agc-view="month">Mes</button>'
      +     '<button type="button" class="vct-agenda-view-btn" data-vct-agc-view="week">Semana</button>'
      +     '<button type="button" class="vct-agenda-view-btn" data-vct-agc-view="day">D' + CHAR(237) + 'a</button>'
      +   '</div>'
      +   '<div class="vct-agenda-nav">'
      +     '<button type="button" class="vct-agenda-nav-btn" data-vct-agc-prev aria-label="Anterior"><span data-vct-icon="chevron-left"></span></button>'
      +     '<h2 class="vct-agenda-title" data-vct-agc-title></h2>'
      +     '<button type="button" class="vct-agenda-nav-btn" data-vct-agc-next aria-label="Siguiente"><span data-vct-icon="chevron-right"></span></button>'
      +   '</div>'
      +   '<div class="vct-agenda-toolbar-right"><div class="vct-agenda-jump">'
      +     '<select class="vct-select vct-agenda-select-month" data-vct-agc-month>'
      +       '<option value="1">Enero</option><option value="2">Febrero</option><option value="3">Marzo</option>'
      +       '<option value="4">Abril</option><option value="5">Mayo</option><option value="6">Junio</option>'
      +       '<option value="7">Julio</option><option value="8">Agosto</option><option value="9">Septiembre</option>'
      +       '<option value="10">Octubre</option><option value="11">Noviembre</option><option value="12">Diciembre</option>'
      +     '</select>'
      +     '<select class="vct-select vct-agenda-select-year" data-vct-agc-year></select>'
      +   '</div></div>'
      + '</div>'

      + '<div class="vct-360-stats-row vct-agc-stats" data-vct-agc-stats></div>'

      + '<div class="vct-agenda-legend vct-agc-legend">'
      +   '<span class="vct-agenda-legend-item"><i class="vct-agc-dot vct-agc-dot-libre"></i>Libre</span>'
      +   '<span class="vct-agenda-legend-item"><i class="vct-agc-dot vct-agc-dot-parcial"></i>Parcial</span>'
      +   '<span class="vct-agenda-legend-item"><i class="vct-agc-dot vct-agc-dot-ocupado"></i>Ocupado</span>'
      +   '<span class="vct-agenda-legend-item"><i class="vct-agc-dot vct-agc-dot-bloqueado"></i>No disponible</span>'
      +   '<span class="vct-agenda-legend-item"><i class="vct-agc-dot vct-agc-dot-feriado"></i>Feriado</span>'
      + '</div>'

      + CASE WHEN @NEED_PICK = 1
             THEN '<div class="vct-agc-empty" data-vct-agc-empty>'
                + '<span class="vct-agc-empty-icon" data-vct-icon="calendar-search"></span>'
                + '<p>' + CASE WHEN @VE_TODO=1 THEN 'Eleg' + CHAR(237) + ' un consultor para ver su disponibilidad.'
                               ELSE 'No se encontr' + CHAR(243) + ' tu ficha de consultor activa.' END + '</p></div>'
             ELSE '<div class="vct-agenda-view-pane vct-agc-pane" data-vct-agc-pane></div>' END

      + '</section>'
      + '</div>';

    SET @OUTPARAM1 = ISNULL(@HTML_SHELL,'') + @HTML;
END
GO

PRINT 'OK: VCT_MAIN_AGENDA_CONSULTOR creado/actualizado.';
GO

/* ===== Ruteo fallback: ACTION=AGENDA_CONSULTOR -> VCT_MAIN_AGENDA_CONSULTOR =====
   (ademas de la asociacion en el designer). Mismo patron que PROYECTOS. */
DECLARE @D NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.VCT_MAIN_DASHBOARD'));
IF @D IS NULL
    PRINT 'No existe dbo.VCT_MAIN_DASHBOARD (se omite el ruteo fallback).';
ELSE IF CHARINDEX(N'AGENDACONS_RUTEO_V1', @D) > 0
    PRINT 'VCT_MAIN_DASHBOARD ya ruteaba Agenda del consultor. Sin cambios.';
ELSE IF CHARINDEX(N'ACCIONES_RUTEO_V1', @D) = 0
    PRINT 'AVISO: no se encontro ACCIONES_RUTEO_V1; no se toco el ruteo (el designer alcanza).';
ELSE
BEGIN
    SET @D = REPLACE(@D, NCHAR(13)+NCHAR(10), NCHAR(10));
    DECLARE @NL NCHAR(1) = NCHAR(10);
    DECLARE @ANCLA NVARCHAR(MAX) =
        N'    /* ACCIONES_RUTEO_V1: el menu Acciones (ACTION=PLANIFICACION) no tiene paso propio en la plataforma */';
    DECLARE @NUEVO NVARCHAR(MAX) =
        N'    /* AGENDACONS_RUTEO_V1: el menu Agenda del consultor (ACTION=AGENDA_CONSULTOR) no tiene paso propio en la plataforma */' + @NL +
        N'    IF OBJECT_ID(''dbo.VCT_MAIN_AGENDA_CONSULTOR'') IS NOT NULL' + @NL +
        N'       AND EXISTS (SELECT 1 FROM dbo.VCT_BUFFER WITH(NOLOCK) WHERE PAR_KEY = @IPKEYJOB AND UPPER(LTRIM(RTRIM(ISNULL(ACTION,'''')))) = ''AGENDA_CONSULTOR'')' + @NL +
        N'    BEGIN' + @NL +
        N'        EXEC dbo.VCT_MAIN_AGENDA_CONSULTOR @IPKEYJOB = @IPKEYJOB, @FORM_ID = @FORM_ID, @IUNIDAD = @IUNIDAD, @IAGENTE = @IAGENTE,' + @NL +
        N'             @OUTPARAM1 = @OUTPARAM1 OUTPUT, @OUTPARAM2 = @OUTPARAM2 OUTPUT, @OUTPARAM3 = @OUTPARAM3 OUTPUT;' + @NL +
        N'        RETURN;' + @NL +
        N'    END;' + @NL + @NL +
        @ANCLA;

    IF CHARINDEX(@ANCLA, @D) = 0
        PRINT 'AVISO: no se encontro el ancla exacta; no se toco el ruteo (el designer alcanza).';
    ELSE
    BEGIN
        SET @D = REPLACE(@D, @ANCLA, @NUEVO);
        DECLARE @kp INT = CHARINDEX(N'PROCEDURE', @D), @kpre NVARCHAR(60);
        SET @kpre = SUBSTRING(@D, CASE WHEN @kp > 40 THEN @kp - 40 ELSE 1 END, CASE WHEN @kp > 40 THEN 40 ELSE @kp - 1 END);
        IF CHARINDEX(N'OR ALTER', @kpre) = 0 AND CHARINDEX(N'CREATE', @kpre) > 0
            SET @D = STUFF(@D, (CASE WHEN @kp > 40 THEN @kp - 40 ELSE 1 END) + CHARINDEX(N'CREATE', @kpre) - 1, 6, N'ALTER');
        BEGIN TRY
            EXEC sp_executesql @D;
            PRINT 'OK: VCT_MAIN_DASHBOARD rutea ACTION=AGENDA_CONSULTOR a VCT_MAIN_AGENDA_CONSULTOR.';
        END TRY
        BEGIN CATCH
            PRINT 'ERROR al rutear: ' + ERROR_MESSAGE() + ' (el SP quedo creado igual; el designer alcanza).';
        END CATCH;
    END;
END;
GO
