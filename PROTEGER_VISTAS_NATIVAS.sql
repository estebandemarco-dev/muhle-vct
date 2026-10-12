/* ========================================================================
   PROTEGER_VISTAS_NATIVAS
   ------------------------------------------------------------------------
   Las vistas nativas del sistema (core Engage + catalogos del sistema
   original) NO se pueden modificar ni eliminar. Ya se borraron una vez por
   error y hubo que recuperarlas de la base productiva.

   1) Verifica que las 49 vistas existan (lista las que falten).
   2) Crea el trigger de base TR_VCT_PROTEGER_VISTAS_NATIVAS: si alguien
      (script, SSMS o un SP) intenta DROP VIEW o ALTER VIEW sobre una de
      estas vistas, la operacion se cancela con un mensaje claro.
      No afecta a ningun otro objeto (tablas, SPs, otras vistas).
   No crea tablas, vistas ni funciones. No toca permisos. Re-ejecutable.

   Si algun dia hiciera falta tocar una de estas vistas a proposito, hay que
   deshabilitar el trigger a mano y volver a habilitarlo:
       DISABLE TRIGGER TR_VCT_PROTEGER_VISTAS_NATIVAS ON DATABASE;
       ...
       ENABLE TRIGGER TR_VCT_PROTEGER_VISTAS_NATIVAS ON DATABASE;
   ======================================================================== */
USE [MuhlePROD];
SET NOCOUNT ON;
GO

/* 1. control de existencia */
DECLARE @V TABLE (NOMBRE SYSNAME);
INSERT INTO @V (NOMBRE) VALUES
    (N'VW_SYS_UNIDAD'),
    (N'VW_SYS_USUARIO'),
    (N'Calendar_vw'),
    (N'VW_SYS_PROCESS_ATTACH_QTY'),
    (N'VW_SYS_PROCESS_NOTE_QTY'),
    (N'VW_SYS_QUERY_INBOX'),
    (N'VW_SYS_QUERY_INBOX_COUNT'),
    (N'EVI_TABLES'),
    (N'EVI_TABLE_COLUMNS'),
    (N'EVI_TABLE_INDEXES'),
    (N'EVI_TABLE_COLUMN_INDEXES'),
    (N'EVI_TABLE_SIZES'),
    (N'EVI_SCHEMA_SIZES'),
    (N'VW_SYS_CANTIDAD_USUARIOS'),
    (N'EVI_VIEWS'),
    (N'VW_SYS_CRITERIOS'),
    (N'VW_SYS_CAT_TYPE'),
    (N'VW_SYS_PROCESS_TYPE_CATS'),
    (N'VW_SYS_PROCESS_REASONS'),
    (N'VW_SYS_PROCESS_SUBREASONS'),
    (N'VW_SYS_HISTORY_PROCESS'),
    (N'VW_SYS_HISTORY_ACTIVITY'),
    (N'VW_SYS_HISTORY_CALL'),
    (N'EVI_TABLE_CONSTRAINTS'),
    (N'EVI_TABLE_COLUMN_CONSTRAINTS'),
    (N'EVI_SEQUENCES'),
    (N'EVI_TABLE_TRIGGERS'),
    (N'EVI_OBJECTS'),
    (N'EVI_OBJECT_DEPENDENCIES'),
    (N'EVI_OBJECT_SOURCES'),
    (N'EVI_TABLE_COLUMN_FOREIGN_KEYS'),
    (N'EVI_DATA_TYPES'),
    (N'EVI_DATABASE_SESSIONS'),
    (N'EVI_PROCEDURES'),
    (N'v_sys_profiles'),
    (N'VW_CLIENTES'),
    (N'VW_COTIZACIONES'),
    (N'VW_MOTIVOS_TRAMITE'),
    (N'VW_PROVEEDORES'),
    (N'VW_PROYECTOS'),
    (N'VW_RPT_AGENTE'),
    (N'VW_SERVICIOS'),
    (N'VW_SYS_LISTAS_INTERNAS'),
    (N'VW_SYS_PROCESOS_PEND_INBOX'),
    (N'VW_SYS_PROCESOS_PEND_LISTAS'),
    (N'VW_SYS_RPT_MOT_SUBMOT'),
    (N'VW_SYS_SEARCH'),
    (N'VW_TIPOS_VIATICOS'),
    (N'VW_USER_TABLES');

