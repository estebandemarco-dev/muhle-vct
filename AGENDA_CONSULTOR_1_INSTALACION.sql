/* ============================================================================
   AGENDA_CONSULTOR_1_INSTALACION
   ----------------------------------------------------------------------------
   Modelo nuevo de DISPONIBILIDAD del consultor.
     - Tabla  VCT_PRM_AGENDA_CONSULTOR : solo lo que el consultor DECLARA
       (capacidad del dia + bloqueos). NO guarda ocupacion ni asignaciones.
     - Funcion VCT_FN_AGENDA_CONSULTOR_RANGO : calcula por dia la capacidad,
       horas ocupadas (derivadas de las visitas), horas disponibles y estado.
     - Funcion VCT_FN_AGENDA_CONSULTOR_DIA : atajo de un solo dia.
     - Migracion CONSERVADORA (preview por defecto) desde LK_AGENDA_EMPLEADO:
       solo trae capacidades distintas del default (8 h), nunca asignaciones.

   Regla central: una sola fuente de verdad. La OCUPACION sale siempre de
   VCT_PROYECTOS_VISITAS* (lo planificado prorrateado + lo registrado real);
   los FERIADOS/FINDES salen de dbo.Calendar. La agenda guarda solo excepciones.

   Re-ejecutable. Compat 100/140 (sin OPENJSON / STRING_AGG / TRY_CONVERT).
   ============================================================================ */
USE [MuhlePROD];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------------
   1) TABLA  VCT_PRM_AGENDA_CONSULTOR   (una fila por consultor + dia)
   --------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.VCT_PRM_AGENDA_CONSULTOR') IS NULL
BEGIN
    CREATE TABLE dbo.VCT_PRM_AGENDA_CONSULTOR
    (
        ID              INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_VCT_PRM_AGENDA_CONSULTOR PRIMARY KEY,
        ID_CONSULTOR    INT          NOT NULL
            CONSTRAINT FK_VCT_PRM_AGENDA_CONS REFERENCES dbo.VCT_CONSULTORES (ID),
        FECHA           DATE         NOT NULL,
        HORAS_CAPACIDAD DECIMAL(5,2) NOT NULL
            CONSTRAINT DF_VCT_PRM_AGENDA_CAP DEFAULT (8),
        DISPONIBLE      BIT          NOT NULL
            CONSTRAINT DF_VCT_PRM_AGENDA_DISP DEFAULT (1),
        MOTIVO          VARCHAR(200) NULL,   -- por que esta bloqueado (reemplaza al HOLIDAYTEXT viejo)
        OBSERVACIONES   VARCHAR(400) NULL,
        FECHA_ALTA      DATETIME     NULL CONSTRAINT DF_VCT_PRM_AGENDA_FA DEFAULT (GETDATE()),
        USUARIO_ALTA    VARCHAR(100) NULL,
        FECHA_UPD       DATETIME     NULL,
        USUARIO_UPD     VARCHAR(100) NULL,
        CONSTRAINT UX_VCT_PRM_AGENDA_CONS_FECHA UNIQUE (ID_CONSULTOR, FECHA)
    );
    PRINT 'Tabla VCT_PRM_AGENDA_CONSULTOR creada.';
END
ELSE
    PRINT 'Tabla VCT_PRM_AGENDA_CONSULTOR ya existia. Sin cambios de estructura.';
GO

