--Theo dõi Lệnh nhập hàng
--creater: LAMND
--modifiedat: 2026-11-22T04:08:11.9644830
--modifiedby: TINNT

CREATE OR REPLACE FUNCTION dbo.ufn_vct_receiptcommandlist(p_docdate1 date DEFAULT '2021-01-01'::date, p_docdate2 date DEFAULT '2022-12-31'::date,
    p_doccodelist character varying DEFAULT 'RC'::character varying, p_customerid character varying DEFAULT ''::character varying,
    p_employeeid character varying DEFAULT ''::character varying, p_deptid character varying DEFAULT ''::character varying,
    p_itemid character varying DEFAULT ''::character varying, p_warehouseid character varying DEFAULT ''::character varying,
    p_nuserid integer DEFAULT 0, p_langid integer DEFAULT 0, p_branchcode character varying DEFAULT 'A01'::character varying,
    p_currencycode0 character varying DEFAULT 'VND'::character varying)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
        _DocCodeList varchar := '';
        _quantitytype NUMERIC(18, 2) := 0;
    BEGIN
        p_nuserid := dbo.ufn_sys_getvaluefromappname('UserId', p_nuserid::varchar);

        IF COALESCE(p_itemid, '') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_itemid, p_ColGen => 'ItemId', p_ColName => 'Id', p_TableName => 'B20Item',
                p_AndOrKey => 'AND', p_Key => _Key1);
        END IF;

        IF COALESCE(p_customerid, '') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_customerid, p_ColGen => 'CustomerId', p_ColName => 'Id', p_TableName => 'B20Customer',
                p_AndOrKey => 'AND', p_Key => _Key1);
        END IF;

        IF COALESCE(p_employeeid, '') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_employeeid, p_ColGen => 'EmployeeId', p_ColName => 'Id', p_TableName => 'B20Employee',
                p_AndOrKey => 'AND', p_Key => _Key1);
        END IF;
        _DocCodeList := REPLACE (p_doccodelist, ',', ''',''');

        IF _DocCodeList <> '' THEN
            _Key1 := _Key1 || ' AND (DocCode IN (''' || RTRIM(_DocCodeList) || '''))';
        END IF;

        --1.Tạo bảng tạm Lệnh nhập hàng (RC)
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_RC;
        CREATE TEMP TABLE Tmp_V_CtTmp_RC AS
        SELECT id,
            BizDocId,
            DocCode,
            DocNo,
            DocDate,
            CurrencyCode,
            CustomerId,
            ''::varchar(24) AS CustomerCode,
            ''::varchar(192) AS CustomerName,
            EmployeeId,
            ''::varchar(24) AS EmployeeCode,
            ''::varchar(64) AS EmployeeName,
            RowId,
            ItemId,
            ''::varchar(24) AS ItemCode,
            ''::varchar(192) AS ItemName,
            Unit,
            IsPromotionItem,
            Quantity9,
            _quantitytype AS Quantity_DO,
            _quantitytype AS Quantity_Remain,
            ConvertRate9,
            Quantity,
            PurchaseUnitPrice,
            TimeDiscount,
            InvoiceUnitPrice,
            OriginalUnitCost,
            UnitCost,
            OriginalAmount,
            Amount,
            OriginalAmount9,
            Amount9,
            TaxCode,
            0::numeric(8, 4) AS TaxRate,
            OriginalAmount3,
            Amount3,
            AtchDocDate,
            AtchDocNo,
            AtchDocFormNo,
            ReceiptDate_EO,
            DiscountRate_EO,
            SpeakerBOMType,
            SpeakerBOMCode,
            BizDocId_PO,
            RowId_PO,
            BizDocId_RR
        FROM dbo.vb30bizdocdetail_getdata_item
        LIMIT 0;

        ----1.1 Lấy dữ liệu RC từ view chi tiết chứng từ
        CALL dbo.usp_B30BizDocDetail_GetData(p_DocDate1 := p_DocDate1, p_DocDate2 := p_DocDate2, p_Key := _Key1, p_CtTmp := 'Tmp_V_CtTmp_RC',
            p_nUserId := p_nUserId, p_LangId := p_LangId, p_BranchCode := p_BranchCode, p_CurrencyCode0 := p_CurrencyCode0,
            p_BizDocName := 'vb30bizdocdetail_getdata_item'
        --, p_PrintExec := 0::int2
        );

        --2. Tạo bảng tạm và lấy dữ liệu Thông báo nhập hàng (DO)
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_DO;
        CREATE TEMP TABLE Tmp_V_CtTmp_DO AS
        SELECT BizDocId,
            ROWID,
            ItemId,
            Quantity9,
            BizDocId AS BizDocId_RC
        FROM Tmp_V_CtTmp_RC
        LIMIT 0;
        ----2.1 Tạo key lấy dữ liệu chi tiết Thông báo hàng về
        _Key1 := '  DocCode = ''DO'' AND EXISTS (SELECT 1 FROM Tmp_V_CtTmp_RC WHERE Tmp_V_CtTmp_RC.BizDocId = sc.BizDocId_RC ) ';
        ----2.2 Lấy dữ liệu Thông báo hàng 
        CALL dbo.usp_B30BizDocDetail_GetData(p_DocDate2 := p_DocDate2, p_Key := _Key1, p_CtTmp := 'Tmp_V_CtTmp_DO',
            p_nUserId := p_nUserId, p_LangId := p_LangId, p_BranchCode := p_BranchCode, p_CurrencyCode0 := p_CurrencyCode0,
            p_BizDocName := 'vb30bizdocdetail_getdata_item'
        --, p_PrintExec := 0::int2
        );

        --3.Cập nhật dữ liệu cho RC, Tổng hợp chi tiết số lượng DO theo từng RC
        WITH CTE_RC AS (SELECT rc.bizdocid, rc.RowId, d0.Quantity9 AS Quantity9_DO FROM Tmp_V_CtTmp_RC rc LEFT JOIN (SELECT ItemId,
            BizDocId_RC, sum(Quantity9) AS Quantity9 FROM Tmp_V_CtTmp_DO GROUP BY itemid, bizdocid_rc) d0 ON rc.BizDocId = d0.bizdocid_rc AND rc.ItemId = d0.itemid)
        UPDATE Tmp_V_CtTmp_RC
        SET Quantity_DO = COALESCE(rc.Quantity9_DO, 0),
            Quantity_Remain = COALESCE(Quantity9, 0) - COALESCE(rc.Quantity9_DO, 0)
        FROM CTE_RC rc
        WHERE rc.bizdocid = Tmp_V_CtTmp_RC.BizDocId AND rc.rowid = Tmp_V_CtTmp_RC.RowId;

        -- 4. Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info('Tmp_V_CtTmp_RC'::REGCLASS,
            '[
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
        }
    ]'::JSONB, p_PrintExec := 0::int2);

        -- 5. Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_V_CtTmp_RC;

        RETURN NEXT _ref1;
    END;
$function$;
BEGIN
    ;

    SELECT *
    FROM dbo.ufn_vct_receiptcommandlist(p_docdate1 := '2026-11-01T00:00:00'::date, p_docdate2 := '2026-11-22T00:00:00'::date,
        p_nuserid := 1011, p_branchcode := 'A01');

    FETCH ALL IN ref1;

    COMMIT;

END;