DECLARE @faltan INT = (SELECT COUNT(*) FROM @V v WHERE OBJECT_ID(N'dbo.' + v.NOMBRE, 'V') IS NULL);
IF @faltan = 0
    PRINT 'OK: las 49 vistas nativas existen.';
ELSE
BEGIN
    PRINT 'ATENCION: faltan ' + CONVERT(VARCHAR(10), @faltan) + ' vistas nativas (recuperarlas de la base productiva):';
    SELECT v.NOMBRE AS VISTA_FALTANTE FROM @V v WHERE OBJECT_ID(N'dbo.' + v.NOMBRE, 'V') IS NULL ORDER BY v.NOMBRE;
END;
GO

/* 2. trigger de proteccion */
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_PROTEGER_VISTAS_NATIVAS' AND parent_class = 0)
    DROP TRIGGER TR_VCT_PROTEGER_VISTAS_NATIVAS ON DATABASE;
GO

CREATE TRIGGER TR_VCT_PROTEGER_VISTAS_NATIVAS
ON DATABASE
FOR DROP_VIEW, ALTER_VIEW
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ev XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) = UPPER(@ev.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)'));
    DECLARE @tipo NVARCHAR(100) = @ev.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)');
    IF @obj IN (
        N'VW_SYS_UNIDAD',
        N'VW_SYS_USUARIO',
        N'CALENDAR_VW',
        N'VW_SYS_PROCESS_ATTACH_QTY',
        N'VW_SYS_PROCESS_NOTE_QTY',
        N'VW_SYS_QUERY_INBOX',
        N'VW_SYS_QUERY_INBOX_COUNT',
        N'EVI_TABLES',
        N'EVI_TABLE_COLUMNS',
        N'EVI_TABLE_INDEXES',
        N'EVI_TABLE_COLUMN_INDEXES',
        N'EVI_TABLE_SIZES',
        N'EVI_SCHEMA_SIZES',
        N'VW_SYS_CANTIDAD_USUARIOS',
        N'EVI_VIEWS',
        N'VW_SYS_CRITERIOS',
        N'VW_SYS_CAT_TYPE',
        N'VW_SYS_PROCESS_TYPE_CATS',
        N'VW_SYS_PROCESS_REASONS',
        N'VW_SYS_PROCESS_SUBREASONS',
        N'VW_SYS_HISTORY_PROCESS',
        N'VW_SYS_HISTORY_ACTIVITY',
        N'VW_SYS_HISTORY_CALL',
        N'EVI_TABLE_CONSTRAINTS',
        N'EVI_TABLE_COLUMN_CONSTRAINTS',
        N'EVI_SEQUENCES',
        N'EVI_TABLE_TRIGGERS',
        N'EVI_OBJECTS',
        N'EVI_OBJECT_DEPENDENCIES',
        N'EVI_OBJECT_SOURCES',
        N'EVI_TABLE_COLUMN_FOREIGN_KEYS',
        N'EVI_DATA_TYPES',
        N'EVI_DATABASE_SESSIONS',
        N'EVI_PROCEDURES',
        N'V_SYS_PROFILES',
        N'VW_CLIENTES',
        N'VW_COTIZACIONES',
        N'VW_MOTIVOS_TRAMITE',
        N'VW_PROVEEDORES',
        N'VW_PROYECTOS',
        N'VW_RPT_AGENTE',
        N'VW_SERVICIOS',
        N'VW_SYS_LISTAS_INTERNAS',
        N'VW_SYS_PROCESOS_PEND_INBOX',
        N'VW_SYS_PROCESOS_PEND_LISTAS',
        N'VW_SYS_RPT_MOT_SUBMOT',
        N'VW_SYS_SEARCH',
        N'VW_TIPOS_VIATICOS',
        N'VW_USER_TABLES'
    )
    BEGIN
        ROLLBACK;
        RAISERROR('BLOQUEADO: la vista %s es nativa del sistema y no se puede modificar ni eliminar (%s).', 16, 1, @obj, @tipo);
    END;
END;
GO

PRINT 'OK: trigger TR_VCT_PROTEGER_VISTAS_NATIVAS activo (bloquea DROP/ALTER de las vistas nativas).';
GO
