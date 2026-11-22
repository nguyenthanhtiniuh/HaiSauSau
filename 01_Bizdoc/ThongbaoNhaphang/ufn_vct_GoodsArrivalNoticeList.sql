/*
TINNT
19112026
Lấy dữ liệu Thông báo nhập hàng
để kế thừa qua Phiếu nhập kho
*/

CREATE OR REPLACE FUNCTION dbo.ufn_vct_GoodsArrivalNoticeList(p_docdate1 date DEFAULT '2026-01-01'::date, p_docdate2 date DEFAULT '2022-12-31'::date,
    p_customerid character varying DEFAULT ''::character varying, p_employeeid character varying DEFAULT ''::character varying,
    p_itemid character varying DEFAULT ''::character varying, p_deptid character varying DEFAULT ''::character varying,
    p_nuserid integer DEFAULT 0, p_branchcode character varying DEFAULT 'A01'::character varying, p_doclist character varying DEFAULT ''::character varying)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
        _DocList VARCHAR(128) := '';
        _codetype varchar(24) := '';
        _nametype text := '';
        _rowidtype varchar(16) := '';
        _bizdocidtype varchar(16) := '';
        _quantitytype NUMERIC(18, 5) := 0;
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

        IF COALESCE(p_deptid, '') <> '' THEN
            _Key1 := dbo.ufn_sys_GenKey(p_Code => p_deptid, p_ColGen => 'DeptId', p_ColName => 'Id', p_TableName => 'B20Dept',
                p_AndOrKey => 'AND', p_Key => _Key1);
        END IF;

        _DocList := REPLACE (p_DocList, ',', ''',''');

        IF _DocList <> '' THEN
            _Key1 := _Key1 || ' AND (DocCode IN (''' || RTRIM(_DocList) || '''))';
        END IF;

        -- Lấy dữ liệu Thông báo nhập hàng (DO)
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_DO;

        CREATE TEMP TABLE Tmp_V_CtTmp_DO AS
        SELECT DocCode,
            DocNo,
            DocDate,
            bizdocid,
            rowid,
            customerid,
            _codetype AS customercode,
            _nametype CustomerName,
            itemid,
            ItemCode,
            ItemName,
            Unit,
            _quantitytype Quantity9,
            _quantitytype Quantity,
            _quantitytype Quantity_SN,
            _quantitytype Quantity_REMAIN,
            EstimatedtimeDelivery,
            Remark,
            employeeid,
            _codetype AS employeecode,
            _nametype EmployeeName,
            bizdocid_po,
            rowid_po
        FROM dbo.vb30bizdocdetail_getdata
        LIMIT 0;

        CALL dbo.usp_b30bizdocdetail_getdata(p_docdate1 := p_docdate1, p_docdate2 := p_docdate2, p_key := _Key1, p_cttmp := 'Tmp_V_CtTmp_DO',
            p_branchcode := p_branchcode, p_nuserid := p_nuserid);

        -- Lấy dữ liệu Phiếu Nhập kho (SN)
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_SN;

        CREATE TEMP TABLE Tmp_V_CtTmp_SN AS
        SELECT DocCode,
            DocNo,
            DocDate,
            itemid,
            snT.quantity9,
            snT.quantity,
            _bizdocidtype AS bizdocid_PO,
            _bizdocidtype AS bizdocid_DO,
            _rowidtype AS rowid,
            _rowidtype AS rowid_po
        FROM dbo.B30StatsStockLedger snT
        LIMIT 0;

        _Key1 := 'EXISTS (SELECT * FROM Tmp_V_CtTmp_DO d0 WHERE sc.bizdocid_DO = d0.bizdocid AND sc.itemid = d0.itemid )';

        CALL dbo.usp_B30StatsStockLedger_GetData(p_DocDate1 := p_DocDate1, p_DocDate2 := p_DocDate2, p_key := _Key1,
            p_cttmp := 'Tmp_V_CtTmp_SN', p_BranchCode := p_BranchCode, p_nUserId := p_nUserId, p_groupbycols := ''::text,
            p_notsumcols := ''::text, p_PrintExec := 1::int2);

        -- Tổng hợp số lượng nhập kho theo DO và mã hàng
        CREATE TEMP TABLE Tmp_Qty_SN AS
        SELECT itemid,
            bizdocid_PO,
            sum(quantity9) AS quantity9
        FROM Tmp_V_CtTmp_SN
        GROUP BY itemid,
            bizdocid_PO;

        UPDATE Tmp_V_CtTmp_DO d0
        SET Quantity_SN = sn.quantity9,
          Quantity_REMAIN = d0.Quantity - sn.quantity9
        FROM Tmp_Qty_SN sn
        WHERE d0.itemid = sn.itemid AND d0.bizdocid_po = sn.bizdocid_PO;

        DROP TABLE
        IF EXISTS Tmp_Qty_SN;

        -- Tổng hợp số lượng đặt mua theo DO và mã hàng
        -- DROP TABLE
        -- IF EXISTS Tmp_PO_Summary;

        -- CREATE TEMP TABLE Tmp_PO_Summary AS
        -- SELECT po.BizDocId_DO,
        --     po.ItemId,
        --     SUM(po.FulfilledQuantity) FILTER (WHERE po.DocDate BETWEEN p_docdate1 AND p_docdate2) AS QuantityPOInPeriod,
        --     SUM(po.FulfilledQuantity) FILTER (WHERE po.DocDate > p_docdate2) AS QuantityPOAfterPeriod
        -- FROM dbo.vb30bizdocdetail_getdatapo po
        -- WHERE po.IsActive = TRUE AND po.BranchCode = p_branchcode AND COALESCE(po.BizDocId_DO, '') <> ''
        --  AND EXISTS (SELECT 1 FROM Tmp_V_CtTmp_DO p_DO WHERE
        --  p_DO.BizDocId = po.BizDocId_DO AND p_DO.BranchCode = p_branchcode AND p_DO.IsActive = TRUE AND p_DO.ItemId = po.ItemId)
        -- GROUP BY po.BizDocId_DO,
        --     po.ItemId;

        -- Tổng hợp kết quả DO
        -- DROP TABLE
        -- IF EXISTS Tmp_DO_Result;

        -- CREATE TEMP TABLE Tmp_DO_Result AS
        -- SELECT bc.*,
        --     bc.Quantity AS QuantityRequestSum,
        --     ''::VARCHAR(256) AS ItemName,
        --     ''::VARCHAR(24) AS ItemCode,
        --     ''::VARCHAR(256) AS CustomerName,
        --     ''::VARCHAR(256) AS EmployeeName,
        --     COALESCE(po.QuantityPOInPeriod, 0)::NUMERIC(18, 5) AS QuantityPOInPeriod,
        --     COALESCE(po.QuantityPOAfterPeriod, 0)::NUMERIC(18, 5) AS QuantityPOAfterPeriod,
        --     bc.Quantity - COALESCE(po.QuantityPOInPeriod, 0)::NUMERIC(18, 5) - COALESCE(po.QuantityPOAfterPeriod, 0)::NUMERIC(18,
        --     5) AS QuantityPODifference
        -- FROM Tmp_V_CtTmp_DO bc
        -- LEFT JOIN Tmp_PO_Summary po ON po.BizDocId_DO = bc.BizDocId AND po.ItemId = bc.ItemId;

        -- Cập nhật tên danh mục
        -- UPDATE Tmp_V_CtTmp_DO
        -- SET ItemName = COALESCE(i.Name, ''),
        --     ItemCode = COALESCE(i.Code, ''),
        --     CustomerName = COALESCE(c.Name, ''),
        --     customercode = COALESCE(c.code, ''),
        --     Employeecode = COALESCE(e.code, ''),
        --     EmployeeName = COALESCE(e.Name, '')
        -- FROM Tmp_V_CtTmp_DO d0
        -- LEFT JOIN dbo.b20item i ON i.Id = d0.ItemId
        -- LEFT JOIN dbo.b20customer c ON c.Id = d0.CustomerId
        -- LEFT JOIN dbo.b20employee e ON e.Id = d0.EmployeeId;

        -- Trả kết quả
        OPEN _ref1 FOR
        -- SELECT * FROM Tmp_V_CtTmp_DO;
        SELECT *
        FROM Tmp_V_CtTmp_DO;

        RETURN NEXT _ref1;
    END;
$function$;

BEGIN
    ;

    SELECT *
    FROM dbo.ufn_vct_GoodsArrivalNoticeList(p_docdate2 := '2026-11-19T00:00:00'::date, p_customerid := '241', p_nuserid := 1011,
        p_branchcode := 'A01', p_DocList := 'DO');

    FETCH ALL IN ref1;

    COMMIT;

END;
