--Theo dõi Đơn đặt hàng mua
CREATE OR REPLACE FUNCTION dbo.ufn_vct_purchaseorderlist(p_docdate1 date DEFAULT '2021-01-01'::date, p_docdate2 date DEFAULT '2022-12-31'::date,
    p_customerid character varying DEFAULT ''::character varying, p_employeeid character varying DEFAULT ''::character varying,
    p_itemid character varying DEFAULT ''::character varying, p_nuserid integer DEFAULT 0, p_branchcode character varying DEFAULT 'A01'::character varying,
    p_reporttype integer DEFAULT 1)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
        _codetype VARCHAR(24) := '';
        _nametype VARCHAR(256) := '';
        _quantitytype NUMERIC(18, 2) := 0;
    BEGIN
        p_nuserid := dbo.ufn_sys_getvaluefromappname('UserId', p_nuserid::VARCHAR);

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

        --1.Lấy dữ liệu PO
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_PO;
        CREATE TEMP TABLE Tmp_V_CtTmp_PO AS
        SELECT id /*Thông tin chi tiết PO*/,
            bizdocid,
            rowid,
            parentrowid,
            builtinorder,
            description,
            itemid,
            _codetype AS itemcode,
            _nametype AS itemname,
            unit,
            quantity9,
            convertrate9,
            quantity,
            _quantitytype AS TotalQuantityRC,
            _quantitytype AS QuantityRCDifference,
            purchaseunitprice,
            timediscount,
            invoiceunitprice,
            amount9,
            taxcode,
            0::numeric(8, 4) AS TaxRate,
            amount3,
            amount,
            receiptdate_eo,
            discountrate_eo,
            closeddate,
            ispromotionitem,
            speakerbomtype,
            speakerbomcode,
            remark,
            bizdocid_prs,
            branchcode /*Thông tin đầu phiếu PO*/,
            doccode,
            docstatus,
            docno,
            docdate,
            customerid,
            _codetype AS customercode,
            _nametype AS customername,
            employeeid,
            _codetype AS employeecode,
            _nametype AS employeename,
            deptid,
            _codetype AS deptcode,
            _nametype AS deptname,
            transtype,
            isactive,
            id_po
        FROM dbo.vb30bizdocdetail_getdatapo_item
        LIMIT 0;

        CALL dbo.usp_b30bizdocdetail_getdatapo(p_docdate1 := p_docdate1, p_docdate2 := p_docdate2, p_key := _Key1,
            p_cttmp := 'Tmp_V_CtTmp_PO', p_branchcode := p_branchcode, p_nuserid := p_nuserid, p_reporttype := p_reporttype);

        --2.Tổng hợp số lượng RC theo PO và mã hàng
        DROP TABLE
        IF EXISTS Tmp_RC_Summary;
        CREATE TEMP TABLE Tmp_RC_Summary AS
        SELECT rc.BizDocId_PO,
            rc.ItemId,
            SUM(rc.Quantity) AS TotalQuantityRC
        FROM dbo.vb30bizdocdetail_getdatarc rc
        WHERE rc.IsActive = TRUE AND rc.BranchCode = p_branchcode AND rc.BizDocId_PO <> '' AND EXISTS (SELECT 1 FROM Tmp_V_CtTmp_PO po WHERE po.BizDocId = rc.BizDocId_PO AND po.BranchCode = p_branchcode AND po.IsActive = TRUE AND po.ItemId = rc.ItemId)
        GROUP BY rc.BizDocId_PO,
            rc.ItemId;

        --3.Cập nhật số lượng RC vào chi tiết PO
        WITH ctebizpo AS (SELECT po.bizdocid, po.itemid, po.rowid, biz_rc.TotalQuantityRC FROM Tmp_V_CtTmp_PO po LEFT JOIN (SELECT BizDocId_PO,
            ItemId, sum(TotalQuantityRC) TotalQuantityRC FROM Tmp_RC_Summary GROUP BY BizDocId_PO, ItemId) biz_rc ON biz_rc.BizDocId_PO = po.bizdocid AND biz_rc.ItemId = po.itemid)
        UPDATE Tmp_V_CtTmp_PO
        SET TotalQuantityRC = COALESCE(po.TotalQuantityRC, 0),
            QuantityRCDifference = COALESCE(Tmp_V_CtTmp_PO.quantity9, 0) - COALESCE(po.TotalQuantityRC, 0)
        FROM ctebizpo po
        WHERE Tmp_V_CtTmp_PO.bizdocid = po.bizdocid AND Tmp_V_CtTmp_PO.itemid = po.itemid AND Tmp_V_CtTmp_PO.rowid = po.rowid;

        -- 4.Cập nhật thông tin Item, Customer , Employee
        PERFORM dbo.ufn_update_catalog_info('Tmp_V_CtTmp_PO'::REGCLASS,
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
        },
        {
            "source_table": "dbo.b20dept",
            "target_key": "deptid",
            "source_key": "id",
            "column_map": {
                "deptcode": "code",
                "deptname": "name"
            }
        }
    ]'::JSONB, p_PrintExec := 0::int2);

        --5.Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_V_CtTmp_PO;

        RETURN NEXT _ref1;
    END;
$function$;
BEGIN
    ;

    SELECT *
    FROM dbo.ufn_Vct_PurchaseOrderList(p_docdate1 := '2026-11-01T00:00:00'::date, p_docdate2 := '2026-11-22T00:00:00'::date,
        p_nuserid := 1011, p_branchcode := 'A01', p_reporttype := 2);
    FETCH ALL IN ref1;

    COMMIT;

END;