/* ---------------------------------------------------------------------------
   2) FUNCION  VCT_FN_AGENDA_CONSULTOR_RANGO
      Devuelve una fila por dia del rango con el calculo de disponibilidad.
      OCUPADAS = horas registradas reales + horas planificadas prorrateadas
                 de las visitas donde el consultor esta asignado (los dias
                 ya registrados no se cuentan dos veces).
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.VCT_FN_AGENDA_CONSULTOR_RANGO
(
    @ID_CONSULTOR INT,
    @DESDE        DATE,
    @HASTA        DATE
)
RETURNS TABLE
AS
RETURN
(
    WITH OCUP_RAW AS
    (
        /* a) lo REGISTRADO (real) por dia */
        SELECT R.FECHA AS F,
               CONVERT(DECIMAL(9,2), ISNULL(R.HORAS,0)) AS H
        FROM dbo.VCT_PROYECTOS_VISITAS_REGISTRO R
        WHERE R.ID_CONSULTOR = @ID_CONSULTOR
          AND R.FECHA BETWEEN @DESDE AND @HASTA

        UNION ALL

        /* b) lo PLANIFICADO prorrateado por dia (solo dias sin registro de esa visita) */
        SELECT cal.Fecha AS F,
               CONVERT(DECIMAL(9,2), ISNULL(VC.HORAS_PLANIFICADAS,0))
                   / NULLIF(COALESCE(NULLIF(V.DIAS,0), DC.N), 0) AS H
        FROM dbo.VCT_PROYECTOS_VISITAS V
        JOIN dbo.VCT_PROYECTOS_VISITAS_CONSULTORES VC
             ON VC.ID_VISITA = V.ID
            AND VC.ID_CONSULTOR = @ID_CONSULTOR
        JOIN dbo.Calendar cal
             ON cal.Fecha BETWEEN CONVERT(DATE, V.FECHA_DESDE)
                              AND CONVERT(DATE, ISNULL(V.FECHA_HASTA, V.FECHA_DESDE))
        CROSS APPLY
        (
            SELECT COUNT(*) AS N
            FROM dbo.Calendar c2
            WHERE c2.Fecha BETWEEN CONVERT(DATE, V.FECHA_DESDE)
                               AND CONVERT(DATE, ISNULL(V.FECHA_HASTA, V.FECHA_DESDE))
        ) DC
        WHERE cal.Fecha BETWEEN @DESDE AND @HASTA
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.VCT_PROYECTOS_VISITAS_REGISTRO R2
              WHERE R2.ID_VISITA   = V.ID
                AND R2.ID_CONSULTOR = @ID_CONSULTOR
                AND R2.FECHA        = cal.Fecha
          )
    ),
    OCUP AS
    (
        SELECT F, CONVERT(DECIMAL(9,2), SUM(H)) AS HORAS
        FROM OCUP_RAW
        GROUP BY F
    ),
    BASE AS
    (
        SELECT
            cal.Fecha,
            cal.FinDeSemana,
            cal.IsHoliday,
            cal.HolidayText,
            AG.DISPONIBLE,
            AG.MOTIVO,
            CONVERT(DECIMAL(5,2),
                CASE WHEN cal.FinDeSemana = 1 OR cal.IsHoliday = 1
                       OR ISNULL(AG.DISPONIBLE,1) = 0 THEN 0
                     ELSE ISNULL(AG.HORAS_CAPACIDAD, 8)
                END) AS CAP,
            CONVERT(DECIMAL(9,2), ISNULL(O.HORAS, 0)) AS OCUP
        FROM dbo.Calendar cal
        LEFT JOIN dbo.VCT_PRM_AGENDA_CONSULTOR AG
               ON AG.ID_CONSULTOR = @ID_CONSULTOR
              AND AG.FECHA = cal.Fecha
        LEFT JOIN OCUP O
               ON O.F = cal.Fecha
        WHERE cal.Fecha BETWEEN @DESDE AND @HASTA
    )
    SELECT
        @ID_CONSULTOR                       AS ID_CONSULTOR,
        Fecha                               AS FECHA,
        CAP                                 AS HORAS_CAPACIDAD,
        OCUP                                AS HORAS_OCUPADAS,
        CONVERT(DECIMAL(9,2),
            CASE WHEN CAP - OCUP < 0 THEN 0 ELSE CAP - OCUP END) AS HORAS_DISP,
        CASE WHEN IsHoliday = 1            THEN 'FERIADO'
             WHEN FinDeSemana = 1          THEN 'FINDE'
             WHEN ISNULL(DISPONIBLE,1) = 0 THEN 'BLOQUEADO'
             WHEN OCUP <= 0                THEN 'LIBRE'
             WHEN OCUP >= CAP              THEN 'OCUPADO'
             ELSE 'PARCIAL'
        END                                 AS ESTADO,
        CASE WHEN IsHoliday = 1            THEN HolidayText
             WHEN ISNULL(DISPONIBLE,1) = 0 THEN MOTIVO
             ELSE NULL
        END                                 AS MOTIVO
    FROM BASE
);
GO
PRINT 'Funcion VCT_FN_AGENDA_CONSULTOR_RANGO creada/actualizada.';
GO

