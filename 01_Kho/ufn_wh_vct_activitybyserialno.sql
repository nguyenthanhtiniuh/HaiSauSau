CREATE OR REPLACE FUNCTION dbo.ufn_wh_vct_activitybyserialno(p_docdate1 date DEFAULT '2021-01-01'::date, p_docdate2 date DEFAULT '2022-12-31'::date,
    p_itemid character varying DEFAULT ''::character varying, p_itemserialno character varying DEFAULT ''::character varying,
    p_warehouseid character varying DEFAULT ''::character varying, p_docgroup smallint DEFAULT (0)::smallint, p_doclist character varying DEFAULT ''::character varying,
    p_groupbylistfield character varying DEFAULT ''::character varying, p_branchcode character varying DEFAULT 'A00'::character varying,
    p_nuserid integer DEFAULT 0, p_langid smallint DEFAULT (0)::smallint, pout_layout_xml text DEFAULT ''::text)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    /*
-- Coder: HuyTQ
-- Manager: ChamVT
-- Bảng kê nhập xuất theo Serial
*/
    DECLARE
        _ref_out refcursor := 'ref_out';
        _ref1 refcursor := 'ref1';
        _Key TEXT := '';
        _DocList VARCHAR(128) := '';
        _codetype varchar(24) := '';
        _nametype text := '';
    BEGIN
        -- Tự động lấy thông tin theo AppName khi thực hiện trong chương trình, không theo tham số truyền vào
        p_nUserId := dbo.ufn_sys_getvaluefromappname('UserId', p_nUserId::VARCHAR);

        IF p_WarehouseId <> '' THEN
            _Key := dbo.ufn_sys_GenKey(p_Code := p_WarehouseId, p_ColGen := 'WarehouseId', p_ColName := 'Id',
                p_TableName := 'B20Warehouse', p_AndOrKey := 'AND', p_Key := _Key);
        ELSE
            _Key := ' AND WarehouseId IS NOT NULL';
        END IF;

        IF p_ItemId <> '' THEN
            _Key := dbo.ufn_sys_GenKey(p_Code := p_ItemId, p_ColGen := 'ItemId', p_ColName := 'Id', p_TableName := 'B20Item',
                p_AndOrKey := 'AND', p_Key := _Key);
        ELSE
            _Key := _Key || ' AND ItemId IS NOT NULL';
        END IF;

        IF p_itemserialno <> '' THEN
            _Key := _Key || ' AND (itemserialno LIKE ''' || REPLACE (p_itemserialno, ',', '%'' OR itemserialno LIKE ''') || '%'')';
        ELSE
            _Key := _Key || ' AND (itemserialno <> '''')';
        END IF;

        _DocList := REPLACE (p_DocList, ',', ''',''');

        IF _DocList <> '' THEN
            _Key := _Key || ' AND (DocCode IN (''' || RTRIM(_DocList) || '''))';
        END IF;

        IF p_DocGroup IN (1, 2) THEN
            _Key := _Key || ' AND (DocGroup = ''' || RTRIM(p_DocGroup::TEXT) || ''')';
        END IF;

        IF _Key <> '' THEN
            _Key := SUBSTRING(_Key, 6, LENGTH(_Key) - 5);
        END IF;

        -- Bảng lấy dữ liệu
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp0;

        CREATE TEMP TABLE Tmp_V_CtTmp0 AS
        SELECT Id,
            Stt,
            rowid,
            WarehouseId,
            WarehouseCode,
            COALESCE(_nametype, '') AS WarehouseName,
            ItemId,
            ItemCode,
            COALESCE(_nametype, '') AS ItemName,
            Unit,
            locationid,
            locationcode,
            COALESCE(_nametype, '') AS locationname,
            itemserialno,
            Quantity,
            DocCode,
            DocGroup,
            DocNo,
            DocDate,
            Description,
            _nametype AS NewFormatStyleKey
        FROM dbo.B00CtTmp
        LIMIT 0;

        CALL dbo.usp_sys_DefaultTable(p_table := 'Tmp_V_CtTmp0');

        --CALL dbo.usp_b30statsstockledgerphys_getdata(p_DocDate1 := p_DocDate1, p_DocDate2 := p_DocDate2, p_key := _Key,        p_cttmp := 'Tmp_V_CtTmp0', p_BranchCode := p_BranchCode, p_nUserId := p_nUserId, p_LangId := p_LangId);

        CALL dbo.usp_B30StatsStockLedger_GetData(p_DocDate1 := p_DocDate1, p_DocDate2 := p_DocDate2, p_key := _Key,
            p_cttmp := 'Tmp_V_CtTmp0', p_BranchCode := p_BranchCode, p_nUserId := p_nUserId, p_LangId := p_LangId,
            p_groupbycols := ''::text, p_notsumcols := ''::text, p_PrintExec := 0::int2);

        UPDATE Tmp_V_CtTmp0 a
        SET ItemCode = b.Code
        FROM dbo.B20Item b
        WHERE a.ItemId = b.Id;

        WITH updates AS (SELECT tb.rowid, COALESCE(item.Code, '') AS NewItemCode, COALESCE(item.Name, '') AS NewItemName,
            COALESCE(item.Unit, '') AS NewUnit, COALESCE(wh.Code, '<<No Code>>') AS NewWarehouseCode, wh.Code || ' - ' || wh.Name AS NewWarehouseName,
            COALESCE(loca.Code, '') AS NewLocationCode, COALESCE(loca.Name, '') AS NewLocationName FROM Tmp_V_CtTmp0 AS tb LEFT OUTER JOIN dbo.B20Item AS item ON tb.ItemId = item.Id LEFT OUTER JOIN dbo.B20Warehouse AS wh ON tb.WarehouseId = wh.Id LEFT OUTER JOIN dbo.b20location AS loca ON tb.locationid = loca.Id)
        UPDATE Tmp_V_CtTmp0
        SET ItemCode = u.NewItemCode,
            ItemName = u.NewItemName,
            Unit = u.NewUnit,
            WarehouseCode = u.NewWarehouseCode,
            WarehouseName = u.NewWarehouseName,
            LocationCode = u.NewLocationCode,
            LocationName = u.NewLocationName
        FROM updates u
        WHERE Tmp_V_CtTmp0.rowid = u.rowid;

        IF COALESCE(p_GroupByListField, '') <> '' THEN

            p_GroupByListField := REPLACE (p_GroupByListField, 'ItemId', 'ItemId1');

            p_GroupByListField := REPLACE (p_GroupByListField, 'WarehouseId', 'WarehouseId1');

            pout_LAYOUT_XML := ('
			<DefaultReport>
			<Content>
				<Groups>
					<' || REPLACE (p_GroupByListField, ',', ' /> <') || ' />
				</Groups>
			</Content>
			</DefaultReport>');
        END IF;

        OPEN _ref_out FOR
        SELECT pout_LAYOUT_XML;

        RETURN NEXT _ref_out;

        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_V_CtTmp0;
 

        RETURN NEXT _ref1;
    END;
$function$;

BEGIN
    ;

    SELECT *
    FROM dbo.ufn_WH_vct_activitybyserialno(p_docdate1 := '2026-01-01'::date, p_docdate2 := '2026-11-17'::date,
        p_docgroup := 1::smallint, p_groupbylistfield := 'ItemId'::text, p_branchcode := 'A01'::text, p_nuserid := 1011::integer,
        p_langid := 0::smallint);

    FETCH ALL IN ref1;
    COMMIT;

END;
