CREATE OR REPLACE FUNCTION dbo.ufn_b30statsdocitem_convertfromb30bizdocdetail_bh(p_idlist text, p_currencycode character varying, p_exchangerate numeric DEFAULT 1, p_branchcode character varying DEFAULT 'A01'::character varying)
 RETURNS SETOF refcursor
 LANGUAGE plpgsql
AS $function$
    DECLARE
        _ref1 refcursor := 'ref1';
        _record record;
    BEGIN
        IF dbo.ufn_sys_isjson(p_IdList) = 0 THEN
            RETURN;
        END IF;

        DROP TABLE
        IF EXISTS Tmp_IdList;
        CREATE TEMP TABLE Tmp_IdList AS
        SELECT a.*
        FROM (SELECT * FROM jsonb_each(dbo.ufn_sys_json_lowerkey(p_IdList::jsonb)) LIMIT 1) AS j,
            LATERAL jsonb_to_recordset(CASE WHEN jsonb_typeof(j.value) = 'array' THEN j.value ELSE NULL END) AS a(Id INT,
            BizDocId varchar(16), RowId varchar(16), Quantity_Remain numeric(18, 2));

        -- -- Khởi tạo bảng tạm chính
        DROP TABLE
        IF EXISTS Tmp_BizDoc;
        CREATE TEMP TABLE Tmp_BizDoc ON COMMIT DROP AS
        SELECT CAST(- 1 * b0.Id AS INT) AS Id,
            b.BizDocId AS BizdocId_BH,
            b.DocCode,
            b.DocNo,
            b.DocDate,
            b.CurrencyCode,
            c.Name AS CustomerName,
            e.Name AS EmployeeName,
            b0.RowId AS RowId_BH,
            b0.ItemId,
            item.Name AS ItemName,
            b0.Unit,
            COALESCE(tm.Quantity_Remain, 0) AS Quantity9,
            b0.ConvertRate9,
            b0.Quantity,
            b0.OriginalUnitCost_Std,
            b0.DiscountRate,
            b0.OriginalUnitCost_AftDisc,
            b0.OriginalUnitCost_Case,
            b0.OriginalUnitCost_Qty,
            b0.OriginalUnitCost_Vou,
            b0.OriginalUnitCost,
            b0.UnitCost,
            b0.OriginalUnitCost_QT,
            b0.OriginalAmount,
            b0.Amount,
            b0.OriginalAmount9,
            b0.Amount9,
            b0.TaxCode,
            Tax.Rate AS TaxRate,
            b0.OriginalAmount3,
            b0.Amount3,
            b0.BizDocId_SO,
            b0.RowId_SO,
            b0.Quantity9 AS Quantity_SI,
            b0.Quantity9 AS Quantity_Remain
        FROM dbo.B30BizDocDetail AS b0
        INNER JOIN dbo.B30BizDoc AS b ON b.BizDocId = b0.BizDocId
        LEFT JOIN Tmp_IdList tm ON tm.RowId = b0.RowId
        LEFT JOIN dbo.B20Customer c ON c.Id = b.CustomerId
        LEFT JOIN dbo.B20Employee e ON e.Id = b.EmployeeId
        LEFT JOIN dbo.B20Tax Tax ON Tax.Code = b0.TaxCode
        LEFT JOIN dbo.B20Item item ON item.Id = b0.ItemId
        WHERE b0.RowId IN (SELECT RowId FROM Tmp_IdList);

        -- Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_BizDoc;
        RETURN NEXT _ref1;
    END;
$function$