/* ---------------------------------------------------------------------------
   3) FUNCION  VCT_FN_AGENDA_CONSULTOR_DIA  (atajo de un solo dia)
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.VCT_FN_AGENDA_CONSULTOR_DIA
(
    @ID_CONSULTOR INT,
    @FECHA        DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT * FROM dbo.VCT_FN_AGENDA_CONSULTOR_RANGO(@ID_CONSULTOR, @FECHA, @FECHA)
);
GO
PRINT 'Funcion VCT_FN_AGENDA_CONSULTOR_DIA creada/actualizada.';
GO

/* ---------------------------------------------------------------------------
   4) MIGRACION DESDE LK_AGENDA_EMPLEADO  (segun el TIPO real)
      Por defecto SOLO MUESTRA (preview). Para aplicar: @APLICAR = 1.

      Mapeo de TIPO (confirmado por la distribucion real):
        ND, LIC  -> BLOQUEO     : DISPONIBLE=0 (dia no disponible / licencia)
        D        -> CAPACIDAD   : solo si HORAS 1..12 y <> 8 (part-time real)
        A,OC,OP,OA,POT -> OMITIR: es ocupacion/asignacion, ya vive en
                                  VCT_PROYECTOS_VISITAS* (no se duplica).

      Prioridad si un mismo consultor+fecha tuviera varias: BLOQUEO manda.
   --------------------------------------------------------------------------- */
DECLARE @APLICAR BIT = 0;   -- <<< poner en 1 para ejecutar la migracion real

PRINT '';
PRINT '--- Preview: candidatos a migrar por clase ---';

;WITH SRC AS
(
    SELECT a.ID_EMPLEADO AS ID_CONSULTOR,
           a.FECHA,
           UPPER(LTRIM(RTRIM(ISNULL(a.TIPO,'')))) AS TIPO,
           a.HORAS
    FROM dbo.LK_AGENDA_EMPLEADO a
    JOIN dbo.VCT_CONSULTORES c ON c.ID = a.ID_EMPLEADO
),
BLOQUEOS AS   -- ND / LIC -> DISPONIBLE = 0
(
    SELECT DISTINCT ID_CONSULTOR, FECHA,
           MAX(CASE WHEN TIPO = 'LIC' THEN 'Licencia' ELSE 'No disponible' END) AS MOTIVO
    FROM SRC
    WHERE TIPO IN ('ND','LIC')
    GROUP BY ID_CONSULTOR, FECHA
),
CAPACIDAD AS  -- D con horas part-time (<>8) y plausibles, sin bloqueo ese dia
(
    SELECT s.ID_CONSULTOR, s.FECHA, MAX(s.HORAS) AS HORAS_CAP
    FROM SRC s
    WHERE s.TIPO = 'D'
      AND ISNULL(s.HORAS,0) BETWEEN 1 AND 12
      AND ISNULL(s.HORAS,0) <> 8
      AND NOT EXISTS (SELECT 1 FROM BLOQUEOS b
                      WHERE b.ID_CONSULTOR = s.ID_CONSULTOR AND b.FECHA = s.FECHA)
    GROUP BY s.ID_CONSULTOR, s.FECHA
)
SELECT 'BLOQUEOS (ND/LIC)' AS CLASE,
       COUNT(*) AS FILAS, COUNT(DISTINCT ID_CONSULTOR) AS CONSULTORES,
       MIN(FECHA) AS DESDE, MAX(FECHA) AS HASTA
FROM BLOQUEOS b
WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_AGENDA_CONSULTOR d
                  WHERE d.ID_CONSULTOR = b.ID_CONSULTOR AND d.FECHA = b.FECHA)
