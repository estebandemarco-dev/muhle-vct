/* ========================================================================
   V360_GRILLAS_ESTANDAR_V1
   ------------------------------------------------------------------------
   NO toca permisos ni vistas. Estandar unico de columnas en las 4 Vistas 360
   (CLAUDE.md, regla 15): mismo nombre de columna = misma data y mismo diseno
   en cualquier pestana y en cualquier 360.

   Sobre dbo.VCT_MAIN_CLIENTES_V360, VCT_MAIN_CONSULTORES_V360,
   VCT_MAIN_EMPLEADOS_V360 y VCT_MAIN_PROVEEDORES_V360:
   1) Columna Proyecto = "(codigo) nombre" + referencia debajo. Se saca el
      renglon extra "Rol: ..." (Consultor / Empleado, Resumen y pestana
      Proyectos), que no es data de la columna Proyecto.
   2) Sube las versiones: vct-datagrid.css?v=30 y vct-datagrid.js?v=12
      (el js v12 trae VCTColStd: anchos del catalogo en las tablas del
      Resumen; el css v30 la tipografia y la celda de proyecto).
   Lee OBJECT_DEFINITION y aplica por anclas; si no encuentra algo avisa y
   sigue. Re-ejecutable. Sin caracteres no ASCII.
   Antes de correrlo: subir css/vct-datagrid.css (v30) y js/vct-datagrid.js (v12).
   ======================================================================== */
SET NOCOUNT ON;

DECLARE @SPS TABLE (ORD INT, NOMBRE SYSNAME);
INSERT INTO @SPS VALUES (1, N'VCT_MAIN_CLIENTES_V360'), (2, N'VCT_MAIN_CONSULTORES_V360'),
                        (3, N'VCT_MAIN_EMPLEADOS_V360'), (4, N'VCT_MAIN_PROVEEDORES_V360');

DECLARE @VER TABLE (ORD INT, MARCA NVARCHAR(40), NUEVO NVARCHAR(10));
INSERT INTO @VER VALUES (1, N'vct-datagrid.css?v=', N'30'), (2, N'vct-datagrid.js?v=', N'12');

DECLARE @nom SYSNAME, @d NVARCHAR(MAX), @orig NVARCHAR(MAX), @trg_on BIT = 0,
        @p INT, @s INT, @e INT, @k INT, @q INT, @r NVARCHAR(MAX), @rol INT, @ok BIT,
        @marca NVARCHAR(40), @nuevo NVARCHAR(10), @vo INT, @cambios INT, @antes NVARCHAR(400), @msg NVARCHAR(2000);

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_VCT_AUDITORIA_DDL' AND parent_class = 0 AND is_disabled = 0) SET @trg_on = 1;
IF @trg_on = 1 DISABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;

