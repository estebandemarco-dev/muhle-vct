/* ====================================================================
   CONSULTOR_SERVICIOS_3_SECCION
   --------------------------------------------------------------------
   Parche a VCT_MAIN_CONSULTORES_V360. INCLUYE todo lo de las normas por
   servicio y AGREGA la seccion/solapa SERVICIOS del consultor (reunion 09/10).
   Reemplaza a CONSULTOR_SERVICIOS_2_NORMAS (correr solo este). Cambios:
     - Modal de Norma: nuevo select Servicio (obligatorio) desde
       VCT_PRM_SERVICIOS, guarda en VCT_CONSULTORES_NORMAS.ID_SERVICIO.
     - Grilla de Normas: columna Servicio (la misma norma puede estar
       hasta 3 veces, una por servicio).
     - Validacion de duplicados: por norma + servicio (no solo norma).
   Generado desde la definicion vigente (db/objetos). El esquema ya tiene
   ID_SERVICIO (ver CONSULTOR_SERVICIOS_1_MODELO). Anda en compat 100 y 140.
   ==================================================================== */
USE [MuhlePROD];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER  PROCEDURE [dbo].[VCT_MAIN_CONSULTORES_V360]
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
    SET NOCOUNT ON; /* MIGRADO_DG: grillas internas con el motor vct-datagrid */
 
    SET @OUTPARAM1='';
    SET @OUTPARAM2='';
    SET @OUTPARAM3='';
 
    DECLARE
        @HTML_SHELL         VARCHAR(MAX)='',
        @RESULTADO_SHELL    VARCHAR(20)='',
        @CAN_VIEW           BIT=0,
        @CAN_EDIT           BIT=0,
        @BTN_BACK           VARCHAR(MAX)='';
 
    /* ============================================================
       1. PERMISOS
       ============================================================ */
    SELECT
        @CAN_VIEW = MAX(CASE WHEN A.Id='CONSULTORES.VIEW' THEN 1 ELSE 0 END),
        @CAN_EDIT = MAX(CASE WHEN A.Id='CONSULTORES.EDIT' THEN 1 ELSE 0 END)
    FROM dbo.Actions A WITH(NOLOCK)
    INNER JOIN dbo.GroupsActions GA WITH(NOLOCK)
        ON GA.ActionId COLLATE DATABASE_DEFAULT =
           A.Id COLLATE DATABASE_DEFAULT
    WHERE UPPER(LTRIM(RTRIM(GA.GroupId))) =
          UPPER(LTRIM(RTRIM(@IUNIDAD)))
      AND A.Id IN ('CONSULTORES.VIEW','CONSULTORES.EDIT');
 
    SET @CAN_VIEW=ISNULL(@CAN_VIEW,0);
    SET @CAN_EDIT=ISNULL(@CAN_EDIT,0);
 
    /* ============================================================
       2. SHELL GENERAL DEL FRAMEWORK
       ------------------------------------------------------------
       Reutiliza Sidebar + Header global ya cerrados.
       La Vista 360 no renderiza una cabecera interna propia.
       ============================================================ */
    BEGIN TRY
        EXEC dbo.VCT_GET_SHELL
             @IUNIDAD            = @IUNIDAD,
             @IAGENTE            = @IAGENTE,
             @FORM_ID            = @FORM_ID,
             @TITLE              = 'Vista 360 de Consultor',
             @SUBTITLE           = 'Información completa del consultor, sus proyectos, gestiones y relaciones.',
             @SEARCH_PLACEHOLDER = '',
             @SHOW_SEARCH        = 0,
             @OSHELL             = @HTML_SHELL OUTPUT,
             @ORESULTADO         = @RESULTADO_SHELL OUTPUT;
    END TRY
    BEGIN CATCH
        SET @HTML_SHELL='';
        SET @RESULTADO_SHELL='ERROR';
    END CATCH;
 
    IF @CAN_VIEW=0
    BEGIN
        SET @OUTPARAM1=ISNULL(@HTML_SHELL,'')+'
<div class="vct-page vct-page-main"
     data-vct-page
     data-vct-sidebar-id="5"
     data-vct-form-id="'+ISNULL(@FORM_ID,'')+'">
    <section class="vct-card">
        <div class="vct-card-body">
            <h2 class="vct-card-title">Acceso restringido</h2>
            <p class="vct-card-subtitle">No posee permisos para visualizar la Vista 360 de Consultores.</p>
        </div>
    </section>
</div>';
        RETURN;
    END;
 
    /* ============================================================
       3. CONSULTOR SELECCIONADO
       ------------------------------------------------------------
       La ficha base se normaliza dinámicamente para no forzar columnas
       opcionales de VCT_CONSULTORES. La única clave requerida es ID.
       ============================================================ */
    DECLARE @ID_CONSULTOR INT=0;
 
    SELECT TOP 1
        @ID_CONSULTOR=ISNULL(IDSELEC01,0)
    FROM dbo.VCT_BUFFER WITH(NOLOCK)
    WHERE PAR_KEY=@IPKEYJOB;
 
    DECLARE
        @NOMBRES              VARCHAR(150)='',
        @APELLIDOS            VARCHAR(150)='',
        @RAZON_SOCIAL         VARCHAR(250)='',
        @TIPO_DOCUMENTO       VARCHAR(50)='',
        @NRO_DOCUMENTO        VARCHAR(50)='',
        @CUIT                 VARCHAR(30)='',
        @LEGAJO               VARCHAR(50)='',
        @CARGO                VARCHAR(100)='',
        @AREA                 VARCHAR(100)='',
        @FORMACION            VARCHAR(100)='',
        @MOVILIDAD            VARCHAR(50)='',
        @FECHA_INGRESO        DATETIME=NULL,
        @FECHA_EGRESO         DATETIME=NULL,
        @INGRESA_SISTEMA      BIT=0,
        @USUARIO_SEGURIDAD    VARCHAR(100)='',
        @ESTADO               VARCHAR(30)='',
        @FECHA_ALTA           DATETIME=NULL;
 
    IF OBJECT_ID('tempdb..#CONSULTOR_BASE') IS NOT NULL DROP TABLE #CONSULTOR_BASE;
    CREATE TABLE #CONSULTOR_BASE
    (
        NOMBRES VARCHAR(150),
        APELLIDOS VARCHAR(150),
        RAZON_SOCIAL VARCHAR(250),
        TIPO_DOCUMENTO VARCHAR(50),
        NRO_DOCUMENTO VARCHAR(50),
        CUIT VARCHAR(30),
        LEGAJO VARCHAR(50),
        CARGO VARCHAR(100),
        AREA VARCHAR(100),
        FORMACION VARCHAR(100),
        MOVILIDAD VARCHAR(50),
        FECHA_INGRESO DATETIME,
        FECHA_EGRESO DATETIME,
        INGRESA_SISTEMA BIT,
        USUARIO_SEGURIDAD VARCHAR(100),
        ESTADO VARCHAR(30),
        FECHA_ALTA DATETIME
    );
 
    IF OBJECT_ID('dbo.VCT_CONSULTORES','U') IS NOT NULL
       AND COL_LENGTH('dbo.VCT_CONSULTORES','ID') IS NOT NULL
    BEGIN
        DECLARE
            @C_NOMBRES NVARCHAR(500)=N'''''',
            @C_APELLIDOS NVARCHAR(500)=N'''''',
            @C_RAZON NVARCHAR(500)=N'''''',
            @C_TDOC NVARCHAR(500)=N'''''',
            @C_NDOC NVARCHAR(500)=N'''''',
            @C_CUIT NVARCHAR(500)=N'''''',
            @C_LEGAJO NVARCHAR(500)=N'''''',
            @C_CARGO NVARCHAR(500)=N'''''',
            @C_AREA NVARCHAR(500)=N'''''',
            @C_FORMACION NVARCHAR(500)=N'''''',
            @C_MOVILIDAD NVARCHAR(500)=N'''''',
            @C_FINGRESO NVARCHAR(500)=N'NULL',
            @C_FEGRESO NVARCHAR(500)=N'NULL',
            @C_INGRESA NVARCHAR(500)=N'0',
            @C_USUARIO NVARCHAR(500)=N'''''',
            @C_ESTADO NVARCHAR(500)=N'''''',
            @C_FALTA NVARCHAR(500)=N'NULL',
            @SQL_BASE NVARCHAR(MAX)=N'';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','NOMBRES') IS NOT NULL
            SET @C_NOMBRES=N'CONVERT(VARCHAR(150),ISNULL(C.NOMBRES,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','NOMBRE') IS NOT NULL
            SET @C_NOMBRES=N'CONVERT(VARCHAR(150),ISNULL(C.NOMBRE,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','APELLIDOS') IS NOT NULL
            SET @C_APELLIDOS=N'CONVERT(VARCHAR(150),ISNULL(C.APELLIDOS,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','APELLIDO') IS NOT NULL
            SET @C_APELLIDOS=N'CONVERT(VARCHAR(150),ISNULL(C.APELLIDO,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','RAZON_SOCIAL') IS NOT NULL
            SET @C_RAZON=N'CONVERT(VARCHAR(250),ISNULL(C.RAZON_SOCIAL,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','NOMBRE_FANTASIA') IS NOT NULL
            SET @C_RAZON=N'CONVERT(VARCHAR(250),ISNULL(C.NOMBRE_FANTASIA,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','TIPO_DOCUMENTO') IS NOT NULL
            SET @C_TDOC=N'CONVERT(VARCHAR(50),ISNULL(C.TIPO_DOCUMENTO,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','NRO_DOCUMENTO') IS NOT NULL
            SET @C_NDOC=N'CONVERT(VARCHAR(50),ISNULL(C.NRO_DOCUMENTO,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','DOCUMENTO') IS NOT NULL
            SET @C_NDOC=N'CONVERT(VARCHAR(50),ISNULL(C.DOCUMENTO,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','DNI') IS NOT NULL
            SET @C_NDOC=N'CONVERT(VARCHAR(50),ISNULL(C.DNI,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','CUIT') IS NOT NULL
            SET @C_CUIT=N'CONVERT(VARCHAR(30),ISNULL(C.CUIT,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','LEGAJO') IS NOT NULL
            SET @C_LEGAJO=N'CONVERT(VARCHAR(50),ISNULL(C.LEGAJO,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','CODIGO') IS NOT NULL
            SET @C_LEGAJO=N'CONVERT(VARCHAR(50),ISNULL(C.CODIGO,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','REFERENCIA') IS NOT NULL
            SET @C_LEGAJO=N'CONVERT(VARCHAR(50),ISNULL(C.REFERENCIA,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','CARGO') IS NOT NULL
            SET @C_CARGO=N'CONVERT(VARCHAR(100),ISNULL(C.CARGO,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','ESPECIALIDAD') IS NOT NULL
            SET @C_CARGO=N'CONVERT(VARCHAR(100),ISNULL(C.ESPECIALIDAD,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','CATEGORIA') IS NOT NULL
            SET @C_CARGO=N'CONVERT(VARCHAR(100),ISNULL(C.CATEGORIA,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','ROL') IS NOT NULL
            SET @C_CARGO=N'CONVERT(VARCHAR(100),ISNULL(C.ROL,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','AREA') IS NOT NULL
            SET @C_AREA=N'CONVERT(VARCHAR(100),ISNULL(C.AREA,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','PROFESION') IS NOT NULL
            SET @C_AREA=N'CONVERT(VARCHAR(100),ISNULL(C.PROFESION,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','FORMACION') IS NOT NULL
            SET @C_FORMACION=N'CONVERT(VARCHAR(100),ISNULL(C.FORMACION,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','TITULO') IS NOT NULL
            SET @C_FORMACION=N'CONVERT(VARCHAR(100),ISNULL(C.TITULO,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','MOVILIDAD') IS NOT NULL
            SET @C_MOVILIDAD=N'CONVERT(VARCHAR(50),ISNULL(C.MOVILIDAD,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_INGRESO') IS NOT NULL
            SET @C_FINGRESO=N'C.FECHA_INGRESO';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_INICIO') IS NOT NULL
            SET @C_FINGRESO=N'C.FECHA_INICIO';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_ALTA') IS NOT NULL
            SET @C_FINGRESO=N'C.FECHA_ALTA';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_EGRESO') IS NOT NULL
            SET @C_FEGRESO=N'C.FECHA_EGRESO';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_BAJA') IS NOT NULL
            SET @C_FEGRESO=N'C.FECHA_BAJA';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','INGRESA_SISTEMA') IS NOT NULL
            SET @C_INGRESA=N'CONVERT(BIT,ISNULL(C.INGRESA_SISTEMA,0))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','ID_USUARIO_SEGURIDAD') IS NOT NULL
            SET @C_USUARIO=N'CONVERT(VARCHAR(100),ISNULL(C.ID_USUARIO_SEGURIDAD,''''))';
        ELSE IF COL_LENGTH('dbo.VCT_CONSULTORES','USUARIO') IS NOT NULL
            SET @C_USUARIO=N'CONVERT(VARCHAR(100),ISNULL(C.USUARIO,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','ESTADO') IS NOT NULL
            SET @C_ESTADO=N'CONVERT(VARCHAR(30),ISNULL(C.ESTADO,''''))';
 
        IF COL_LENGTH('dbo.VCT_CONSULTORES','FECHA_ALTA') IS NOT NULL
            SET @C_FALTA=N'C.FECHA_ALTA';
        ELSE
            SET @C_FALTA=@C_FINGRESO;
 
        SET @SQL_BASE=N'
            INSERT INTO #CONSULTOR_BASE
            (NOMBRES,APELLIDOS,RAZON_SOCIAL,TIPO_DOCUMENTO,NRO_DOCUMENTO,CUIT,
             LEGAJO,CARGO,AREA,FORMACION,MOVILIDAD,FECHA_INGRESO,FECHA_EGRESO,
             INGRESA_SISTEMA,USUARIO_SEGURIDAD,ESTADO,FECHA_ALTA)
            SELECT TOP 1
                '+@C_NOMBRES+N','+@C_APELLIDOS+N','+@C_RAZON+N','+
                @C_TDOC+N','+@C_NDOC+N','+@C_CUIT+N','+@C_LEGAJO+N','+
                @C_CARGO+N','+@C_AREA+N','+@C_FORMACION+N','+@C_MOVILIDAD+N','+
                @C_FINGRESO+N','+@C_FEGRESO+N','+@C_INGRESA+N','+@C_USUARIO+N','+
                @C_ESTADO+N','+@C_FALTA+N'
            FROM dbo.VCT_CONSULTORES C WITH(NOLOCK)
            WHERE C.ID=@PID;';
 
        EXEC sp_executesql @SQL_BASE,N'@PID INT',@PID=@ID_CONSULTOR;
    END;
 
    SELECT TOP 1
        @NOMBRES=ISNULL(NOMBRES,''),
        @APELLIDOS=ISNULL(APELLIDOS,''),
        @RAZON_SOCIAL=ISNULL(RAZON_SOCIAL,''),
        @TIPO_DOCUMENTO=ISNULL(TIPO_DOCUMENTO,''),
        @NRO_DOCUMENTO=ISNULL(NRO_DOCUMENTO,''),
        @CUIT=ISNULL(CUIT,''),
        @LEGAJO=ISNULL(LEGAJO,''),
        @CARGO=ISNULL(CARGO,''),
        @AREA=ISNULL(AREA,''),
        @FORMACION=ISNULL(FORMACION,''),
        @MOVILIDAD=ISNULL(MOVILIDAD,''),
        @FECHA_INGRESO=FECHA_INGRESO,
        @FECHA_EGRESO=FECHA_EGRESO,
        @INGRESA_SISTEMA=ISNULL(INGRESA_SISTEMA,0),
        @USUARIO_SEGURIDAD=LOWER(LTRIM(RTRIM(ISNULL(USUARIO_SEGURIDAD,'')))),
        @ESTADO=UPPER(LTRIM(RTRIM(ISNULL(ESTADO,'')))),
        @FECHA_ALTA=FECHA_ALTA
    FROM #CONSULTOR_BASE;
 
    IF NULLIF(LTRIM(RTRIM(ISNULL(@NOMBRES,'')+ISNULL(@APELLIDOS,'')+ISNULL(@RAZON_SOCIAL,''))),'') IS NULL
    BEGIN
        SET @OUTPARAM1=ISNULL(@HTML_SHELL,'')+'
<div class="vct-page vct-page-main"
     data-vct-page
     data-vct-sidebar-id="5"
     data-vct-form-id="'+ISNULL(@FORM_ID,'')+'">
    <section class="vct-card">
        <div class="vct-card-body">
            <h2 class="vct-card-title">Sin consultor seleccionado</h2>
            <p class="vct-card-subtitle">Volvé al listado de Consultores y elegí uno para abrir su Vista 360.</p>
        </div>
    </section>
