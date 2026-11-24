CREATE OR REPLACE FUNCTION dbo.ufn_vct_purchaseorderlist(p_docdate1 date DEFAULT '2021-01-01'::date,p_docdate2 date DEFAULT '2022-12-31'::date
,p_customerid character varying DEFAULT ''::character varying,p_employeeid character varying DEFAULT ''::character varying
,p_itemid character varying DEFAULT ''::character varying,p_nuserid integer DEFAULT 0,p_branchcode character varying DEFAULT 'A01'::character varying
,p_reporttype integer DEFAULT 1)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    DECLARE
        _Key1 TEXT := '(1 = 1)';
        _ref1 refcursor := 'ref1';
    BEGIN
        p_nuserid := dbo.ufn_sys_getvaluefromappname('UserId',p_nuserid::VARCHAR);

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

        -- Lấy dữ liệu PO
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp_PO;

        CREATE TEMP TABLE Tmp_V_CtTmp_PO AS
        SELECT *
        FROM dbo.vb30bizdocdetail_getdatapo_item
        LIMIT 0;

        CALL dbo.usp_b30bizdocdetail_getdatapo(
            p_docdate1 := p_docdate1
            ,p_docdate2 := p_docdate2
            ,p_key := _Key1
            ,p_cttmp := 'Tmp_V_CtTmp_PO'
            ,p_branchcode := p_branchcode
            ,p_nuserid := p_nuserid
            ,p_reporttype := p_reporttype
        );

        -- Tổng hợp số lượng RC theo PO và mã hàng
        DROP TABLE
        IF EXISTS Tmp_RC_Summary;

        CREATE TEMP TABLE Tmp_RC_Summary AS
        SELECT rc.BizDocId_PO
               ,rc.ItemId
               ,SUM(rc.Quantity) AS TotalQuantityRC
        FROM dbo.vb30bizdocdetail_getdatarc rc
        WHERE rc.IsActive = TRUE AND rc.BranchCode = p_branchcode AND rc.BizDocId_PO <> '' AND EXISTS (SELECT 1 FROM Tmp_V_CtTmp_PO po WHERE po.BizDocId = rc.BizDocId_PO AND po.BranchCode = p_branchcode AND po.IsActive = TRUE AND po.ItemId = rc.ItemId)
        GROUP BY rc.BizDocId_PO
                 ,rc.ItemId;

        -- Tổng hợp kết quả PO
        DROP TABLE
        IF EXISTS Tmp_PO_Result;

        CREATE TEMP TABLE Tmp_PO_Result AS
        SELECT bc.*
               ,''::VARCHAR(256) AS ItemName
               ,''::VARCHAR(24) AS ItemCode
               ,''::VARCHAR(256) AS CustomerName
               ,''::VARCHAR(256) AS EmployeeName
               ,0::numeric(15,5) AS TaxRate
               ,COALESCE(rc.TotalQuantityRC,0)::NUMERIC(18,5) AS TotalQuantityRC
               ,bc.Quantity::NUMERIC(18,5) - COALESCE(rc.TotalQuantityRC,0)::NUMERIC(18,5) AS QuantityRCDifference
        FROM Tmp_V_CtTmp_PO bc
        LEFT JOIN Tmp_RC_Summary rc ON rc.BizDocId_PO = bc.BizDocId AND rc.ItemId = bc.ItemId;

        -- Cập nhật tên danh mục
        UPDATE Tmp_PO_Result r
        SET ItemName = COALESCE(i.Name,'')
            ,ItemCode = COALESCE(i.Code,'')
            ,CustomerName = COALESCE(c.Name,'')
            ,EmployeeName = COALESCE(e.Name,'')
            ,TaxRate = COALESCE(tax.Rate,0)
        FROM Tmp_V_CtTmp_PO bc
        LEFT JOIN dbo.b20item i ON i.Id = bc.ItemId
        LEFT JOIN dbo.b20customer c ON c.Id = bc.CustomerId
        LEFT JOIN dbo.b20employee e ON e.Id = bc.EmployeeId
        LEFT JOIN dbo.b20tax tax ON tax.Code = bc.TaxCode
        WHERE r.Id = bc.Id;

        -- Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_PO_Result;

        RETURN NEXT _ref1;
    END;
$function$
