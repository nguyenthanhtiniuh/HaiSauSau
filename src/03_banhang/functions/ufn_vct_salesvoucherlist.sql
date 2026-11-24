CREATE OR REPLACE FUNCTION dbo.ufn_vct_salesvoucherlist(p_docdate1 date DEFAULT '2021-01-01'::date,p_docdate2 date DEFAULT '2022-12-31'::date
,p_doccodelist character varying DEFAULT 'BH'::character varying,p_customerid character varying DEFAULT ''::character varying
,p_employeeid character varying DEFAULT ''::character varying,p_deptid character varying DEFAULT ''::character varying,p_itemid character varying DEFAULT ''::character varying
,p_warehouseid character varying DEFAULT ''::character varying,p_nuserid integer DEFAULT 0,p_langid integer DEFAULT 0,p_branchcode character varying DEFAULT 'A01'::character varying
,p_currencycode0 character varying DEFAULT 'VND'::character varying)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
        _DocCodeList varchar := '';
        _codetype VARCHAR(24) := '';
        _nametype VARCHAR(256) := '';
        _quantitytype NUMERIC(18,2) := 0;
    BEGIN
        --Báo cáo Theo dõi Phiếu bán hàng (BH)
        p_nuserid := dbo.ufn_sys_getvaluefromappname('UserId',p_nuserid::varchar);

        IF COALESCE(p_itemid,'') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_itemid,p_ColGen => 'ItemId',p_ColName => 'Id',p_TableName => 'B20Item'
    ,p_AndOrKey => 'AND',p_Key => _Key1);
        END IF;

        IF COALESCE(p_customerid,'') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_customerid,p_ColGen => 'CustomerId',p_ColName => 'Id',p_TableName => 'B20Customer'
    ,p_AndOrKey => 'AND',p_Key => _Key1);
        END IF;

        IF COALESCE(p_employeeid,'') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_employeeid,p_ColGen => 'EmployeeId',p_ColName => 'Id',p_TableName => 'B20Employee'
    ,p_AndOrKey => 'AND',p_Key => _Key1);
        END IF;
        _DocCodeList := REPLACE (p_doccodelist,',',''',''');

        IF _DocCodeList <> '' THEN
            _Key1 := _Key1 || ' AND (DocCode IN (''' || RTRIM(_DocCodeList) || '''))';
        END IF;

        -- 1. Tạo bảng tạm Phiếu bán hàng (BH)
        DROP TABLE
        IF EXISTS Tmp_B_CtTmp_BH;
        CREATE TEMP TABLE Tmp_B_CtTmp_BH AS
        SELECT Id /*--Thông tin chi tiết*/
               ,BizDocId
               ,RowId
               ,ItemId
               ,_codetype AS ItemCode
               ,_nametype AS ItemName
               ,Unit
               ,Quantity9
               ,_quantitytype AS Quantity_SI
               ,_quantitytype AS Quantity_Remain
               ,ConvertRate9
               ,Quantity /*Thông tin đầu phiếu*/
               ,DocCode
               ,DocNo
               ,DocDate
               ,CustomerId
               ,_codetype AS CustomerCode
               ,_nametype AS CustomerName
               ,EmployeeId
               ,_codetype AS EmployeeCode
               ,_nametype AS EmployeeName /*--Thông tin lấy từ Đơn đặt hàng bán(SO)*/
               ,OriginalUnitCost_Std
               ,DiscountRate
               ,OriginalUnitCost_AftDisc
               ,OriginalUnitCost_Case
               ,OriginalUnitCost_Qty
               ,OriginalUnitCost_Vou
               ,OriginalUnitCost
               ,UnitCost
               ,OriginalUnitCost_QT
               ,OriginalAmount
               ,Amount
               ,OriginalAmount9
               ,Amount9
               ,TaxCode
               ,0::numeric(8,4) AS TaxRate
               ,OriginalAmount3
               ,Amount3
               ,BizDocId_SO
               ,RowId_SO
        FROM dbo.b00cttmp tb
        LIMIT 0;
        ----1.1 Lấy dữ liệu Phiếu bán hàng
        CALL dbo.usp_B30BizDocDetail_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_Key := _Key1
            ,p_CtTmp := 'Tmp_B_CtTmp_BH'
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_BranchCode := p_BranchCode
            ,p_CurrencyCode0 := p_CurrencyCode0
            ,p_BizDocName := 'vb30bizdocdetail_getdata'
            ,p_PrintExec := 1::int2
        );

        --2. Tạo bảng tạm cấu trúc chi tiết Phiếu xuất bán
        DROP TABLE
        IF EXISTS Tmp_B_CtTmp_SI;
        CREATE TEMP TABLE Tmp_B_CtTmp_SI AS
        SELECT tb.statsdocid
               ,rowid
               ,ItemId
               ,Quantity9
               ,BizDocId AS BizDocId_BH
               ,tb.BizDocId_SO
               ,tb.RowId_SO
        FROM dbo.b00cttmp tb
        LIMIT 0;

        ----2.1 Tạo key lấy dữ liệu chi tiết Phiếu xuất bán
        _Key1 := ' DocCode = ''SI''  AND EXISTS (SELECT 1 FROM Tmp_B_CtTmp_BH WHERE Tmp_B_CtTmp_BH.BizDocId = sc.BizDocId_BH )  ';

        ----2.2 Lấy dữ liệu chi tiết Phiếu xuất bán
        CALL dbo.usp_B30StatsStockLedger_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_key := _Key1
            ,p_cttmp := 'Tmp_B_CtTmp_SI'
            ,p_BranchCode := p_BranchCode
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_groupbycols := ''::text
            ,p_notsumcols := ''::text
            ,p_PrintExec := 1::int2
        );

        --3. Cập nhật thông tin Quantity_SI, Quantity_Remain
        WITH cte_bh AS (SELECT bh.BizDocId,bh.RowId,si.Quantity9 FROM Tmp_B_CtTmp_BH bh LEFT JOIN (SELECT BizDocId_BH,ItemId
             ,sum(Quantity9) AS Quantity9 FROM Tmp_B_CtTmp_SI GROUP BY BizDocId_BH,ItemId) si ON bh.BizDocId = si.BizDocId_BH AND bh.ItemId = si.ItemId)
        UPDATE Tmp_B_CtTmp_BH
        SET Quantity_SI = COALESCE(bh.Quantity9,0)
            ,Quantity_Remain = COALESCE(Tmp_B_CtTmp_BH.Quantity9,0) - COALESCE(bh.Quantity9,0)
        FROM cte_bh bh
        WHERE Tmp_B_CtTmp_BH.BizDocId = bh.BizDocId AND Tmp_B_CtTmp_BH.RowId = bh.RowId;

        DELETE FROM Tmp_B_CtTmp_BH
        WHERE Quantity_Remain = 0;

        -- 4. Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info(
            'Tmp_B_CtTmp_BH'::REGCLASS
            ,'[
        {
            "source_table": "dbo.b20item",
            "target_key": "itemid",
            "source_key": "id",
            "column_map": {
                "itemcode": "code",
                "itemname": "name" 
            }
        },
        {
            "source_table": "dbo.b20customer",
            "target_key": "customerid",
            "source_key": "id",
            "column_map": {
                "customercode": "code",
                "customername": "name"
            }
        },
        {
            "source_table": "dbo.b20employee",
            "target_key": "employeeid",
            "source_key": "id",
            "column_map": {
                "employeecode": "code",
                "employeename": "name"
            }
        },
        {
            "source_table": "dbo.b20tax",
            "target_key": "taxcode",
            "source_key": "code",
            "column_map": {
                "taxrate": "rate" 
            }
        } 
    ]'::JSONB
            ,p_PrintExec := 0::int2
        );

        -- 5. Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_B_CtTmp_BH;

        RETURN NEXT _ref1;
    END;
$function$
