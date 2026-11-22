CREATE OR REPLACE FUNCTION dbo.ufn_biz_Track_Supplier_Return_Requests(p_docdate1 date DEFAULT '2021-01-01'::date,p_docdate2 date DEFAULT '2022-12-31'::date
,p_doccodelist character varying DEFAULT 'RR'::character varying,p_customerid character varying DEFAULT ''::character varying
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
        --Báo cáo Theo dõi Yêu cầu trả hàng NCC
        --Track_Supplier_Return_Requests
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

        -- 1. Tạo bảng tạm Yêu cầu xuất kho (RR)
        DROP TABLE
        IF EXISTS Tmp_B_CtTmp_RR;
        CREATE TEMP TABLE Tmp_B_CtTmp_RR AS
        SELECT Id /*--Thông tin chi tiết*/
               ,BizDocId
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
               ,BizDocId_RR
               ,BizDocId_RC /*Phiếu nhập kho*/
               ,tb.statsdocid_sn
        FROM dbo.b00cttmp tb
        LIMIT 0;
        ----1.1 Lấy dữ liệu Yêu cầu xuất kho (RR)
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

        --2. Tạo bảng tạm cấu trúc chi tiết Phiếu xuất trả hàng NCC (SR)
        DROP TABLE
        IF EXISTS Tmp_S_CtTmp_SR;
        CREATE TEMP TABLE Tmp_S_CtTmp_SR AS
        SELECT tb.statsdocid
               ,rowid
               ,ItemId
               ,Quantity9
               ,BizDocId_RR
               ,tb.bizdocid_po
               ,tb.rowid_po
        FROM dbo.b00cttmp tb
        LIMIT 0;

        ----2.1 Tạo key lấy dữ liệu chi tiết Phiếu xuất trả hàng NCC (SR)
        _Key1 := ' DocCode = ''SR''  AND EXISTS (SELECT 1 FROM Tmp_B_CtTmp_RR WHERE Tmp_B_CtTmp_RR.BizDocId = sc.BizDocId_RR )  ';

        ----2.2 Lấy dữ liệu chi tiết Phiếu xuất trả hàng NCC (SR)
        CALL dbo.usp_B30StatsStockLedger_GetData(
            p_DocDate1 := p_DocDate1
            ,p_DocDate2 := p_DocDate2
            ,p_key := _Key1
            ,p_cttmp := 'Tmp_S_CtTmp_SR'
            ,p_BranchCode := p_BranchCode
            ,p_nUserId := p_nUserId
            ,p_LangId := p_LangId
            ,p_groupbycols := ''::text
            ,p_notsumcols := ''::text
            ,p_PrintExec := 1::int2
        );

        --3. Cập nhật thông tin Quantity_RR, Quantity_Remain
        WITH cte_bizdo AS (SELECT bizdo.BizDocId,bizdo.RowId,sn.Quantity9 FROM Tmp_B_CtTmp_RR bizdo LEFT JOIN (SELECT BizDocId_RR
             ,ItemId,sum(Quantity9) AS Quantity9 FROM Tmp_S_CtTmp_SR GROUP BY BizDocId_RR,ItemId) sn ON bizdo.BizDocId = sn.BizDocId_RR AND bizdo.ItemId = sn.ItemId)
        UPDATE Tmp_B_CtTmp_RR
        SET Quantity_RR = COALESCE(bizdo.Quantity9,0)
            ,Quantity_Remain = COALESCE(Tmp_B_CtTmp_RR.Quantity9,0) - COALESCE(bizdo.Quantity9,0)
        FROM cte_bizdo bizdo
        WHERE Tmp_B_CtTmp_RR.BizDocId = bizdo.BizDocId AND Tmp_B_CtTmp_RR.RowId = bizdo.RowId;

        DELETE FROM Tmp_B_CtTmp_RR
        WHERE Quantity_Remain = 0;

        -- 4. Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info(
            'Tmp_B_CtTmp_RR'::REGCLASS
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
        FROM Tmp_B_CtTmp_RR;

        RETURN NEXT _ref1;
    END;
$function$;
BEGIN
    ;

    SELECT *
    FROM dbo.ufn_biz_Track_Supplier_Return_Requests(p_docdate1 := '2026-11-01T00:00:00'::date,p_docdate2 := '2026-11-22T00:00:00'::date
         ,p_nuserid := 1011,p_branchcode := 'A01');
    FETCH ALL IN ref1;

    COMMIT;

END;
