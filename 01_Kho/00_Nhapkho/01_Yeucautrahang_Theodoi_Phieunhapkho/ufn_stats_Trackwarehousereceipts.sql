CREATE OR REPLACE FUNCTION dbo.ufn_stats_Trackwarehousereceipts(p_docdate1 date DEFAULT '2021-01-01'::date,p_docdate2 date DEFAULT '2022-12-31'::date
,p_doccodelist character varying DEFAULT 'SN'::character varying,p_customerid character varying DEFAULT ''::character varying
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
        --Báo cáo Theo dõi Phiếu nhập kho
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
        --Tmp_S_CtTmp_SN
        -- 1. Tạo bảng tạm Phiếu Nhập kho (SN)
        DROP TABLE
        IF EXISTS Tmp_S_CtTmp_SN;
        CREATE TEMP TABLE Tmp_S_CtTmp_SN AS
        SELECT Id /*--Thông tin chi tiết*/
               ,statsdocid
               ,RowId
               ,ItemId
               ,_codetype AS ItemCode
               ,_nametype AS ItemName
               ,Unit
               ,Quantity9
               ,_quantitytype AS Quantity_RR
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
               ,_nametype AS EmployeeName /*--Thông tin lấy từ Đơn đặt hàng mua(PO)*/
               ,PurchaseUnitPrice
               ,TimeDiscount
               ,InvoiceUnitPrice
               ,OriginalUnitCost
               ,UnitCost
               ,OriginalAmount
               ,Amount
               ,OriginalAmount9
               ,Amount9
               ,TaxCode
               ,0::numeric(8,4) AS TaxRate
               ,OriginalAmount3
               ,Amount3
               ,AtchDocDate
               ,AtchDocNo
               ,AtchDocFormNo
               ,IsPromotionItem
               ,ReceiptDate_EO
               ,DiscountRate_EO
               ,SpeakerBOMType
               ,SpeakerBOMCode
               ,BizDocId_PO
               ,RowId_PO
        --,BizDocId_RR
        --,BizDocId_RC
        FROM dbo.b00cttmp tb
        LIMIT 0;

        ----1.1 Lấy dữ liệu Thông báo hàng về
        CALL dbo.usp_B30StatsStockLedger_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_key := _Key1
            ,p_cttmp := 'Tmp_S_CtTmp_SN'
            ,p_BranchCode := p_BranchCode
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_groupbycols := ''::text
            ,p_notsumcols := ''::text
            ,p_PrintExec := 1::int2
        );

        --2. Tạo bảng tạm cấu trúc chi tiết Phiếu yêu cầu trả hàng (RR)
        DROP TABLE
        IF EXISTS Tmp_B_CtTmp_RR;
        CREATE TEMP TABLE Tmp_B_CtTmp_RR AS
        SELECT tb.statsdocid AS statsdocid_sn
               ,rowid
               ,ItemId
               ,Quantity9
               ,BizDocId AS BizDocId_DO
               ,tb.bizdocid_po
               ,tb.rowid_po
        FROM dbo.b00cttmp tb
        LIMIT 0;

        ----2.1 Tạo key lấy dữ liệu chi tiết Phiếu yêu cầu trả hàng
        _Key1 := ' DocCode = ''RR''  AND EXISTS (SELECT 1 FROM Tmp_S_CtTmp_SN WHERE Tmp_S_CtTmp_SN.statsdocid = sc.statsdocid_sn )  ';

        ----2.2 Lấy dữ liệu chi tiết Phiếu yêu cầu trả hàng 
        CALL dbo.usp_B30BizDocDetail_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_Key := _Key1
            ,p_CtTmp := 'Tmp_B_CtTmp_RR'
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_BranchCode := p_BranchCode
            ,p_CurrencyCode0 := p_CurrencyCode0
            ,p_BizDocName := 'vb30bizdocdetail_getdata'
            ,p_PrintExec := 0::int2
        );

        --3. Cập nhật thông tin Quantity_RR, Quantity_Remain
        WITH cte_a AS (SELECT SSN.statsdocid,SSN.RowId,BRR.Quantity9 AS Quantity9_RR FROM Tmp_S_CtTmp_SN SSN LEFT JOIN (SELECT statsdocid_sn
             ,ItemId,sum(Quantity9) AS Quantity9 FROM Tmp_B_CtTmp_RR GROUP BY statsdocid_sn,ItemId) BRR ON SSN.statsdocid = BRR.statsdocid_sn AND SSN.ItemId = BRR.ItemId)
        UPDATE Tmp_S_CtTmp_SN
        SET Quantity_RR = COALESCE(tblA.Quantity9_RR,0)
            ,Quantity_Remain = COALESCE(Tmp_S_CtTmp_SN.Quantity9,0) - COALESCE(tblA.Quantity9_RR,0)
        FROM cte_a tblA
        WHERE Tmp_S_CtTmp_SN.statsdocid = tblA.statsdocid AND Tmp_S_CtTmp_SN.RowId = tblA.RowId;
        ----3.1 Dòng nào kế thừa hết thì clear luôn
        DELETE FROM Tmp_S_CtTmp_SN
        WHERE Quantity_Remain = 0;

        -- 4. Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info(
            'Tmp_S_CtTmp_SN'::REGCLASS
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
        FROM Tmp_S_CtTmp_SN;

        RETURN NEXT _ref1;
    END;
$function$;
BEGIN
    ;

    SELECT *
    FROM dbo.ufn_stats_Trackwarehousereceipts(p_docdate1 := '2026-11-01T00:00:00'::date,p_docdate2 := '2026-11-22T00:00:00'::date
         ,p_nuserid := 1011,p_branchcode := 'A01');
    FETCH ALL IN ref1;

    COMMIT;

END;