DECLARE csp CURSOR LOCAL FAST_FORWARD FOR SELECT NOMBRE FROM @SPS ORDER BY ORD;
OPEN csp;
FETCH NEXT FROM csp INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @d = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + QUOTENAME(@nom)));
    IF @d IS NULL
        PRINT 'AVISO: no existe dbo.' + @nom + ' (se saltea).';
    ELSE
    BEGIN
        SET @orig = @d;
        SET @msg = @nom + ':';

        /* ---- 1. sacar los renglones "Rol: ..." de la celda de proyecto ----
           Bloque: CASE WHEN ... THEN '<span class="vct-360-project-ref">Rol: ' + ... ELSE '' END + */
        SET @rol = 0;
        SET @ok = 1;
        WHILE @ok = 1 AND CHARINDEX(N'>Rol: ', @d) > 0
        BEGIN
            SET @p = CHARINDEX(N'>Rol: ', @d);
            SET @r = REVERSE(LEFT(@d, @p - 1));
            SET @k = CHARINDEX(N'NEHW ESAC', @r);
            SET @s = CASE WHEN @k > 0 THEN @p - @k - 8 ELSE 0 END;
            SET @e = CHARINDEX(N'END', @d, @p);
            IF @k = 0 OR @s < 1 OR SUBSTRING(@d, @s, 9) <> N'CASE WHEN' OR @p - @s > 400
               OR @e = 0 OR @e - @p > 600 OR CHARINDEX(N'ELSE', SUBSTRING(@d, @p, @e - @p)) = 0
            BEGIN
                SET @msg = @msg + ' AVISO no se pudo ubicar un bloque "Rol:" (se deja como esta);';
                SET @ok = 0;
            END
            ELSE
            BEGIN
                SET @q = @e + 3;
                WHILE @q <= LEN(@d) AND SUBSTRING(@d, @q, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13)) SET @q = @q + 1;
                IF SUBSTRING(@d, @q, 1) = N'+' SET @q = @q + 1;
                ELSE SET @q = @e + 3;
                SET @d = STUFF(@d, @s, @q - @s, N'');
                SET @rol = @rol + 1;
            END;
        END;
        SET @msg = @msg + ' renglones Rol quitados=' + CONVERT(VARCHAR(10), @rol) + ';';

        /* ---- 2. versiones de la grilla ---- */
        DECLARE cv CURSOR LOCAL FAST_FORWARD FOR SELECT ORD, MARCA, NUEVO FROM @VER ORDER BY ORD;
        OPEN cv;
        FETCH NEXT FROM cv INTO @vo, @marca, @nuevo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @cambios = 0;
            SET @antes = N'';
            SET @p = CHARINDEX(@marca, @d);
            WHILE @p > 0
            BEGIN
                SET @q = @p + LEN(@marca);
                SET @k = @q;
                WHILE @k <= LEN(@d) AND SUBSTRING(@d, @k, 1) LIKE N'[0-9]' SET @k = @k + 1;
                SET @antes = @antes + CASE WHEN @antes = N'' THEN N'' ELSE N',' END + SUBSTRING(@d, @q, @k - @q);
                IF SUBSTRING(@d, @q, @k - @q) <> @nuevo
                BEGIN
                    SET @d = STUFF(@d, @q, @k - @q, @nuevo);
                    SET @cambios = @cambios + 1;
                END;
                SET @p = CHARINDEX(@marca, @d, @q);
            END;
            SET @msg = @msg + ' ' + @marca + CASE WHEN @antes = N'' THEN N'(no esta)' ELSE @antes + N'->' + @nuevo END + ';';
            FETCH NEXT FROM cv INTO @vo, @marca, @nuevo;
        END;
        CLOSE cv;
        DEALLOCATE cv;

        /* ---- 3. grabar ---- */
        IF @d = @orig
            PRINT 'OK   ' + @msg + ' sin cambios (ya estaba al dia).';
        ELSE
        BEGIN
            SET @p = PATINDEX(N'%CREATE%PROC%', @d);
            IF @p = 0
                PRINT 'FALLO ' + @msg + ' no se encontro CREATE PROCEDURE.';
            ELSE
            BEGIN
                IF PATINDEX(N'%CREATE%OR%ALTER%PROC%', SUBSTRING(@d, @p, 60)) <> 1
                    SET @d = STUFF(@d, @p, 6, N'ALTER');
                BEGIN TRY
                    EXEC sp_executesql @d;
                    PRINT 'OK   ' + @msg;
                END TRY
                BEGIN CATCH
                    PRINT 'FALLO ' + @msg + ' ' + ERROR_MESSAGE() + ' (sin cambios)';
                END CATCH;
            END;
        END;
    END;
    FETCH NEXT FROM csp INTO @nom;
END;
CLOSE csp;
DEALLOCATE csp;

IF @trg_on = 1
BEGIN
    ENABLE TRIGGER TR_VCT_AUDITORIA_DDL ON DATABASE;
    PRINT 'OK   trigger TR_VCT_AUDITORIA_DDL reactivado.';
END;
