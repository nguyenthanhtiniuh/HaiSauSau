CREATE OR REPLACE FUNCTION dbo.ufn_vct_goodsarrivalnoticelist(p_docdate1 date DEFAULT '2021-01-01'::date,p_docdate2 date DEFAULT '2022-12-31'::date
,p_doccodelist character varying DEFAULT 'DO'::character varying,p_customerid character varying DEFAULT ''::character varying
,p_employeeid character varying DEFAULT ''::character varying,p_deptid character varying DEFAULT ''::character varying,p_itemid character varying DEFAULT ''::character varying
,p_warehouseid character varying DEFAULT ''::character varying,p_nuserid integer DEFAULT 0,p_langid integer DEFAULT 0,p_branchcode character varying DEFAULT 'A01'::character varying
,p_currencycode0 character varying DEFAULT 'VND'::character varying)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        -- 0. Báo cáo Theo dõi Thông báo hàng về (DO)
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
        _DocCodeList varchar := '';
        _codetype VARCHAR(24) := '';
        _nametype VARCHAR(256) := '';
        _quantitytype NUMERIC(18,2) := 0;
    BEGIN
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

        -- 1. Tạo bảng tạm Thông báo nhập hàng (DO)
        DROP TABLE
        IF EXISTS Tmp_B_CtTmp_DO;
        CREATE TEMP TABLE Tmp_B_CtTmp_DO AS
        SELECT Id /*--Thông tin chi tiết*/
               ,BizDocId
               ,RowId
               ,ItemId
               ,_codetype AS ItemCode
               ,_nametype AS ItemName
               ,Unit
               ,Quantity9
               ,_quantitytype AS Quantity_SN
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
               ,BizDocId_RR
               ,BizDocId_RC
        FROM dbo.b00cttmp tb
        LIMIT 0;
        ----1.1 Lấy dữ liệu Thông báo hàng về
        CALL dbo.usp_B30BizDocDetail_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_Key := _Key1
            ,p_CtTmp := 'Tmp_B_CtTmp_DO'
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_BranchCode := p_BranchCode
            ,p_CurrencyCode0 := p_CurrencyCode0
            ,p_BizDocName := 'vb30bizdocdetail_getdata'
            ,p_PrintExec := 1::int2
        );

        --2. Tạo bảng tạm cấu trúc chi tiết phiếu Nhập kho
        DROP TABLE
        IF EXISTS Tmp_S_CtTmp_SN;
        CREATE TEMP TABLE Tmp_S_CtTmp_SN AS
        SELECT tb.statsdocid
               ,rowid
               ,ItemId
               ,Quantity9
               ,BizDocId AS BizDocId_DO
               ,tb.bizdocid_po
               ,tb.rowid_po
        FROM dbo.b00cttmp tb
        LIMIT 0;

        ----2.1 Tạo key lấy dữ liệu chi tiết Phiếu nhập kho
        _Key1 := ' DocCode = ''SN''  AND EXISTS (SELECT 1 FROM Tmp_B_CtTmp_DO WHERE Tmp_B_CtTmp_DO.BizDocId = sc.BizDocId_DO )  ';

        ----2.2 Lấy dữ liệu chi tiết Phiếu nhập kho
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

        --3. Cập nhật thông tin Quantity_SN, Quantity_Remain
        WITH cte_bizdo AS (SELECT bizdo.BizDocId,bizdo.RowId,sn.Quantity9 FROM Tmp_B_CtTmp_DO bizdo LEFT JOIN (SELECT BizDocId_DO
             ,ItemId,sum(Quantity9) AS Quantity9 FROM Tmp_S_CtTmp_SN GROUP BY BizDocId_DO,ItemId) sn ON bizdo.BizDocId = sn.BizDocId_DO AND bizdo.ItemId = sn.ItemId)
        UPDATE Tmp_B_CtTmp_DO
        SET Quantity_SN = COALESCE(bizdo.Quantity9,0)
            ,Quantity_Remain = COALESCE(Tmp_B_CtTmp_DO.Quantity9,0) - COALESCE(bizdo.Quantity9,0)
        FROM cte_bizdo bizdo
        WHERE Tmp_B_CtTmp_DO.BizDocId = bizdo.BizDocId AND Tmp_B_CtTmp_DO.RowId = bizdo.RowId;

        DELETE FROM Tmp_B_CtTmp_DO
        WHERE Quantity_Remain = 0;

        -- 4. Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info(
            'Tmp_B_CtTmp_DO'::REGCLASS
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
        FROM Tmp_B_CtTmp_DO;

        RETURN NEXT _ref1;
    END;
$function$