UNION ALL
SELECT 'CAPACIDAD (D <>8)' AS CLASE,
       COUNT(*), COUNT(DISTINCT ID_CONSULTOR), MIN(FECHA), MAX(FECHA)
FROM CAPACIDAD c
WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_AGENDA_CONSULTOR d
                  WHERE d.ID_CONSULTOR = c.ID_CONSULTOR AND d.FECHA = c.FECHA);

IF @APLICAR = 1
BEGIN
    /* 4.1 BLOQUEOS (ND / LIC) */
    INSERT INTO dbo.VCT_PRM_AGENDA_CONSULTOR
        (ID_CONSULTOR, FECHA, HORAS_CAPACIDAD, DISPONIBLE, MOTIVO, OBSERVACIONES, FECHA_ALTA, USUARIO_ALTA)
    SELECT b.ID_CONSULTOR, b.FECHA, 0, 0, b.MOTIVO,
           'Migrado de LK_AGENDA_EMPLEADO (bloqueo).', GETDATE(), 'MIGRACION'
    FROM (
        SELECT a.ID_EMPLEADO AS ID_CONSULTOR, a.FECHA,
               MAX(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(a.TIPO,'')))) = 'LIC' THEN 'Licencia' ELSE 'No disponible' END) AS MOTIVO
        FROM dbo.LK_AGENDA_EMPLEADO a
        WHERE UPPER(LTRIM(RTRIM(ISNULL(a.TIPO,'')))) IN ('ND','LIC')
          AND EXISTS (SELECT 1 FROM dbo.VCT_CONSULTORES c WHERE c.ID = a.ID_EMPLEADO)
        GROUP BY a.ID_EMPLEADO, a.FECHA
    ) b
    WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_AGENDA_CONSULTOR d
                      WHERE d.ID_CONSULTOR = b.ID_CONSULTOR AND d.FECHA = b.FECHA);
    PRINT 'Bloqueos (ND/LIC) insertados: ' + CONVERT(VARCHAR(20), @@ROWCOUNT);

    /* 4.2 CAPACIDAD part-time (D <>8), solo donde no quedo ya un bloqueo */
    INSERT INTO dbo.VCT_PRM_AGENDA_CONSULTOR
        (ID_CONSULTOR, FECHA, HORAS_CAPACIDAD, DISPONIBLE, OBSERVACIONES, FECHA_ALTA, USUARIO_ALTA)
    SELECT x.ID_CONSULTOR, x.FECHA, x.HORAS_CAP, 1,
           'Migrado de LK_AGENDA_EMPLEADO (capacidad declarada distinta de 8).',
           GETDATE(), 'MIGRACION'
    FROM (
        SELECT a.ID_EMPLEADO AS ID_CONSULTOR, a.FECHA, MAX(a.HORAS) AS HORAS_CAP
        FROM dbo.LK_AGENDA_EMPLEADO a
        JOIN dbo.VCT_CONSULTORES c ON c.ID = a.ID_EMPLEADO
        WHERE UPPER(LTRIM(RTRIM(ISNULL(a.TIPO,'')))) = 'D'
          AND ISNULL(a.HORAS,0) BETWEEN 1 AND 12
          AND ISNULL(a.HORAS,0) <> 8
        GROUP BY a.ID_EMPLEADO, a.FECHA
    ) x
    WHERE NOT EXISTS (SELECT 1 FROM dbo.VCT_PRM_AGENDA_CONSULTOR d
                      WHERE d.ID_CONSULTOR = x.ID_CONSULTOR AND d.FECHA = x.FECHA);
    PRINT 'Capacidades (D <>8) insertadas: ' + CONVERT(VARCHAR(20), @@ROWCOUNT);
END
ELSE
    PRINT 'PREVIEW (no se inserto nada). Si el mapeo ND/LIC/D esta ok, poner @APLICAR = 1 y volver a correr.';
GO

PRINT '';
PRINT '=== Listo. Prueba rapida (descomentar y poner un ID de consultor y rango):';
PRINT '--   SELECT * FROM dbo.VCT_FN_AGENDA_CONSULTOR_RANGO(19, ''2026-10-01'', ''2026-10-31'') ORDER BY FECHA;';
GO
