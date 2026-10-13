    /* DIAG_FLOW_NODOS2 (SOLO LECTURA) - Query > SQLCMD Mode (F5)
       Busca en las tablas del motor de flujo DONDE se ata el nodo/estructura al SP,
       comparando CONFIGURACION (anda) vs AGENDA_CONSULTOR (no anda).
       Barre columnas de texto buscando los SP_CODE y las estructuras clave.
       No cambia nada. Correr en ventana NUEVA y vacia. */
    :OUT C:\Users\Usuario\Desktop\muhle-vct\_diag\DIAG_FLOW_NODOS2.txt
    USE [MuhlePROD];
    SET NOCOUNT ON;
    
    DECLARE @tabs TABLE (t SYSNAME);
    INSERT INTO @tabs(t) VALUES
     ('CALL_CONV_STRUCTURES'),('CONV_STRUCTURE_STEP_NORMAL'),('CONV_STRUCTURE_STEP_QUESTION'),
     ('CONV_STRUCTURE_STEP_TRAN'),('PHYSICAL_CALL_CONV_STEPS'),('DSS_TBPHYSICAL_CALL_CONV_STEPS'),
     ('PHYSICAL_ACTIVITIES'),('STEP_CHECKS_SP'),('STEP_RESULTS');
    
    DECLARE @t SYSNAME, @sql NVARCHAR(MAX), @pred NVARCHAR(MAX);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT t FROM @tabs WHERE OBJECT_ID('dbo.'+t) IS NOT NULL;
    OPEN c; FETCH NEXT FROM c INTO @t;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '';
        PRINT '===== ' + @t + ' : filas que mencionan CONFIGURACI / AGENDA_CONS / estructuras clave =====';
    
        SELECT @pred = ISNULL((
            SELECT ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%VCT_MAIN_CONFIGURACI%'''
                 + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%VCT_MAIN_AGENDA_CONS%'''
                 + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%C576D92F%'''
                 + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%EE2B3F6F%'''
                 + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%AGENDA_CONSULTOR%'''
                 + ' OR CONVERT(NVARCHAR(MAX),' + QUOTENAME(COLUMN_NAME) + ') LIKE ''%CONFIGURACION%'''
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = @t
              AND DATA_TYPE IN ('varchar','nvarchar','char','nchar','text','ntext','uniqueidentifier')
            FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)'), '');
    
        IF @pred = ''
            PRINT '(sin columnas de texto)';
        ELSE
        BEGIN
            SET @sql = 'SELECT * FROM dbo.' + QUOTENAME(@t) + ' WHERE 1=0' + @pred;
            BEGIN TRY EXEC sys.sp_executesql @sql; END TRY
            BEGIN CATCH PRINT 'ERROR en ' + @t + ': ' + ERROR_MESSAGE(); END CATCH;
        END;
    
        FETCH NEXT FROM c INTO @t;
    END;
    CLOSE c; DEALLOCATE c;
    
    PRINT '';
    PRINT '===== FIN =====';
    GO