</div>';
        RETURN;
    END;
 
    DECLARE @NOMBRE_COMPLETO VARCHAR(320)=
        CASE
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@NOMBRES,'')+ISNULL(@APELLIDOS,''))),'') IS NOT NULL
                THEN LTRIM(RTRIM(
                    ISNULL(@NOMBRES,'')+
                    CASE WHEN @NOMBRES<>'' AND @APELLIDOS<>'' THEN ' ' ELSE '' END+
                    ISNULL(@APELLIDOS,'')
                ))
            ELSE LTRIM(RTRIM(ISNULL(@RAZON_SOCIAL,'')))
        END;
 
    DECLARE @USUARIO_DISPLAY VARCHAR(200)='';
 
    IF NULLIF(@USUARIO_SEGURIDAD,'') IS NOT NULL
    BEGIN
        SELECT TOP 1
            @USUARIO_DISPLAY=
                LOWER(LTRIM(RTRIM(ISNULL(G.UserMemberID,''))))+
                ' ('+LTRIM(RTRIM(ISNULL(G.GroupId,'')))+')'
        FROM dbo.GroupsUserMembers G WITH(NOLOCK)
        WHERE UPPER(LTRIM(RTRIM(ISNULL(G.GroupId,''))))<>'SQUAD'
          AND LOWER(LTRIM(RTRIM(ISNULL(G.UserMemberID,''))))=
              @USUARIO_SEGURIDAD
        ORDER BY G.GroupId;
    END;
 
    IF NULLIF(@USUARIO_DISPLAY,'') IS NULL
        SET @USUARIO_DISPLAY=
            CASE WHEN @INGRESA_SISTEMA=1
                 THEN ISNULL(NULLIF(@USUARIO_SEGURIDAD,''),'-')
                 ELSE '-' END;
 
    /* ============================================================
       4. ESTADO DE FORMS / TABS
       ============================================================ */
    DECLARE
        @VFORM_SAVE       VARCHAR(10)='',
        @VFORM_DELETE     VARCHAR(10)='',
        @VFORM_PRINCIPAL  VARCHAR(10)='',
        @VFORM_FLAG02     VARCHAR(10)='0',
        @VFORM_ENTITY     VARCHAR(30)='',
        @VFORM_ROW_ID     VARCHAR(100)='',
        @VFORM_T11        VARCHAR(1000)='',
        @VFORM_T12        VARCHAR(1000)='',
        @VFORM_T13        VARCHAR(1000)='',
        @VFORM_T14        VARCHAR(1000)='',
        @VFORM_T15        VARCHAR(1000)='',
        @VFORM_T16        VARCHAR(1000)='',
        @VFORM_T17        VARCHAR(2000)='',
        @VFORM_ERROR      VARCHAR(1000)='',
        @VFORM_REOPEN     BIT=0,
        @ACTIVE_TAB       VARCHAR(50)='resumen';
 
    SELECT TOP 1
        @VFORM_SAVE=ISNULL(CONVERT(VARCHAR(10),FLAG01),''),
        @VFORM_DELETE=ISNULL(CONVERT(VARCHAR(10),FLAG03),''),
        @VFORM_PRINCIPAL=ISNULL(CONVERT(VARCHAR(10),FLAG04),''),
        @VFORM_FLAG02=ISNULL(CONVERT(VARCHAR(10),FLAG02),'0'),
        @VFORM_ENTITY=UPPER(LTRIM(RTRIM(ISNULL(TEXTO30,'')))),
        @VFORM_ROW_ID=LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(100),IDSELEC02),''))),
        @VFORM_T11=ISNULL(TEXTO11,''),
        @VFORM_T12=ISNULL(TEXTO12,''),
        @VFORM_T13=ISNULL(TEXTO13,''),
        @VFORM_T14=ISNULL(TEXTO14,''),
        @VFORM_T15=ISNULL(TEXTO15,''),
        @VFORM_T16=ISNULL(TEXTO16,''),
        @VFORM_T17=ISNULL(TEXTO17,''),
        @ACTIVE_TAB=ISNULL(NULLIF(ACTIVE_TAB,''),'resumen')
    FROM dbo.VCT_BUFFER WITH(NOLOCK)
    WHERE PAR_KEY=@IPKEYJOB;
 
    /* Defensa contra buffers historicos con valores concatenados. */
    IF CHARINDEX(',',ISNULL(@VFORM_ENTITY,''))>0
        SET @VFORM_ENTITY=LEFT(@VFORM_ENTITY,CHARINDEX(',',@VFORM_ENTITY)-1);
 
    IF CHARINDEX(',',ISNULL(@VFORM_ROW_ID,''))>0
        SET @VFORM_ROW_ID=LEFT(@VFORM_ROW_ID,CHARINDEX(',',@VFORM_ROW_ID)-1);
 
    IF CHARINDEX(',',ISNULL(@ACTIVE_TAB,''))>0
        SET @ACTIVE_TAB=LEFT(@ACTIVE_TAB,CHARINDEX(',',@ACTIVE_TAB)-1);
 
    SET @VFORM_ENTITY=UPPER(LTRIM(RTRIM(ISNULL(@VFORM_ENTITY,''))));
    SET @VFORM_ROW_ID=LTRIM(RTRIM(ISNULL(@VFORM_ROW_ID,'')));
    SET @ACTIVE_TAB=ISNULL(NULLIF(LTRIM(RTRIM(@ACTIVE_TAB)),''),'resumen');
 
    DECLARE @V360_RESET_TAB BIT=
        CASE
            WHEN @VFORM_SAVE='1'
              OR @VFORM_DELETE='1'
              OR @VFORM_PRINCIPAL='1'
                THEN 0
            ELSE 1
        END;
 
    IF @V360_RESET_TAB=1
    BEGIN
        UPDATE dbo.VCT_BUFFER
           SET IDSELEC02=NULL,
               TEXTO11=NULL,TEXTO12=NULL,TEXTO13=NULL,TEXTO14=NULL,
               TEXTO15=NULL,TEXTO16=NULL,TEXTO17=NULL,TEXTO30=NULL,
               FLAG01=0,FLAG02=0,FLAG03=0,FLAG04=0,
               ACTIVE_TAB='resumen'
         WHERE PAR_KEY=@IPKEYJOB;
 
        SET @VFORM_SAVE='';
        SET @VFORM_DELETE='';
        SET @VFORM_PRINCIPAL='';
        SET @VFORM_FLAG02='0';
        SET @VFORM_ENTITY='';
        SET @VFORM_ROW_ID='';
        SET @VFORM_T11='';
        SET @VFORM_T12='';
        SET @VFORM_T13='';
        SET @VFORM_T14='';
        SET @VFORM_T15='';
        SET @VFORM_T16='';
        SET @VFORM_T17='';
        SET @ACTIVE_TAB='resumen';
    END;
 
    /* ============================================================
       5. MODELO DE RELACION DE DOMICILIOS / TELEFONOS / EMAILS
       ============================================================ */
    DECLARE
        @DOM_MODE  VARCHAR(20)='NONE',
        @TEL_MODE  VARCHAR(20)='NONE',
        @MAIL_MODE VARCHAR(20)='NONE';
 
    IF OBJECT_ID('dbo.VCT_DOMICILIOS','U') IS NOT NULL
    BEGIN
        IF COL_LENGTH('dbo.VCT_DOMICILIOS','TIPO_ENTIDAD') IS NOT NULL
           AND COL_LENGTH('dbo.VCT_DOMICILIOS','ID_ENTIDAD') IS NOT NULL
            SET @DOM_MODE='GENERIC';
        ELSE IF COL_LENGTH('dbo.VCT_DOMICILIOS','IDCONSULTOR') IS NOT NULL
            SET @DOM_MODE='IDCONSULTOR';
        ELSE IF COL_LENGTH('dbo.VCT_DOMICILIOS','ID_CONSULTOR') IS NOT NULL
            SET @DOM_MODE='ID_CONSULTOR';
    END;
 
    IF OBJECT_ID('dbo.VCT_TELEFONOS','U') IS NOT NULL
    BEGIN
        IF COL_LENGTH('dbo.VCT_TELEFONOS','TIPO_ENTIDAD') IS NOT NULL
           AND COL_LENGTH('dbo.VCT_TELEFONOS','ID_ENTIDAD') IS NOT NULL
            SET @TEL_MODE='GENERIC';
        ELSE IF COL_LENGTH('dbo.VCT_TELEFONOS','IDCONSULTOR') IS NOT NULL
            SET @TEL_MODE='IDCONSULTOR';
        ELSE IF COL_LENGTH('dbo.VCT_TELEFONOS','ID_CONSULTOR') IS NOT NULL
            SET @TEL_MODE='ID_CONSULTOR';
    END;
 
    IF OBJECT_ID('dbo.VCT_EMAILS','U') IS NOT NULL
    BEGIN
        IF COL_LENGTH('dbo.VCT_EMAILS','TIPO_ENTIDAD') IS NOT NULL
           AND COL_LENGTH('dbo.VCT_EMAILS','ID_ENTIDAD') IS NOT NULL
            SET @MAIL_MODE='GENERIC';
        ELSE IF COL_LENGTH('dbo.VCT_EMAILS','IDCONSULTOR') IS NOT NULL
            SET @MAIL_MODE='IDCONSULTOR';
        ELSE IF COL_LENGTH('dbo.VCT_EMAILS','ID_CONSULTOR') IS NOT NULL
            SET @MAIL_MODE='ID_CONSULTOR';
    END;
 
    /* Normas: deteccion puntual del modelo actual para alta/edicion. */
    DECLARE
        @NORM_TABLE_CRUD SYSNAME='',
        @NORM_LINK_COL SYSNAME='',
        @NORM_IDNORMA_COL SYSNAME='',
        @NORM_CALIF_COL SYSNAME='',
        @NORM_DESDE_COL SYSNAME='',
        @NORM_OBS_COL SYSNAME='',
        @NORM_SERV_COL SYSNAME='';
 
    IF OBJECT_ID('dbo.VCT_CONSULTORES_NORMAS','U') IS NOT NULL
        SET @NORM_TABLE_CRUD='dbo.VCT_CONSULTORES_NORMAS';
 
    IF @NORM_TABLE_CRUD<>''
    BEGIN
        IF COL_LENGTH(@NORM_TABLE_CRUD,'ID_CONSULTOR') IS NOT NULL SET @NORM_LINK_COL='ID_CONSULTOR';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'IDCONSULTOR') IS NOT NULL SET @NORM_LINK_COL='IDCONSULTOR';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'CONSULTOR_ID') IS NOT NULL SET @NORM_LINK_COL='CONSULTOR_ID';
 
        IF COL_LENGTH(@NORM_TABLE_CRUD,'ID_NORMA') IS NOT NULL SET @NORM_IDNORMA_COL='ID_NORMA';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'IDNORMA') IS NOT NULL SET @NORM_IDNORMA_COL='IDNORMA';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'NORMA_ID') IS NOT NULL SET @NORM_IDNORMA_COL='NORMA_ID';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'ID_NORMAS') IS NOT NULL SET @NORM_IDNORMA_COL='ID_NORMAS';
 
        IF COL_LENGTH(@NORM_TABLE_CRUD,'CALIFICACION') IS NOT NULL SET @NORM_CALIF_COL='CALIFICACION';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'NIVEL') IS NOT NULL SET @NORM_CALIF_COL='NIVEL';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'CATEGORIA') IS NOT NULL SET @NORM_CALIF_COL='CATEGORIA';
 
        IF COL_LENGTH(@NORM_TABLE_CRUD,'FECHA_DESDE') IS NOT NULL SET @NORM_DESDE_COL='FECHA_DESDE';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'DESDE') IS NOT NULL SET @NORM_DESDE_COL='DESDE';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'FECHA_INICIO') IS NOT NULL SET @NORM_DESDE_COL='FECHA_INICIO';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'VIGENCIA_DESDE') IS NOT NULL SET @NORM_DESDE_COL='VIGENCIA_DESDE';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'FECHA_ALTA') IS NOT NULL SET @NORM_DESDE_COL='FECHA_ALTA';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'FECHA') IS NOT NULL SET @NORM_DESDE_COL='FECHA';
 
        IF COL_LENGTH(@NORM_TABLE_CRUD,'OBSERVACIONES') IS NOT NULL SET @NORM_OBS_COL='OBSERVACIONES';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'OBSERVACION') IS NOT NULL SET @NORM_OBS_COL='OBSERVACION';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'COMENTARIOS') IS NOT NULL SET @NORM_OBS_COL='COMENTARIOS';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'COMENTARIO') IS NOT NULL SET @NORM_OBS_COL='COMENTARIO';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'NOTAS') IS NOT NULL SET @NORM_OBS_COL='NOTAS';

        IF COL_LENGTH(@NORM_TABLE_CRUD,'ID_SERVICIO') IS NOT NULL SET @NORM_SERV_COL='ID_SERVICIO';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'IDSERVICIO') IS NOT NULL SET @NORM_SERV_COL='IDSERVICIO';
        ELSE IF COL_LENGTH(@NORM_TABLE_CRUD,'SERVICIO_ID') IS NOT NULL SET @NORM_SERV_COL='SERVICIO_ID';
    END;
 
 
    /* Días mensuales: detección del modelo para alta de historial. */
    DECLARE
        @HIST_TABLE_CRUD SYSNAME='',
        @HIST_LINK_MODE VARCHAR(20)='NONE',
        @HIST_LINK_COL SYSNAME='',
        @HIST_FECHA_COL_CRUD SYSNAME='',
        @HIST_PERIODO_COL_CRUD SYSNAME='',
        @HIST_MES_COL_CRUD SYSNAME='',
        @HIST_ANIO_COL_CRUD SYSNAME='',
        @HIST_DIAS_COL_CRUD SYSNAME='',
        @HIST_OBS_COL_CRUD SYSNAME='';
 
    IF OBJECT_ID('dbo.VCT_CONSULTORES_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_CONSULTORES_HISTORICO_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_HISTORICO_DIAS_CONSULTORES','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_HISTORICO_DIAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTORES_DIAS','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_CONSULTORES_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_DIAS_CONSULTORES','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_DIAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTOR_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_CONSULTOR_HISTORICO_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE_CRUD='dbo.VCT_HISTORICO_DIAS';
 
    IF @HIST_TABLE_CRUD<>''
    BEGIN
        IF COL_LENGTH(@HIST_TABLE_CRUD,'TIPO_ENTIDAD') IS NOT NULL
           AND COL_LENGTH(@HIST_TABLE_CRUD,'ID_ENTIDAD') IS NOT NULL
            SET @HIST_LINK_MODE='GENERIC';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'ID_CONSULTOR') IS NOT NULL
        BEGIN SET @HIST_LINK_MODE='COLUMN'; SET @HIST_LINK_COL='ID_CONSULTOR'; END;
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'IDCONSULTOR') IS NOT NULL
        BEGIN SET @HIST_LINK_MODE='COLUMN'; SET @HIST_LINK_COL='IDCONSULTOR'; END;
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'CONSULTOR_ID') IS NOT NULL
        BEGIN SET @HIST_LINK_MODE='COLUMN'; SET @HIST_LINK_COL='CONSULTOR_ID'; END;
 
        IF COL_LENGTH(@HIST_TABLE_CRUD,'FECHA') IS NOT NULL SET @HIST_FECHA_COL_CRUD='FECHA';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'FECHA_DIA') IS NOT NULL SET @HIST_FECHA_COL_CRUD='FECHA_DIA';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'FECHA_DESDE') IS NOT NULL SET @HIST_FECHA_COL_CRUD='FECHA_DESDE';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'FECHA_TRABAJO') IS NOT NULL SET @HIST_FECHA_COL_CRUD='FECHA_TRABAJO';
 
        IF COL_LENGTH(@HIST_TABLE_CRUD,'PERIODO') IS NOT NULL SET @HIST_PERIODO_COL_CRUD='PERIODO';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'PERIODO_ID') IS NOT NULL SET @HIST_PERIODO_COL_CRUD='PERIODO_ID';
 
        IF COL_LENGTH(@HIST_TABLE_CRUD,'MES') IS NOT NULL SET @HIST_MES_COL_CRUD='MES';
        IF COL_LENGTH(@HIST_TABLE_CRUD,'ANIO') IS NOT NULL SET @HIST_ANIO_COL_CRUD='ANIO';
 
        IF COL_LENGTH(@HIST_TABLE_CRUD,'DIAS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'CANTIDAD_DIAS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='CANTIDAD_DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'CANT_DIAS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='CANT_DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'CANTDIAS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='CANTDIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'DIAS_TRABAJADOS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='DIAS_TRABAJADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'DIAS_ASIGNADOS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='DIAS_ASIGNADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'DIAS_FACTURADOS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='DIAS_FACTURADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'JORNADAS') IS NOT NULL SET @HIST_DIAS_COL_CRUD='JORNADAS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'CANTIDAD') IS NOT NULL SET @HIST_DIAS_COL_CRUD='CANTIDAD';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'VALOR') IS NOT NULL SET @HIST_DIAS_COL_CRUD='VALOR';
 
        IF @HIST_DIAS_COL_CRUD=''
        BEGIN
            SELECT TOP 1 @HIST_DIAS_COL_CRUD=C.name
            FROM sys.columns C
            INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
            WHERE C.object_id=OBJECT_ID(@HIST_TABLE_CRUD)
              AND T.name IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real','money','smallmoney')
              AND UPPER(C.name) NOT IN ('ID','ID_CONSULTOR','IDCONSULTOR','ID_ENTIDAD','IDPROYECTO','ID_PROYECTO')
              AND (UPPER(C.name) LIKE '%DIA%' OR UPPER(C.name) LIKE '%JORN%' OR UPPER(C.name) LIKE '%CANT%')
            ORDER BY CASE WHEN UPPER(C.name) LIKE '%DIA%' THEN 1 WHEN UPPER(C.name) LIKE '%JORN%' THEN 2 ELSE 3 END,C.column_id;
        END;
 
        IF COL_LENGTH(@HIST_TABLE_CRUD,'OBSERVACIONES') IS NOT NULL SET @HIST_OBS_COL_CRUD='OBSERVACIONES';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'OBSERVACION') IS NOT NULL SET @HIST_OBS_COL_CRUD='OBSERVACION';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'COMENTARIOS') IS NOT NULL SET @HIST_OBS_COL_CRUD='COMENTARIOS';
        ELSE IF COL_LENGTH(@HIST_TABLE_CRUD,'NOTAS') IS NOT NULL SET @HIST_OBS_COL_CRUD='NOTAS';
    END;
 
    DECLARE
        @SQL_CRUD NVARCHAR(MAX)='',
        @RC INT=0,
        @NEXISTS INT=0,
        @EXEC_PRINCIPAL VARCHAR(2)='NO',
        @EXEC_T17 VARCHAR(2000)=NULL,
        @EXEC_T13 VARCHAR(1000)=NULL,
        @EXEC_EMAIL VARCHAR(1000)=NULL,
        @EXEC_EMAIL_OBS VARCHAR(1000)=NULL,
        @EXEC_NORM_DATE DATETIME=NULL,
        @EXEC_NORM_ID INT=NULL,
        @EXEC_NORM_TEXT VARCHAR(100)=NULL,
        @EXEC_NORM_CALIF VARCHAR(1000)=NULL,
        @EXEC_NORM_SERV INT=NULL,
        @EXEC_NORM_OBS VARCHAR(2000)=NULL,
        @EXEC_HIST_DATE DATETIME=NULL,
        @EXEC_HIST_DIAS DECIMAL(18,2)=NULL,
        @EXEC_HIST_OBS VARCHAR(2000)=NULL,
        @EXEC_HIST_PERIODO VARCHAR(6)=NULL,
        @EXEC_NOMBRE_COMPLETO VARCHAR(320)='';
 
    SET @EXEC_NOMBRE_COMPLETO=LOWER(ISNULL(@NOMBRE_COMPLETO,''));
 
    /* ============================================================
       6. ELIMINAR
       ============================================================ */
    IF @VFORM_DELETE='1'
    BEGIN
        SET @VFORM_ERROR='';
 
        IF @CAN_EDIT=0
            SET @VFORM_ERROR='No posee permisos para eliminar datos del consultor.';
        ELSE IF NULLIF(@VFORM_ROW_ID,'') IS NULL
            SET @VFORM_ERROR='No se recibió el registro a eliminar.';
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='DOMICILIO'
        BEGIN
            SET @ACTIVE_TAB='domicilio';
 
            IF @DOM_MODE='NONE'
                SET @VFORM_ERROR='La tabla de domicilios todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @DOM_MODE
                    WHEN 'GENERIC' THEN
                        N'DELETE FROM dbo.VCT_DOMICILIOS
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'DELETE FROM dbo.VCT_DOMICILIOS
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'DELETE FROM dbo.VCT_DOMICILIOS
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El domicilio seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='TELEFONO'
        BEGIN
            SET @ACTIVE_TAB='telefonos';
 
            IF @TEL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de teléfonos todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @TEL_MODE
                    WHEN 'GENERIC' THEN
                        N'DELETE FROM dbo.VCT_TELEFONOS
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'DELETE FROM dbo.VCT_TELEFONOS
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'DELETE FROM dbo.VCT_TELEFONOS
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El teléfono seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='EMAIL'
        BEGIN
            SET @ACTIVE_TAB='email';
 
            IF @MAIL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de emails todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @MAIL_MODE
                    WHEN 'GENERIC' THEN
                        N'DELETE FROM dbo.VCT_EMAILS
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'DELETE FROM dbo.VCT_EMAILS
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'DELETE FROM dbo.VCT_EMAILS
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El email seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        SET @VFORM_REOPEN=CASE WHEN @VFORM_ERROR<>'' THEN 1 ELSE 0 END;
 
        UPDATE dbo.VCT_BUFFER
           SET FLAG03=0,
               ACTIVE_TAB=@ACTIVE_TAB
         WHERE PAR_KEY=@IPKEYJOB;
    END;
 
    /* ============================================================
       7. MARCAR PRINCIPAL
       ============================================================ */
    IF @VFORM_PRINCIPAL='1'
    BEGIN
        SET @VFORM_ERROR='';
 
        IF @CAN_EDIT=0
            SET @VFORM_ERROR='No posee permisos para modificar datos del consultor.';
        ELSE IF NULLIF(@VFORM_ROW_ID,'') IS NULL
            SET @VFORM_ERROR='No se recibió el registro a marcar como principal.';
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='DOMICILIO'
        BEGIN
            SET @ACTIVE_TAB='domicilio';
 
            IF @DOM_MODE='NONE'
                SET @VFORM_ERROR='La tabla de domicilios todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @DOM_MODE
                    WHEN 'GENERIC' THEN
                        N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;
                          UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''SI''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                          WHERE IDCONSULTOR=@PID;
                          UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''SI''
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                          WHERE ID_CONSULTOR=@PID;
                          UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''SI''
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El domicilio seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='TELEFONO'
        BEGIN
            SET @ACTIVE_TAB='telefonos';
 
            IF @TEL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de teléfonos todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @TEL_MODE
                    WHEN 'GENERIC' THEN
                        N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;
                          UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''SI''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                          WHERE IDCONSULTOR=@PID;
                          UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''SI''
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                          WHERE ID_CONSULTOR=@PID;
                          UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''SI''
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El teléfono seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='EMAIL'
        BEGIN
            SET @ACTIVE_TAB='email';
 
            IF @MAIL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de emails todavía no posee una relación con Consultores.';
            ELSE
            BEGIN
                SET @SQL_CRUD=
                    CASE @MAIL_MODE
                    WHEN 'GENERIC' THEN
                        N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;
                          UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''SI''
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    WHEN 'IDCONSULTOR' THEN
                        N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                          WHERE IDCONSULTOR=@PID;
                          UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''SI''
                          WHERE IDCONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    ELSE
                        N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                          WHERE ID_CONSULTOR=@PID;
                          UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''SI''
                          WHERE ID_CONSULTOR=@PID
                            AND CONVERT(VARCHAR(100),ID)=@RID;
                          SET @ORC=@@ROWCOUNT;'
                    END;
 
                SET @RC=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@ORC INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@ORC=@RC OUTPUT;
 
                IF @RC=0
                    SET @VFORM_ERROR='El email seleccionado ya no existe o no pertenece al consultor.';
            END;
        END;
 
        SET @VFORM_REOPEN=CASE WHEN @VFORM_ERROR<>'' THEN 1 ELSE 0 END;
 
        UPDATE dbo.VCT_BUFFER
           SET FLAG04=0,
               ACTIVE_TAB=@ACTIVE_TAB
         WHERE PAR_KEY=@IPKEYJOB;
    END;
 
    /* ============================================================
       8. GUARDAR / EDITAR RELACIONADOS
       ============================================================ */
    IF @VFORM_SAVE='1'
    BEGIN
        SET @VFORM_ERROR='';
        SET @EXEC_PRINCIPAL=CASE WHEN @VFORM_FLAG02='1' THEN 'SI' ELSE 'NO' END;
        SET @EXEC_T17=NULLIF(LTRIM(RTRIM(@VFORM_T17)),'');
        SET @EXEC_T13=NULLIF(LTRIM(RTRIM(@VFORM_T13)),'');
        SET @EXEC_EMAIL=LTRIM(RTRIM(ISNULL(@VFORM_T11,'')));
        SET @EXEC_EMAIL_OBS=NULLIF(LTRIM(RTRIM(@VFORM_T12)),'');
 
        IF @CAN_EDIT=0
            SET @VFORM_ERROR='No posee permisos para modificar datos del consultor.';
 
        /* ---------------- DOMICILIO ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='DOMICILIO'
        BEGIN
            SET @ACTIVE_TAB='domicilio';
 
            IF @DOM_MODE='NONE'
                SET @VFORM_ERROR='La tabla de domicilios todavía no posee una relación con Consultores.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL
                SET @VFORM_ERROR='La calle es obligatoria.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T12)),'') IS NULL
                SET @VFORM_ERROR='El número es obligatorio.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T15)),'') IS NULL
                SET @VFORM_ERROR='La localidad es obligatoria.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T16)),'') IS NULL
                SET @VFORM_ERROR='La provincia es obligatoria.';
            ELSE IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.CAT_DATA CD WITH(NOLOCK)
                WHERE CD.PAR_KEY=
                (
                    SELECT TOP 1 PKEY
                    FROM dbo.CAT_TYPE WITH(NOLOCK)
                    WHERE CAT_TYPE_CODE='Provincia'
                )
                  AND CD.CAT_DATA_CODE COLLATE DATABASE_DEFAULT=
                      LTRIM(RTRIM(@VFORM_T16)) COLLATE DATABASE_DEFAULT
            )
                SET @VFORM_ERROR='La provincia seleccionada no es válida.';
 
            IF @VFORM_ERROR=''
            BEGIN TRY
                IF @VFORM_FLAG02='1'
                BEGIN
                    SET @SQL_CRUD=
                        CASE @DOM_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                              WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                              WHERE IDCONSULTOR=@PID;'
                        ELSE
                            N'UPDATE dbo.VCT_DOMICILIOS SET PRINCIPAL=''NO''
                              WHERE ID_CONSULTOR=@PID;'
                        END;
 
                    EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
                END;
 
                IF @VFORM_ROW_ID=''
                BEGIN
                    SET @SQL_CRUD=
                        CASE @DOM_MODE
                        WHEN 'GENERIC' THEN
                            N'INSERT INTO dbo.VCT_DOMICILIOS
                              (TIPO_ENTIDAD,ID_ENTIDAD,CALLE,NRO,PISO,DEPTO,LOCALIDAD,PROVINCIA,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (''CONSULTOR'',@PID,@P11,@P12,@P13,@P14,@P15,@P16,@PPR,@P17);'
                        WHEN 'IDCONSULTOR' THEN
                            N'INSERT INTO dbo.VCT_DOMICILIOS
                              (IDCONSULTOR,CALLE,NRO,PISO,DEPTO,LOCALIDAD,PROVINCIA,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@P12,@P13,@P14,@P15,@P16,@PPR,@P17);'
                        ELSE
                            N'INSERT INTO dbo.VCT_DOMICILIOS
                              (ID_CONSULTOR,CALLE,NRO,PISO,DEPTO,LOCALIDAD,PROVINCIA,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@P12,@P13,@P14,@P15,@P16,@PPR,@P17);'
                        END;
 
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@P11 VARCHAR(1000),@P12 VARCHAR(1000),@P13 VARCHAR(1000),
                           @P14 VARCHAR(1000),@P15 VARCHAR(1000),@P16 VARCHAR(1000),
                           @PPR VARCHAR(2),@P17 VARCHAR(2000)',
                         @PID=@ID_CONSULTOR,@P11=@VFORM_T11,@P12=@VFORM_T12,
                         @P13=@VFORM_T13,@P14=@VFORM_T14,@P15=@VFORM_T15,
                         @P16=@VFORM_T16,
                         @PPR=@EXEC_PRINCIPAL,
                         @P17=@EXEC_T17;
                END
                ELSE
                BEGIN
                    SET @SQL_CRUD=
                        CASE @DOM_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_DOMICILIOS
                                 SET CALLE=@P11,NRO=@P12,PISO=@P13,DEPTO=@P14,
                                     LOCALIDAD=@P15,PROVINCIA=@P16,PRINCIPAL=@PPR,
                                     OBSERVACIONES=@P17
                               WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_DOMICILIOS
                                 SET CALLE=@P11,NRO=@P12,PISO=@P13,DEPTO=@P14,
                                     LOCALIDAD=@P15,PROVINCIA=@P16,PRINCIPAL=@PPR,
                                     OBSERVACIONES=@P17
                               WHERE IDCONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        ELSE
                            N'UPDATE dbo.VCT_DOMICILIOS
                                 SET CALLE=@P11,NRO=@P12,PISO=@P13,DEPTO=@P14,
                                     LOCALIDAD=@P15,PROVINCIA=@P16,PRINCIPAL=@PPR,
                                     OBSERVACIONES=@P17
                               WHERE ID_CONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        END;
 
                    SET @RC=0;
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@RID VARCHAR(100),@P11 VARCHAR(1000),@P12 VARCHAR(1000),
                           @P13 VARCHAR(1000),@P14 VARCHAR(1000),@P15 VARCHAR(1000),
                           @P16 VARCHAR(1000),@PPR VARCHAR(2),@P17 VARCHAR(2000),
                           @ORC INT OUTPUT',
                         @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,
                         @P11=@VFORM_T11,@P12=@VFORM_T12,@P13=@VFORM_T13,
                         @P14=@VFORM_T14,@P15=@VFORM_T15,@P16=@VFORM_T16,
                         @PPR=@EXEC_PRINCIPAL,
                         @P17=@EXEC_T17,
                         @ORC=@RC OUTPUT;
 
                    IF @RC=0
                        SET @VFORM_ERROR='El domicilio a editar ya no existe o no pertenece al consultor.';
                END;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;
 
        /* ---------------- TELEFONO ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='TELEFONO'
        BEGIN
            SET @ACTIVE_TAB='telefonos';
 
            IF @TEL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de teléfonos todavía no posee una relación con Consultores.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL
                SET @VFORM_ERROR='El código de área es obligatorio.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T12)),'') IS NULL
                SET @VFORM_ERROR='El número es obligatorio.';
 
            IF @VFORM_ERROR=''
            BEGIN TRY
                IF @VFORM_FLAG02='1'
                BEGIN
                    SET @SQL_CRUD=
                        CASE @TEL_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                              WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                              WHERE IDCONSULTOR=@PID;'
                        ELSE
                            N'UPDATE dbo.VCT_TELEFONOS SET PRINCIPAL=''NO''
                              WHERE ID_CONSULTOR=@PID;'
                        END;
 
                    EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
                END;
 
                IF @VFORM_ROW_ID=''
                BEGIN
                    SET @SQL_CRUD=
                        CASE @TEL_MODE
                        WHEN 'GENERIC' THEN
                            N'INSERT INTO dbo.VCT_TELEFONOS
                              (TIPO_ENTIDAD,ID_ENTIDAD,CODAREA,NRO,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (''CONSULTOR'',@PID,@P11,@P12,@PPR,@P13);'
                        WHEN 'IDCONSULTOR' THEN
                            N'INSERT INTO dbo.VCT_TELEFONOS
                              (IDCONSULTOR,CODAREA,NRO,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@P12,@PPR,@P13);'
                        ELSE
                            N'INSERT INTO dbo.VCT_TELEFONOS
                              (ID_CONSULTOR,CODAREA,NRO,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@P12,@PPR,@P13);'
                        END;
 
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@P11 VARCHAR(1000),@P12 VARCHAR(1000),
                           @PPR VARCHAR(2),@P13 VARCHAR(1000)',
                         @PID=@ID_CONSULTOR,@P11=@VFORM_T11,@P12=@VFORM_T12,
                         @PPR=@EXEC_PRINCIPAL,
                         @P13=@EXEC_T13;
                END
                ELSE
                BEGIN
                    SET @SQL_CRUD=
                        CASE @TEL_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_TELEFONOS
                                 SET CODAREA=@P11,NRO=@P12,PRINCIPAL=@PPR,OBSERVACIONES=@P13
                               WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_TELEFONOS
                                 SET CODAREA=@P11,NRO=@P12,PRINCIPAL=@PPR,OBSERVACIONES=@P13
                               WHERE IDCONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        ELSE
                            N'UPDATE dbo.VCT_TELEFONOS
                                 SET CODAREA=@P11,NRO=@P12,PRINCIPAL=@PPR,OBSERVACIONES=@P13
                               WHERE ID_CONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        END;
 
                    SET @RC=0;
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@RID VARCHAR(100),@P11 VARCHAR(1000),@P12 VARCHAR(1000),
                           @PPR VARCHAR(2),@P13 VARCHAR(1000),@ORC INT OUTPUT',
                         @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,
                         @P11=@VFORM_T11,@P12=@VFORM_T12,
                         @PPR=@EXEC_PRINCIPAL,
                         @P13=@EXEC_T13,
                         @ORC=@RC OUTPUT;
 
                    IF @RC=0
                        SET @VFORM_ERROR='El teléfono a editar ya no existe o no pertenece al consultor.';
                END;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;
 
        /* ---------------- EMAIL ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='EMAIL'
        BEGIN
            SET @ACTIVE_TAB='email';
 
            IF @MAIL_MODE='NONE'
                SET @VFORM_ERROR='La tabla de emails todavía no posee una relación con Consultores.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL
                SET @VFORM_ERROR='El email es obligatorio.';
            ELSE IF LTRIM(RTRIM(@VFORM_T11)) NOT LIKE '%_@_%._%'
                SET @VFORM_ERROR='El email no tiene un formato válido.';
 
            IF @VFORM_ERROR=''
            BEGIN
                SET @SQL_CRUD=
                    CASE @MAIL_MODE
                    WHEN 'GENERIC' THEN
                        N'SELECT @ON=COUNT(*) FROM dbo.VCT_EMAILS
                          WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                            AND LOWER(LTRIM(RTRIM(ISNULL(EMAIL,''''))))=LOWER(LTRIM(RTRIM(@PEMAIL)))
                            AND (@RID='''' OR CONVERT(VARCHAR(100),ID)<>@RID);'
                    WHEN 'IDCONSULTOR' THEN
                        N'SELECT @ON=COUNT(*) FROM dbo.VCT_EMAILS
                          WHERE IDCONSULTOR=@PID
                            AND LOWER(LTRIM(RTRIM(ISNULL(EMAIL,''''))))=LOWER(LTRIM(RTRIM(@PEMAIL)))
                            AND (@RID='''' OR CONVERT(VARCHAR(100),ID)<>@RID);'
                    ELSE
                        N'SELECT @ON=COUNT(*) FROM dbo.VCT_EMAILS
                          WHERE ID_CONSULTOR=@PID
                            AND LOWER(LTRIM(RTRIM(ISNULL(EMAIL,''''))))=LOWER(LTRIM(RTRIM(@PEMAIL)))
                            AND (@RID='''' OR CONVERT(VARCHAR(100),ID)<>@RID);'
                    END;
 
                SET @NEXISTS=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@RID VARCHAR(100),@PEMAIL VARCHAR(1000),@ON INT OUTPUT',
                     @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,@PEMAIL=@VFORM_T11,
                     @ON=@NEXISTS OUTPUT;
 
                IF @NEXISTS>0
                    SET @VFORM_ERROR='El consultor ya posee ese email registrado.';
            END;
 
            IF @VFORM_ERROR=''
            BEGIN TRY
                IF @VFORM_FLAG02='1'
                BEGIN
                    SET @SQL_CRUD=
                        CASE @MAIL_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                              WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                              WHERE IDCONSULTOR=@PID;'
                        ELSE
                            N'UPDATE dbo.VCT_EMAILS SET PRINCIPAL=''NO''
                              WHERE ID_CONSULTOR=@PID;'
                        END;
 
                    EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
                END;
 
                IF @VFORM_ROW_ID=''
                BEGIN
                    SET @SQL_CRUD=
                        CASE @MAIL_MODE
                        WHEN 'GENERIC' THEN
                            N'INSERT INTO dbo.VCT_EMAILS
                              (TIPO_ENTIDAD,ID_ENTIDAD,EMAIL,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (''CONSULTOR'',@PID,@P11,@PPR,@P12);'
                        WHEN 'IDCONSULTOR' THEN
                            N'INSERT INTO dbo.VCT_EMAILS
                              (IDCONSULTOR,EMAIL,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@PPR,@P12);'
                        ELSE
                            N'INSERT INTO dbo.VCT_EMAILS
                              (ID_CONSULTOR,EMAIL,PRINCIPAL,OBSERVACIONES)
                              VALUES
                              (@PID,@P11,@PPR,@P12);'
                        END;
 
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@P11 VARCHAR(1000),@PPR VARCHAR(2),@P12 VARCHAR(1000)',
                         @PID=@ID_CONSULTOR,@P11=@EXEC_EMAIL,
                         @PPR=@EXEC_PRINCIPAL,
                         @P12=@EXEC_EMAIL_OBS;
                END
                ELSE
                BEGIN
                    SET @SQL_CRUD=
                        CASE @MAIL_MODE
                        WHEN 'GENERIC' THEN
                            N'UPDATE dbo.VCT_EMAILS
                                 SET EMAIL=@P11,PRINCIPAL=@PPR,OBSERVACIONES=@P12
                               WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        WHEN 'IDCONSULTOR' THEN
                            N'UPDATE dbo.VCT_EMAILS
                                 SET EMAIL=@P11,PRINCIPAL=@PPR,OBSERVACIONES=@P12
                               WHERE IDCONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        ELSE
                            N'UPDATE dbo.VCT_EMAILS
                                 SET EMAIL=@P11,PRINCIPAL=@PPR,OBSERVACIONES=@P12
                               WHERE ID_CONSULTOR=@PID
                                 AND CONVERT(VARCHAR(100),ID)=@RID;
                              SET @ORC=@@ROWCOUNT;'
                        END;
 
                    SET @RC=0;
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@RID VARCHAR(100),@P11 VARCHAR(1000),
                           @PPR VARCHAR(2),@P12 VARCHAR(1000),@ORC INT OUTPUT',
                         @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,
                         @P11=@EXEC_EMAIL,
                         @PPR=@EXEC_PRINCIPAL,
                         @P12=@EXEC_EMAIL_OBS,
                         @ORC=@RC OUTPUT;
 
                    IF @RC=0
                        SET @VFORM_ERROR='El email a editar ya no existe o no pertenece al consultor.';
                END;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;
 
        /* ---------------- NORMA ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='NORMA'
        BEGIN
            SET @ACTIVE_TAB='normas';
            SET @EXEC_NORM_DATE=NULL;
            SET @EXEC_NORM_ID=NULL;
            SET @EXEC_NORM_TEXT=LTRIM(RTRIM(ISNULL(@VFORM_T11,'')));
            SET @EXEC_NORM_CALIF=NULLIF(LTRIM(RTRIM(@VFORM_T12)),'');
            SET @EXEC_NORM_SERV=CASE WHEN NULLIF(LTRIM(RTRIM(@VFORM_T15)),'') IS NOT NULL AND LTRIM(RTRIM(@VFORM_T15)) NOT LIKE '%[^0-9]%' THEN CONVERT(INT,LTRIM(RTRIM(@VFORM_T15))) ELSE NULL END;
            SET @EXEC_NORM_OBS=NULLIF(LTRIM(RTRIM(@VFORM_T14)),'');
 
            IF @NORM_TABLE_CRUD=''
                SET @VFORM_ERROR='La tabla VCT_CONSULTORES_NORMAS no existe.';
            ELSE IF @NORM_LINK_COL='' OR @NORM_IDNORMA_COL=''
                SET @VFORM_ERROR='La relación de normas no posee las columnas necesarias para Consultor / Norma.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL
                SET @VFORM_ERROR='La norma es obligatoria.';
            ELSE IF LTRIM(RTRIM(@VFORM_T11)) LIKE '%[^0-9]%'
                SET @VFORM_ERROR='La norma seleccionada no es válida.';
            ELSE IF OBJECT_ID('dbo.VCT_PRM_NORMAS','U') IS NULL
                SET @VFORM_ERROR='No se encontró el maestro VCT_PRM_NORMAS.';
            ELSE
            BEGIN
                SELECT TOP 1 @EXEC_NORM_ID=PN.ID
                FROM dbo.VCT_PRM_NORMAS PN WITH(NOLOCK)
                WHERE CONVERT(VARCHAR(100),PN.ID)=@EXEC_NORM_TEXT;
 
                IF @EXEC_NORM_ID IS NULL
                    SET @VFORM_ERROR='La norma seleccionada no existe.';
            END;
 
            IF @VFORM_ERROR='' AND NULLIF(LTRIM(RTRIM(@VFORM_T13)),'') IS NOT NULL
            BEGIN
                IF ISDATE(@VFORM_T13)=0
                    SET @VFORM_ERROR='La fecha Desde no es válida.';
                ELSE
                    SET @EXEC_NORM_DATE=CONVERT(DATETIME,@VFORM_T13);
            END;

            /* Servicio obligatorio y valido (la calificacion es por norma y servicio). */
            IF @VFORM_ERROR='' AND @NORM_SERV_COL<>''
            BEGIN
                IF @EXEC_NORM_SERV IS NULL
                    SET @VFORM_ERROR='El servicio es obligatorio.';
                ELSE IF OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NOT NULL
                     AND NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_SERVICIOS WHERE ID=@EXEC_NORM_SERV)
                    SET @VFORM_ERROR='El servicio seleccionado no existe.';
            END;
 
            /* Una norma se registra una sola vez por servicio y consultor. */
            IF @VFORM_ERROR=''
            BEGIN
                SET @SQL_CRUD=N'SELECT @ON=COUNT(*) FROM '+@NORM_TABLE_CRUD+N' WITH(NOLOCK)'+
                    N' WHERE '+QUOTENAME(@NORM_LINK_COL)+N'=@PID'+
                    N' AND CONVERT(VARCHAR(100),'+QUOTENAME(@NORM_IDNORMA_COL)+N')=@PNORMA'+
                    CASE WHEN @NORM_SERV_COL<>'' THEN N' AND '+QUOTENAME(@NORM_SERV_COL)+N'=@PSERV' ELSE N'' END+
                    N' AND (@RID='''' OR CONVERT(VARCHAR(100),ID)<>@RID);';
 
                SET @NEXISTS=0;
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@PNORMA VARCHAR(100),@PSERV INT,@RID VARCHAR(100),@ON INT OUTPUT',
                     @PID=@ID_CONSULTOR,@PNORMA=@EXEC_NORM_TEXT,@PSERV=@EXEC_NORM_SERV,@RID=@VFORM_ROW_ID,
                     @ON=@NEXISTS OUTPUT;
 
                IF @NEXISTS>0
                    SET @VFORM_ERROR='El consultor ya tiene esa norma en ese servicio.';
            END;
 
            IF @VFORM_ERROR=''
            BEGIN TRY
                IF @VFORM_ROW_ID=''
                BEGIN
                    DECLARE @NORM_INSERT_COLS NVARCHAR(MAX)=
                        QUOTENAME(@NORM_LINK_COL)+N','+QUOTENAME(@NORM_IDNORMA_COL);
                    DECLARE @NORM_INSERT_VALS NVARCHAR(MAX)=N'@PID,@PNORMA';
 
                    IF @NORM_CALIF_COL<>''
                    BEGIN
                        SET @NORM_INSERT_COLS=@NORM_INSERT_COLS+N','+QUOTENAME(@NORM_CALIF_COL);
                        SET @NORM_INSERT_VALS=@NORM_INSERT_VALS+N',@PCALIF';
                    END;
                    IF @NORM_DESDE_COL<>''
                    BEGIN
                        SET @NORM_INSERT_COLS=@NORM_INSERT_COLS+N','+QUOTENAME(@NORM_DESDE_COL);
                        SET @NORM_INSERT_VALS=@NORM_INSERT_VALS+N',@PDESDE';
                    END;
                    IF @NORM_OBS_COL<>''
                    BEGIN
                        SET @NORM_INSERT_COLS=@NORM_INSERT_COLS+N','+QUOTENAME(@NORM_OBS_COL);
                        SET @NORM_INSERT_VALS=@NORM_INSERT_VALS+N',@POBS';
                    END;
 
                    IF @NORM_SERV_COL<>''
                    BEGIN
                        SET @NORM_INSERT_COLS=@NORM_INSERT_COLS+N','+QUOTENAME(@NORM_SERV_COL);
                        SET @NORM_INSERT_VALS=@NORM_INSERT_VALS+N',@PSERV';
                    END;
                    SET @SQL_CRUD=N'INSERT INTO '+@NORM_TABLE_CRUD+N' ('+@NORM_INSERT_COLS+N') VALUES ('+@NORM_INSERT_VALS+N');';
 
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@PNORMA INT,@PCALIF VARCHAR(1000),@PDESDE DATETIME,@POBS VARCHAR(2000),@PSERV INT',
                         @PID=@ID_CONSULTOR,
                         @PNORMA=@EXEC_NORM_ID,
                         @PCALIF=@EXEC_NORM_CALIF,
                         @PDESDE=@EXEC_NORM_DATE,
                         @POBS=@EXEC_NORM_OBS,
                         @PSERV=@EXEC_NORM_SERV;
                END
                ELSE
                BEGIN
                    DECLARE @NORM_SET NVARCHAR(MAX)=QUOTENAME(@NORM_IDNORMA_COL)+N'=@PNORMA';
 
                    IF @NORM_CALIF_COL<>'' SET @NORM_SET=@NORM_SET+N','+QUOTENAME(@NORM_CALIF_COL)+N'=@PCALIF';
                    IF @NORM_DESDE_COL<>'' SET @NORM_SET=@NORM_SET+N','+QUOTENAME(@NORM_DESDE_COL)+N'=@PDESDE';
                    IF @NORM_OBS_COL<>'' SET @NORM_SET=@NORM_SET+N','+QUOTENAME(@NORM_OBS_COL)+N'=@POBS';
                    IF @NORM_SERV_COL<>'' SET @NORM_SET=@NORM_SET+N','+QUOTENAME(@NORM_SERV_COL)+N'=@PSERV';
 
                    SET @SQL_CRUD=N'UPDATE '+@NORM_TABLE_CRUD+N' SET '+@NORM_SET+
                        N' WHERE '+QUOTENAME(@NORM_LINK_COL)+N'=@PID AND CONVERT(VARCHAR(100),ID)=@RID; SET @ORC=@@ROWCOUNT;';
 
                    SET @RC=0;
                    EXEC sp_executesql
                         @SQL_CRUD,
                         N'@PID INT,@RID VARCHAR(100),@PNORMA INT,@PCALIF VARCHAR(1000),@PDESDE DATETIME,@POBS VARCHAR(2000),@PSERV INT,@ORC INT OUTPUT',
                         @PID=@ID_CONSULTOR,@RID=@VFORM_ROW_ID,
                         @PNORMA=@EXEC_NORM_ID,
                         @PCALIF=@EXEC_NORM_CALIF,
                         @PDESDE=@EXEC_NORM_DATE,
                         @POBS=@EXEC_NORM_OBS,
                         @PSERV=@EXEC_NORM_SERV,
                         @ORC=@RC OUTPUT;
 
                    IF @RC=0
                        SET @VFORM_ERROR='La norma a editar ya no existe o no pertenece al consultor.';
                END;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;
 
        /* ---------------- SERVICIO DEL CONSULTOR (SERVCONS) ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='SERVCONS'
        BEGIN
            SET @ACTIVE_TAB='servicios';
            DECLARE @EXEC_SC_ID INT=NULL, @EXEC_SC_OBS VARCHAR(2000)=NULLIF(LTRIM(RTRIM(@VFORM_T12)),'');

            IF OBJECT_ID('dbo.VCT_CONSULTORES_SERVICIOS','U') IS NULL
                SET @VFORM_ERROR='La tabla VCT_CONSULTORES_SERVICIOS no existe.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL OR LTRIM(RTRIM(@VFORM_T11)) LIKE '%[^0-9]%'
                SET @VFORM_ERROR='El servicio es obligatorio.';
            ELSE IF OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_SERVICIOS WHERE ID=CONVERT(INT,LTRIM(RTRIM(@VFORM_T11))))
                SET @VFORM_ERROR='El servicio seleccionado no existe.';
            ELSE
                SET @EXEC_SC_ID=CONVERT(INT,LTRIM(RTRIM(@VFORM_T11)));

            IF @VFORM_ERROR='' AND EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES_SERVICIOS WHERE ID_CONSULTOR=@ID_CONSULTOR AND ID_SERVICIO=@EXEC_SC_ID AND (@VFORM_ROW_ID='' OR CONVERT(VARCHAR(100),ID)<>@VFORM_ROW_ID))
                SET @VFORM_ERROR='El consultor ya tiene ese servicio.';

            IF @VFORM_ERROR=''
            BEGIN TRY
                IF @VFORM_ROW_ID=''
                    INSERT INTO dbo.VCT_CONSULTORES_SERVICIOS (ID_CONSULTOR,ID_SERVICIO,OBSERVACIONES,FECHA_ALTA,USUARIO_ALTA)
                    VALUES (@ID_CONSULTOR,@EXEC_SC_ID,@EXEC_SC_OBS,GETDATE(),@IAGENTE);
                ELSE
                BEGIN
                    UPDATE dbo.VCT_CONSULTORES_SERVICIOS SET ID_SERVICIO=@EXEC_SC_ID,OBSERVACIONES=@EXEC_SC_OBS,FECHA_UPD=GETDATE(),USUARIO_UPD=@IAGENTE
                    WHERE ID_CONSULTOR=@ID_CONSULTOR AND CONVERT(VARCHAR(100),ID)=@VFORM_ROW_ID;
                    IF @@ROWCOUNT=0 SET @VFORM_ERROR='El servicio a editar ya no existe o no pertenece al consultor.';
                END;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;

        /* ---------------- DIAS MENSUALES ---------------- */
        IF @VFORM_ERROR='' AND @VFORM_ENTITY='HIST_DIAS'
        BEGIN
            SET @ACTIVE_TAB='dias';
            SET @EXEC_HIST_DATE=NULL;
            SET @EXEC_HIST_DIAS=NULL;
            SET @EXEC_HIST_OBS=NULLIF(LTRIM(RTRIM(@VFORM_T13)),'');
            SET @EXEC_HIST_PERIODO=NULL;
 
            IF @HIST_TABLE_CRUD=''
                SET @VFORM_ERROR='No se encontró una tabla de histórico de días para Consultores.';
            ELSE IF @HIST_LINK_MODE='NONE'
                SET @VFORM_ERROR='La tabla de histórico de días no posee relación con Consultores.';
            ELSE IF @HIST_DIAS_COL_CRUD=''
                SET @VFORM_ERROR='No se encontró la columna de días en el histórico.';
            ELSE IF @HIST_FECHA_COL_CRUD='' AND @HIST_PERIODO_COL_CRUD='' AND (@HIST_MES_COL_CRUD='' OR @HIST_ANIO_COL_CRUD='')
                SET @VFORM_ERROR='El histórico no posee una columna de fecha o período compatible.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T11)),'') IS NULL OR ISDATE(@VFORM_T11)=0
                SET @VFORM_ERROR='El mes es obligatorio y debe ser una fecha válida.';
            ELSE IF NULLIF(LTRIM(RTRIM(@VFORM_T12)),'') IS NULL
                SET @VFORM_ERROR='La cantidad de días es obligatoria.';
            ELSE IF ISNUMERIC(REPLACE(LTRIM(RTRIM(@VFORM_T12)),',','.'))=0
                SET @VFORM_ERROR='La cantidad de días debe ser numérica.';
 
            IF @VFORM_ERROR=''
            BEGIN
                SET @EXEC_HIST_DATE=CONVERT(DATETIME,@VFORM_T11);
                SET @EXEC_HIST_DATE=DATEADD(MONTH,DATEDIFF(MONTH,0,@EXEC_HIST_DATE),0);
                SET @EXEC_HIST_DIAS=CONVERT(DECIMAL(18,2),REPLACE(LTRIM(RTRIM(@VFORM_T12)),',','.'));
                SET @EXEC_HIST_PERIODO=CONVERT(VARCHAR(6),@EXEC_HIST_DATE,112);
 
                IF @EXEC_HIST_DIAS<0
                    SET @VFORM_ERROR='La cantidad de días no puede ser negativa.';
            END;
 
            IF @VFORM_ERROR=''
            BEGIN TRY
                DECLARE @HIST_INSERT_COLS NVARCHAR(MAX)='';
                DECLARE @HIST_INSERT_VALS NVARCHAR(MAX)='';
 
                IF @HIST_LINK_MODE='GENERIC'
                BEGIN
                    SET @HIST_INSERT_COLS=N'[TIPO_ENTIDAD],[ID_ENTIDAD]';
                    SET @HIST_INSERT_VALS=N'''CONSULTOR'',@PID';
                END
                ELSE
                BEGIN
                    SET @HIST_INSERT_COLS=QUOTENAME(@HIST_LINK_COL);
                    SET @HIST_INSERT_VALS=N'@PID';
                END;
 
                IF @HIST_FECHA_COL_CRUD<>''
                BEGIN
                    SET @HIST_INSERT_COLS=@HIST_INSERT_COLS+N','+QUOTENAME(@HIST_FECHA_COL_CRUD);
                    SET @HIST_INSERT_VALS=@HIST_INSERT_VALS+N',@PFECHA';
                END;
 
                IF @HIST_PERIODO_COL_CRUD<>''
                BEGIN
                    SET @HIST_INSERT_COLS=@HIST_INSERT_COLS+N','+QUOTENAME(@HIST_PERIODO_COL_CRUD);
                    SET @HIST_INSERT_VALS=@HIST_INSERT_VALS+N',@PPER';
                END;
 
                IF @HIST_MES_COL_CRUD<>'' AND @HIST_ANIO_COL_CRUD<>''
                BEGIN
                    SET @HIST_INSERT_COLS=@HIST_INSERT_COLS+N','+QUOTENAME(@HIST_MES_COL_CRUD)+N','+QUOTENAME(@HIST_ANIO_COL_CRUD);
                    SET @HIST_INSERT_VALS=@HIST_INSERT_VALS+N',MONTH(@PFECHA),YEAR(@PFECHA)';
                END;
 
                SET @HIST_INSERT_COLS=@HIST_INSERT_COLS+N','+QUOTENAME(@HIST_DIAS_COL_CRUD);
                SET @HIST_INSERT_VALS=@HIST_INSERT_VALS+N',@PDIAS';
 
                IF @HIST_OBS_COL_CRUD<>''
                BEGIN
                    SET @HIST_INSERT_COLS=@HIST_INSERT_COLS+N','+QUOTENAME(@HIST_OBS_COL_CRUD);
                    SET @HIST_INSERT_VALS=@HIST_INSERT_VALS+N',@POBS';
                END;
 
                SET @SQL_CRUD=N'INSERT INTO '+@HIST_TABLE_CRUD+N' ('+@HIST_INSERT_COLS+N') VALUES ('+@HIST_INSERT_VALS+N');';
 
                EXEC sp_executesql
                     @SQL_CRUD,
                     N'@PID INT,@PFECHA DATETIME,@PPER VARCHAR(6),@PDIAS DECIMAL(18,2),@POBS VARCHAR(2000)',
                     @PID=@ID_CONSULTOR,@PFECHA=@EXEC_HIST_DATE,@PPER=@EXEC_HIST_PERIODO,@PDIAS=@EXEC_HIST_DIAS,@POBS=@EXEC_HIST_OBS;
            END TRY
            BEGIN CATCH
                SET @VFORM_ERROR=ERROR_MESSAGE();
            END CATCH;
        END;
 
        SET @VFORM_REOPEN=CASE WHEN @VFORM_ERROR<>'' THEN 1 ELSE 0 END;
 
        IF @VFORM_ERROR<>''
        BEGIN
            UPDATE dbo.VCT_BUFFER
               SET FLAG01=0,FLAG03=0,FLAG04=0,ACTIVE_TAB=@ACTIVE_TAB
             WHERE PAR_KEY=@IPKEYJOB;
        END
        ELSE
        BEGIN
            UPDATE dbo.VCT_BUFFER
               SET IDSELEC02=NULL,
                   TEXTO11=NULL,TEXTO12=NULL,TEXTO13=NULL,TEXTO14=NULL,
                   TEXTO15=NULL,TEXTO16=NULL,TEXTO17=NULL,TEXTO30=NULL,
                   FLAG01=0,FLAG02=0,FLAG03=0,FLAG04=0,
                   ACTIVE_TAB=@ACTIVE_TAB
             WHERE PAR_KEY=@IPKEYJOB;
        END;
    END;
 
    /* ============================================================
       9. NORMALIZACION DE DOMICILIOS / TELEFONOS / EMAILS
       ============================================================ */
    IF OBJECT_ID('tempdb..#DOMICILIOS360') IS NOT NULL DROP TABLE #DOMICILIOS360;
    CREATE TABLE #DOMICILIOS360
    (
        ID INT,
        CALLE VARCHAR(300),
        NRO VARCHAR(50),
        PISO VARCHAR(50),
        DEPTO VARCHAR(50),
        LOCALIDAD VARCHAR(100),
        PROVINCIA VARCHAR(100),
        PRINCIPAL VARCHAR(10),
        OBSERVACIONES VARCHAR(1000)
    );
 
    IF OBJECT_ID('tempdb..#TELEFONOS360') IS NOT NULL DROP TABLE #TELEFONOS360;
    CREATE TABLE #TELEFONOS360
    (
        ID INT,
        CODAREA VARCHAR(50),
        NRO VARCHAR(50),
        PRINCIPAL VARCHAR(10),
        OBSERVACIONES VARCHAR(1000)
    );
 
    IF OBJECT_ID('tempdb..#EMAILS360') IS NOT NULL DROP TABLE #EMAILS360;
    CREATE TABLE #EMAILS360
    (
        ID INT,
        EMAIL VARCHAR(300),
        PRINCIPAL VARCHAR(10),
        OBSERVACIONES VARCHAR(1000)
    );
 
    IF @DOM_MODE<>'NONE'
    BEGIN
        SET @SQL_CRUD=
            CASE @DOM_MODE
            WHEN 'GENERIC' THEN
                N'INSERT INTO #DOMICILIOS360
                  SELECT ID,CONVERT(VARCHAR(300),CALLE),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(50),PISO),CONVERT(VARCHAR(50),DEPTO),
                         CONVERT(VARCHAR(100),LOCALIDAD),CONVERT(VARCHAR(100),PROVINCIA),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_DOMICILIOS WITH(NOLOCK)
                   WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
            WHEN 'IDCONSULTOR' THEN
                N'INSERT INTO #DOMICILIOS360
                  SELECT ID,CONVERT(VARCHAR(300),CALLE),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(50),PISO),CONVERT(VARCHAR(50),DEPTO),
                         CONVERT(VARCHAR(100),LOCALIDAD),CONVERT(VARCHAR(100),PROVINCIA),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_DOMICILIOS WITH(NOLOCK)
                   WHERE IDCONSULTOR=@PID;'
            ELSE
                N'INSERT INTO #DOMICILIOS360
                  SELECT ID,CONVERT(VARCHAR(300),CALLE),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(50),PISO),CONVERT(VARCHAR(50),DEPTO),
                         CONVERT(VARCHAR(100),LOCALIDAD),CONVERT(VARCHAR(100),PROVINCIA),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_DOMICILIOS WITH(NOLOCK)
                   WHERE ID_CONSULTOR=@PID;'
            END;
 
        EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
    END;
 
    IF @TEL_MODE<>'NONE'
    BEGIN
        SET @SQL_CRUD=
            CASE @TEL_MODE
            WHEN 'GENERIC' THEN
                N'INSERT INTO #TELEFONOS360
                  SELECT ID,CONVERT(VARCHAR(50),CODAREA),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_TELEFONOS WITH(NOLOCK)
                   WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
            WHEN 'IDCONSULTOR' THEN
                N'INSERT INTO #TELEFONOS360
                  SELECT ID,CONVERT(VARCHAR(50),CODAREA),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_TELEFONOS WITH(NOLOCK)
                   WHERE IDCONSULTOR=@PID;'
            ELSE
                N'INSERT INTO #TELEFONOS360
                  SELECT ID,CONVERT(VARCHAR(50),CODAREA),CONVERT(VARCHAR(50),NRO),
                         CONVERT(VARCHAR(10),PRINCIPAL),CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_TELEFONOS WITH(NOLOCK)
                   WHERE ID_CONSULTOR=@PID;'
            END;
 
        EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
    END;
 
    IF @MAIL_MODE<>'NONE'
    BEGIN
        SET @SQL_CRUD=
            CASE @MAIL_MODE
            WHEN 'GENERIC' THEN
                N'INSERT INTO #EMAILS360
                  SELECT ID,CONVERT(VARCHAR(300),EMAIL),CONVERT(VARCHAR(10),PRINCIPAL),
                         CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_EMAILS WITH(NOLOCK)
                   WHERE TIPO_ENTIDAD=''CONSULTOR'' AND ID_ENTIDAD=@PID;'
            WHEN 'IDCONSULTOR' THEN
                N'INSERT INTO #EMAILS360
                  SELECT ID,CONVERT(VARCHAR(300),EMAIL),CONVERT(VARCHAR(10),PRINCIPAL),
                         CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_EMAILS WITH(NOLOCK)
                   WHERE IDCONSULTOR=@PID;'
            ELSE
                N'INSERT INTO #EMAILS360
                  SELECT ID,CONVERT(VARCHAR(300),EMAIL),CONVERT(VARCHAR(10),PRINCIPAL),
                         CONVERT(VARCHAR(1000),OBSERVACIONES)
                    FROM dbo.VCT_EMAILS WITH(NOLOCK)
                   WHERE ID_CONSULTOR=@PID;'
            END;
 
        EXEC sp_executesql @SQL_CRUD,N'@PID INT',@PID=@ID_CONSULTOR;
    END;
 
    DECLARE
        @DomiciliosCount INT=0,
        @TelefonosCount INT=0,
        @EmailsCount INT=0;
 
    SELECT @DomiciliosCount=COUNT(*) FROM #DOMICILIOS360;
    SELECT @TelefonosCount=COUNT(*) FROM #TELEFONOS360;
    SELECT @EmailsCount=COUNT(*) FROM #EMAILS360;
 
    /* ============================================================
       10. PROYECTOS RELACIONADOS AL CONSULTOR - RELACION CANONICA
       ------------------------------------------------------------
       Se consulta dbo.VCT_VW_PROYECTOS_ACTORES.
 
       La vista prioriza evidencia:
         1. Equipo del proyecto
         2. Visitas
         3. Participacion en gestiones
 
       Esto evita que una V360 dependa de una sola tabla historica.
       ============================================================ */
    IF OBJECT_ID('tempdb..#PROYECTOS360') IS NOT NULL DROP TABLE #PROYECTOS360;
 
    CREATE TABLE #PROYECTOS360
    (
        ID INT,
        ID_CLIENTE INT,
        CODIGO VARCHAR(100),
        NOMBRE VARCHAR(300),
        REFERENCIA VARCHAR(300),
        CLIENTE_NOMBRE VARCHAR(300),
        ESTADO_CODIGO VARCHAR(50),
        ESTADO VARCHAR(100),
        FECHA_INICIO DATETIME,
        FECHA_FIN DATETIME,
        PORCENTAJE_AVANCE INT,
        RELACION VARCHAR(150)
    );
 
    INSERT INTO #PROYECTOS360
    (
        ID,
        ID_CLIENTE,
        CODIGO,
        NOMBRE,
        REFERENCIA,
        CLIENTE_NOMBRE,
        ESTADO_CODIGO,
        ESTADO,
        FECHA_INICIO,
        FECHA_FIN,
        PORCENTAJE_AVANCE,
        RELACION
    )
    SELECT
        P.ID,
        P.IDCLIENTE,
        CONVERT(VARCHAR(100),P.CODIGO),
        CONVERT(VARCHAR(300),P.NOMBRE),
        CONVERT(VARCHAR(300),P.REFERENCIA),
        CONVERT(VARCHAR(300),ISNULL(NULLIF(C.RAZON_SOCIAL,''),'Sin cliente')),
        PE.CODIGO,
        PE.DESCRIPCION,
        P.FECHA_INICIO,
        P.FECHA_FIN,
        ISNULL(P.PORCENTAJE_AVANCE,0),
 
        ISNULL
        (
            (
                SELECT TOP 1 A.RELACION
                FROM dbo.VCT_VW_PROYECTOS_ACTORES A WITH(NOLOCK)
                WHERE A.ID_PROYECTO=P.ID
                  AND A.TIPO_ENTIDAD='CONSULTOR'
                  AND A.ID_ENTIDAD=@ID_CONSULTOR
                ORDER BY A.PRIORIDAD_FUENTE,A.RELACION
            ),
            'Consultor'
        ) AS RELACION
 
    FROM dbo.VCT_PROYECTOS P WITH(NOLOCK)
 
    LEFT JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS PE WITH(NOLOCK)
        ON PE.ID=P.ID_ESTADO
 
    LEFT JOIN dbo.VCT_CLIENTES C WITH(NOLOCK)
        ON C.ID=P.IDCLIENTE
 
    WHERE EXISTS
    (
        SELECT 1
        FROM dbo.VCT_VW_PROYECTOS_ACTORES A WITH(NOLOCK)
        WHERE A.ID_PROYECTO=P.ID
          AND A.TIPO_ENTIDAD='CONSULTOR'
          AND A.ID_ENTIDAD=@ID_CONSULTOR
    );
 
    DECLARE
        @ProyectosCount INT=0,
        @ProyectosEnCurso INT=0;
 
    SELECT
        @ProyectosCount=COUNT(*),
        @ProyectosEnCurso=ISNULL
        (
            SUM(CASE WHEN ESTADO_CODIGO='ENCURSO' THEN 1 ELSE 0 END),
            0
        )
    FROM #PROYECTOS360;
 
    /* ============================================================
       11. GESTIONES DEL CONSULTOR - RELACION CANONICA
       ------------------------------------------------------------
       La gestion pertenece al consultor cuando figura como
       participante activo. El responsable visible se resuelve mediante
       dbo.VCT_VW_GESTIONES_RESPONSABLES.
       ============================================================ */
    IF OBJECT_ID('tempdb..#GESTIONES360') IS NOT NULL DROP TABLE #GESTIONES360;
 
    CREATE TABLE #GESTIONES360
    (
        ID INT,
        FECHA DATETIME,
        PROYECTO_CODIGO VARCHAR(100),
        PROYECTO_NOMBRE VARCHAR(300),
        PROYECTO_REFERENCIA VARCHAR(300),
        CLIENTE_NOMBRE VARCHAR(300),
        TITULO VARCHAR(300),
        TIPO VARCHAR(200),
        SUBTIPO VARCHAR(200),
        RESULTADO VARCHAR(300),
        RESPONSABLE VARCHAR(320),
        VENCIMIENTO DATETIME,
        ESTADO_CODIGO VARCHAR(50),
        ESTADO VARCHAR(100),
        ES_FINAL BIT
    );
 
    INSERT INTO #GESTIONES360
    (
        ID,
        FECHA,
        PROYECTO_CODIGO,
        PROYECTO_NOMBRE,
        PROYECTO_REFERENCIA,
        CLIENTE_NOMBRE,
        TITULO,
        TIPO,
        SUBTIPO,
        RESULTADO,
        RESPONSABLE,
        VENCIMIENTO,
        ESTADO_CODIGO,
        ESTADO,
        ES_FINAL
    )
    SELECT
        G.ID,
        ISNULL(G.FECHA_CIERRE,ISNULL(G.FECHA_INICIO,G.FECHA_CREACION)),
        CONVERT(VARCHAR(100),P.CODIGO),
        CONVERT(VARCHAR(300),P.NOMBRE),
        CONVERT(VARCHAR(300),P.REFERENCIA),
        CONVERT(VARCHAR(300),ISNULL(NULLIF(C.RAZON_SOCIAL,''),'Sin cliente')),
        CONVERT(VARCHAR(300),ISNULL(NULLIF(G.TITULO,''),'Gestión')),
        CONVERT(VARCHAR(200),ISNULL(T.DESCRIPCION,ISNULL(T.CODIGO,''))),
        CONVERT(VARCHAR(200),ISNULL(ST.DESCRIPCION,ISNULL(ST.CODIGO,''))),
        CONVERT(VARCHAR(300),ISNULL(RS.DESCRIPCION,ISNULL(RS.CODIGO,''))),
        CONVERT(VARCHAR(320),ISNULL(GR.NOMBRE,'-')),
        G.FECHA_VENCIMIENTO,
        GE.CODIGO,
        GE.DESCRIPCION,
        ISNULL(GE.ES_FINAL,0)
 
    FROM dbo.VCT_GESTIONES G WITH(NOLOCK)
 
    LEFT JOIN dbo.VCT_PROYECTOS P WITH(NOLOCK)
        ON P.ID=G.ID_PROYECTO
 
    LEFT JOIN dbo.VCT_CLIENTES C WITH(NOLOCK)
        ON C.ID=P.IDCLIENTE
 
    LEFT JOIN dbo.VCT_PRM_GESTIONES_TIPOS T WITH(NOLOCK)
        ON T.ID=G.ID_TIPO
 
    LEFT JOIN dbo.VCT_PRM_GESTIONES_SUBTIPOS ST WITH(NOLOCK)
        ON ST.ID=G.ID_SUBTIPO
 
    LEFT JOIN dbo.VCT_PRM_GESTIONES_RESULTADOS RS WITH(NOLOCK)
        ON RS.ID=G.ID_RESULTADO
 
    LEFT JOIN dbo.VCT_PRM_GESTIONES_ESTADOS GE WITH(NOLOCK)
        ON GE.ID=G.ID_ESTADO
 
    LEFT JOIN dbo.VCT_VW_GESTIONES_RESPONSABLES GR WITH(NOLOCK)
        ON GR.ID_GESTION=G.ID
 
    WHERE EXISTS
    (
        SELECT 1
        FROM dbo.VCT_GESTIONES_PARTICIPANTES GP WITH(NOLOCK)
        WHERE GP.ID_GESTION=G.ID
          AND GP.TIPO_ENTIDAD='CONSULTOR'
          AND GP.ID_ENTIDAD=@ID_CONSULTOR
          AND GP.ESTADO='ACTIVO'
    );
 
    DECLARE
        @GestionesCount INT=0,
        @GestionesAnio INT=0,
        @UltimaGestionFecha DATETIME=NULL,
        @UltimaGestionFechaTxt VARCHAR(20)='-',
        @DocumentosCount INT=0;
 
    SELECT
        @GestionesCount=COUNT(*),
        @GestionesAnio=ISNULL
        (
            SUM
            (
                CASE
                    WHEN FECHA IS NOT NULL
                     AND YEAR(FECHA)=YEAR(GETDATE())
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        @UltimaGestionFecha=MAX(FECHA)
    FROM #GESTIONES360;
 
    IF @UltimaGestionFecha IS NOT NULL
        SET @UltimaGestionFechaTxt=CONVERT(VARCHAR(10),@UltimaGestionFecha,103);
 
    /* ============================================================
       11.B NORMALIZACION DE NORMAS / HISTORICO / DOCUMENTOS / NOTAS
       ------------------------------------------------------------
       Estas solapas son de lectura relacionada. Se detectan las tablas
       habituales y el modelo generico TIPO_ENTIDAD + ID_ENTIDAD, o bien
       ID_CONSULTOR / IDCONSULTOR. Si una tabla no existe, la V360 sigue
       funcionando y muestra la grilla vacia correspondiente.
       ============================================================ */
 
    /* ---------------- NORMAS ---------------- */
    IF OBJECT_ID('tempdb..#NORMAS360') IS NOT NULL DROP TABLE #NORMAS360;
    CREATE TABLE #NORMAS360
    (
        ID INT,
        ID_NORMA INT,
        SERVICIO VARCHAR(120),
        CODIGO VARCHAR(100),
        NOMBRE VARCHAR(300),
        ESTADO VARCHAR(80),
        FECHA_DESDE DATETIME,
        FECHA_HASTA DATETIME,
        OBSERVACIONES VARCHAR(1000)
    );
 
    DECLARE
        @NORMA_TABLE SYSNAME='',
        @NORMA_MASTER SYSNAME='',
        @NORMA_ESTADO_LABEL VARCHAR(40)='Estado';
 
    IF OBJECT_ID('dbo.VCT_CONSULTORES_NORMAS','U') IS NOT NULL SET @NORMA_TABLE='dbo.VCT_CONSULTORES_NORMAS';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTOR_NORMAS','U') IS NOT NULL SET @NORMA_TABLE='dbo.VCT_CONSULTOR_NORMAS';
    ELSE IF OBJECT_ID('dbo.VCT_NORMAS_CONSULTORES','U') IS NOT NULL SET @NORMA_TABLE='dbo.VCT_NORMAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_NORMAS','U') IS NOT NULL SET @NORMA_TABLE='dbo.VCT_NORMAS';
 
    IF OBJECT_ID('dbo.VCT_PRM_NORMAS','U') IS NOT NULL SET @NORMA_MASTER='dbo.VCT_PRM_NORMAS';
    ELSE IF OBJECT_ID('dbo.VCT_NORMAS','U') IS NOT NULL SET @NORMA_MASTER='dbo.VCT_NORMAS';
    ELSE IF OBJECT_ID('dbo.VCT_NORMA','U') IS NOT NULL SET @NORMA_MASTER='dbo.VCT_NORMA';
 
    IF @NORMA_TABLE<>'' AND COL_LENGTH(@NORMA_TABLE,'ID') IS NOT NULL
    BEGIN
        DECLARE
            @NFILTER NVARCHAR(MAX)=N'1=0',
            @NJOIN NVARCHAR(MAX)=N'',
            @NCOD NVARCHAR(500)=N'''''',
            @NNOM NVARCHAR(500)=N'''''',
            @NEST NVARCHAR(500)=N'''''',
            @NFD NVARCHAR(500)=N'NULL',
            @NFH NVARCHAR(500)=N'NULL',
            @NOBS NVARCHAR(500)=N'''''',
            @NIDNORMA_COL SYSNAME='',
            @NIDNORMA_EXPR NVARCHAR(500)=N'NULL',
            @NSERV NVARCHAR(500)=N'NULL',
            @NFALLBACK_COL SYSNAME='',
            @SQL_NORMA NVARCHAR(MAX)=N'';
 
        IF COL_LENGTH(@NORMA_TABLE,'TIPO_ENTIDAD') IS NOT NULL AND COL_LENGTH(@NORMA_TABLE,'ID_ENTIDAD') IS NOT NULL
            SET @NFILTER=N'N.TIPO_ENTIDAD=''CONSULTOR'' AND N.ID_ENTIDAD=@PID';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'ID_CONSULTOR') IS NOT NULL
            SET @NFILTER=N'N.ID_CONSULTOR=@PID';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'IDCONSULTOR') IS NOT NULL
            SET @NFILTER=N'N.IDCONSULTOR=@PID';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'CONSULTOR_ID') IS NOT NULL
            SET @NFILTER=N'N.CONSULTOR_ID=@PID';
 
        IF COL_LENGTH(@NORMA_TABLE,'IDNORMA') IS NOT NULL SET @NIDNORMA_COL='IDNORMA';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'ID_NORMA') IS NOT NULL SET @NIDNORMA_COL='ID_NORMA';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'NORMA_ID') IS NOT NULL SET @NIDNORMA_COL='NORMA_ID';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'ID_NORMAS') IS NOT NULL SET @NIDNORMA_COL='ID_NORMAS';
 
        IF @NIDNORMA_COL<>''
            SET @NIDNORMA_EXPR=N'CONVERT(INT,N.'+QUOTENAME(@NIDNORMA_COL)+N')';
 
        IF @NORMA_TABLE<>@NORMA_MASTER
           AND @NORMA_MASTER<>''
           AND @NIDNORMA_COL<>''
           AND COL_LENGTH(@NORMA_MASTER,'ID') IS NOT NULL
            SET @NJOIN=N' LEFT JOIN '+@NORMA_MASTER+N' M WITH(NOLOCK) ON M.ID=N.'+QUOTENAME(@NIDNORMA_COL)+N' ';
 
        /* Código / referencia. */
        IF COL_LENGTH(@NORMA_TABLE,'CODIGO') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(N.CODIGO,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'COD_NORMA') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(N.COD_NORMA,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'CODNORMA') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(N.CODNORMA,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'CODIGO') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(M.CODIGO,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'COD_NORMA') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(M.COD_NORMA,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'CODNORMA') IS NOT NULL SET @NCOD=N'CONVERT(VARCHAR(100),ISNULL(M.CODNORMA,''''))';
 
        /* Nombre de la norma. Se contemplan los nombres legacy más habituales. */
        IF COL_LENGTH(@NORMA_TABLE,'NOMBRE') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.NOMBRE,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'NORMA') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.NORMA,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'DESCRIPCION') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.DESCRIPCION,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'DESCRIPCION_NORMA') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.DESCRIPCION_NORMA,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'TITULO') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.TITULO,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'DENOMINACION') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.DENOMINACION,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'NOMBRE') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.NOMBRE,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'NORMA') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.NORMA,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'DESCRIPCION') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.DESCRIPCION,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'DESCRIPCION_NORMA') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.DESCRIPCION_NORMA,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'TITULO') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.TITULO,''''))';
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'DENOMINACION') IS NOT NULL SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.DENOMINACION,''''))';
 
        /* Modelo actual: la descripción canónica está en dbo.VCT_NORMAS.DESCRIPCION. */
        IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'DESCRIPCION') IS NOT NULL
            SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.DESCRIPCION,''''))';
 
        IF @NNOM=N'''''' AND @NJOIN<>N''
        BEGIN
            SET @NFALLBACK_COL='';
            SELECT TOP 1 @NFALLBACK_COL=C.name
            FROM sys.columns C
            INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
            WHERE C.object_id=OBJECT_ID(@NORMA_MASTER)
              AND T.name IN ('varchar','nvarchar','char','nchar','text','ntext')
              AND (
                    UPPER(C.name) LIKE '%NORMA%'
                 OR UPPER(C.name) LIKE '%NOMBRE%'
                 OR UPPER(C.name) LIKE '%DESCRIP%'
                 OR UPPER(C.name) LIKE '%TITULO%'
                 OR UPPER(C.name) LIKE '%DENOM%'
                 OR UPPER(C.name) LIKE '%REFER%'
              )
            ORDER BY CASE
                WHEN UPPER(C.name)='NORMA' THEN 1
                WHEN UPPER(C.name) LIKE '%NOMBRE%' THEN 2
                WHEN UPPER(C.name) LIKE '%DENOM%' THEN 3
                WHEN UPPER(C.name) LIKE '%DESCRIP%' THEN 4
                WHEN UPPER(C.name) LIKE '%TITULO%' THEN 5
                ELSE 6 END,
                C.column_id;
 
            IF NULLIF(@NFALLBACK_COL,'') IS NOT NULL
                SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(M.'+QUOTENAME(@NFALLBACK_COL)+N',''''))';
        END;
 
        /* Fallback por metadatos: evita mostrar simplemente "Norma" si el campo usa otro nombre. */
        IF @NNOM=N''''''
        BEGIN
            SELECT TOP 1 @NFALLBACK_COL=C.name
            FROM sys.columns C
            INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
            WHERE C.object_id=OBJECT_ID(@NORMA_TABLE)
              AND T.name IN ('varchar','nvarchar','char','nchar','text','ntext')
              AND UPPER(C.name) NOT IN ('TIPO_ENTIDAD','ESTADO','OBSERVACIONES','OBSERVACION','NOTAS','COMENTARIOS','COMENTARIO')
              AND (
                    UPPER(C.name) LIKE '%NORMA%'
                 OR UPPER(C.name) LIKE '%NOMBRE%'
                 OR UPPER(C.name) LIKE '%DESCRIP%'
                 OR UPPER(C.name) LIKE '%TITULO%'
                 OR UPPER(C.name) LIKE '%DENOM%'
                 OR UPPER(C.name) LIKE '%REFER%'
              )
            ORDER BY CASE
                WHEN UPPER(C.name)='NORMA' THEN 1
                WHEN UPPER(C.name) LIKE '%NOMBRE%' THEN 2
                WHEN UPPER(C.name) LIKE '%DESCRIP%' THEN 3
                WHEN UPPER(C.name) LIKE '%DENOM%' THEN 4
                WHEN UPPER(C.name) LIKE '%TITULO%' THEN 5
                ELSE 6 END,
                C.column_id;
 
            IF NULLIF(@NFALLBACK_COL,'') IS NOT NULL
                SET @NNOM=N'CONVERT(VARCHAR(300),ISNULL(N.'+QUOTENAME(@NFALLBACK_COL)+N',''''))';
        END;
 
        /* La relación puede guardar calificación/nivel en lugar de un estado clásico. */
        IF COL_LENGTH(@NORMA_TABLE,'CALIFICACION') IS NOT NULL
        BEGIN SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(N.CALIFICACION,''''))'; SET @NORMA_ESTADO_LABEL='Calificación'; END
        ELSE IF COL_LENGTH(@NORMA_TABLE,'NIVEL') IS NOT NULL
        BEGIN SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(N.NIVEL,''''))'; SET @NORMA_ESTADO_LABEL='Nivel'; END
        ELSE IF COL_LENGTH(@NORMA_TABLE,'CATEGORIA') IS NOT NULL
        BEGIN SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(N.CATEGORIA,''''))'; SET @NORMA_ESTADO_LABEL='Categoría'; END
        ELSE IF COL_LENGTH(@NORMA_TABLE,'ESTADO') IS NOT NULL
        BEGIN SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(N.ESTADO,''''))'; SET @NORMA_ESTADO_LABEL='Estado'; END
        ELSE IF @NJOIN<>N'' AND COL_LENGTH(@NORMA_MASTER,'ESTADO') IS NOT NULL
        BEGIN SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(M.ESTADO,''''))'; SET @NORMA_ESTADO_LABEL='Estado'; END;
 
        IF @NEST=N''''''
        BEGIN
            SET @NFALLBACK_COL='';
            SELECT TOP 1 @NFALLBACK_COL=C.name
            FROM sys.columns C
            INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
            WHERE C.object_id=OBJECT_ID(@NORMA_TABLE)
              AND T.name IN ('varchar','nvarchar','char','nchar')
              AND (
                    UPPER(C.name) LIKE '%CALIF%'
                 OR UPPER(C.name) LIKE '%NIVEL%'
                 OR UPPER(C.name) LIKE '%ESTADO%'
              )
            ORDER BY CASE
                WHEN UPPER(C.name) LIKE '%CALIF%' THEN 1
                WHEN UPPER(C.name) LIKE '%NIVEL%' THEN 2
                ELSE 3 END,
                C.column_id;
 
            IF NULLIF(@NFALLBACK_COL,'') IS NOT NULL
            BEGIN
                SET @NEST=N'CONVERT(VARCHAR(80),ISNULL(N.'+QUOTENAME(@NFALLBACK_COL)+N',''''))';
                SET @NORMA_ESTADO_LABEL=CASE
                    WHEN UPPER(@NFALLBACK_COL) LIKE '%CALIF%' THEN 'Calificación'
                    WHEN UPPER(@NFALLBACK_COL) LIKE '%NIVEL%' THEN 'Nivel'
                    ELSE 'Estado' END;
            END;
        END;
 
        IF COL_LENGTH(@NORMA_TABLE,'FECHA_DESDE') IS NOT NULL SET @NFD=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_DESDE))=1 THEN CONVERT(DATETIME,N.FECHA_DESDE) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'DESDE') IS NOT NULL SET @NFD=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.DESDE))=1 THEN CONVERT(DATETIME,N.DESDE) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'FECHA_INICIO') IS NOT NULL SET @NFD=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_INICIO))=1 THEN CONVERT(DATETIME,N.FECHA_INICIO) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'VIGENCIA_DESDE') IS NOT NULL SET @NFD=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.VIGENCIA_DESDE))=1 THEN CONVERT(DATETIME,N.VIGENCIA_DESDE) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'FECHA_ALTA') IS NOT NULL SET @NFD=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_ALTA))=1 THEN CONVERT(DATETIME,N.FECHA_ALTA) ELSE NULL END';
 
        IF COL_LENGTH(@NORMA_TABLE,'FECHA_HASTA') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_HASTA))=1 THEN CONVERT(DATETIME,N.FECHA_HASTA) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'HASTA') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.HASTA))=1 THEN CONVERT(DATETIME,N.HASTA) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'FECHA_VENCIMIENTO') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_VENCIMIENTO))=1 THEN CONVERT(DATETIME,N.FECHA_VENCIMIENTO) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'VENCIMIENTO') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.VENCIMIENTO))=1 THEN CONVERT(DATETIME,N.VENCIMIENTO) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'VIGENCIA_HASTA') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.VIGENCIA_HASTA))=1 THEN CONVERT(DATETIME,N.VIGENCIA_HASTA) ELSE NULL END';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'FECHA_FIN') IS NOT NULL SET @NFH=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),N.FECHA_FIN))=1 THEN CONVERT(DATETIME,N.FECHA_FIN) ELSE NULL END';
 
        IF COL_LENGTH(@NORMA_TABLE,'OBSERVACIONES') IS NOT NULL SET @NOBS=N'CONVERT(VARCHAR(1000),ISNULL(N.OBSERVACIONES,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'OBSERVACION') IS NOT NULL SET @NOBS=N'CONVERT(VARCHAR(1000),ISNULL(N.OBSERVACION,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'COMENTARIOS') IS NOT NULL SET @NOBS=N'CONVERT(VARCHAR(1000),ISNULL(N.COMENTARIOS,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'COMENTARIO') IS NOT NULL SET @NOBS=N'CONVERT(VARCHAR(1000),ISNULL(N.COMENTARIO,''''))';
        ELSE IF COL_LENGTH(@NORMA_TABLE,'NOTAS') IS NOT NULL SET @NOBS=N'CONVERT(VARCHAR(1000),ISNULL(N.NOTAS,''''))';

        IF OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NOT NULL
        BEGIN
            IF COL_LENGTH(@NORMA_TABLE,'ID_SERVICIO') IS NOT NULL
                SET @NSERV=N'(SELECT TOP 1 CONVERT(VARCHAR(120),PS.DESCRIPCION) FROM dbo.VCT_PRM_SERVICIOS PS WHERE PS.ID=N.ID_SERVICIO)';
            ELSE IF COL_LENGTH(@NORMA_TABLE,'IDSERVICIO') IS NOT NULL
                SET @NSERV=N'(SELECT TOP 1 CONVERT(VARCHAR(120),PS.DESCRIPCION) FROM dbo.VCT_PRM_SERVICIOS PS WHERE PS.ID=N.IDSERVICIO)';
            ELSE IF COL_LENGTH(@NORMA_TABLE,'SERVICIO_ID') IS NOT NULL
                SET @NSERV=N'(SELECT TOP 1 CONVERT(VARCHAR(120),PS.DESCRIPCION) FROM dbo.VCT_PRM_SERVICIOS PS WHERE PS.ID=N.SERVICIO_ID)';
        END;
 
        IF @NFILTER<>N'1=0'
        BEGIN
            SET @SQL_NORMA=N'INSERT INTO #NORMAS360 (ID,ID_NORMA,SERVICIO,CODIGO,NOMBRE,ESTADO,FECHA_DESDE,FECHA_HASTA,OBSERVACIONES)
                SELECT N.ID,'+@NIDNORMA_EXPR+N','+@NSERV+N','+@NCOD+N','+@NNOM+N','+@NEST+N','+@NFD+N','+@NFH+N','+@NOBS+N'
                FROM '+@NORMA_TABLE+N' N WITH(NOLOCK) '+@NJOIN+N' WHERE '+@NFILTER+N';';
            EXEC sp_executesql @SQL_NORMA,N'@PID INT',@PID=@ID_CONSULTOR;
        END;
    END;
 
    /* ---------------- SERVICIOS DEL CONSULTOR ---------------- */
    IF OBJECT_ID('tempdb..#SERVICIOS360') IS NOT NULL DROP TABLE #SERVICIOS360;
    CREATE TABLE #SERVICIOS360 (ID INT, ID_SERVICIO INT, SERVICIO VARCHAR(120), OBSERVACIONES VARCHAR(1000), FECHA_ALTA DATETIME);
    IF OBJECT_ID('dbo.VCT_CONSULTORES_SERVICIOS','U') IS NOT NULL
        INSERT INTO #SERVICIOS360 (ID,ID_SERVICIO,SERVICIO,OBSERVACIONES,FECHA_ALTA)
        SELECT CS.ID, CS.ID_SERVICIO,
               CONVERT(VARCHAR(120),ISNULL(PS.DESCRIPCION,'Servicio #'+CONVERT(VARCHAR(20),CS.ID_SERVICIO))),
               CONVERT(VARCHAR(1000),ISNULL(CS.OBSERVACIONES,'')),
               CS.FECHA_ALTA
        FROM dbo.VCT_CONSULTORES_SERVICIOS CS WITH(NOLOCK)
        LEFT JOIN dbo.VCT_PRM_SERVICIOS PS WITH(NOLOCK) ON PS.ID=CS.ID_SERVICIO
        WHERE CS.ID_CONSULTOR=@ID_CONSULTOR;

    /* ---------------- HISTORICO DE DIAS ---------------- */
    IF OBJECT_ID('tempdb..#HIST_DIAS360') IS NOT NULL DROP TABLE #HIST_DIAS360;
    CREATE TABLE #HIST_DIAS360
    (
        ID INT,
        FECHA DATETIME,
        PERIODO VARCHAR(80),
        PROYECTO VARCHAR(400),
        DIAS DECIMAL(18,2),
        OBSERVACIONES VARCHAR(1000)
    );
 
    DECLARE @HIST_TABLE SYSNAME='';
    IF OBJECT_ID('dbo.VCT_CONSULTORES_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_CONSULTORES_HISTORICO_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_HISTORICO_DIAS_CONSULTORES','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_HISTORICO_DIAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTORES_DIAS','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_CONSULTORES_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_DIAS_CONSULTORES','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_DIAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTOR_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_CONSULTOR_HISTORICO_DIAS';
    ELSE IF OBJECT_ID('dbo.VCT_HISTORICO_DIAS','U') IS NOT NULL SET @HIST_TABLE='dbo.VCT_HISTORICO_DIAS';
 
    IF @HIST_TABLE<>'' AND COL_LENGTH(@HIST_TABLE,'ID') IS NOT NULL
    BEGIN
        DECLARE
            @HFILTER NVARCHAR(MAX)=N'1=0',
            @HFECHA NVARCHAR(500)=N'NULL',
            @HPERIODO NVARCHAR(500)=N'''''',
            @HPROY NVARCHAR(500)=N'''''',
            @HDIAS NVARCHAR(500)=N'0',
            @HOBS NVARCHAR(500)=N'''''',
            @HJOIN NVARCHAR(MAX)=N'',
            @HDIAS_COL SYSNAME='',
            @HPROY_ID_COL SYSNAME='',
            @SQL_HIST NVARCHAR(MAX)=N'';
 
        IF COL_LENGTH(@HIST_TABLE,'TIPO_ENTIDAD') IS NOT NULL AND COL_LENGTH(@HIST_TABLE,'ID_ENTIDAD') IS NOT NULL
            SET @HFILTER=N'H.TIPO_ENTIDAD=''CONSULTOR'' AND H.ID_ENTIDAD=@PID';
        ELSE IF COL_LENGTH(@HIST_TABLE,'ID_CONSULTOR') IS NOT NULL
            SET @HFILTER=N'H.ID_CONSULTOR=@PID';
        ELSE IF COL_LENGTH(@HIST_TABLE,'IDCONSULTOR') IS NOT NULL
            SET @HFILTER=N'H.IDCONSULTOR=@PID';
        ELSE IF COL_LENGTH(@HIST_TABLE,'CONSULTOR_ID') IS NOT NULL
            SET @HFILTER=N'H.CONSULTOR_ID=@PID';
 
        IF COL_LENGTH(@HIST_TABLE,'FECHA') IS NOT NULL SET @HFECHA=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),H.FECHA))=1 THEN CONVERT(DATETIME,H.FECHA) ELSE NULL END';
        ELSE IF COL_LENGTH(@HIST_TABLE,'FECHA_DIA') IS NOT NULL SET @HFECHA=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),H.FECHA_DIA))=1 THEN CONVERT(DATETIME,H.FECHA_DIA) ELSE NULL END';
        ELSE IF COL_LENGTH(@HIST_TABLE,'FECHA_DESDE') IS NOT NULL SET @HFECHA=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),H.FECHA_DESDE))=1 THEN CONVERT(DATETIME,H.FECHA_DESDE) ELSE NULL END';
        ELSE IF COL_LENGTH(@HIST_TABLE,'FECHA_TRABAJO') IS NOT NULL SET @HFECHA=N'CASE WHEN ISDATE(CONVERT(VARCHAR(50),H.FECHA_TRABAJO))=1 THEN CONVERT(DATETIME,H.FECHA_TRABAJO) ELSE NULL END';
 
        IF COL_LENGTH(@HIST_TABLE,'PERIODO') IS NOT NULL SET @HPERIODO=N'CONVERT(VARCHAR(80),ISNULL(H.PERIODO,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'PERIODO_ID') IS NOT NULL SET @HPERIODO=N'CONVERT(VARCHAR(80),ISNULL(H.PERIODO_ID,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'MES') IS NOT NULL AND COL_LENGTH(@HIST_TABLE,'ANIO') IS NOT NULL
            SET @HPERIODO=N'RIGHT(''0''+CONVERT(VARCHAR(2),H.MES),2)+''/''+CONVERT(VARCHAR(4),H.ANIO)';
 
        IF COL_LENGTH(@HIST_TABLE,'DIAS') IS NOT NULL SET @HDIAS_COL='DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'CANTIDAD_DIAS') IS NOT NULL SET @HDIAS_COL='CANTIDAD_DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'CANT_DIAS') IS NOT NULL SET @HDIAS_COL='CANT_DIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'CANTDIAS') IS NOT NULL SET @HDIAS_COL='CANTDIAS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'DIAS_TRABAJADOS') IS NOT NULL SET @HDIAS_COL='DIAS_TRABAJADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'DIAS_ASIGNADOS') IS NOT NULL SET @HDIAS_COL='DIAS_ASIGNADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'DIAS_FACTURADOS') IS NOT NULL SET @HDIAS_COL='DIAS_FACTURADOS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'JORNADAS') IS NOT NULL SET @HDIAS_COL='JORNADAS';
        ELSE IF COL_LENGTH(@HIST_TABLE,'CANTIDAD') IS NOT NULL SET @HDIAS_COL='CANTIDAD';
        ELSE IF COL_LENGTH(@HIST_TABLE,'VALOR') IS NOT NULL SET @HDIAS_COL='VALOR';
 
        IF @HDIAS_COL=''
        BEGIN
            SELECT TOP 1 @HDIAS_COL=C.name
            FROM sys.columns C
            INNER JOIN sys.types T ON T.user_type_id=C.user_type_id
            WHERE C.object_id=OBJECT_ID(@HIST_TABLE)
              AND T.name IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real','money','smallmoney')
              AND UPPER(C.name) NOT IN ('ID','ID_CONSULTOR','IDCONSULTOR','ID_ENTIDAD','IDPROYECTO','ID_PROYECTO')
              AND (
                    UPPER(C.name) LIKE '%DIA%'
                 OR UPPER(C.name) LIKE '%JORN%'
                 OR UPPER(C.name) LIKE '%CANT%'
              )
            ORDER BY CASE
                WHEN UPPER(C.name) LIKE '%DIA%' THEN 1
                WHEN UPPER(C.name) LIKE '%JORN%' THEN 2
                ELSE 3 END,
                C.column_id;
        END;
 
        IF @HDIAS_COL<>''
            SET @HDIAS=N'CASE WHEN ISNUMERIC(REPLACE(CONVERT(VARCHAR(100),H.'+QUOTENAME(@HDIAS_COL)+N'), '','', ''.''))=1 AND REPLACE(CONVERT(VARCHAR(100),H.'+QUOTENAME(@HDIAS_COL)+N'), '','', ''.'') NOT LIKE ''%[eE$]%'' THEN CONVERT(DECIMAL(18,2),REPLACE(CONVERT(VARCHAR(100),H.'+QUOTENAME(@HDIAS_COL)+N'), '','', ''.'')) ELSE 0 END';
 
        IF COL_LENGTH(@HIST_TABLE,'IDPROYECTO') IS NOT NULL SET @HPROY_ID_COL='IDPROYECTO';
        ELSE IF COL_LENGTH(@HIST_TABLE,'ID_PROYECTO') IS NOT NULL SET @HPROY_ID_COL='ID_PROYECTO';
        ELSE IF COL_LENGTH(@HIST_TABLE,'PROYECTO_ID') IS NOT NULL SET @HPROY_ID_COL='PROYECTO_ID';
 
        IF @HPROY_ID_COL<>'' AND OBJECT_ID('dbo.VCT_PROYECTOS','U') IS NOT NULL
        BEGIN
            SET @HJOIN=N' LEFT JOIN dbo.VCT_PROYECTOS HP WITH(NOLOCK) ON HP.ID=H.'+QUOTENAME(@HPROY_ID_COL)+N' ';
            SET @HPROY=N'CONVERT(VARCHAR(400),LTRIM(RTRIM(ISNULL(HP.CODIGO,'''')+CASE WHEN ISNULL(HP.CODIGO,'''')<>'''' AND ISNULL(HP.NOMBRE,'''')<>'''' THEN '' - '' ELSE '''' END+ISNULL(HP.NOMBRE,''''))))';
        END
        ELSE IF COL_LENGTH(@HIST_TABLE,'PROYECTO') IS NOT NULL
            SET @HPROY=N'CONVERT(VARCHAR(400),ISNULL(H.PROYECTO,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'NOMBRE_PROYECTO') IS NOT NULL
            SET @HPROY=N'CONVERT(VARCHAR(400),ISNULL(H.NOMBRE_PROYECTO,''''))';
 
        IF COL_LENGTH(@HIST_TABLE,'OBSERVACIONES') IS NOT NULL SET @HOBS=N'CONVERT(VARCHAR(1000),ISNULL(H.OBSERVACIONES,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'OBSERVACION') IS NOT NULL SET @HOBS=N'CONVERT(VARCHAR(1000),ISNULL(H.OBSERVACION,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'COMENTARIOS') IS NOT NULL SET @HOBS=N'CONVERT(VARCHAR(1000),ISNULL(H.COMENTARIOS,''''))';
        ELSE IF COL_LENGTH(@HIST_TABLE,'NOTAS') IS NOT NULL SET @HOBS=N'CONVERT(VARCHAR(1000),ISNULL(H.NOTAS,''''))';
 
        IF @HFILTER<>N'1=0'
        BEGIN
            SET @SQL_HIST=N'INSERT INTO #HIST_DIAS360 (ID,FECHA,PERIODO,PROYECTO,DIAS,OBSERVACIONES)
                SELECT H.ID,'+@HFECHA+N','+@HPERIODO+N','+@HPROY+N','+@HDIAS+N','+@HOBS+N'
                FROM '+@HIST_TABLE+N' H WITH(NOLOCK) '+@HJOIN+N' WHERE '+@HFILTER+N';';
            EXEC sp_executesql @SQL_HIST,N'@PID INT',@PID=@ID_CONSULTOR;
        END;
    END;
 
    /* Normaliza periodos legacy YYYYMM para la grilla y para el gráfico mensual. */
    UPDATE H
       SET FECHA=COALESCE(H.FECHA,CONVERT(DATETIME,LTRIM(RTRIM(H.PERIODO))+'01',112)),
           PERIODO=RIGHT(LTRIM(RTRIM(H.PERIODO)),2)+'/'+LEFT(LTRIM(RTRIM(H.PERIODO)),4)
    FROM #HIST_DIAS360 H
    WHERE LEN(LTRIM(RTRIM(ISNULL(H.PERIODO,''))))=6
      AND LTRIM(RTRIM(H.PERIODO)) NOT LIKE '%[^0-9]%'
      AND LEFT(LTRIM(RTRIM(H.PERIODO)),4) BETWEEN '1900' AND '2100'
      AND RIGHT(LTRIM(RTRIM(H.PERIODO)),2) BETWEEN '01' AND '12';
 
    UPDATE H
       SET PERIODO=RIGHT('0'+CONVERT(VARCHAR(2),MONTH(H.FECHA)),2)+'/'+CONVERT(VARCHAR(4),YEAR(H.FECHA))
    FROM #HIST_DIAS360 H
    WHERE H.FECHA IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ISNULL(H.PERIODO,''))),'') IS NULL;
 
    /* ---------------- DOCUMENTOS ----------------
       Documentos de proyecto vinculados directamente al consultor
       principal o acompañante.
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#DOCUMENTOS360') IS NOT NULL DROP TABLE #DOCUMENTOS360;
    CREATE TABLE #DOCUMENTOS360
    (
        ID INT,
        TIPO VARCHAR(150),
        NOMBRE VARCHAR(300),
        ESTADO VARCHAR(80),
        FECHA_EMISION DATETIME,
        FECHA_VENCIMIENTO DATETIME,
        OBSERVACIONES VARCHAR(1000)
    );
 
    INSERT INTO #DOCUMENTOS360
    (
        ID,
        TIPO,
        NOMBRE,
        ESTADO,
        FECHA_EMISION,
        FECHA_VENCIMIENTO,
        OBSERVACIONES
    )
    SELECT
        D.ID,
 
        CONVERT
        (
            VARCHAR(150),
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(D.TIPO)),''),
                ISNULL(NULLIF(LTRIM(RTRIM(PD.CODIGO)),''),'Documento')
            )
        ),
 
        CONVERT
        (
            VARCHAR(300),
            LTRIM
            (
                RTRIM
                (
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(P.CODIGO,''))),'') IS NOT NULL
                            THEN '('+P.CODIGO+') '
                        ELSE ''
                    END
                    +
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(PD.DESCRIPCION,''))),'') IS NOT NULL
                            THEN PD.DESCRIPCION
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(D.NRO_INTERNO,''))),'') IS NOT NULL
                            THEN D.NRO_INTERNO
                        ELSE 'Documento #'+CONVERT(VARCHAR(20),D.ID)
                    END
                )
            )
        ),
 
        CONVERT(VARCHAR(80),ISNULL(D.ESTADO,'')),
        D.FECHA_DOCUMENTO,
        D.FECHA_CIERRE,
 
        CONVERT
        (
            VARCHAR(1000),
            LTRIM
            (
                RTRIM
                (
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(D.NRO_INTERNO,''))),'') IS NOT NULL
                            THEN 'Nro. interno: '+D.NRO_INTERNO
                        ELSE ''
                    END
                    +
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(D.NRO_INTERNO,''))),'') IS NOT NULL
                         AND NULLIF(LTRIM(RTRIM(ISNULL(D.OBSERVACIONES,''))),'') IS NOT NULL
                            THEN ' - '
                        ELSE ''
                    END
                    +
                    ISNULL(D.OBSERVACIONES,'')
                )
            )
        )
 
    FROM dbo.VCT_PROYECTOS_DOCUMENTOS D WITH(NOLOCK)
 
    LEFT JOIN dbo.VCT_PRM_DOCUMENTOS PD WITH(NOLOCK)
        ON PD.ID=D.ID_DOCUMENTO
 
    LEFT JOIN dbo.VCT_PROYECTOS P WITH(NOLOCK)
        ON P.ID=D.ID_PROYECTO
 
    WHERE D.ID_CONSULTOR=@ID_CONSULTOR
       OR D.ID_CONSULTOR_ACOMP=@ID_CONSULTOR
       OR LTRIM(RTRIM(ISNULL(D.CONSULTOR_LEGACY,'')))=CONVERT(VARCHAR(20),@ID_CONSULTOR)
       OR LTRIM(RTRIM(ISNULL(D.CONSULTOR_ACOMP_LEGACY,'')))=CONVERT(VARCHAR(20),@ID_CONSULTOR);
 
    /* ---------------- NOTAS ---------------- */
    IF OBJECT_ID('tempdb..#NOTAS360') IS NOT NULL DROP TABLE #NOTAS360;
    CREATE TABLE #NOTAS360
    (
        ID INT,
        FECHA DATETIME,
        TITULO VARCHAR(300),
        NOTA VARCHAR(2000),
        USUARIO VARCHAR(150)
    );
 
    DECLARE @NOTA_TABLE SYSNAME='';
    IF OBJECT_ID('dbo.VCT_CONSULTORES_NOTAS','U') IS NOT NULL SET @NOTA_TABLE='dbo.VCT_CONSULTORES_NOTAS';
    ELSE IF OBJECT_ID('dbo.VCT_CONSULTOR_NOTAS','U') IS NOT NULL SET @NOTA_TABLE='dbo.VCT_CONSULTOR_NOTAS';
    ELSE IF OBJECT_ID('dbo.VCT_NOTAS_CONSULTORES','U') IS NOT NULL SET @NOTA_TABLE='dbo.VCT_NOTAS_CONSULTORES';
    ELSE IF OBJECT_ID('dbo.VCT_NOTAS','U') IS NOT NULL SET @NOTA_TABLE='dbo.VCT_NOTAS';
 
    IF @NOTA_TABLE<>'' AND COL_LENGTH(@NOTA_TABLE,'ID') IS NOT NULL
    BEGIN
        DECLARE
            @NOTAFILTER NVARCHAR(MAX)=N'1=0',
            @NFECHA NVARCHAR(500)=N'NULL',
            @NTIT NVARCHAR(500)=N'''''',
            @NTXT NVARCHAR(500)=N'''''',
            @NUSR NVARCHAR(500)=N'''''',
            @SQL_NOTA NVARCHAR(MAX)=N'';
 
        IF COL_LENGTH(@NOTA_TABLE,'TIPO_ENTIDAD') IS NOT NULL AND COL_LENGTH(@NOTA_TABLE,'ID_ENTIDAD') IS NOT NULL
            SET @NOTAFILTER=N'X.TIPO_ENTIDAD=''CONSULTOR'' AND X.ID_ENTIDAD=@PID';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'ID_CONSULTOR') IS NOT NULL
            SET @NOTAFILTER=N'X.ID_CONSULTOR=@PID';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'IDCONSULTOR') IS NOT NULL
            SET @NOTAFILTER=N'X.IDCONSULTOR=@PID';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'CONSULTOR_ID') IS NOT NULL
            SET @NOTAFILTER=N'X.CONSULTOR_ID=@PID';
 
        IF COL_LENGTH(@NOTA_TABLE,'FECHA') IS NOT NULL SET @NFECHA=N'X.FECHA';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'FECHA_ALTA') IS NOT NULL SET @NFECHA=N'X.FECHA_ALTA';
        IF COL_LENGTH(@NOTA_TABLE,'TITULO') IS NOT NULL SET @NTIT=N'CONVERT(VARCHAR(300),ISNULL(X.TITULO,''''))';
        IF COL_LENGTH(@NOTA_TABLE,'NOTA') IS NOT NULL SET @NTXT=N'CONVERT(VARCHAR(2000),ISNULL(X.NOTA,''''))';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'DESCRIPCION') IS NOT NULL SET @NTXT=N'CONVERT(VARCHAR(2000),ISNULL(X.DESCRIPCION,''''))';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'OBSERVACIONES') IS NOT NULL SET @NTXT=N'CONVERT(VARCHAR(2000),ISNULL(X.OBSERVACIONES,''''))';
        IF COL_LENGTH(@NOTA_TABLE,'USUARIO') IS NOT NULL SET @NUSR=N'CONVERT(VARCHAR(150),ISNULL(X.USUARIO,''''))';
        ELSE IF COL_LENGTH(@NOTA_TABLE,'USUARIO_ALTA') IS NOT NULL SET @NUSR=N'CONVERT(VARCHAR(150),ISNULL(X.USUARIO_ALTA,''''))';
 
        IF @NOTAFILTER<>N'1=0'
        BEGIN
            SET @SQL_NOTA=N'INSERT INTO #NOTAS360 (ID,FECHA,TITULO,NOTA,USUARIO)
                SELECT X.ID,'+@NFECHA+N','+@NTIT+N','+@NTXT+N','+@NUSR+N'
                FROM '+@NOTA_TABLE+N' X WITH(NOLOCK) WHERE '+@NOTAFILTER+N';';
            EXEC sp_executesql @SQL_NOTA,N'@PID INT',@PID=@ID_CONSULTOR;
        END;
    END;
 
    DECLARE
        @NormasCount INT=0,
        @ServiciosCount INT=0,
        @HistoricoCount INT=0,
        @HistoricoDiasTotal DECIMAL(18,2)=0,
        @DocumentosVigentes INT=0,
        @NotasCount INT=0;
 
    SELECT @NormasCount=COUNT(*) FROM #NORMAS360;
    SELECT @ServiciosCount=COUNT(*) FROM #SERVICIOS360;
    SELECT @HistoricoCount=COUNT(*),@HistoricoDiasTotal=ISNULL(SUM(DIAS),0) FROM #HIST_DIAS360;
    SELECT
        @DocumentosCount=COUNT(*),
        @DocumentosVigentes=ISNULL
        (
            SUM(CASE WHEN FECHA_VENCIMIENTO IS NULL THEN 1 ELSE 0 END),
            0
        )
    FROM #DOCUMENTOS360;
    SELECT @NotasCount=COUNT(*) FROM #NOTAS360;
 
    /* ============================================================
       11.C KPI OPERATIVOS DEL CONSULTOR
       ------------------------------------------------------------
       Se apoyan en el modelo normalizado actual:
         - dias: visitas del consultor ya ocurridas, no anuladas/canceladas;
         - honorarios/viaticos: importes ARS registrados para el consultor;
         - sin liquidar: registros economicos que no figuran cerrados/pagados.
       Si no existen las tablas nuevas, dias cae al historico normalizado
       y los importes quedan en cero sin romper la Vista 360.
       ============================================================ */
    DECLARE
        @DiasEjecutados DECIMAL(18,2)=0,
        @ProyectosConDias INT=0,
        @DiasPromedioProyecto DECIMAL(18,1)=0,
        @HonorariosViaticosARS NUMERIC(18,2)=0,
        @SinLiquidar INT=0,
        @HonorariosViaticosTxt VARCHAR(40)='0';
 
    IF OBJECT_ID('dbo.VCT_PROYECTOS_VISITAS','U') IS NOT NULL
       AND OBJECT_ID('dbo.VCT_PROYECTOS_VISITAS_CONSULTORES','U') IS NOT NULL
    BEGIN
        SELECT
            @DiasEjecutados=ISNULL(SUM(CONVERT(DECIMAL(18,2),
                CASE
                    WHEN V.DIAS IS NOT NULL AND V.DIAS>0 THEN V.DIAS
                    WHEN V.FECHA_DESDE IS NOT NULL AND V.FECHA_HASTA IS NOT NULL
                        THEN DATEDIFF(DAY,V.FECHA_DESDE,V.FECHA_HASTA)+1
                    WHEN V.FECHA_DESDE IS NOT NULL THEN 1
                    ELSE 0
                END)),0),
            @ProyectosConDias=COUNT(DISTINCT V.ID_PROYECTO)
        FROM dbo.VCT_PROYECTOS_VISITAS V WITH(NOLOCK)
        INNER JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC WITH(NOLOCK)
            ON VC.ID_VISITA=V.ID
        WHERE VC.ID_CONSULTOR=@ID_CONSULTOR
          AND ISNULL(V.FECHA_DESDE,V.FECHA_HASTA)<=GETDATE()
          AND UPPER(ISNULL(V.ESTADO,'')) NOT IN ('CANCELADA','CANCELADO','ANULADA','ANULADO');
    END;
 
    IF @DiasEjecutados=0 AND ISNULL(@HistoricoDiasTotal,0)>0
        SET @DiasEjecutados=@HistoricoDiasTotal;
 
    IF @ProyectosConDias=0 AND @DiasEjecutados>0
        SET @ProyectosConDias=CASE WHEN @ProyectosCount>0 THEN @ProyectosCount ELSE 1 END;
 
    IF @ProyectosConDias>0
        SET @DiasPromedioProyecto=CONVERT(DECIMAL(18,1),@DiasEjecutados/@ProyectosConDias);
 
    IF OBJECT_ID('dbo.VCT_HONORARIOS','U') IS NOT NULL
    BEGIN
        SELECT
            @HonorariosViaticosARS=@HonorariosViaticosARS+ISNULL(SUM(CASE WHEN ISNULL(MONEDA,'ARS')='ARS' THEN ISNULL(IMPORTE,0) ELSE 0 END),0),
            @SinLiquidar=@SinLiquidar+ISNULL(SUM(CASE WHEN UPPER(ISNULL(ESTADO,'REGISTRADO')) NOT IN ('PAGADO','LIQUIDADO','LIQUIDADA','CERRADO','CERRADA','CANCELADO','CANCELADA') THEN 1 ELSE 0 END),0)
        FROM dbo.VCT_HONORARIOS WITH(NOLOCK)
        WHERE ID_CONSULTOR=@ID_CONSULTOR;
    END;
 
    IF OBJECT_ID('dbo.VCT_VIATICOS','U') IS NOT NULL
    BEGIN
        SELECT
            @HonorariosViaticosARS=@HonorariosViaticosARS+ISNULL(SUM(CASE WHEN ISNULL(MONEDA,'ARS')='ARS' THEN ISNULL(IMPORTE,0) ELSE 0 END),0),
            @SinLiquidar=@SinLiquidar+ISNULL(SUM(CASE
                WHEN ISNULL(SALDO_PENDIENTE,0)>0 THEN 1
                WHEN UPPER(ISNULL(ESTADO_PAGO,'')) NOT IN ('PAGADO','PAGADA','CANCELADO','CANCELADA') THEN 1
                ELSE 0 END),0)
        FROM dbo.VCT_VIATICOS WITH(NOLOCK)
        WHERE ID_CONSULTOR=@ID_CONSULTOR;
    END;
 
    SET @HonorariosViaticosTxt=CONVERT(VARCHAR(40),CAST(ROUND(ISNULL(@HonorariosViaticosARS,0),0) AS MONEY),1);
    IF RIGHT(@HonorariosViaticosTxt,3)='.00'
        SET @HonorariosViaticosTxt=LEFT(@HonorariosViaticosTxt,LEN(@HonorariosViaticosTxt)-3);
 
    /* ============================================================
       12. FOOTER GENERICO
       ============================================================ */
    DECLARE @HTML_GRID_FOOTER VARCHAR(MAX)=
        '<div class="vct-grid-footer">' +
            '<div class="vct-grid-footer-info" data-vct-grid-info></div>' +
            '<div class="vct-pagination" data-vct-grid-pagination></div>' +
            '<div class="vct-grid-page-size">' +
                '<span>Registros por página:</span>' +
                '<select class="vct-select vct-select-sm" data-vct-grid-page-size>' +
                    '<option value="10" selected="selected">10</option>' +
                    '<option value="20">20</option>' +
                    '<option value="50">50</option>' +
                    '<option value="100">100</option>' +
                '</select>' +
            '</div>' +
        '</div>';
 
    /* ============================================================
       13. HTML PROYECTOS
       ============================================================ */
    DECLARE
        @HTML_PROYECTOS VARCHAR(MAX)='',
        @HTML_PROYECTOS_TOP VARCHAR(MAX)='';
 
    SELECT @HTML_PROYECTOS=ISNULL((
        SELECT
            '<tr data-vct-row>' +
                '<td data-label="Cliente" class="vct-360-cell-client" style="width:20% !important;">'+
                    '<span class="vct-360-project-name">'+
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.CLIENTE_NOMBRE,''),'Sin cliente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                    '</span>'+
                '</td>'+
                '<td data-label="Proyecto" style="width:42% !important;text-align:left !important;">' +
                    '<span class="vct-360-project-name">('+
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.CODIGO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                    ') '+
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.NOMBRE,'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                    '</span>'+
                    CASE WHEN ISNULL(P.REFERENCIA,'')<>''
                         THEN '<span class="vct-360-project-ref">'+
                              REPLACE(REPLACE(REPLACE(REPLACE(P.REFERENCIA,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                              '</span>'
                         ELSE '' END+
                CASE WHEN ISNULL(P.RELACION,'')<>''
                     THEN '<span class="vct-360-project-ref">Rol: '+
                          REPLACE(REPLACE(REPLACE(REPLACE(P.RELACION,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                          '</span>'
                     ELSE '' END+
                '</td>'+
                '<td class="vct-text-center" data-label="Estado" style="width:10% !important;">'+
                    '<span class="vct-360-badge '+
                    CASE
                        WHEN P.ESTADO_CODIGO='ENCURSO' THEN 'is-progress'
                        WHEN P.ESTADO_CODIGO='TERMINADO' THEN 'is-done'
                        WHEN P.ESTADO_CODIGO='CANCELADO' THEN 'is-cancel'
                        ELSE 'is-neutral'
                    END+'">'+
                    REPLACE(REPLACE(REPLACE(
                        CASE WHEN P.ESTADO_CODIGO='ENCURSO'
                             THEN 'EN CURSO'
                             ELSE ISNULL(NULLIF(P.ESTADO,''),'Sin estado') END,
                        '&','&amp;'),'<','&lt;'),'>','&gt;')+
                    '</span>'+
                '</td>'+
                '<td class="vct-text-center" data-label="Inicio" style="width:9% !important;">'+
                    CASE WHEN P.FECHA_INICIO IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),P.FECHA_INICIO,103) END+
                '</td>'+
                '<td class="vct-text-center" data-label="Fin" style="width:9% !important;">'+
                    CASE WHEN P.FECHA_FIN IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),P.FECHA_FIN,103) END+
                '</td>'+
                '<td class="vct-text-center" data-label="Avance" data-vct-sort-value="'+CONVERT(VARCHAR(5),ISNULL(P.PORCENTAJE_AVANCE,0))+'" style="width:10% !important;">'+
                    '<div class="vct-360-progress"><div class="vct-360-progress-bar" style="background:#66062D !important;width:'+
                    CONVERT(VARCHAR(5),
                        CASE
                            WHEN ISNULL(P.PORCENTAJE_AVANCE,0)<0 THEN 0
                            WHEN ISNULL(P.PORCENTAJE_AVANCE,0)>100 THEN 100
                            ELSE ISNULL(P.PORCENTAJE_AVANCE,0)
                        END
                    )+'%;"></div></div>'+
                    '<span class="vct-360-progress-label">'+
                    CONVERT(VARCHAR(5),ISNULL(P.PORCENTAJE_AVANCE,0))+'%</span>'+
                '</td>'+
            '</tr>'
        FROM #PROYECTOS360 P
        ORDER BY
            CASE WHEN P.FECHA_INICIO IS NULL THEN 1 ELSE 0 END,
            P.FECHA_INICIO DESC,
            P.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_PROYECTOS=''
        SET @HTML_PROYECTOS=
            '<div class="vct-360-empty vct-360-fixed-empty">El consultor no posee proyectos relacionados.</div>';
    ELSE
        SET @HTML_PROYECTOS=
            '<div data-vct-dg data-vct-dg-id="v360_con_proyectos" data-vct-dg-title="Proyectos del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="proyecto(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar proyecto, cliente..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-width="20%" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="40%" data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="inicio" data-vct-sortable="true" data-vct-sort-type="date"><span>Inicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="fin" data-vct-sortable="true" data-vct-sort-type="date"><span>Fin</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="avance" data-vct-sortable="true" data-vct-sort-type="number"><span>Avance</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th></tr></thead>'+
            '<tbody>'+@HTML_PROYECTOS+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_PROYECTOS_TOP=ISNULL((
        SELECT TOP 5
            '<tr>'+
                '<td class="vct-360-cell-client" style="width:20% !important;"><span class="vct-360-project-name">'+
                    REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(P.CLIENTE_NOMBRE,''),'Sin cliente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                '</span></td>'+
                '<td style="width:42% !important;text-align:left !important;"><span class="vct-360-project-name">('+
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.CODIGO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                ') '+
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(P.NOMBRE,'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                '</span>'+
                CASE WHEN ISNULL(P.REFERENCIA,'')<>''
                     THEN '<span class="vct-360-project-ref">'+
                          REPLACE(REPLACE(REPLACE(REPLACE(P.REFERENCIA,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                          '</span>'
                     ELSE '' END+
                CASE WHEN ISNULL(P.RELACION,'')<>''
                     THEN '<span class="vct-360-project-ref">Rol: '+
                          REPLACE(REPLACE(REPLACE(REPLACE(P.RELACION,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                          '</span>'
                     ELSE '' END+
                '</td>'+
                '<td class="vct-text-center" style="width:10% !important;"><span class="vct-360-badge '+
                    CASE
                        WHEN P.ESTADO_CODIGO='ENCURSO' THEN 'is-progress'
                        WHEN P.ESTADO_CODIGO='TERMINADO' THEN 'is-done'
                        ELSE 'is-neutral'
                    END+'">'+
                    REPLACE(REPLACE(REPLACE(
                        CASE WHEN P.ESTADO_CODIGO='ENCURSO'
                             THEN 'EN CURSO'
                             ELSE ISNULL(NULLIF(P.ESTADO,''),'Sin estado') END,
                        '&','&amp;'),'<','&lt;'),'>','&gt;')+
                '</span></td>'+
                '<td class="vct-text-center" style="width:9% !important;">'+
                    CASE WHEN P.FECHA_INICIO IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),P.FECHA_INICIO,103) END+
                '</td>'+
                '<td class="vct-text-center" style="width:9% !important;">'+
                    CASE WHEN P.FECHA_FIN IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),P.FECHA_FIN,103) END+
                '</td>'+
                '<td class="vct-text-center" style="width:10% !important;">'+
                    '<div class="vct-360-progress"><div class="vct-360-progress-bar" style="background:#66062D !important;width:'+
                    CONVERT(VARCHAR(5),
                        CASE
                            WHEN ISNULL(P.PORCENTAJE_AVANCE,0)<0 THEN 0
                            WHEN ISNULL(P.PORCENTAJE_AVANCE,0)>100 THEN 100
                            ELSE ISNULL(P.PORCENTAJE_AVANCE,0)
                        END
                    )+'%;"></div></div>'+
                    '<span class="vct-360-progress-label">'+
                    CONVERT(VARCHAR(5),ISNULL(P.PORCENTAJE_AVANCE,0))+'%</span>'+
                '</td>'+
            '</tr>'
        FROM #PROYECTOS360 P
        ORDER BY
            CASE WHEN P.FECHA_INICIO IS NULL THEN 1 ELSE 0 END,
            P.FECHA_INICIO DESC,
            P.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_PROYECTOS_TOP=''
        SET @HTML_PROYECTOS_TOP=
            '<div class="vct-360-empty vct-360-fixed-empty">El consultor no posee proyectos relacionados.</div>';
    ELSE
        SET @HTML_PROYECTOS_TOP=
            '<div class="vct-360-grid-fixed vct-360-grid-five vct-360-projects-recent">'+
                '<table class="vct-360-table vct-360-project-table vct-360-project-table-recent vct-360-project-table-recent-consultor" style="width:100% !important;min-width:0 !important;table-layout:fixed !important;">'+
                    '<colgroup><col style="width:20%"><col style="width:42%"><col style="width:10%"><col style="width:9%"><col style="width:9%"><col style="width:10%"></colgroup>'+ 
                    '<thead><tr>'+
                        '<th style="width:20% !important;">Cliente</th>'+
                        '<th style="width:42% !important;text-align:left !important;">Proyecto</th>'+
                        '<th class="vct-text-center" style="width:10% !important;">Estado</th>'+
                        '<th class="vct-text-center" style="width:9% !important;">Inicio</th>'+
                        '<th class="vct-text-center" style="width:9% !important;">Fin</th>'+
                        '<th class="vct-text-center" style="width:10% !important;">Avance</th>'+
                    '</tr></thead>'+
                    '<tbody>'+@HTML_PROYECTOS_TOP+'</tbody>'+
                '</table>'+
            '</div>';
 
    /* ============================================================
       14. HTML GESTIONES
       "Vencida" se calcula por fecha; no se almacena como estado visual.
       ============================================================ */
    DECLARE
        @HTML_GESTIONES VARCHAR(MAX)='',
        @HTML_GESTIONES_TOP VARCHAR(MAX)='';
 
    SELECT @HTML_GESTIONES=ISNULL((
        SELECT
            '<tr data-vct-row style="border-bottom:1px solid #edf1f5;">'+
                '<td data-label="" class="vct-360-cell-management-icon" aria-hidden="true" style="width:4% !important;border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-management-type-icon"><span data-vct-icon="'+GestionIcono+'"></span></span>'+ 
                '</td>'+ 
                '<td data-label="Gestión" class="vct-360-cell-management" style="width:17% !important;text-align:left !important;border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">'+GestionTitulo+'</span>'+ 
                    CASE WHEN GestionDetalle<>'' THEN '<span class="vct-360-project-ref">'+GestionDetalle+'</span>' ELSE '' END+
                '</td>'+ 
                '<td data-label="Cliente" class="vct-360-cell-client" style="width:13% !important;text-align:left !important;border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">'+ClienteNombre+'</span>'+ 
                '</td>'+ 
                '<td data-label="Proyecto" class="vct-360-cell-management-project vct-360-cell-project" style="width:27% !important;text-align:left !important;border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">('+ProyectoCodigo+') '+ProyectoNombre+'</span>'+ 
                    CASE WHEN ProyectoReferencia<>'' THEN '<span class="vct-360-project-ref">'+ProyectoReferencia+'</span>' ELSE '' END+
                '</td>'+ 
                '<td data-label="Responsable" data-vct-sort-value="'+ResponsableNombre+'" class="vct-360-cell-person" style="width:15% !important;text-align:left !important;border-bottom:1px solid #edf1f5 !important;">'+
                    CASE WHEN ResponsableNombre='-' THEN '-'
                         ELSE '<span class="vct-360-person-inline">'+
                              '<span class="vct-360-contact-avatar vct-360-contact-avatar-sm" style="--vct-avatar-bg:'+ResponsableBg+';--vct-avatar-color:'+ResponsableTx+';">'+ResponsableIniciales+'</span>'+ 
                              '<span class="vct-360-person-name">'+ResponsableNombre+'</span>'+ 
                              '</span>' END+
                '</td>'+ 
                '<td data-label="Vencimiento" class="vct-360-cell-date" style="width:8% !important;text-align:center !important;border-bottom:1px solid #edf1f5 !important;">'+VencimientoTxt+'</td>'+ 
                '<td data-label="Estado" class="vct-360-cell-status" style="width:8% !important;text-align:center !important;border-bottom:1px solid #edf1f5 !important;"><span class="vct-badge" data-vct-badge="'+EstadoBadge+'">'+EstadoVisual+'</span></td>'+ 
                '<td data-label="Fecha" class="vct-360-cell-date" style="width:8% !important;text-align:center !important;border-bottom:1px solid #edf1f5 !important;">'+FechaTxt+'</td>'+ 
            '</tr>'
        FROM
        (
            SELECT
                G.ID AS SortID,
                G.FECHA AS SortFecha,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.TITULO,''),'Gestión'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS GestionTitulo,
                REPLACE(REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(
                        ISNULL(NULLIF(G.TIPO,''),'')+
                        CASE WHEN NULLIF(G.TIPO,'') IS NOT NULL AND NULLIF(G.SUBTIPO,'') IS NOT NULL THEN ' · ' ELSE '' END+
                        ISNULL(NULLIF(G.SUBTIPO,''),'')+
                        CASE WHEN (NULLIF(G.TIPO,'') IS NOT NULL OR NULLIF(G.SUBTIPO,'') IS NOT NULL) AND NULLIF(G.RESULTADO,'') IS NOT NULL THEN ' · ' ELSE '' END+
                        ISNULL(NULLIF(G.RESULTADO,''),'')
                    )),
                    '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS GestionDetalle,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.CLIENTE_NOMBRE,''),'Sin cliente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ClienteNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.PROYECTO_CODIGO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.PROYECTO_NOMBRE,''),'Sin proyecto'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(G.PROYECTO_REFERENCIA,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoReferencia,
                CASE
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%VISITA%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%VISITA%' THEN 'calendar'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%DOCUMENT%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%DOCUMENT%' THEN 'file-text'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%LLAM%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%LLAM%' THEN 'phone'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%MAIL%' OR UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%EMAIL%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%MAIL%' THEN 'mail'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%REUN%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%REUN%' THEN 'users'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%CIERRE%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%CIERRE%PROYECTO%' THEN 'folder'
                    WHEN UPPER(ISNULL(G.TIPO,'')) LIKE '%TAREA%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%TAREA%' THEN 'list-checks'
                    ELSE 'clipboard-check'
                END AS GestionIcono,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(LTRIM(RTRIM(G.RESPONSABLE)),''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ResponsableNombre,
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(ISNULL(G.RESPONSABLE,''))),'') IS NULL THEN '--'
                    WHEN CHARINDEX(' ',LTRIM(RTRIM(G.RESPONSABLE)))>0
                        THEN UPPER(LEFT(LTRIM(RTRIM(G.RESPONSABLE)),1)+LEFT(REVERSE(LEFT(REVERSE(RTRIM(G.RESPONSABLE)),CHARINDEX(' ',REVERSE(RTRIM(G.RESPONSABLE))+' ')-1)),1))
                    ELSE UPPER(LEFT(LTRIM(RTRIM(G.RESPONSABLE)),2))
                END AS ResponsableIniciales,
                CASE ABS(CONVERT(BIGINT,CHECKSUM(ISNULL(G.RESPONSABLE,'')+'|'+CONVERT(VARCHAR(20),G.ID)))) % 8
                    WHEN 0 THEN '#F3DFE5' WHEN 1 THEN '#E3E4FA' WHEN 2 THEN '#DCEBF0' WHEN 3 THEN '#F3E1D9'
                    WHEN 4 THEN '#E4F2EA' WHEN 5 THEN '#F8E7D4' WHEN 6 THEN '#E7E1F5' ELSE '#E4EEF8'
                END AS ResponsableBg,
                CASE ABS(CONVERT(BIGINT,CHECKSUM(ISNULL(G.RESPONSABLE,'')+'|'+CONVERT(VARCHAR(20),G.ID)))) % 8
                    WHEN 0 THEN '#8B2E4A' WHEN 1 THEN '#5257A2' WHEN 2 THEN '#356D84' WHEN 3 THEN '#A05A3C'
                    WHEN 4 THEN '#3C7A57' WHEN 5 THEN '#A66324' WHEN 6 THEN '#6E55A5' ELSE '#3D6B94'
                END AS ResponsableTx,
                ISNULL(CONVERT(VARCHAR(10),G.VENCIMIENTO,103),'-') AS VencimientoTxt,
                ISNULL(CONVERT(VARCHAR(10),G.FECHA,103),'-') AS FechaTxt,
                REPLACE(REPLACE(REPLACE(REPLACE(
                    CASE
                        WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)<0 THEN 'VENCIDA'
                        WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)=0 THEN 'HOY'
                        ELSE UPPER(ISNULL(NULLIF(G.ESTADO,''),'SIN ESTADO'))
                    END,
                    '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS EstadoVisual,
                CASE
                    WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)<0 THEN 'VENCIDA'
                    WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)=0 THEN 'HOY'
                    ELSE ISNULL(G.ESTADO_CODIGO,'SIN ESTADO')
                END AS EstadoBadge
            FROM #GESTIONES360 G
        ) X
        ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END,SortFecha DESC,SortID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_GESTIONES=''
        SET @HTML_GESTIONES='<div class="vct-360-empty vct-360-fixed-empty">Sin gestiones registradas para el consultor.</div>';
    ELSE
        SET @HTML_GESTIONES=
            '<div data-vct-dg data-vct-dg-id="v360_con_gestiones" data-vct-dg-title="Gestiones del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="gestion(es)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar gestion, cliente, proyecto..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-width="4%" data-vct-export-ignore="true" aria-label="Tipo"></th><th data-vct-width="17%" data-vct-sort="gestion" data-vct-sortable="true"><span>Gestión</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="13%" data-vct-sort="cliente" data-vct-sortable="true"><span>Cliente</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="27%" data-vct-sort="proyecto" data-vct-sortable="true"><span>Proyecto</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="15%" data-vct-sort="responsable" data-vct-sortable="true"><span>Responsable</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="8%" data-vct-sort="vencimiento" data-vct-sortable="true" data-vct-sort-type="date"><span>Vencimiento</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="8%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="8%" data-vct-sort="fecha" data-vct-sortable="true" data-vct-sort-type="date"><span>Fecha</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th></tr></thead>'+
            '<tbody>'+@HTML_GESTIONES+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_GESTIONES_TOP=ISNULL((
        SELECT
            '<tr style="border-bottom:1px solid #edf1f5;">'+
                '<td data-label="" class="vct-360-cell-management-icon" aria-hidden="true" style="border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-management-type-icon"><span data-vct-icon="'+GestionIcono+'"></span></span>'+
                '</td>'+
                '<td data-label="Gestión" class="vct-360-cell-management" style="border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">'+GestionTitulo+'</span>'+
                    CASE WHEN SubtipoTxt<>'' THEN '<span class="vct-360-project-ref">'+SubtipoTxt+'</span>' ELSE '' END+
                '</td>'+
                '<td data-label="Cliente" class="vct-360-cell-client" style="border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">'+ClienteNombre+'</span>'+
                '</td>'+
                '<td data-label="Proyecto" class="vct-360-cell-management-project vct-360-cell-project" style="border-bottom:1px solid #edf1f5 !important;">'+
                    '<span class="vct-360-project-name">('+ProyectoCodigo+') '+ProyectoNombre+'</span>'+
                    CASE WHEN ProyectoReferencia<>'' THEN '<span class="vct-360-project-ref">'+ProyectoReferencia+'</span>' ELSE '' END+
                '</td>'+
                '<td data-label="Asignado" class="vct-360-cell-person" style="border-bottom:1px solid #edf1f5 !important;">'+
                    CASE WHEN ResponsableNombre='-' THEN '-'
                         ELSE '<span class="vct-360-person-inline">'+
                              '<span class="vct-360-contact-avatar vct-360-contact-avatar-sm" style="--vct-avatar-bg:'+ResponsableBg+';--vct-avatar-color:'+ResponsableTx+';">'+ResponsableIniciales+'</span>'+
                              '<span class="vct-360-person-name">'+ResponsableNombre+'</span>'+
                              '</span>' END+
                '</td>'+
                '<td data-label="Estado" class="vct-360-cell-status" style="border-bottom:1px solid #edf1f5 !important;"><span class="vct-badge" data-vct-badge="'+EstadoBadge+'">'+EstadoVisual+'</span></td>'+
                '<td data-label="Fecha" class="vct-360-cell-date" style="border-bottom:1px solid #edf1f5 !important;">'+FechaTxt+'</td>'+
            '</tr>'
        FROM
        (
            SELECT TOP 5
                G.ID AS SortID,
                G.FECHA AS SortFecha,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.TITULO,''),'Gestión'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS GestionTitulo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(G.SUBTIPO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS SubtipoTxt,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.CLIENTE_NOMBRE,''),'Sin cliente'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ClienteNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.PROYECTO_CODIGO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoCodigo,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(G.PROYECTO_NOMBRE,''),'Sin proyecto'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoNombre,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(G.PROYECTO_REFERENCIA,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ProyectoReferencia,
                CASE
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%VISITA%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%VISITA%' THEN 'calendar'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%DOCUMENT%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%DOCUMENT%' THEN 'file-text'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%LLAM%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%LLAM%' THEN 'phone'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%MAIL%' OR UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%EMAIL%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%MAIL%' THEN 'mail'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%REUN%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%REUN%' THEN 'users'
                    WHEN UPPER(ISNULL(G.SUBTIPO,'')) LIKE '%CIERRE%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%CIERRE%PROYECTO%' THEN 'folder'
                    WHEN UPPER(ISNULL(G.TIPO,'')) LIKE '%TAREA%' OR UPPER(ISNULL(G.TITULO,'')) LIKE '%TAREA%' THEN 'list-checks'
                    ELSE 'clipboard-check'
                END AS GestionIcono,
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(LTRIM(RTRIM(G.RESPONSABLE)),''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS ResponsableNombre,
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(ISNULL(G.RESPONSABLE,''))),'') IS NULL THEN '--'
                    WHEN CHARINDEX(' ',LTRIM(RTRIM(G.RESPONSABLE)))>0
                        THEN UPPER(LEFT(LTRIM(RTRIM(G.RESPONSABLE)),1)+LEFT(REVERSE(LEFT(REVERSE(RTRIM(G.RESPONSABLE)),CHARINDEX(' ',REVERSE(RTRIM(G.RESPONSABLE))+' ')-1)),1))
                    ELSE UPPER(LEFT(LTRIM(RTRIM(G.RESPONSABLE)),2))
                END AS ResponsableIniciales,
                CASE ABS(CONVERT(BIGINT,CHECKSUM(ISNULL(G.RESPONSABLE,'')+'|'+CONVERT(VARCHAR(20),G.ID)))) % 8
                    WHEN 0 THEN '#F3DFE5' WHEN 1 THEN '#E3E4FA' WHEN 2 THEN '#DCEBF0' WHEN 3 THEN '#F3E1D9'
                    WHEN 4 THEN '#E4F2EA' WHEN 5 THEN '#F8E7D4' WHEN 6 THEN '#E7E1F5' ELSE '#E4EEF8'
                END AS ResponsableBg,
                CASE ABS(CONVERT(BIGINT,CHECKSUM(ISNULL(G.RESPONSABLE,'')+'|'+CONVERT(VARCHAR(20),G.ID)))) % 8
                    WHEN 0 THEN '#8B2E4A' WHEN 1 THEN '#5257A2' WHEN 2 THEN '#356D84' WHEN 3 THEN '#A05A3C'
                    WHEN 4 THEN '#3C7A57' WHEN 5 THEN '#A66324' WHEN 6 THEN '#6E55A5' ELSE '#3D6B94'
                END AS ResponsableTx,
                ISNULL(CONVERT(VARCHAR(10),G.FECHA,103),'-') AS FechaTxt,
                REPLACE(REPLACE(REPLACE(REPLACE(
                    CASE
                        WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)<0 THEN 'VENCIDA'
                        WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)=0 THEN 'HOY'
                        ELSE UPPER(ISNULL(NULLIF(G.ESTADO,''),'SIN ESTADO'))
                    END,
                    '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;') AS EstadoVisual,
                CASE
                    WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)<0 THEN 'VENCIDA'
                    WHEN ISNULL(G.ES_FINAL,0)=0 AND G.VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.VENCIMIENTO)=0 THEN 'HOY'
                    ELSE ISNULL(G.ESTADO_CODIGO,'SIN ESTADO')
                END AS EstadoBadge
            FROM #GESTIONES360 G
            ORDER BY CASE WHEN G.FECHA IS NULL THEN 1 ELSE 0 END,G.FECHA DESC,G.ID DESC
        ) X
        ORDER BY CASE WHEN SortFecha IS NULL THEN 1 ELSE 0 END,SortFecha DESC,SortID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_GESTIONES_TOP=''
        SET @HTML_GESTIONES_TOP='<div class="vct-360-empty vct-360-fixed-empty">Sin gestiones registradas todavía.</div>';
    ELSE
        SET @HTML_GESTIONES_TOP=
            '<div class="vct-360-gestiones-recent vct-360-gestiones-recent-full">'+
                '<table class="vct-360-table vct-360-management-table-recent">'+
                    '<colgroup>'+
                        '<col style="width:4%">'+
                        '<col style="width:20%">'+
                        '<col style="width:16%">'+
                        '<col style="width:27%">'+
                        '<col style="width:15%">'+
                        '<col style="width:10%">'+
                        '<col style="width:8%">'+
                    '</colgroup>'+
                    '<thead><tr>'+
                        '<th aria-label="Tipo"></th>'+
                        '<th>Gestión</th>'+
                        '<th>Cliente</th>'+
                        '<th>Proyecto</th>'+
                        '<th>Asignado</th>'+
                        '<th>Estado</th>'+
                        '<th>Fecha</th>'+
                    '</tr></thead>'+
                    '<tbody>'+@HTML_GESTIONES_TOP+'</tbody>'+
                '</table>'+
            '</div>';
 
    /* ============================================================
       15. HTML DOMICILIOS / TELEFONOS / EMAILS
       ============================================================ */
    DECLARE
        @HTML_DOMICILIOS VARCHAR(MAX)='',
        @HTML_TELEFONOS VARCHAR(MAX)='',
        @HTML_EMAILS VARCHAR(MAX)='';
 
    SELECT @HTML_DOMICILIOS=ISNULL((
        SELECT
            '<tr data-vct-row '+
            'data-vct-id="'+CONVERT(VARCHAR(100),D.ID)+'" '+
            'data-vct-calle="'+REPLACE(REPLACE(ISNULL(D.CALLE,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-nro="'+REPLACE(REPLACE(ISNULL(D.NRO,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-piso="'+REPLACE(REPLACE(ISNULL(D.PISO,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-depto="'+REPLACE(REPLACE(ISNULL(D.DEPTO,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-localidad="'+REPLACE(REPLACE(ISNULL(D.LOCALIDAD,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-provincia="'+REPLACE(REPLACE(ISNULL(D.PROVINCIA,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-principal="'+CASE WHEN UPPER(ISNULL(D.PRINCIPAL,''))='SI' THEN '1' ELSE '0' END+'" '+
            'data-vct-observaciones="'+REPLACE(REPLACE(ISNULL(D.OBSERVACIONES,''),'"','&quot;'),'''','&#39;')+'">'+
            '<td data-label="Dirección">'+
                REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(ISNULL(D.CALLE,'')+
                    CASE WHEN ISNULL(D.NRO,'')<>'' THEN ' '+D.NRO ELSE '' END)),
                    '&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td class="vct-text-center" data-label="Piso / Depto">'+
                REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(ISNULL(D.PISO,'')+
                    CASE WHEN ISNULL(D.DEPTO,'')<>'' THEN ' '+D.DEPTO ELSE '' END)),
                    '&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td data-label="Localidad">'+REPLACE(REPLACE(REPLACE(ISNULL(D.LOCALIDAD,'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
            '<td data-label="Provincia">'+REPLACE(REPLACE(REPLACE(ISNULL(D.PROVINCIA,'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
            '<td class="vct-text-center" data-label="Tipo">'+
                CASE WHEN UPPER(ISNULL(D.PRINCIPAL,''))='SI'
                     THEN '<span class="vct-360-badge is-active">Principal</span>'
                     ELSE '<span class="vct-360-badge is-neutral">Secundario</span>' END+
            '</td>'+
            '<td data-label="Observaciones">'+
                REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(D.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">'+
                CASE WHEN @CAN_EDIT=1 AND @DOM_MODE<>'NONE'
                     THEN '<button type="button" class="vct-row-menu-trigger" '+
                          'data-vct-command="row-context-menu" '+
                          'data-vct-target="vctDrawerConsultorDomicilio" '+
                          'data-vct-entity="DOMICILIO" data-vct-tab="domicilio" '+
                          'data-vct-form-title="Editar domicilio" '+
                          'data-vct-form-subtitle="Modifique los datos de la dirección." '+
                          'data-vct-form-icon="map-pin" aria-label="Acciones">'+
                          '<span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                     ELSE '' END+
            '</td>'+
            '</tr>'
        FROM #DOMICILIOS360 D
        ORDER BY CASE WHEN UPPER(ISNULL(D.PRINCIPAL,''))='SI' THEN 0 ELSE 1 END,D.ID
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @DOM_MODE='NONE'
        SET @HTML_DOMICILIOS=
            '<div class="vct-360-empty vct-360-fixed-empty">La tabla VCT_DOMICILIOS todavía no posee relación con Consultores.</div>';
    ELSE IF @HTML_DOMICILIOS=''
        SET @HTML_DOMICILIOS=
            '<div class="vct-360-empty vct-360-fixed-empty">Sin domicilios registrados.</div>';
    ELSE
        SET @HTML_DOMICILIOS=
            '<div data-vct-dg data-vct-dg-id="v360_con_dom" data-vct-dg-title="Domicilios del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="domicilio(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar domicilio..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-sort="direccion" data-vct-sortable="true"><span>Dirección</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="11%" data-vct-sort="piso" data-vct-sortable="true"><span>Piso / Depto</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="15%" data-vct-sort="localidad" data-vct-sortable="true"><span>Localidad</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="14%" data-vct-sort="provincia" data-vct-sortable="true"><span>Provincia</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="11%" data-vct-sort="tipo" data-vct-sortable="true"><span>Tipo</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="18%" data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th></tr></thead>'+
            '<tbody>'+@HTML_DOMICILIOS+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_TELEFONOS=ISNULL((
        SELECT
            '<tr data-vct-row '+
            'data-vct-id="'+CONVERT(VARCHAR(100),T.ID)+'" '+
            'data-vct-codarea="'+REPLACE(REPLACE(ISNULL(T.CODAREA,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-nro="'+REPLACE(REPLACE(ISNULL(T.NRO,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-principal="'+CASE WHEN UPPER(ISNULL(T.PRINCIPAL,''))='SI' THEN '1' ELSE '0' END+'" '+
            'data-vct-observaciones="'+REPLACE(REPLACE(ISNULL(T.OBSERVACIONES,''),'"','&quot;'),'''','&#39;')+'">'+
            '<td class="vct-text-center" data-label="Código área">'+ISNULL(NULLIF(T.CODAREA,''),'-')+'</td>'+
            '<td data-label="Número">'+ISNULL(NULLIF(T.NRO,''),'-')+'</td>'+
            '<td class="vct-text-center" data-label="Tipo">'+
                CASE WHEN UPPER(ISNULL(T.PRINCIPAL,''))='SI'
                     THEN '<span class="vct-360-badge is-active">Principal</span>'
                     ELSE '<span class="vct-360-badge is-neutral">Secundario</span>' END+
            '</td>'+
            '<td data-label="Observaciones">'+
                REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(T.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">'+
                CASE WHEN @CAN_EDIT=1 AND @TEL_MODE<>'NONE'
                     THEN '<button type="button" class="vct-row-menu-trigger" '+
                          'data-vct-command="row-context-menu" '+
                          'data-vct-target="vctDrawerConsultorTelefono" '+
                          'data-vct-entity="TELEFONO" data-vct-tab="telefonos" '+
                          'data-vct-form-title="Editar teléfono" '+
                          'data-vct-form-subtitle="Modifique el teléfono seleccionado." '+
                          'data-vct-form-icon="phone" aria-label="Acciones">'+
                          '<span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                     ELSE '' END+
            '</td>'+
            '</tr>'
        FROM #TELEFONOS360 T
        ORDER BY CASE WHEN UPPER(ISNULL(T.PRINCIPAL,''))='SI' THEN 0 ELSE 1 END,T.ID
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @TEL_MODE='NONE'
        SET @HTML_TELEFONOS=
            '<div class="vct-360-empty vct-360-fixed-empty">La tabla VCT_TELEFONOS todavía no posee relación con Consultores.</div>';
    ELSE IF @HTML_TELEFONOS=''
        SET @HTML_TELEFONOS=
            '<div class="vct-360-empty vct-360-fixed-empty">Sin teléfonos registrados.</div>';
    ELSE
        SET @HTML_TELEFONOS=
            '<div data-vct-dg data-vct-dg-id="v360_con_tel" data-vct-dg-title="Telefonos del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="telefono(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar telefono..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th class="vct-text-center" data-vct-width="14%" data-vct-sort="codarea" data-vct-sortable="true"><span>Código área</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="20%" data-vct-sort="numero" data-vct-sortable="true"><span>Número</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="14%" data-vct-sort="tipo" data-vct-sortable="true"><span>Tipo</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th></tr></thead>'+
            '<tbody>'+@HTML_TELEFONOS+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_EMAILS=ISNULL((
        SELECT
            '<tr data-vct-row '+
            'data-vct-id="'+CONVERT(VARCHAR(100),E.ID)+'" '+
            'data-vct-email="'+REPLACE(REPLACE(ISNULL(E.EMAIL,''),'"','&quot;'),'''','&#39;')+'" '+
            'data-vct-principal="'+CASE WHEN UPPER(ISNULL(E.PRINCIPAL,''))='SI' THEN '1' ELSE '0' END+'" '+
            'data-vct-observaciones="'+REPLACE(REPLACE(ISNULL(E.OBSERVACIONES,''),'"','&quot;'),'''','&#39;')+'">'+
            '<td data-label="Email">'+
                REPLACE(REPLACE(REPLACE(ISNULL(E.EMAIL,'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td class="vct-text-center" data-label="Tipo">'+
                CASE WHEN UPPER(ISNULL(E.PRINCIPAL,''))='SI'
                     THEN '<span class="vct-360-badge is-active">Principal</span>'
                     ELSE '<span class="vct-360-badge is-neutral">Secundario</span>' END+
            '</td>'+
            '<td data-label="Observaciones">'+
                REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(E.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+
            '</td>'+
            '<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">'+
                CASE WHEN @CAN_EDIT=1 AND @MAIL_MODE<>'NONE'
                     THEN '<button type="button" class="vct-row-menu-trigger" '+
                          'data-vct-command="row-context-menu" '+
                          'data-vct-target="vctDrawerConsultorEmail" '+
                          'data-vct-entity="EMAIL" data-vct-tab="email" '+
                          'data-vct-form-title="Editar email" '+
                          'data-vct-form-subtitle="Modifique el email seleccionado." '+
                          'data-vct-form-icon="mail" aria-label="Acciones">'+
                          '<span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                     ELSE '' END+
            '</td>'+
            '</tr>'
        FROM #EMAILS360 E
        ORDER BY CASE WHEN UPPER(ISNULL(E.PRINCIPAL,''))='SI' THEN 0 ELSE 1 END,E.ID
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @MAIL_MODE='NONE'
        SET @HTML_EMAILS=
            '<div class="vct-360-empty vct-360-fixed-empty">La tabla VCT_EMAILS todavía no posee relación con Consultores.</div>';
    ELSE IF @HTML_EMAILS=''
        SET @HTML_EMAILS=
            '<div class="vct-360-empty vct-360-fixed-empty">Sin emails registrados.</div>';
    ELSE
        SET @HTML_EMAILS=
            '<div data-vct-dg data-vct-dg-id="v360_con_mail" data-vct-dg-title="Emails del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="email(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar email..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-sort="email" data-vct-sortable="true"><span>Email</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="14%" data-vct-sort="tipo" data-vct-sortable="true"><span>Tipo</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="34%" data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th></tr></thead>'+
            '<tbody>'+@HTML_EMAILS+'</tbody>'+
            '</table>'+
            '</div>';
 
    /* ============================================================
       15.B HTML NORMAS / HISTORICO / DOCUMENTOS / NOTAS
       ============================================================ */
    DECLARE
        @HTML_NORMAS VARCHAR(MAX)='',
        @HTML_SERVICIOS VARCHAR(MAX)='',
        @HTML_HISTORICO VARCHAR(MAX)='',
        @HTML_DOCUMENTOS VARCHAR(MAX)='',
        @HTML_NOTAS VARCHAR(MAX)='',
        @NormHasEstado BIT=0,
        @NormHasDesde BIT=0,
        @NormHasHasta BIT=0,
        @HistHasProject BIT=0,
        @HistHasObs BIT=0,
        @HTML_NORMAS_COLGROUP VARCHAR(MAX)='',
        @HTML_HIST_COLGROUP VARCHAR(MAX)='';
 
    SELECT @NormHasEstado=CASE WHEN EXISTS(SELECT 1 FROM #NORMAS360 WHERE NULLIF(LTRIM(RTRIM(ISNULL(ESTADO,''))),'') IS NOT NULL) THEN 1 ELSE 0 END;
    SELECT @NormHasDesde=CASE WHEN EXISTS(SELECT 1 FROM #NORMAS360 WHERE FECHA_DESDE IS NOT NULL) THEN 1 ELSE 0 END;
    SELECT @NormHasHasta=CASE WHEN EXISTS(SELECT 1 FROM #NORMAS360 WHERE FECHA_HASTA IS NOT NULL) THEN 1 ELSE 0 END;
 
    SET @HTML_NORMAS_COLGROUP=
        '<colgroup>'+ 
        CASE
            WHEN @NormHasDesde=1 AND @NormHasHasta=1 THEN '<col style="width:28%">'
            WHEN @NormHasDesde=1 OR @NormHasHasta=1 THEN '<col style="width:31%">'
            WHEN @NormHasEstado=1 THEN '<col style="width:34%">'
            ELSE '<col style="width:38%">' END+
        CASE WHEN @NormHasEstado=1 THEN '<col style="width:16%">' ELSE '' END+
        CASE WHEN @NormHasDesde=1 THEN '<col style="width:12%">' ELSE '' END+
        CASE WHEN @NormHasHasta=1 THEN '<col style="width:12%">' ELSE '' END+
        '<col style="width:'+
        CONVERT(VARCHAR(3),100-
            CASE WHEN @NormHasDesde=1 AND @NormHasHasta=1 THEN 28
                 WHEN @NormHasDesde=1 OR @NormHasHasta=1 THEN 31
                 WHEN @NormHasEstado=1 THEN 34 ELSE 38 END-
            CASE WHEN @NormHasEstado=1 THEN 16 ELSE 0 END-
            CASE WHEN @NormHasDesde=1 THEN 12 ELSE 0 END-
            CASE WHEN @NormHasHasta=1 THEN 12 ELSE 0 END-6)+'%">'+
        '<col style="width:6%">'+
        '</colgroup>';
 
    DECLARE @HTML_NORMAS_FILTRO VARCHAR(MAX)='';
    IF OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NOT NULL
        SELECT @HTML_NORMAS_FILTRO=ISNULL((
            SELECT '<option value="'+REPLACE(REPLACE(REPLACE(ISNULL(PS.DESCRIPCION,''),'&','&amp;'),'<','&lt;'),'"','&quot;')+'">'+
                   REPLACE(REPLACE(REPLACE(ISNULL(PS.DESCRIPCION,''),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</option>'
            FROM dbo.VCT_PRM_SERVICIOS PS WITH(NOLOCK)
            WHERE UPPER(ISNULL(PS.ESTADO,'ACTIVO'))='ACTIVO'
            ORDER BY PS.DESCRIPCION
            FOR XML PATH(''),TYPE).value('.','VARCHAR(MAX)'),'');

    SELECT @HTML_NORMAS=ISNULL((
        SELECT
            '<tr data-vct-row '+
                'data-vct-id="'+CONVERT(VARCHAR(100),N.ID)+'" '+
                'data-vct-idnorma="'+ISNULL(CONVERT(VARCHAR(100),N.ID_NORMA),'')+'" '+
                'data-vct-filter-servicio="'+REPLACE(REPLACE(ISNULL(N.SERVICIO,''),'"','&quot;'),'''','&#39;')+'" '+
                'data-vct-search="'+REPLACE(REPLACE(ISNULL(N.SERVICIO,''),'"','&quot;'),'''','&#39;')+'" '+
                'data-vct-calificacion="'+REPLACE(REPLACE(ISNULL(N.ESTADO,''),'"','&quot;'),'''','&#39;')+'" '+
                'data-vct-desde="'+CASE WHEN N.FECHA_DESDE IS NULL THEN '' ELSE CONVERT(VARCHAR(10),N.FECHA_DESDE,23) END+'" '+
                'data-vct-observaciones="'+REPLACE(REPLACE(ISNULL(N.OBSERVACIONES,''),'"','&quot;'),'''','&#39;')+'">'+
                '<td class="vct-360-wrap-cell" data-label="Norma">'+
                    '<span class="vct-360-project-name">'+
                    REPLACE(REPLACE(REPLACE(REPLACE(
                        LTRIM(RTRIM(
                            CASE
                                WHEN ISNULL(N.NOMBRE,'')<>'' THEN N.NOMBRE
                                WHEN ISNULL(N.CODIGO,'')<>'' THEN N.CODIGO
                                ELSE 'Norma #'+CONVERT(VARCHAR(20),N.ID)
                            END)),
                        '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                    '</span>'+
                    CASE WHEN ISNULL(N.CODIGO,'')<>'' AND ISNULL(N.NOMBRE,'')<>'' AND UPPER(LTRIM(RTRIM(N.CODIGO)))<>UPPER(LTRIM(RTRIM(N.NOMBRE)))
                         THEN '<span class="vct-360-project-ref">'+REPLACE(REPLACE(REPLACE(REPLACE(N.CODIGO,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'</span>'
                         ELSE '' END+
                '</td>'+ 
                '<td data-label="Servicio" data-vct-sort-value="'+REPLACE(REPLACE(ISNULL(N.SERVICIO,''),'"','&quot;'),'''','&#39;')+'">'+
                    CASE WHEN ISNULL(N.SERVICIO,'')='' THEN '-' ELSE '<span class="vct-serv-chip '+CASE WHEN UPPER(N.SERVICIO) LIKE '%AUDITOR%' THEN 'is-auditoria' WHEN UPPER(N.SERVICIO) LIKE '%CAPACIT%' THEN 'is-capacitacion' WHEN UPPER(N.SERVICIO) LIKE '%CONSULT%' THEN 'is-consultoria' ELSE 'is-neutral' END+'">'+REPLACE(REPLACE(REPLACE(N.SERVICIO,'&','&amp;'),'<','&lt;'),'>','&gt;')+'</span>' END+
                '</td>'+
                CASE WHEN @NormHasEstado=1 THEN
                    '<td class="vct-text-center" data-label="'+@NORMA_ESTADO_LABEL+'"><span class="vct-360-badge '+
                        CASE
                            WHEN UPPER(REPLACE(ISNULL(N.ESTADO,''),' ','')) IN ('VIGENTE','ACTIVO','ACTIVA','OK','CUMPLIDA','CUMPLIDO','LIDER','LÍDER','SENIOR','AVANZADO') THEN 'is-active'
                            WHEN UPPER(REPLACE(ISNULL(N.ESTADO,''),' ','')) IN ('VENCIDA','VENCIDO','CANCELADA','CANCELADO','NOAPTO') THEN 'is-cancel'
                            WHEN UPPER(REPLACE(ISNULL(N.ESTADO,''),' ','')) IN ('PENDIENTE','PORRENOVAR','PROGRAMADA','PROGRAMADO','ENCURSO') THEN 'is-planned'
                            ELSE 'is-neutral' END+'">'+
                        REPLACE(REPLACE(REPLACE(UPPER(ISNULL(NULLIF(N.ESTADO,''),'-')),'&','&amp;'),'<','&lt;'),'>','&gt;')+
                    '</span></td>' ELSE '' END+
                CASE WHEN @NormHasDesde=1 THEN '<td class="vct-text-center" data-label="Desde">'+CASE WHEN N.FECHA_DESDE IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),N.FECHA_DESDE,103) END+'</td>' ELSE '' END+
                CASE WHEN @NormHasHasta=1 THEN '<td class="vct-text-center" data-label="Hasta">'+CASE WHEN N.FECHA_HASTA IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),N.FECHA_HASTA,103) END+'</td>' ELSE '' END+
                '<td class="vct-360-wrap-cell" data-label="Observaciones">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(N.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+ 
                '<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">'+
                    CASE WHEN @CAN_EDIT=1 AND @NORM_TABLE_CRUD<>'' AND @NORM_LINK_COL<>'' AND @NORM_IDNORMA_COL<>''
                         THEN '<button type="button" class="vct-row-menu-trigger" '+
                              'data-vct-command="row-context-menu" data-vct-actions="edit" '+
                              'data-vct-target="vctDrawerConsultorNorma" '+
                              'data-vct-entity="NORMA" data-vct-tab="normas" '+
                              'data-vct-form-title="Editar norma" '+
                              'data-vct-form-subtitle="Modifique la norma asociada al consultor." '+
                              'data-vct-form-icon="clipboard-check" aria-label="Acciones">'+
                              '<span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                         ELSE '' END+
                '</td>'+ 
            '</tr>'
        FROM #NORMAS360 N
        ORDER BY CASE WHEN N.FECHA_HASTA IS NULL THEN 1 ELSE 0 END,N.FECHA_HASTA,N.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_NORMAS=''
        SET @HTML_NORMAS='<div class="vct-360-empty vct-360-fixed-empty">Sin normas relacionadas al consultor.</div>';
    ELSE
        SET @HTML_NORMAS=
            '<div data-vct-dg data-vct-dg-id="v360_con_normas" data-vct-dg-title="Normas del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="norma(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar norma..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            CASE WHEN @HTML_NORMAS_FILTRO<>'' THEN '<div data-vct-dg-slot="filters"><select class="vct-select vct-select-sm" data-vct-dg-filter="servicio" aria-label="Servicio"><option value="">Todos los servicios</option>'+@HTML_NORMAS_FILTRO+'</select></div>' ELSE '' END+
            '<table>'+
            '<thead><tr>'+'<th data-vct-sort="norma" data-vct-sortable="true"><span>Norma</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'+'<th data-vct-width="16%" data-vct-sort="servicio" data-vct-sortable="true"><span>Servicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'+CASE WHEN @NormHasEstado=1 THEN '<th class="vct-text-center" data-vct-width="14%" data-vct-sort="estado" data-vct-sortable="true"><span>'+@NORMA_ESTADO_LABEL+'</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END+CASE WHEN @NormHasDesde=1 THEN '<th class="vct-text-center" data-vct-width="11%" data-vct-sort="desde" data-vct-sortable="true" data-vct-sort-type="date"><span>'+'Desde'+'</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END+CASE WHEN @NormHasHasta=1 THEN '<th class="vct-text-center" data-vct-width="11%" data-vct-sort="hasta" data-vct-sortable="true" data-vct-sort-type="date"><span>'+'Hasta'+'</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END+'<th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'+'<th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th>'+'</tr></thead>'+
            '<tbody>'+@HTML_NORMAS+'</tbody>'+
            '</table>'+
            '</div>';
 
    /* Grilla de Servicios del consultor */
    SELECT @HTML_SERVICIOS=ISNULL((
        SELECT
            '<tr data-vct-row '+
                'data-vct-id="'+CONVERT(VARCHAR(100),S.ID)+'" '+
                'data-vct-idservicio="'+ISNULL(CONVERT(VARCHAR(100),S.ID_SERVICIO),'')+'" '+
                'data-vct-observaciones="'+REPLACE(REPLACE(ISNULL(S.OBSERVACIONES,''),'"','&quot;'),'''','&#39;')+'">'+
                '<td data-label="Servicio"><span class="vct-serv-chip '+CASE WHEN UPPER(ISNULL(S.SERVICIO,'')) LIKE '%AUDITOR%' THEN 'is-auditoria' WHEN UPPER(ISNULL(S.SERVICIO,'')) LIKE '%CAPACIT%' THEN 'is-capacitacion' WHEN UPPER(ISNULL(S.SERVICIO,'')) LIKE '%CONSULT%' THEN 'is-consultoria' ELSE 'is-neutral' END+'">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.SERVICIO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</span></td>'+
                '<td class="vct-360-wrap-cell" data-label="Observaciones">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(S.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
                '<td class="vct-text-center" data-label="Desde">'+CASE WHEN S.FECHA_ALTA IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),S.FECHA_ALTA,103) END+'</td>'+
                '<td class="vct-360-action-cell vct-table-action-cell" data-label="Acciones" data-vct-export-ignore="true">'+
                    CASE WHEN @CAN_EDIT=1 AND OBJECT_ID('dbo.VCT_CONSULTORES_SERVICIOS','U') IS NOT NULL
                         THEN '<button type="button" class="vct-row-menu-trigger" data-vct-command="row-context-menu" data-vct-actions="edit" data-vct-target="vctDrawerConsultorServicio" data-vct-entity="SERVCONS" data-vct-tab="servicios" data-vct-form-title="Editar servicio" data-vct-form-subtitle="Modifique el servicio del consultor." data-vct-form-icon="briefcase" aria-label="Acciones"><span class="vct-row-menu-dots" aria-hidden="true">&#8942;</span></button>'
                         ELSE '' END+
                '</td>'+
            '</tr>'
        FROM #SERVICIOS360 S
        ORDER BY S.SERVICIO
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');

    IF @HTML_SERVICIOS=''
        SET @HTML_SERVICIOS='<div class="vct-360-empty vct-360-fixed-empty">El consultor no tiene servicios asignados.</div>';
    ELSE
        SET @HTML_SERVICIOS=
            '<div data-vct-dg data-vct-dg-id="v360_con_servicios" data-vct-dg-title="Servicios del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="servicio(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar servicio..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-sort="servicio" data-vct-sortable="true"><span>Servicio</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="14%" data-vct-sort="desde" data-vct-sortable="true" data-vct-sort-type="date"><span>Desde</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-col-action" data-vct-width="44" data-vct-export-ignore="true"></th></tr></thead>'+
            '<tbody>'+@HTML_SERVICIOS+'</tbody>'+
            '</table>'+
            '</div>';

    SELECT @HistHasProject=CASE WHEN EXISTS(SELECT 1 FROM #HIST_DIAS360 WHERE NULLIF(LTRIM(RTRIM(ISNULL(PROYECTO,''))),'') IS NOT NULL) THEN 1 ELSE 0 END;
    SELECT @HistHasObs=CASE WHEN EXISTS(SELECT 1 FROM #HIST_DIAS360 WHERE NULLIF(LTRIM(RTRIM(ISNULL(OBSERVACIONES,''))),'') IS NOT NULL) THEN 1 ELSE 0 END;
 
    SET @HTML_HIST_COLGROUP=
        '<colgroup>'+ 
        CASE
            WHEN @HistHasProject=1 AND @HistHasObs=1 THEN '<col style="width:18%"><col style="width:34%"><col style="width:12%"><col style="width:36%">'
            WHEN @HistHasProject=1 THEN '<col style="width:20%"><col style="width:60%"><col style="width:20%">'
            WHEN @HistHasObs=1 THEN '<col style="width:20%"><col style="width:18%"><col style="width:62%">'
            ELSE '<col style="width:55%"><col style="width:45%">' END+
        '</colgroup>';
 
    SELECT @HTML_HISTORICO=ISNULL((
        SELECT
            '<tr data-vct-row>'+ 
                '<td class="vct-text-center" data-label="Período" data-vct-sort-value="'+CASE WHEN H.FECHA IS NOT NULL THEN CONVERT(VARCHAR(6),H.FECHA,112) ELSE '0' END+'">'+
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(H.PERIODO,''))),'') IS NOT NULL THEN H.PERIODO
                        WHEN H.FECHA IS NOT NULL THEN RIGHT('0'+CONVERT(VARCHAR(2),MONTH(H.FECHA)),2)+'/'+CONVERT(VARCHAR(4),YEAR(H.FECHA))
                        ELSE '-' END+
                '</td>'+ 
                CASE WHEN @HistHasProject=1 THEN '<td class="vct-360-wrap-cell" data-label="Proyecto">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(H.PROYECTO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>' ELSE '' END+
                '<td class="vct-text-center" data-label="Días" data-vct-sort-value="'+CONVERT(VARCHAR(30),CAST(ROUND(ISNULL(H.DIAS,0)*100,0) AS BIGINT))+'">'+REPLACE(CONVERT(VARCHAR(40),CONVERT(DECIMAL(18,2),ISNULL(H.DIAS,0))),'.',',')+'</td>'+ 
                CASE WHEN @HistHasObs=1 THEN '<td class="vct-360-wrap-cell" data-label="Observaciones">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(H.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>' ELSE '' END+
            '</tr>'
        FROM #HIST_DIAS360 H
        ORDER BY CASE WHEN H.FECHA IS NULL THEN 1 ELSE 0 END,H.FECHA DESC,H.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_HISTORICO=''
        SET @HTML_HISTORICO='<div class="vct-360-empty vct-360-fixed-empty">Sin histórico de días relacionado al consultor.</div>';
    ELSE
        SET @HTML_HISTORICO=
            '<div data-vct-dg data-vct-dg-id="v360_con_hist" data-vct-dg-title="Dias mensuales del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="periodo(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar periodo, proyecto..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr>'+'<th class="vct-text-center" data-vct-width="14%" data-vct-sort="periodo" data-vct-sortable="true" data-vct-sort-type="number"><span>Período</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'+CASE WHEN @HistHasProject=1 THEN '<th data-vct-sort="proyecto" data-vct-sortable="true"><span>'+'Proyecto'+'</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END+'<th class="vct-text-center" data-vct-width="12%" data-vct-sort="dias" data-vct-sortable="true" data-vct-sort-type="number"><span>Días</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>'+CASE WHEN @HistHasObs=1 THEN '<th data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>'+'Observaciones'+'</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th>' ELSE '' END+'</tr></thead>'+
            '<tbody>'+@HTML_HISTORICO+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_DOCUMENTOS=ISNULL((
        SELECT
            '<tr data-vct-row>'+
                '<td data-label="Tipo">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(D.TIPO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
                '<td data-label="Documento"><span class="vct-360-project-name">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(D.NOMBRE,''),'Documento'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</span></td>'+
                '<td class="vct-text-center" data-label="Estado"><span class="vct-360-badge '+
                    CASE
                        WHEN UPPER(REPLACE(ISNULL(D.ESTADO,''),' ','')) IN ('VIGENTE','ACTIVO','ACTIVA','OK','ABIERTO','ABIERTA') THEN 'is-active'
                        WHEN UPPER(REPLACE(ISNULL(D.ESTADO,''),' ','')) IN ('CANCELADO','CANCELADA') THEN 'is-cancel'
                        WHEN UPPER(REPLACE(ISNULL(D.ESTADO,''),' ','')) IN ('CERRADO','CERRADA','FINALIZADO','FINALIZADA','HISTORICO') THEN 'is-done'
                        WHEN UPPER(REPLACE(ISNULL(D.ESTADO,''),' ',''))='PENDIENTE' THEN 'is-planned'
                        WHEN ISNULL(D.ESTADO,'')='' AND D.FECHA_VENCIMIENTO IS NOT NULL THEN 'is-done'
                        ELSE 'is-neutral' END+'">'+
                    REPLACE(REPLACE(REPLACE(
                        CASE WHEN ISNULL(D.ESTADO,'')=''
                             THEN CASE WHEN D.FECHA_VENCIMIENTO IS NOT NULL THEN 'CERRADO' ELSE 'SIN ESTADO' END
                             ELSE UPPER(D.ESTADO) END,
                        '&','&amp;'),'<','&lt;'),'>','&gt;')+
                '</span></td>'+
                '<td class="vct-text-center" data-label="Emisión">'+CASE WHEN D.FECHA_EMISION IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),D.FECHA_EMISION,103) END+'</td>'+
                '<td class="vct-text-center" data-label="Cierre">'+CASE WHEN D.FECHA_VENCIMIENTO IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),D.FECHA_VENCIMIENTO,103) END+'</td>'+
                '<td data-label="Observaciones">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(D.OBSERVACIONES,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
            '</tr>'
        FROM #DOCUMENTOS360 D
        ORDER BY CASE WHEN D.FECHA_VENCIMIENTO IS NULL THEN 1 ELSE 0 END,D.FECHA_VENCIMIENTO,D.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_DOCUMENTOS=''
        SET @HTML_DOCUMENTOS='<div class="vct-360-empty vct-360-fixed-empty">Sin documentos relacionados al consultor.</div>';
    ELSE
        SET @HTML_DOCUMENTOS=
            '<div data-vct-dg data-vct-dg-id="v360_con_docs" data-vct-dg-title="Documentos del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="documento(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar documento..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th data-vct-width="14%" data-vct-sort="tipo" data-vct-sortable="true"><span>Tipo</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-sort="documento" data-vct-sortable="true"><span>Documento</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="11%" data-vct-sort="estado" data-vct-sortable="true"><span>Estado</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="emision" data-vct-sortable="true" data-vct-sort-type="date"><span>Emisión</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th class="vct-text-center" data-vct-width="10%" data-vct-sort="cierre" data-vct-sortable="true" data-vct-sort-type="date"><span>Cierre</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="26%" data-vct-sort="observaciones" data-vct-sortable="true" data-vct-truncate="2"><span>Observaciones</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th></tr></thead>'+
            '<tbody>'+@HTML_DOCUMENTOS+'</tbody>'+
            '</table>'+
            '</div>';
 
    SELECT @HTML_NOTAS=ISNULL((
        SELECT
            '<tr data-vct-row>'+
                '<td class="vct-text-center" data-label="Fecha">'+CASE WHEN N.FECHA IS NULL THEN '-' ELSE CONVERT(VARCHAR(10),N.FECHA,103) END+'</td>'+
                '<td data-label="Título">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(N.TITULO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
                '<td data-label="Nota">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(N.NOTA,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
                '<td data-label="Usuario">'+REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(N.USUARIO,''),'-'),'&','&amp;'),'<','&lt;'),'>','&gt;')+'</td>'+
            '</tr>'
        FROM #NOTAS360 N
        ORDER BY CASE WHEN N.FECHA IS NULL THEN 1 ELSE 0 END,N.FECHA DESC,N.ID DESC
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    IF @HTML_NOTAS=''
        SET @HTML_NOTAS='<div class="vct-360-empty vct-360-fixed-empty">Sin notas relacionadas al consultor.</div>';
    ELSE
        SET @HTML_NOTAS=
            '<div data-vct-dg data-vct-dg-id="v360_con_notas" data-vct-dg-title="Notas del consultor" data-vct-dg-subtitle="Consultor: '+REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@NOMBRE_COMPLETO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+'" data-vct-dg-unit="nota(s)" data-vct-dg-page-size="10" data-vct-dg-search-placeholder="Buscar nota..." data-vct-dg-density="compact" data-vct-dg-layout="fixed">'+
            '<table>'+
            '<thead><tr><th class="vct-text-center" data-vct-width="10%" data-vct-sort="fecha" data-vct-sortable="true" data-vct-sort-type="date"><span>Fecha</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="22%" data-vct-sort="titulo" data-vct-sortable="true"><span>Título</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-sort="nota" data-vct-sortable="true" data-vct-truncate="2"><span>Nota</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th><th data-vct-width="16%" data-vct-sort="usuario" data-vct-sortable="true"><span>Usuario</span><span class="vct-sort-icon" data-vct-icon="chevrons-up-down"></span></th></tr></thead>'+
            '<tbody>'+@HTML_NOTAS+'</tbody>'+
            '</table>'+
            '</div>';
 
    /* ============================================================
       15.C GRAFICOS DEL RESUMEN
       ============================================================ */
    DECLARE
        @HTML_CHART_PROY_ESTADO VARCHAR(MAX)='',
        @HTML_CHART_GEST_ESTADO VARCHAR(MAX)='',
        @HTML_CHART_CLIENTES VARCHAR(MAX)='',
        @P_ACT INT=0,@P_PLAN INT=0,@P_FIN INT=0,@P_OTR INT=0,@P_TOT INT=0,
        @G_REAL INT=0,@G_PEND INT=0,@G_CURSO INT=0,@G_OTR INT=0,@G_TOT INT=0;
 
    SELECT
        @P_ACT=SUM(CASE WHEN ESTADO_CODIGO='ENCURSO' THEN 1 ELSE 0 END),
        @P_PLAN=SUM(CASE WHEN ESTADO_CODIGO IN ('BORRADOR','CONFIRMADO','PAUSADO') THEN 1 ELSE 0 END),
        @P_FIN=SUM(CASE WHEN ESTADO_CODIGO='TERMINADO' THEN 1 ELSE 0 END),
        @P_TOT=COUNT(*)
    FROM #PROYECTOS360;
    SET @P_ACT=ISNULL(@P_ACT,0); SET @P_PLAN=ISNULL(@P_PLAN,0); SET @P_FIN=ISNULL(@P_FIN,0); SET @P_TOT=ISNULL(@P_TOT,0);
    SET @P_OTR=@P_TOT-@P_ACT-@P_PLAN-@P_FIN;
 
    DECLARE @P_ACT_PCT DECIMAL(10,2)=0,@P_PLAN_PCT DECIMAL(10,2)=0,@P_FIN_PCT DECIMAL(10,2)=0,@P_OTR_PCT DECIMAL(10,2)=0;
    IF @P_TOT>0
    BEGIN
        SET @P_ACT_PCT=100.0*@P_ACT/@P_TOT;
        SET @P_PLAN_PCT=100.0*@P_PLAN/@P_TOT;
        SET @P_FIN_PCT=100.0*@P_FIN/@P_TOT;
        SET @P_OTR_PCT=100.0-@P_ACT_PCT-@P_PLAN_PCT-@P_FIN_PCT;
    END;
 
    DECLARE @P_BG VARCHAR(MAX)='';
    SET @P_BG=CASE WHEN @P_TOT=0 THEN '#E8EDF3' ELSE
        'conic-gradient('+
        '#12B76A 0 '+CONVERT(VARCHAR(20),@P_ACT_PCT)+'%,'+
        '#F79009 '+CONVERT(VARCHAR(20),@P_ACT_PCT)+'% '+CONVERT(VARCHAR(20),@P_ACT_PCT+@P_PLAN_PCT)+'%,'+
        '#98A2B3 '+CONVERT(VARCHAR(20),@P_ACT_PCT+@P_PLAN_PCT)+'% '+CONVERT(VARCHAR(20),@P_ACT_PCT+@P_PLAN_PCT+@P_FIN_PCT)+'%,'+
        '#7F56D9 '+CONVERT(VARCHAR(20),@P_ACT_PCT+@P_PLAN_PCT+@P_FIN_PCT)+'% 100%)' END;
 
    SET @HTML_CHART_PROY_ESTADO=
        '<div class="vct-360-chart-simple">'+
            '<div class="vct-360-donut-ring vct-360-donut-lg" style="background:'+@P_BG+';">'+
                '<div class="vct-360-donut-center vct-360-donut-center-lg"><b>'+CONVERT(VARCHAR(10),@P_TOT)+'</b><span>Proyectos</span></div>'+
            '</div>'+
            '<div class="vct-360-donut-legend-lg">'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#12B76A"></i><span>En curso</span><b>'+CONVERT(VARCHAR(10),@P_ACT)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#F79009"></i><span>Otros abiertos</span><b>'+CONVERT(VARCHAR(10),@P_PLAN)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#98A2B3"></i><span>Terminados</span><b>'+CONVERT(VARCHAR(10),@P_FIN)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#7F56D9"></i><span>Otros</span><b>'+CONVERT(VARCHAR(10),@P_OTR)+'</b></div>'+
            '</div>'+
        '</div>';
 
    SELECT
        @G_REAL=SUM(CASE WHEN ESTADO_CODIGO='CUMPLIDA' THEN 1 ELSE 0 END),
        @G_PEND=SUM(CASE WHEN ESTADO_CODIGO='PENDIENTE' THEN 1 ELSE 0 END),
        @G_CURSO=SUM(CASE WHEN ESTADO_CODIGO IN ('EN_PROCESO','EN_ESPERA') THEN 1 ELSE 0 END),
        @G_TOT=COUNT(*)
    FROM #GESTIONES360;
    SET @G_REAL=ISNULL(@G_REAL,0); SET @G_PEND=ISNULL(@G_PEND,0); SET @G_CURSO=ISNULL(@G_CURSO,0); SET @G_TOT=ISNULL(@G_TOT,0);
    SET @G_OTR=@G_TOT-@G_REAL-@G_PEND-@G_CURSO;
 
    DECLARE @G_REAL_PCT DECIMAL(10,2)=0,@G_PEND_PCT DECIMAL(10,2)=0,@G_CURSO_PCT DECIMAL(10,2)=0,@G_OTR_PCT DECIMAL(10,2)=0;
    IF @G_TOT>0
    BEGIN
        SET @G_REAL_PCT=100.0*@G_REAL/@G_TOT;
        SET @G_PEND_PCT=100.0*@G_PEND/@G_TOT;
        SET @G_CURSO_PCT=100.0*@G_CURSO/@G_TOT;
        SET @G_OTR_PCT=100.0-@G_REAL_PCT-@G_PEND_PCT-@G_CURSO_PCT;
    END;
 
    DECLARE @G_BG VARCHAR(MAX)='';
    SET @G_BG=CASE WHEN @G_TOT=0 THEN '#E8EDF3' ELSE
        'conic-gradient('+
        '#12B76A 0 '+CONVERT(VARCHAR(20),@G_REAL_PCT)+'%,'+
        '#F79009 '+CONVERT(VARCHAR(20),@G_REAL_PCT)+'% '+CONVERT(VARCHAR(20),@G_REAL_PCT+@G_PEND_PCT)+'%,'+
        '#2E90FA '+CONVERT(VARCHAR(20),@G_REAL_PCT+@G_PEND_PCT)+'% '+CONVERT(VARCHAR(20),@G_REAL_PCT+@G_PEND_PCT+@G_CURSO_PCT)+'%,'+
        '#F04438 '+CONVERT(VARCHAR(20),@G_REAL_PCT+@G_PEND_PCT+@G_CURSO_PCT)+'% 100%)' END;
 
    SET @HTML_CHART_GEST_ESTADO=
        '<div class="vct-360-chart-simple">'+
            '<div class="vct-360-donut-ring vct-360-donut-lg" style="background:'+@G_BG+';">'+
                '<div class="vct-360-donut-center vct-360-donut-center-lg"><b>'+CONVERT(VARCHAR(10),@G_TOT)+'</b><span>Gestiones</span></div>'+
            '</div>'+
            '<div class="vct-360-donut-legend-lg">'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#12B76A"></i><span>Cumplidas</span><b>'+CONVERT(VARCHAR(10),@G_REAL)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#F79009"></i><span>Pendientes</span><b>'+CONVERT(VARCHAR(10),@G_PEND)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#2E90FA"></i><span>En curso</span><b>'+CONVERT(VARCHAR(10),@G_CURSO)+'</b></div>'+
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#F04438"></i><span>Otros</span><b>'+CONVERT(VARCHAR(10),@G_OTR)+'</b></div>'+
            '</div>'+
        '</div>';
 
    DECLARE @ClientesAsignados INT=0;
    SELECT @ClientesAsignados=COUNT(DISTINCT ID_CLIENTE)
    FROM #PROYECTOS360
    WHERE ID_CLIENTE IS NOT NULL;
 
    SET @HTML_CHART_CLIENTES=
        '<div class="vct-360-chart-simple">'+
            '<div class="vct-360-donut-ring vct-360-donut-lg" style="background:'+
                CASE WHEN @ClientesAsignados=0 THEN '#E8EDF3' ELSE '#2E90FA' END+';">'+
                '<div class="vct-360-donut-center vct-360-donut-center-lg"><b>'+CONVERT(VARCHAR(10),@ClientesAsignados)+'</b><span>Clientes</span></div>'+ 
            '</div>'+ 
            '<div class="vct-360-donut-legend-lg">'+ 
                '<div class="vct-360-donut-legend-item"><i class="vct-360-dot" style="background:#2E90FA"></i><span>Clientes asignados</span><b>'+CONVERT(VARCHAR(10),@ClientesAsignados)+'</b></div>'+ 
            '</div>'+ 
        '</div>';
 
    /* Gestiones vinculadas al consultor dentro de proyectos activos. */
    DECLARE
        @GA_Total INT=0,
        @GA_Cumplidas INT=0,
        @GA_EnCurso INT=0,
        @GA_Pendientes INT=0,
        @GA_Vencidas INT=0,
        @GA_Canceladas INT=0,
        @GA_Otras INT=0,
        @ProyectosActivosConsultor INT=0,
        @HTML_GESTIONES_ACTIVOS VARCHAR(MAX)='';
 
    SELECT @ProyectosActivosConsultor=COUNT(*)
    FROM #PROYECTOS360
    WHERE ESTADO_CODIGO IN ('ENCURSO','CONFIRMADO','PAUSADO');
 
    SELECT
        @GA_Total=COUNT(*),
        @GA_Cumplidas=SUM(CASE WHEN GE.CODIGO='CUMPLIDA' THEN 1 ELSE 0 END),
        @GA_Canceladas=SUM(CASE WHEN GE.CODIGO='CANCELADA' THEN 1 ELSE 0 END),
        @GA_Vencidas=SUM(CASE WHEN ISNULL(GE.ES_FINAL,0)=0 AND G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)<0 THEN 1 ELSE 0 END),
        @GA_EnCurso=SUM(CASE WHEN ISNULL(GE.ES_FINAL,0)=0
                                  AND NOT (G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)<0)
                                  AND GE.CODIGO IN ('EN_PROCESO','EN_ESPERA') THEN 1 ELSE 0 END),
        @GA_Pendientes=SUM(CASE WHEN ISNULL(GE.ES_FINAL,0)=0
                                     AND NOT (G.FECHA_VENCIMIENTO IS NOT NULL AND DATEDIFF(DAY,GETDATE(),G.FECHA_VENCIMIENTO)<0)
                                     AND ISNULL(GE.CODIGO,'') NOT IN ('EN_PROCESO','EN_ESPERA') THEN 1 ELSE 0 END)
    FROM dbo.VCT_GESTIONES G WITH(NOLOCK)
    INNER JOIN dbo.VCT_PROYECTOS P WITH(NOLOCK) ON P.ID=G.ID_PROYECTO
    LEFT JOIN dbo.VCT_PRM_PROYECTOS_ESTADOS PE WITH(NOLOCK) ON PE.ID=P.ID_ESTADO
    LEFT JOIN dbo.VCT_PRM_GESTIONES_ESTADOS GE WITH(NOLOCK) ON GE.ID=G.ID_ESTADO
    WHERE PE.CODIGO IN ('ENCURSO','CONFIRMADO','PAUSADO')
      AND EXISTS
      (
          SELECT 1
          FROM dbo.VCT_GESTIONES_PARTICIPANTES GP WITH(NOLOCK)
          WHERE GP.ID_GESTION=G.ID
            AND GP.TIPO_ENTIDAD='CONSULTOR'
            AND GP.ID_ENTIDAD=@ID_CONSULTOR
            AND GP.ESTADO='ACTIVO'
      );
 
    SET @GA_Total=ISNULL(@GA_Total,0);
    SET @GA_Cumplidas=ISNULL(@GA_Cumplidas,0);
    SET @GA_EnCurso=ISNULL(@GA_EnCurso,0);
    SET @GA_Pendientes=ISNULL(@GA_Pendientes,0);
    SET @GA_Vencidas=ISNULL(@GA_Vencidas,0);
    SET @GA_Canceladas=ISNULL(@GA_Canceladas,0);
    SET @GA_Otras=@GA_Total-(@GA_Cumplidas+@GA_EnCurso+@GA_Pendientes+@GA_Vencidas+@GA_Canceladas);
    IF @GA_Otras<0 SET @GA_Otras=0;
 
    DECLARE @GA_PctCumplidas INT=CASE WHEN @GA_Total>0 THEN (@GA_Cumplidas*100)/@GA_Total ELSE 0 END;
    DECLARE @GA_PctEnCurso INT=CASE WHEN @GA_Total>0 THEN (@GA_EnCurso*100)/@GA_Total ELSE 0 END;
    DECLARE @GA_PctPendientes INT=CASE WHEN @GA_Total>0 THEN (@GA_Pendientes*100)/@GA_Total ELSE 0 END;
    DECLARE @GA_PctVencidas INT=CASE WHEN @GA_Total>0 THEN (@GA_Vencidas*100)/@GA_Total ELSE 0 END;
    DECLARE @GA_PctCanceladas INT=CASE WHEN @GA_Total>0 THEN (@GA_Canceladas*100)/@GA_Total ELSE 0 END;
    DECLARE @GA_PctOtras INT=CASE WHEN @GA_Total>0 THEN (@GA_Otras*100)/@GA_Total ELSE 0 END;
 
    IF @GA_Total=0
        SET @HTML_GESTIONES_ACTIVOS='<div class="vct-360-empty vct-360-fixed-empty">No hay gestiones del consultor asociadas a proyectos activos.</div>';
    ELSE
        SET @HTML_GESTIONES_ACTIVOS=
            '<div class="vct-360-active-management-chart">'+
                '<div class="vct-360-active-management-main">'+
                    '<div class="vct-360-active-management-bar">'+
                        CASE WHEN @GA_Cumplidas>0 THEN '<span class="is-complete" style="flex:'+CONVERT(VARCHAR(12),@GA_Cumplidas)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_Cumplidas)+'</span>' ELSE '' END+
                        CASE WHEN @GA_EnCurso>0 THEN '<span class="is-progress" style="flex:'+CONVERT(VARCHAR(12),@GA_EnCurso)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_EnCurso)+'</span>' ELSE '' END+
                        CASE WHEN @GA_Pendientes>0 THEN '<span class="is-pending" style="flex:'+CONVERT(VARCHAR(12),@GA_Pendientes)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_Pendientes)+'</span>' ELSE '' END+
                        CASE WHEN @GA_Vencidas>0 THEN '<span class="is-overdue" style="flex:'+CONVERT(VARCHAR(12),@GA_Vencidas)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_Vencidas)+'</span>' ELSE '' END+
                        CASE WHEN @GA_Canceladas>0 THEN '<span class="is-cancelled" style="flex:'+CONVERT(VARCHAR(12),@GA_Canceladas)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_Canceladas)+'</span>' ELSE '' END+
                        CASE WHEN @GA_Otras>0 THEN '<span class="is-other" style="flex:'+CONVERT(VARCHAR(12),@GA_Otras)+' 1 0;">'+CONVERT(VARCHAR(10),@GA_Otras)+'</span>' ELSE '' END+
                    '</div>'+
                    '<div class="vct-360-active-management-legend">'+
                        '<span><i class="is-complete"></i><b>Cumplidas</b><small>'+CONVERT(VARCHAR(10),@GA_Cumplidas)+' ('+CONVERT(VARCHAR(5),@GA_PctCumplidas)+'%)</small></span>'+
                        '<span><i class="is-progress"></i><b>En curso</b><small>'+CONVERT(VARCHAR(10),@GA_EnCurso)+' ('+CONVERT(VARCHAR(5),@GA_PctEnCurso)+'%)</small></span>'+
                        '<span><i class="is-pending"></i><b>Pendientes</b><small>'+CONVERT(VARCHAR(10),@GA_Pendientes)+' ('+CONVERT(VARCHAR(5),@GA_PctPendientes)+'%)</small></span>'+
                        '<span><i class="is-overdue"></i><b>Vencidas</b><small>'+CONVERT(VARCHAR(10),@GA_Vencidas)+' ('+CONVERT(VARCHAR(5),@GA_PctVencidas)+'%)</small></span>'+
                        CASE WHEN @GA_Canceladas>0 THEN '<span><i class="is-cancelled"></i><b>Canceladas</b><small>'+CONVERT(VARCHAR(10),@GA_Canceladas)+' ('+CONVERT(VARCHAR(5),@GA_PctCanceladas)+'%)</small></span>' ELSE '' END+
                        CASE WHEN @GA_Otras>0 THEN '<span><i class="is-other"></i><b>Otras</b><small>'+CONVERT(VARCHAR(10),@GA_Otras)+' ('+CONVERT(VARCHAR(5),@GA_PctOtras)+'%)</small></span>' ELSE '' END+
                    '</div>'+
                '</div>'+
                '<div class="vct-360-active-management-total">'+
                    '<span>Total de gestiones</span><b>'+CONVERT(VARCHAR(10),@GA_Total)+'</b>'+
                    '<small>'+CONVERT(VARCHAR(10),@ProyectosActivosConsultor)+' proyecto(s) activo(s)</small>'+
                '</div>'+
            '</div>';
 
    /* ============================================================
       16. FORM ACTIONS / DRAWERS
       ============================================================ */
    DECLARE
        @BTN_ADD_DOM VARCHAR(MAX)='',
        @BTN_ADD_TEL VARCHAR(MAX)='',
        @BTN_ADD_MAIL VARCHAR(MAX)='',
        @BTN_ADD_NORMA VARCHAR(MAX)='',
        @BTN_ADD_SERVC VARCHAR(MAX)='',
        @BTN_ADD_HIST VARCHAR(MAX)='',
        @HTML_DRAWER_DOM VARCHAR(MAX)='',
        @HTML_DRAWER_TEL VARCHAR(MAX)='',
        @HTML_DRAWER_MAIL VARCHAR(MAX)='',
        @HTML_DRAWER_NORMA VARCHAR(MAX)='',
        @HTML_DRAWER_SERVC VARCHAR(MAX)='',
        @HTML_DRAWER_HIST VARCHAR(MAX)='';
 
    IF @CAN_EDIT=1 AND @DOM_MODE<>'NONE'
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorDomicilio',
             @FORM_TITLE='Nuevo domicilio',
             @FORM_SUBTITLE='Agregue una dirección para el consultor.',
             @FORM_ICON='map-pin',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='map-pin',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar domicilio',
             @OUTHTML=@BTN_ADD_DOM OUTPUT;
    END;
 
    IF @CAN_EDIT=1 AND @TEL_MODE<>'NONE'
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorTelefono',
             @FORM_TITLE='Nuevo teléfono',
             @FORM_SUBTITLE='Agregue un teléfono para el consultor.',
             @FORM_ICON='phone',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='phone',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar teléfono',
             @OUTHTML=@BTN_ADD_TEL OUTPUT;
    END;
 
    IF @CAN_EDIT=1 AND @MAIL_MODE<>'NONE'
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorEmail',
             @FORM_TITLE='Nuevo email',
             @FORM_SUBTITLE='Agregue un email para el consultor.',
             @FORM_ICON='mail',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='mail',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar email',
             @OUTHTML=@BTN_ADD_MAIL OUTPUT;
    END;
 
    IF @CAN_EDIT=1 AND @NORM_TABLE_CRUD<>'' AND @NORM_LINK_COL<>'' AND @NORM_IDNORMA_COL<>''
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorNorma',
             @FORM_TITLE='Nueva norma',
             @FORM_SUBTITLE='Asigne una norma al consultor.',
             @FORM_ICON='clipboard-check',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='clipboard-check',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar norma',
             @OUTHTML=@BTN_ADD_NORMA OUTPUT;
    END;

    IF @CAN_EDIT=1 AND OBJECT_ID('dbo.VCT_CONSULTORES_SERVICIOS','U') IS NOT NULL
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorServicio',
             @FORM_TITLE='Nuevo servicio',
             @FORM_SUBTITLE='Asigne un servicio al consultor.',
             @FORM_ICON='briefcase',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='briefcase',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar servicio',
             @OUTHTML=@BTN_ADD_SERVC OUTPUT;
    END;
 
    IF @CAN_EDIT=1 AND @HIST_TABLE_CRUD<>'' AND @HIST_LINK_MODE<>'NONE' AND @HIST_DIAS_COL_CRUD<>''
    BEGIN
        EXEC dbo.VCT_MAIN_RENDER_FORM_ACTION
             @MODE='CREATE',
             @TARGET_FORM='vctDrawerConsultorDias',
             @FORM_TITLE='Nuevo registro de días',
             @FORM_SUBTITLE='Registre los días correspondientes a un mes.',
             @FORM_ICON='calendar-days',
             @BUTTON_TEXT='Agregar',
             @BUTTON_ICON='calendar-days',
             @BUTTON_CLASS='vct-btn vct-btn-new vct-btn-sm',
             @TOOLTIP='Agregar días mensuales',
             @OUTHTML=@BTN_ADD_HIST OUTPUT;
    END;
 
    IF OBJECT_ID('tempdb..#VCT_FORM_FIELDS') IS NOT NULL DROP TABLE #VCT_FORM_FIELDS;
    CREATE TABLE #VCT_FORM_FIELDS
    (
        ORDEN INT,
        FIELD_NAME VARCHAR(50),
        LABEL VARCHAR(150),
        FIELD_TYPE VARCHAR(20),
        COL_SPAN INT,
        REQUIRED BIT,
        MAX_LENGTH INT,
        PLACEHOLDER VARCHAR(250),
        OPTIONS_SOURCE VARCHAR(100),
        DEFAULT_VALUE VARCHAR(MAX),
        READONLY BIT,
        HIDDEN BIT,
        HELP_TEXT VARCHAR(500),
        SOURCE_FIELD VARCHAR(100)
    );
 
    DECLARE
        @ERR_DOM VARCHAR(MAX)='',
        @ERR_TEL VARCHAR(MAX)='',
        @ERR_MAIL VARCHAR(MAX)='',
        @ERR_NORMA VARCHAR(MAX)='',
        @ERR_HIST VARCHAR(MAX)='',
        @ERR_SERVC VARCHAR(MAX)='',
        @OPEN_SERVC BIT=0,
        @OPEN_DOM BIT=0,
        @OPEN_TEL BIT=0,
        @OPEN_MAIL BIT=0,
        @OPEN_NORMA BIT=0,
        @OPEN_HIST BIT=0;
 
    SET @ERR_DOM=CASE WHEN @VFORM_ENTITY='DOMICILIO' THEN @VFORM_ERROR ELSE '' END;
    SET @ERR_TEL=CASE WHEN @VFORM_ENTITY='TELEFONO' THEN @VFORM_ERROR ELSE '' END;
    SET @ERR_MAIL=CASE WHEN @VFORM_ENTITY='EMAIL' THEN @VFORM_ERROR ELSE '' END;
    SET @ERR_NORMA=CASE WHEN @VFORM_ENTITY='NORMA' THEN @VFORM_ERROR ELSE '' END;
    SET @ERR_HIST=CASE WHEN @VFORM_ENTITY='HIST_DIAS' THEN @VFORM_ERROR ELSE '' END;
    SET @ERR_SERVC=CASE WHEN @VFORM_ENTITY='SERVCONS' THEN @VFORM_ERROR ELSE '' END;
 
    SET @OPEN_DOM=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='DOMICILIO' THEN 1 ELSE 0 END;
    SET @OPEN_TEL=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='TELEFONO' THEN 1 ELSE 0 END;
    SET @OPEN_MAIL=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='EMAIL' THEN 1 ELSE 0 END;
    SET @OPEN_NORMA=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='NORMA' THEN 1 ELSE 0 END;
    SET @OPEN_HIST=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='HIST_DIAS' THEN 1 ELSE 0 END;
    SET @OPEN_SERVC=CASE WHEN @VFORM_REOPEN=1 AND @VFORM_ENTITY='SERVCONS' THEN 1 ELSE 0 END;
 
    /* Domicilio */
    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Calle / Avenida','TEXT',12,1,300,'Ingrese calle o avenida',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,'calle'),
    (2,'TEXTO12','Número','TEXT',4,1,30,'Número',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,'nro'),
    (3,'TEXTO13','Piso','TEXT',4,0,50,'Piso',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T13 ELSE NULL END,0,0,NULL,'piso'),
    (4,'TEXTO14','Depto','TEXT',4,0,50,'Depto',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T14 ELSE NULL END,0,0,NULL,'depto'),
    (5,'TEXTO15','Localidad','TEXT',6,1,100,'Localidad',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T15 ELSE NULL END,0,0,NULL,'localidad'),
    (6,'TEXTO16','Provincia','TEXT',6,1,100,'Provincia',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T16 ELSE NULL END,0,0,NULL,'provincia'),
    (7,'FLAG02','Principal','TOGGLE',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_FLAG02 ELSE '0' END,0,0,NULL,'principal'),
    (8,'TEXTO17','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_T17 ELSE NULL END,0,0,NULL,'observaciones'),
    (9,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_DOM=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,'id'),
    (10,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'DOMICILIO',0,1,NULL,NULL),
    (11,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (12,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (13,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (14,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'domicilio',0,1,NULL,NULL);
 
    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorDomicilio',
         @TITLE='Domicilio',
         @SUBTITLE='Datos de dirección del consultor.',
         @ICON='map-pin',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_DOM,
         @OPEN_ON_RENDER=@OPEN_DOM,
         @OUTHTML=@HTML_DRAWER_DOM OUTPUT;
 
    /* Provincia: opciones desde CAT_DATA. */
    DECLARE @HTML_PROVINCIAS VARCHAR(MAX)='';
 
    SELECT @HTML_PROVINCIAS=ISNULL((
        SELECT
            '<option value="'+
            REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CONVERT(VARCHAR(100),CD.CAT_DATA_CODE),''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
            '">'+
            REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(CONVERT(VARCHAR(300),CD.CAT_DATA_DESC),''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
            '</option>'
        FROM dbo.CAT_DATA CD WITH(NOLOCK)
        WHERE CD.PAR_KEY=
        (
            SELECT TOP 1 PKEY
            FROM dbo.CAT_TYPE WITH(NOLOCK)
            WHERE CAT_TYPE_CODE='Provincia'
        )
        ORDER BY CD.CAT_DATA_CODE
        FOR XML PATH(''),TYPE
    ).value('.','VARCHAR(MAX)'),'');
 
    SET @HTML_DRAWER_DOM=ISNULL(@HTML_DRAWER_DOM,'')+
        '<template data-vct-field-options '+
        'data-vct-target="vctDrawerConsultorDomicilio" '+
        'data-vct-field="TEXTO16" data-vct-placeholder="Seleccione una provincia">'+
        ISNULL(@HTML_PROVINCIAS,'')+
        '</template>';
 
    /* Telefono */
    DELETE FROM #VCT_FORM_FIELDS;
 
    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Código de área','TEXT',6,1,30,'Código de área',NULL,
        CASE WHEN @OPEN_TEL=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,'codarea'),
    (2,'TEXTO12','Número','TEXT',6,1,50,'Número',NULL,
        CASE WHEN @OPEN_TEL=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,'nro'),
    (3,'FLAG02','Principal','TOGGLE',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_TEL=1 THEN @VFORM_FLAG02 ELSE '0' END,0,0,NULL,'principal'),
    (4,'TEXTO13','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_TEL=1 THEN @VFORM_T13 ELSE NULL END,0,0,NULL,'observaciones'),
    (5,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_TEL=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,'id'),
    (6,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'TELEFONO',0,1,NULL,NULL),
    (7,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (8,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (9,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (10,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'telefonos',0,1,NULL,NULL);
 
    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorTelefono',
         @TITLE='Teléfono',
         @SUBTITLE='Número de contacto del consultor.',
         @ICON='phone',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_TEL,
         @OPEN_ON_RENDER=@OPEN_TEL,
         @OUTHTML=@HTML_DRAWER_TEL OUTPUT;
 
    /* Email */
    DELETE FROM #VCT_FORM_FIELDS;
 
    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Email','EMAIL',12,1,300,'email@dominio.com',NULL,
        CASE WHEN @OPEN_MAIL=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,'email'),
    (2,'FLAG02','Principal','TOGGLE',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_MAIL=1 THEN @VFORM_FLAG02 ELSE '0' END,0,0,NULL,'principal'),
    (3,'TEXTO12','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_MAIL=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,'observaciones'),
    (4,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_MAIL=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,'id'),
    (5,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'EMAIL',0,1,NULL,NULL),
    (6,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (7,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (8,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (9,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'email',0,1,NULL,NULL);
 
    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorEmail',
         @TITLE='Email',
         @SUBTITLE='Correo electrónico del consultor.',
         @ICON='mail',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_MAIL,
         @OPEN_ON_RENDER=@OPEN_MAIL,
         @OUTHTML=@HTML_DRAWER_MAIL OUTPUT;
 
    /* Norma */
    DELETE FROM #VCT_FORM_FIELDS;
 
    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Norma','TEXT',6,1,100,'Seleccione una norma',NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,'idnorma'),
    (2,'TEXTO15','Servicio','TEXT',6,1,100,'Seleccione un servicio',NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T15 ELSE NULL END,0,0,'La calificaci&oacute;n es por norma y servicio.','idservicio'),
    (3,'TEXTO12','Calificación','TEXT',6,0,100,'Ej.: Auditor, Senior, Líder',NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,'calificacion'),
    (4,'TEXTO13','Desde','DATE',6,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T13 ELSE NULL END,0,0,NULL,'desde'),
    (5,'TEXTO14','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_T14 ELSE NULL END,0,0,NULL,'observaciones'),
    (6,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_NORMA=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,'id'),
    (7,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'NORMA',0,1,NULL,NULL),
    (8,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (9,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (10,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (11,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'normas',0,1,NULL,NULL);
 
    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorNorma',
         @TITLE='Norma',
         @SUBTITLE='Norma y calificación asociadas al consultor.',
         @ICON='clipboard-check',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_NORMA,
         @OPEN_ON_RENDER=@OPEN_NORMA,
         @OUTHTML=@HTML_DRAWER_NORMA OUTPUT;
 
    DECLARE @HTML_NORMAS_OPTIONS VARCHAR(MAX)='', @HTML_SERV_OPTIONS VARCHAR(MAX)='';
    IF OBJECT_ID('dbo.VCT_PRM_SERVICIOS','U') IS NOT NULL
        SELECT @HTML_SERV_OPTIONS=ISNULL((
            SELECT '<option value="'+CONVERT(VARCHAR(30),PS.ID)+'">'+
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(PS.DESCRIPCION,''),'Servicio #'+CONVERT(VARCHAR(20),PS.ID)),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                '</option>'
            FROM dbo.VCT_PRM_SERVICIOS PS WITH(NOLOCK)
            WHERE UPPER(ISNULL(PS.ESTADO,'ACTIVO'))='ACTIVO'
            ORDER BY PS.DESCRIPCION,PS.ID
            FOR XML PATH(''),TYPE
        ).value('.','VARCHAR(MAX)'),'');
 
    IF OBJECT_ID('dbo.VCT_PRM_NORMAS','U') IS NOT NULL
    BEGIN
        SELECT @HTML_NORMAS_OPTIONS=ISNULL((
            SELECT
                '<option value="'+CONVERT(VARCHAR(30),PN.ID)+'">'+
                REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(NULLIF(PN.DESCRIPCION,''),'Norma #'+CONVERT(VARCHAR(20),PN.ID)),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;')+
                CASE WHEN UPPER(ISNULL(PN.ESTADO,''))<>'ACTIVO' THEN ' - '+REPLACE(REPLACE(REPLACE(ISNULL(PN.ESTADO,''),'&','&amp;'),'<','&lt;'),'>','&gt;') ELSE '' END+
                '</option>'
            FROM dbo.VCT_PRM_NORMAS PN WITH(NOLOCK)
            ORDER BY CASE WHEN UPPER(ISNULL(PN.ESTADO,''))='ACTIVO' THEN 0 ELSE 1 END,PN.DESCRIPCION,PN.ID
            FOR XML PATH(''),TYPE
        ).value('.','VARCHAR(MAX)'),'');
    END;
 
    SET @HTML_DRAWER_NORMA=ISNULL(@HTML_DRAWER_NORMA,'')+
        '<template data-vct-field-options '+
        'data-vct-target="vctDrawerConsultorNorma" '+
        'data-vct-field="TEXTO11" data-vct-placeholder="Seleccione una norma">'+
        ISNULL(@HTML_NORMAS_OPTIONS,'')+
        '</template>'+
        '<template data-vct-field-options '+
        'data-vct-target="vctDrawerConsultorNorma" '+
        'data-vct-field="TEXTO15" data-vct-placeholder="Seleccione un servicio">'+
        ISNULL(@HTML_SERV_OPTIONS,'')+
        '</template>';
 
    /* Servicio del consultor */
    DELETE FROM #VCT_FORM_FIELDS;

    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Servicio','TEXT',12,1,100,'Seleccione un servicio',NULL,
        CASE WHEN @OPEN_SERVC=1 THEN @VFORM_T11 ELSE NULL END,0,0,NULL,'idservicio'),
    (2,'TEXTO12','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_SERVC=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,'observaciones'),
    (3,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,
        CASE WHEN @OPEN_SERVC=1 THEN @VFORM_ROW_ID ELSE NULL END,0,1,NULL,'id'),
    (4,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'SERVCONS',0,1,NULL,NULL),
    (5,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (6,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (7,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (8,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'servicios',0,1,NULL,NULL);

    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorServicio',
         @TITLE='Servicio',
         @SUBTITLE='Servicio que presta el consultor.',
         @ICON='briefcase',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_SERVC,
         @OPEN_ON_RENDER=@OPEN_SERVC,
         @OUTHTML=@HTML_DRAWER_SERVC OUTPUT;

    SET @HTML_DRAWER_SERVC=ISNULL(@HTML_DRAWER_SERVC,'')+
        '<template data-vct-field-options '+
        'data-vct-target="vctDrawerConsultorServicio" '+
        'data-vct-field="TEXTO11" data-vct-placeholder="Seleccione un servicio">'+
        ISNULL(@HTML_SERV_OPTIONS,'')+
        '</template>';

    /* Días mensuales */
    DELETE FROM #VCT_FORM_FIELDS;
 
    INSERT INTO #VCT_FORM_FIELDS VALUES
    (1,'TEXTO11','Mes','DATE',6,1,NULL,NULL,NULL,
        CASE WHEN @OPEN_HIST=1 THEN @VFORM_T11 ELSE NULL END,0,0,'Seleccione cualquier fecha del mes a registrar.',NULL),
    (2,'TEXTO12','Días','DECIMAL',6,1,NULL,'0',NULL,
        CASE WHEN @OPEN_HIST=1 THEN @VFORM_T12 ELSE NULL END,0,0,NULL,NULL),
    (3,'TEXTO13','Observaciones','TEXTAREA',12,0,1000,'Observaciones',NULL,
        CASE WHEN @OPEN_HIST=1 THEN @VFORM_T13 ELSE NULL END,0,0,NULL,NULL),
    (4,'IDSELEC02','ID','HIDDEN',12,0,NULL,NULL,NULL,NULL,0,1,NULL,NULL),
    (5,'TEXTO30','Entidad','HIDDEN',12,0,NULL,NULL,NULL,'HIST_DIAS',0,1,NULL,NULL),
    (6,'FLAG01','Guardar','HIDDEN',12,0,NULL,NULL,NULL,'1',0,1,NULL,NULL),
    (7,'FLAG03','Eliminar','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (8,'FLAG04','PrincipalCmd','HIDDEN',12,0,NULL,NULL,NULL,'0',0,1,NULL,NULL),
    (9,'ACTIVE_TAB','Tab','HIDDEN',12,0,NULL,NULL,NULL,'dias',0,1,NULL,NULL);
 
    EXEC dbo.VCT_MAIN_RENDER_FORM
         @FORM_ID='vctDrawerConsultorDias',
         @TITLE='Días mensuales',
         @SUBTITLE='Registro mensual de días del consultor.',
         @ICON='calendar-days',
         @LAYOUT='DRAWER',
         @SAVE_LABEL='Guardar',
         @CANCEL_LABEL='Cancelar',
         @ERROR_MESSAGE=@ERR_HIST,
         @OPEN_ON_RENDER=@OPEN_HIST,
         @OUTHTML=@HTML_DRAWER_HIST OUTPUT;
 
    /* ============================================================
       17. HEADER / BREADCRUMB / FICHA
       ============================================================ */
    DECLARE
        @INICIALES VARCHAR(4)='',
        @C_NOMBRE VARCHAR(400)='',
        @C_DOC VARCHAR(180)='',
        @C_CODIGO VARCHAR(120)='',
        @C_CARGO_TXT VARCHAR(220)='',
        @C_ALTA_TXT VARCHAR(30)='-',
        @C_ANTIGUEDAD_TXT VARCHAR(80)='-',
        @ESTADO_BADGE_CLASE VARCHAR(20)='is-neutral',
        @ESTADO_BADGE_TEXTO VARCHAR(50)='SIN ESTADO';
 
    SET @INICIALES=UPPER(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@NOMBRES,'')+ISNULL(@APELLIDOS,''))),'') IS NOT NULL
                THEN LEFT(LTRIM(ISNULL(@NOMBRES,'')),1)+LEFT(LTRIM(ISNULL(@APELLIDOS,'')),1)
            ELSE LEFT(LTRIM(ISNULL(@RAZON_SOCIAL,'')),2)
        END
    );
    IF NULLIF(@INICIALES,'') IS NULL SET @INICIALES='--';
 
    SET @C_NOMBRE=REPLACE(REPLACE(REPLACE(REPLACE(@NOMBRE_COMPLETO,'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');
 
    SET @C_DOC=REPLACE(REPLACE(REPLACE(REPLACE(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@CUIT,''))),'') IS NOT NULL THEN 'CUIT '+LTRIM(RTRIM(@CUIT))
            ELSE LTRIM(RTRIM(ISNULL(@TIPO_DOCUMENTO,'')+' '+ISNULL(@NRO_DOCUMENTO,'')))
        END,
        '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');
 
    SET @C_CODIGO=REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@LEGAJO,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');
    SET @C_CARGO_TXT=REPLACE(REPLACE(REPLACE(REPLACE(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@CARGO,''))),'') IS NOT NULL THEN @CARGO
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@AREA,''))),'') IS NOT NULL THEN @AREA
            ELSE @FORMACION
        END,
        '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;');
 
    IF @FECHA_ALTA IS NOT NULL SET @C_ALTA_TXT=CONVERT(VARCHAR(10),@FECHA_ALTA,103);
    ELSE IF @FECHA_INGRESO IS NOT NULL SET @C_ALTA_TXT=CONVERT(VARCHAR(10),@FECHA_INGRESO,103);
 
    DECLARE @C_FECHA_BASE DATETIME=ISNULL(@FECHA_ALTA,@FECHA_INGRESO);
    IF @C_FECHA_BASE IS NOT NULL
    BEGIN
        DECLARE @C_MESES INT=DATEDIFF(MONTH,@C_FECHA_BASE,GETDATE());
        IF DATEADD(MONTH,@C_MESES,@C_FECHA_BASE)>GETDATE() SET @C_MESES=@C_MESES-1;
        IF @C_MESES<0 SET @C_MESES=0;
        SET @C_ANTIGUEDAD_TXT=
            CASE
                WHEN @C_MESES>=12 THEN CONVERT(VARCHAR(10),@C_MESES/12)+' año'+CASE WHEN @C_MESES/12=1 THEN '' ELSE 's' END
                ELSE CONVERT(VARCHAR(10),@C_MESES)+' mes'+CASE WHEN @C_MESES=1 THEN '' ELSE 'es' END
            END;
    END;
 
    IF @ESTADO='ACTIVO'
    BEGIN
        SET @ESTADO_BADGE_CLASE='is-active';
        SET @ESTADO_BADGE_TEXTO='ACTIVO';
    END
    ELSE IF @ESTADO='INACTIVO'
    BEGIN
        SET @ESTADO_BADGE_CLASE='is-inactive';
        SET @ESTADO_BADGE_TEXTO='INACTIVO';
    END
    ELSE
        SET @ESTADO_BADGE_TEXTO=ISNULL(NULLIF(@ESTADO,''),'SIN ESTADO');
 
    DECLARE @HTML_ESTADO_BADGE VARCHAR(250)=
        '<span class="vct-360-badge '+@ESTADO_BADGE_CLASE+'">'+@ESTADO_BADGE_TEXTO+'</span>';
 
    SET @BTN_BACK=
        '<nav class="vct-breadcrumb-simple" aria-label="Breadcrumb">'+
            '<button type="button" class="vct-breadcrumb-link" '+
                    'data-vct-v360-back '+
                    'data-vct-sidebar-mod="5">Consultores</button>'+
            '<span class="vct-breadcrumb-sep">›</span>'+
            '<span class="vct-breadcrumb-item">Vista 360</span>'+
            '<span class="vct-breadcrumb-sep">›</span>'+
            '<span class="vct-breadcrumb-current">'+@C_NOMBRE+'</span>'+
        '</nav>';
 
    /* ============================================================
       18. OUTPUT 1 - HEADER / FICHA / KPI / TABS
       ============================================================ */
    SET @OUTPARAM1=
        ISNULL(@HTML_SHELL,'')+'
<style>
/* Ajuste LOCAL: evita que los títulos largos de Proyecto/Gestión se
   pinten por encima de las columnas siguientes (Responsable, Estado,
   Fecha) en las tablas de esta Vista 360. No modifica CSS global. */
.vct-consultor360-module .vct-360-project-name,
.vct-consultor360-module .vct-360-project-ref{
  white-space:normal !important;
  overflow-wrap:break-word !important;
  word-break:break-word !important;
}
/* Color caracteristico por servicio (consistente donde aparezca el chip). */
.vct-serv-chip{display:inline-block;padding:2px 10px;border-radius:999px;font-size:12px;font-weight:600;line-height:1.6;border:1px solid transparent;white-space:nowrap;}
.vct-serv-chip.is-consultoria{background:#E7F0FD;color:#1D63C7;border-color:#CFE0FB;}
.vct-serv-chip.is-auditoria{background:#F3E8FB;color:#7F43C0;border-color:#E6D2F6;}
.vct-serv-chip.is-capacitacion{background:#E3F6EC;color:#0E9F6E;border-color:#C7EBD8;}
.vct-serv-chip.is-neutral{background:#EEF2F6;color:#64748B;border-color:#E2E8F0;}
</style>
<div class="vct-page vct-page-main"
     data-vct-page
     data-vct-sidebar-id="5"
     data-vct-form-id="'+ISNULL(@FORM_ID,'')+'">
 
<link rel="stylesheet" href="../css/vct-datagrid.css?v=4"><script src="../js/vct-export.js?v=1"></script><script src="../js/vct-datagrid.js?v=3"></script><section class="vct-module vct-360-module vct-consultor360-module vct-cliente360-module vct-360-visual-final"
         data-vct-module
         data-vct-entity-theme="consultor"
         data-vct-tabs
         data-vct-tabs-active="'+ISNULL(@ACTIVE_TAB,'resumen')+'"
         data-vct-tabs-reset="'+CONVERT(VARCHAR(1),@V360_RESET_TAB)+'"
         data-vct-consultor-key="'+CONVERT(VARCHAR(100),@ID_CONSULTOR)+'">
 
    <div class="vct-360-breadcrumb-row">
        '+ISNULL(@BTN_BACK,'')+'
    </div>
 
    <div class="vct-360-client-strip vct-360-consultor-strip">
        <div class="vct-360-card-left">
            <div class="vct-360-avatar">'+@INICIALES+'</div>
            <div class="vct-360-identity">
                <div class="vct-360-identity-title">
                    <h1>'+@C_NOMBRE+'</h1>
                    '+@HTML_ESTADO_BADGE+'
                </div>
                <div class="vct-360-client-meta">
                    <span><span data-vct-icon="file-text"></span>'+CASE WHEN @C_DOC='' THEN '-' ELSE @C_DOC END+'</span>
                    <span><span data-vct-icon="id-card"></span>Código '+CASE WHEN @C_CODIGO='' THEN '-' ELSE @C_CODIGO END+'</span>
                    <span><span data-vct-icon="briefcase"></span>'+CASE WHEN @C_CARGO_TXT='' THEN '-' ELSE @C_CARGO_TXT END+'</span>
                    <span><span data-vct-icon="calendar"></span>Activo desde '+@C_ALTA_TXT+'</span>
                    <span><span data-vct-icon="clock-3"></span>Antigüedad '+@C_ANTIGUEDAD_TXT+'</span>
                </div>
            </div>
        </div>
 
        <div class="vct-360-card-right">
            <div class="vct-360-alerts" data-vct-alerts data-vct-alert-count="0" aria-label="Alertas: 0">
                <span class="vct-360-alert-icon"><span data-vct-icon="bell"></span></span>
                <span class="vct-360-alert-count">0</span>
            </div>
            <span class="vct-360-card-divider" aria-hidden="true"></span>
            <div class="vct-360-last-management">
                <span class="vct-360-inline-stat-icon"><span data-vct-icon="calendar"></span></span>
                <span>
                    <span class="vct-360-inline-stat-label">Última Gestión</span>
                    <span class="vct-360-inline-stat-value">'+@UltimaGestionFechaTxt+'</span>
                </span>
            </div>
        </div>
    </div>
 
    <div class="vct-360-content-shell">
        <div class="vct-360-stats-row">
            <div class="vct-360-stat" data-vct-tone="blue">
                <span class="vct-360-stat-main"><span class="vct-360-stat-label">Proyectos totales</span><b>'+CONVERT(VARCHAR(10),@ProyectosCount)+'</b><small>'+CONVERT(VARCHAR(10),@ProyectosEnCurso)+' en curso</small></span>
                <span class="vct-360-stat-icon"><span data-vct-icon="folder"></span></span>
            </div>
            <div class="vct-360-stat" data-vct-tone="violet">
                <span class="vct-360-stat-main"><span class="vct-360-stat-label">Gestiones</span><b>'+CONVERT(VARCHAR(10),@GestionesCount)+'</b><small>'+CONVERT(VARCHAR(10),@GestionesAnio)+' este año</small></span>
                <span class="vct-360-stat-icon"><span data-vct-icon="list-checks"></span></span>
            </div>
            <div class="vct-360-stat" data-vct-tone="mint">
                <span class="vct-360-stat-main"><span class="vct-360-stat-label">Días ejecutados</span><b>'+REPLACE(CONVERT(VARCHAR(40),CONVERT(DECIMAL(18,1),@DiasEjecutados)),'.',',')+'</b><small>promedio '+REPLACE(CONVERT(VARCHAR(40),@DiasPromedioProyecto),'.',',')+' por proyecto</small></span>
                <span class="vct-360-stat-icon"><span data-vct-icon="calendar-days"></span></span>
            </div>
            <div class="vct-360-stat" data-vct-tone="amber">
                <span class="vct-360-stat-main"><span class="vct-360-stat-label">Honorarios / viáticos</span><b>$'+@HonorariosViaticosTxt+'</b><small>'+CONVERT(VARCHAR(10),@SinLiquidar)+' sin liquidar</small></span>
                <span class="vct-360-stat-icon"><span data-vct-icon="circle-dollar-sign"></span></span>
            </div>
        </div>
 
        <div class="vct-360-tabsbar" data-vct-tablist>
            <button type="button" data-vct-tab="resumen"><span data-vct-icon="scan-eye"></span><span>Resumen</span></button>
            <button type="button" data-vct-tab="servicios"><span data-vct-icon="briefcase"></span><span>Servicios</span></button>
            <button type="button" data-vct-tab="proyectos"><span data-vct-icon="folder"></span><span>Proyectos</span></button>
            <button type="button" data-vct-tab="gestiones"><span data-vct-icon="list-checks"></span><span>Gestiones</span></button>
            <button type="button" data-vct-tab="normas"><span data-vct-icon="clipboard-check"></span><span>Normas</span></button>
            <button type="button" data-vct-tab="dias"><span data-vct-icon="calendar-days"></span><span>Días mensuales</span></button>
            <button type="button" data-vct-tab="domicilio"><span data-vct-icon="map-pin"></span><span>Domicilios</span></button>
            <button type="button" data-vct-tab="telefonos"><span data-vct-icon="phone"></span><span>Teléfonos</span></button>
            <button type="button" data-vct-tab="email"><span data-vct-icon="mail"></span><span>Emails</span></button>
            <button type="button" data-vct-tab="documentos"><span data-vct-icon="file-text"></span><span>Documentos</span></button>
            <button type="button" data-vct-tab="notas"><span data-vct-icon="clipboard-check"></span><span>Notas</span></button>
            <button type="button" data-vct-tab="agenda"><span data-vct-icon="calendar"></span><span>Agenda</span></button>
        </div>
';
 
    /* ============================================================
       19. OUTPUT 2 - PANELES
       ============================================================ */
    SET @OUTPARAM2='
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="resumen">
            <div class="vct-360-box vct-360-box-compact vct-360-recent-projects-box">
                <div class="vct-360-box-head">
                    <h3><span class="vct-360-title-icon" data-vct-icon="folder"></span>Últimos Proyectos</h3>
                    <button type="button" data-vct-tab-link="proyectos">Ver todos</button>
                </div>
                '+@HTML_PROYECTOS_TOP+'
            </div>
 
            <div class="vct-360-box vct-360-active-management-box">
                <div class="vct-360-box-head">
                    <div>
                        <h3><span class="vct-360-title-icon" data-vct-icon="chart-bar"></span>Gestiones de proyectos activos</h3>
                        <p class="vct-360-box-subtitle">Distribución por estado de las gestiones del consultor vinculadas a proyectos activos.</p>
                    </div>
                </div>
                '+@HTML_GESTIONES_ACTIVOS+'
            </div>
 
            <div class="vct-360-box vct-360-box-compact vct-360-recent-management-box">
                <div class="vct-360-box-head">
                    <h3><span class="vct-360-title-icon" data-vct-icon="list-checks"></span>Últimas Gestiones</h3>
                    <button type="button" data-vct-tab-link="gestiones">Ver todas</button>
                </div>
                '+@HTML_GESTIONES_TOP+'
            </div>
 
            <div class="vct-360-summary-charts">
                <div class="vct-360-box">
                    <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="folder"></span>Proyectos por estado</h3></div>
                    '+@HTML_CHART_PROY_ESTADO+'
                </div>
                <div class="vct-360-box">
                    <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="users"></span>Clientes asignados</h3></div>
                    '+@HTML_CHART_CLIENTES+'
                </div>
                <div class="vct-360-box">
                    <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="list-checks"></span>Gestiones por estado</h3></div>
                    '+@HTML_CHART_GEST_ESTADO+'
                </div>
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="domicilio">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="map-pin"></span>Domicilios ('+CONVERT(VARCHAR(10),@DomiciliosCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_DOM,'')+'</div>
                </div>
                '+@HTML_DOMICILIOS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="telefonos">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="phone"></span>Teléfonos ('+CONVERT(VARCHAR(10),@TelefonosCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_TEL,'')+'</div>
                </div>
                '+@HTML_TELEFONOS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="email">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="mail"></span>Emails ('+CONVERT(VARCHAR(10),@EmailsCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_MAIL,'')+'</div>
                </div>
                '+@HTML_EMAILS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="servicios">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="briefcase"></span>Servicios ('+CONVERT(VARCHAR(10),@ServiciosCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_SERVC,'')+'</div>
                </div>
                '+@HTML_SERVICIOS+'
            </div>
        </div>

        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="normas">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="clipboard-check"></span>Normas ('+CONVERT(VARCHAR(10),@NormasCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_NORMA,'')+'</div>
                </div>
                '+@HTML_NORMAS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="dias">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head vct-360-section-head">
                    <div><h3><span class="vct-360-title-icon" data-vct-icon="calendar-days"></span>Días mensuales ('+CONVERT(VARCHAR(10),@HistoricoCount)+')</h3></div>
                    <div class="vct-360-box-actions">'+ISNULL(@BTN_ADD_HIST,'')+'</div>
                </div>
                '+@HTML_HISTORICO+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="proyectos">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="folder"></span>Proyectos ('+CONVERT(VARCHAR(10),@ProyectosCount)+')</h3></div>
                '+@HTML_PROYECTOS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="gestiones">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="list-checks"></span>Gestiones ('+CONVERT(VARCHAR(10),@GestionesCount)+')</h3></div>
                '+@HTML_GESTIONES+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="documentos">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="file-text"></span>Documentos ('+CONVERT(VARCHAR(10),@DocumentosCount)+')</h3></div>
                '+@HTML_DOCUMENTOS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="notas">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="clipboard-check"></span>Notas ('+CONVERT(VARCHAR(10),@NotasCount)+')</h3></div>
                '+@HTML_NOTAS+'
            </div>
        </div>
 
        <div class="vct-360-panel vct-consultor360-panel" data-vct-panel="agenda">
            <div class="vct-360-box vct-360-box-grid-auto">
                <div class="vct-360-box-head"><h3><span class="vct-360-title-icon" data-vct-icon="calendar"></span>Agenda</h3></div>
                <div class="vct-360-empty vct-360-fixed-empty">Sin datos por el momento.</div>
            </div>
        </div>
    </div>
</section>
</div>';
 
    /* ============================================================
       20. OUTPUT 3 - DRAWERS
       ============================================================ */
    SET @OUTPARAM3=
        ISNULL(@HTML_DRAWER_DOM,'')+
        ISNULL(@HTML_DRAWER_TEL,'')+
        ISNULL(@HTML_DRAWER_MAIL,'')+
        ISNULL(@HTML_DRAWER_NORMA,'')+
        ISNULL(@HTML_DRAWER_SERVC,'')+
        ISNULL(@HTML_DRAWER_HIST,'');
 
END
GO
