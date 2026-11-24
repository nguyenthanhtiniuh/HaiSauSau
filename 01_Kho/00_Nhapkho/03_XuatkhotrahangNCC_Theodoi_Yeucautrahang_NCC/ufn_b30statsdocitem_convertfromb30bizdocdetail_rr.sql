CREATE OR REPLACE FUNCTION dbo.ufn_b30statsdocitem_convertfromb30bizdocdetail_rr(p_idlist text,p_currencycode character varying
,p_exchangerate numeric DEFAULT 1,p_branchcode character varying DEFAULT 'A01'::character varying)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
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
        FROM (SELECT * FROM jsonb_each(dbo.ufn_sys_json_lowerkey(p_IdList::jsonb)) LIMIT 1) AS j
             ,LATERAL jsonb_to_recordset(CASE WHEN jsonb_typeof(j.value) = 'array' THEN j.value ELSE NULL END) AS a(Id INT
             ,BizDocId varchar(16),RowId varchar(16),Quantity_Remain numeric(18,2));

        -- -- Khởi tạo bảng tạm chính
        DROP TABLE
        IF EXISTS Tmp_BizDoc;
        CREATE TEMP TABLE Tmp_BizDoc ON COMMIT DROP AS
        SELECT CAST(- 1 * b0.Id AS INT) AS Id /*Thông tin chi tiết*/
               ,b0.ItemId
               ,item.Name AS ItemName
               ,b0.Unit
               ,b0.IsPromotionItem
               ,COALESCE(tm.Quantity_Remain,0) AS Quantity9
               ,COALESCE(b0.ConvertRate9,1) AS ConvertRate9
               ,COALESCE(tm.Quantity_Remain,0) * COALESCE(b0.ConvertRate9,1) AS Quantity /*Thông tin đầu phiếu*/
               ,b.BizDocId AS BizDocId_RR
               ,b.DocCode
               ,b.DocNo
               ,b.DocDate
               ,b.CurrencyCode
               ,b.customerid
               ,c.Name AS CustomerName
               ,b.employeeid
               ,e.Name AS EmployeeName /*Thông tin Đơn đặt hàng mua (PO)*/
               ,b0.PurchaseUnitPrice
               ,b0.TimeDiscount
               ,b0.InvoiceUnitPrice
               ,b0.OriginalUnitCost
               ,b0.UnitCost
               ,b0.OriginalAmount
               ,b0.Amount
               ,b0.OriginalAmount9
               ,b0.Amount9
               ,b0.TaxCode
               ,Tax.Rate AS TaxRate
               ,b0.OriginalAmount3
               ,b0.Amount3
               ,b0.AtchDocDate
               ,b0.AtchDocNo
               ,b0.AtchDocFormNo
               ,b0.ReceiptDate_EO
               ,b0.DiscountRate_EO
               ,b0.SpeakerBOMType
               ,b0.SpeakerBOMCode
               ,b0.BizDocId_PO
               ,b0.RowId_PO /*Lệnh nhập hàng (RC)*/
               ,b0.BizDocId_RC /*Thông báo hàng về (DO)*/
               ,b0.bizdocid_do /*Phiếu nhập kho (SN)*/
               ,b0.statsdocid_sn
        FROM dbo.B30BizDocDetail AS b0
        INNER JOIN dbo.B30BizDoc AS b ON b.BizDocId = b0.BizDocId
        LEFT JOIN Tmp_IdList tm ON b0.bizdocid = tm.BizDocId AND tm.RowId = b0.RowId
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
