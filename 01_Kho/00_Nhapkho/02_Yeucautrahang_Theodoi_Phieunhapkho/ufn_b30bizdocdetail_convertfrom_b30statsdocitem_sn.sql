/*--Hàm convert từ bảng b30statsdocitem sang b30bizdocdetail
--Kế thừa dữ liệu từ Báo cáo Theo dõi Phiếu nhập kho
*/
CREATE OR REPLACE FUNCTION dbo.ufn_b30bizdocdetail_convertfrom_b30statsdocitem_sn(p_idlist text,p_currencycode character varying
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
             ,statsdocid varchar(16),RowId varchar(16),Quantity_Remain numeric(18,2));

        -- -- Khởi tạo bảng tạm chính
        DROP TABLE
        IF EXISTS Tmp_StatsDoc;
        CREATE TEMP TABLE Tmp_StatsDoc ON COMMIT DROP AS
        SELECT CAST(- 1 * b0.Id AS INT) AS Id /*Thông tin chi tiết*/
               ,b.statsdocid AS statsdocid_sn
               ,b0.ItemId
               ,item.Name AS ItemName
               ,b0.Unit
               ,b0.IsPromotionItem
               ,COALESCE(tm.Quantity_Remain,0) AS Quantity9
               ,b0.ConvertRate9
               ,COALESCE(tm.Quantity_Remain,0) * COALESCE(b0.ConvertRate9,1) AS Quantity /*Thông tin đầu phiếu*/
               ,b.CurrencyCode
               ,b.customerid
               ,c.Name AS CustomerName
               ,b.employeeid
               ,e.Name AS EmployeeName /*Thông tin chi tiết PO*/
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
               ,b0.RowId_PO /*Lệnh nhập hàng*/
               ,b0.BizDocId_RC
        FROM dbo.b30statsdocinventory AS b0
        INNER JOIN dbo.b30statsdocitem AS b ON b.statsdocid = b0.statsdocid
        LEFT JOIN Tmp_IdList tm ON tm.RowId = b0.RowId
        LEFT JOIN dbo.B20Customer c ON c.Id = b.CustomerId
        LEFT JOIN dbo.B20Employee e ON e.Id = b.EmployeeId
        LEFT JOIN dbo.B20Tax Tax ON Tax.Code = b0.TaxCode
        LEFT JOIN dbo.B20Item item ON item.Id = b0.ItemId
        WHERE b0.RowId IN (SELECT RowId FROM Tmp_IdList);

        -- Trả kết quả
        OPEN _ref1 FOR
        SELECT *
        FROM Tmp_StatsDoc;
        RETURN NEXT _ref1;
    END;
$function$;
BEGIN
    ;

    SELECT *
    FROM dbo.ufn_b30bizdocdetail_convertfrom_b30statsdocitem_sn(
        p_idlist := '{"Table":[{"Id":62,"StatsDocId":"A010000127SN","RowId":"A010000187SN","Quantity_Remain":4.00},{"Id":62,"StatsDocId":"A010000127SN","RowId":"A010000189SN","Quantity_Remain":4.00},{"Id":62,"StatsDocId":"A010000127SN","RowId":"A010000191SN","Quantity_Remain":4.00}]}'
        ,p_currencycode := 'VND'
        ,p_exchangerate := 1.0
        ,p_branchcode := 'A01'
    );
    FETCH ALL IN ref1;

    COMMIT;

END;
