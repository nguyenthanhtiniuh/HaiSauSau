CREATE OR REPLACE PROCEDURE dbo.usp_b30bizdocdetail_getdata(IN p_docdate1 date DEFAULT '2006-01-01'::date,IN p_docdate2 date DEFAULT '2010-01-31'::date
,IN p_usingdatekey smallint DEFAULT 1,IN p_key text DEFAULT ''::text,IN p_cttmp character varying DEFAULT ''::character varying
,IN p_datecol character varying DEFAULT 'DocDate'::character varying,IN p_branchcode character varying DEFAULT 'A00'::character varying
,IN p_currencycode0 character DEFAULT 'VND'::bpchar,IN p_groupbycols text DEFAULT ''::text,IN p_notsumcols text DEFAULT ''::text
,IN p_nuserid integer DEFAULT 0,IN p_langid integer DEFAULT 0,IN p_bizdocname character varying DEFAULT 'vb30bizdocdetail_getdata'::character varying
,IN p_printexec smallint DEFAULT 0)
LANGUAGE plpgsql AS $procedure$
    DECLARE
        -- Coder: ThanhND
        -- Manager: VuLA
        -- Thủ tục GetData lấy dữ liệu từ BizDoc
        _strExec TEXT;
        _FieldSelect TEXT DEFAULT '';
        _FieldInsert TEXT DEFAULT '';
        _Where_Key TEXT := '(IsActive = TRUE)';
        _BranchCodeTmp VARCHAR(24) := '';
        _ref_table_exists BOOLEAN;
        _ref_table_exists_Count INT;
    BEGIN
        IF p_DateCol IS NULL OR p_DateCol = '' THEN
            p_DateCol := 'DocDate';
        END IF;

        p_DocDate1 := COALESCE(p_DocDate1,'19000101'::DATE);

        IF p_UsingDateKey = 1 THEN
            _Where_Key := _Where_Key || ' AND (' || p_DateCol || ' BETWEEN ''' || p_DocDate1 || ''' AND ''' || p_DocDate2 || ''')';
        END IF;

        IF p_Key <> '' THEN
            _Where_Key := _Where_Key || ' AND (' || p_Key || ')';
        END IF;

        IF COALESCE(p_BizDocName,'') = '' THEN
            p_BizDocName := 'vb30bizdocdetail_getdata';
        END IF;

        p_BizDocName := REPLACE (LOWER(p_BizDocName),'dbo.','');
        p_CtTmp := LOWER(p_CtTmp);

        -- Kiểm tra tồn tại bảng hay view
        _ref_table_exists := to_regclass(p_BizDocName) IS NOT NULL;
        IF NOT _ref_table_exists THEN
            RETURN;
        END IF;

        -- Kiểm tra tồn tại bảng hay view (p_CtTmp)
        _ref_table_exists := to_regclass(p_CtTmp) IS NOT NULL;
        IF NOT _ref_table_exists THEN
            RETURN;
        END IF;

        p_GroupByCols := REPLACE (TRIM(COALESCE(LOWER(p_GroupByCols),'')),' ','');

        -- Kiểm tra các cột trong p_GroupByCols có tồn tại trong bảng nguồn không
        IF p_GroupByCols <> '' THEN
            DROP TABLE
            IF EXISTS Tmp_Sys_GetData_GroupCols;
            CREATE TEMP TABLE Tmp_Sys_GetData_GroupCols(colname TEXT);

            INSERT INTO Tmp_Sys_GetData_GroupCols(colname)
            SELECT TRIM(LOWER(value))
            FROM regexp_split_to_table(p_GroupByCols,',') AS value;

            SELECT COUNT(1) INTO STRICT _ref_table_exists_Count
            FROM Tmp_Sys_GetData_GroupCols gc
            INNER JOIN information_schema.columns c ON gc.colname = c.column_name
            WHERE c.table_name = p_BizDocName;

            IF _ref_table_exists_Count <> (SELECT COUNT(*) FROM Tmp_Sys_GetData_GroupCols) THEN
                RAISE NOTICE 'Error: Một hoặc nhiều cột trong p_GroupByCols (%) không tồn tại trong bảng %'
                  ,p_GroupByCols
                  ,p_BizDocName;
                DROP TABLE
                IF EXISTS Tmp_Sys_GetData_GroupCols;
                RETURN;
            END IF;
        END IF;

        DROP TABLE
        IF EXISTS Tmp_Cols;
        CREATE TEMP TABLE Tmp_Cols(column_name VARCHAR(64));
        WITH intersect_columns AS (SELECT column_name FROM information_schema.columns WHERE table_name = LOWER(p_CtTmp) INTERSECT SELECT column_name FROM information_schema.columns WHERE table_name = LOWER(p_BizDocName))
             ,ordered_columns AS (SELECT s.column_name,s.ordinal_position FROM information_schema.columns s INNER JOIN intersect_columns ic ON s.column_name = ic.column_name WHERE s.table_name = LOWER(p_BizDocName) ORDER BY s.ordinal_position)
        INSERT INTO Tmp_Cols(column_name)
        SELECT column_name
        FROM ordered_columns;

        SELECT COALESCE(STRING_AGG(column_name,','),'') INTO _FieldInsert
        FROM Tmp_Cols;

        IF p_GroupByCols = '' THEN
            _FieldSelect := _FieldInsert;
        ELSE
            SELECT COALESCE(
                STRING_AGG(
                    CASE WHEN POSITION(',' || column_name || ',' IN ',' || LOWER(p_GroupByCols) || ',') > 0 THEN column_name WHEN dbo.ufn_sys_IsNumericType((SELECT data_type FROM information_schema.columns WHERE table_name = LOWER(p_BizDocName) AND column_name = oc.column_name)) = TRUE AND column_name NOT ILIKE '%Id' THEN 'SUM(' || column_name || ')' ELSE 'MAX(' || column_name || ')' END
                    ,','
                )
                ,''
            ) INTO _FieldSelect
            FROM Tmp_Cols oc;
        END IF;

        _strExec := 'INSERT INTO ' || p_CtTmp || ' (' || _FieldInsert || ') ' || 'SELECT ' || _FieldSelect || ' FROM ' || p_BizDocName || ' sc ' || ' WHERE BranchCode IN (SELECT BranchCode FROM dbo.ufn_B00Branch_GetChildTable(''' || (p_BranchCode) || ''')) ' || ' AND ' || _Where_Key;

        IF COALESCE(p_GroupByCols,'') <> '' THEN
            _strExec := _strExec || ' GROUP BY ' || p_GroupByCols;
        END IF;

        IF p_PrintExec = 1 THEN
            RAISE NOTICE '%'
                 ,_strExec;
        END IF;

        EXECUTE _strExec;

        -- Kiểm tra RoleId = 8 cấm xem giá trị
        CALL dbo.usp_sys_UpdateZeroValue(p_nUserId := p_nUserId,p_CtTmp := p_CtTmp,p_ColList := '');

    END;
$procedure$
