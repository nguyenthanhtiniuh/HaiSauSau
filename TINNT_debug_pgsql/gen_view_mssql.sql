DECLARE @table TABLE (TableName NVARCHAR(256), Id INT IDENTITY, _Check INT DEFAULT 0)
INSERT INTO @table (TableName)
SELECT TRIM(value)
FROM STRING_SPLIT('B30LCDoc', ',')

DECLARE @_Table_Name VARCHAR(256) = ''
DECLARE @_Extension_View VARCHAR(256) = ''

SELECT @_Extension_View = '_VC'

SELECT @_Extension_View = ''

SELECT @_Extension_View = '_Edit'
SELECT @_Extension_View = '_Explore'

WHILE EXISTS (SELECT * FROM @table WHERE _Check = 0)
BEGIN
    SELECT TOP 1 @_Table_Name = TRIM(TableName)
    FROM @table
    WHERE _Check = 0
    ORDER BY Id ASC

    UPDATE @table
    SET _Check = 1
    WHERE TableName = @_Table_Name

    DECLARE @_object_id INT = OBJECT_ID(@_Table_Name)
    DROP TABLE IF EXISTS #tblINFORMATION_SCHEMACOLUMNS
    SELECT schemacolumns.COLUMN_NAME,
        UPPER(schemacolumns.DATA_TYPE) AS DATA_TYPE,
        schemacolumns.CHARACTER_MAXIMUM_LENGTH,
        schemacolumns.IS_NULLABLE,
        schemacolumns.ORDINAL_POSITION,
        _description.value,
        CASE WHEN RIGHT(schemacolumns.COLUMN_NAME, 2) = 'Id' THEN 'Id' WHEN RIGHT(schemacolumns.COLUMN_NAME, 4) = 'Code' THEN 'Code' ELSE '' END AS _TypeColum,
        CAST(ISNULL(metadata.Description, '') AS NVARCHAR(400)) AS Description,
        CASE WHEN CHARINDEX('Id', schemacolumns.COLUMN_NAME) >= 1 THEN REPLACE(schemacolumns.COLUMN_NAME, 'Id', '') WHEN CHARINDEX('Code', schemacolumns.COLUMN_NAME) >= 1 THEN REPLACE(schemacolumns.COLUMN_NAME, 'Code', '') ELSE '' END AS LookupKeyBr,
        CASE WHEN schemacolumns.CHARACTER_MAXIMUM_LENGTH IS NULL THEN '100' ELSE TRIM(STR(schemacolumns.CHARACTER_MAXIMUM_LENGTH)) END AS XML_Width,
        CASE WHEN CHARINDEX('char', metadata.DataType) >= 1 THEN 'TextAlign:LeftTop;' ELSE 'TextAlign:RightTop;' END AS TextAlign,
        CAST('' AS NVARCHAR(256)) EditorBr    
    INTO #tblINFORMATION_SCHEMACOLUMNS
    FROM INFORMATION_SCHEMA.COLUMNS schemacolumns
        LEFT JOIN (SELECT prop.value, col.column_id FROM sys.columns col INNER JOIN sys.tables tab ON col.object_id = tab.object_id AND tab.name = @_Table_Name LEFT JOIN sys.extended_properties prop ON col.object_id = prop.major_id AND col.column_id = prop.minor_id AND prop.class = 1) _description ON _description.column_id = schemacolumns.ORDINAL_POSITION
        LEFT JOIN (SELECT c.name AS ColumnName, t.name AS DataType, c.max_length, c.precision, c.scale, c.is_nullable, c.is_identity, d.definition AS DefaultValue, ep.value AS Description FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id LEFT JOIN sys.default_constraints d ON c.default_object_id = d.object_id LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description' WHERE c.object_id = OBJECT_ID('dbo.' + @_Table_Name + '')) metadata ON metadata.ColumnName = schemacolumns.COLUMN_NAME
    WHERE schemacolumns.TABLE_NAME = @_Table_Name

    DECLARE @_Table_Name_Alias NVARCHAR(256) = N''

    SELECT @_Table_Name_Alias = REPLACE(@_Table_Name, 'B20', '')
    SELECT @_Table_Name_Alias = REPLACE(@_Table_Name_Alias, 'B30', '')
    SELECT @_Table_Name_Alias = REPLACE(@_Table_Name_Alias, 'B40', '')    
    SELECT @_Table_Name_Alias = (@_Table_Name_Alias)

    DROP TABLE IF EXISTS #loookcom;
    SELECT loo.LookupKey,
        loo.LookupTable,
        omm.Text,
        omm.Text_English,
        CONCAT(' FROM ', @_Table_Name, '   ', @_Table_Name_Alias, '  ') AS FR_,
        CONCAT(' LEFT JOIN ' + REPLACE(loo.LookupTable, '{=BRANCH(''DataCode'')}', '0') + ' ' + (loo.LookupKey) + '   WITH (NOLOCK)  ON ', @_Table_Name_Alias, '.', COLUMN_NAME, ' = ', loo.LookupKey, '.', ns._TypeColum) AS LEFT_,
        '
	   ,' + loo.LookupKey + '.Code AS ' + loo.LookupKey + 'Code
      ,' + loo.LookupKey + '.Name AS ' + loo.LookupKey + 'Name' AS Col_Alias,
        ns.*
    INTO #loookcom
    FROM #tblINFORMATION_SCHEMACOLUMNS ns
        LEFT JOIN B10THACOID.dbo.B00Lookup loo ON (ns.LookupKeyBr = loo.LookupKey OR COLUMN_NAME = loo.LookupKey        
        ) AND loo.LookupKey NOT IN ('DocStatus', 'Branch', 'Currency', 'UNIT', 'FiscalYear')
        LEFT JOIN B10THACOID.dbo.B00Command omm ON loo.LookupKey = omm.CommandKey

    DECLARE @_Script_Create NVARCHAR(MAX) = N''
    DECLARE @_Script_Create_Select NVARCHAR(MAX) = N' SELECT '
    DECLARE @_Script_Create_From NVARCHAR(MAX) = N''
    DECLARE @_Script_Create_LeftJoin NVARCHAR(MAX) = N''
    DECLARE @_Script_All NVARCHAR(MAX) = N''

    SELECT @_Script_Create_Select = @_Script_Create_Select + N' ' + (@_Table_Name_Alias + '.' + COLUMN_NAME + ' , ')
    FROM #loookcom

    SELECT @_Script_Create_Select = LEFT(@_Script_Create_Select, (LEN(@_Script_Create_Select) - CHARINDEX(',', REVERSE(@_Script_Create_Select))))

    SELECT @_Script_Create_Select = @_Script_Create_Select + N' ' + Col_Alias
    FROM #loookcom
    WHERE Col_Alias IS NOT NULL

    SELECT TOP 1 @_Script_Create_From = FR_
    FROM #loookcom

    SELECT @_Script_Create_LeftJoin = STRING_AGG(LEFT_, ' ' + CHAR(10) + ' ')
    FROM #loookcom
    WHERE LookupKey IS NOT NULL

    IF (CHARINDEX('_Explore', @_Extension_View) >= 1)
    BEGIN
        SELECT @_Script_Create_Select = @_Script_Create_Select + N'     ,CreatedBy.FullName AS CreatedName ,ModifiedBy.FullName AS ModifiedName  '
    END

    PRINT CONCAT(' CREATE OR ALTER VIEW  v' + @_Table_Name + '' + @_Extension_View + ' AS ', @_Script_Create_Select, CHAR(10) + '', @_Script_Create_From, CHAR(10) + '', @_Script_Create_LeftJoin)

    SELECT @_Script_All = CONCAT('CREATE OR ALTER VIEW  v' + @_Table_Name + '' + @_Extension_View + ' AS ', (@_Script_Create_Select), CHAR(10) + '', @_Script_Create_From, CHAR(10) + '', @_Script_Create_LeftJoin)    
    SELECT @_Script_All = REPLACE(@_Script_All, ',ZGTKH.Name AS ZGTKHName', ' ')

    IF (CHARINDEX('_Explore', @_Extension_View) >= 1)
    BEGIN
        SELECT @_Script_All = CONCAT(@_Script_All, '  LEFT JOIN dbo.B00UserList CreatedBy WITH (NOLOCK) ON ' + @_Table_Name_Alias + '.CreatedBy = CreatedBy.Id LEFT JOIN dbo.B00UserList ModifiedBy WITH (NOLOCK) ON ' + @_Table_Name_Alias + '.ModifiedBy = ModifiedBy.Id  ')
    END

    SELECT @_Table_Name,
        @_Table_Name + @_Extension_View,
        @_Script_All    

    DROP TABLE IF EXISTS #loookcom
END