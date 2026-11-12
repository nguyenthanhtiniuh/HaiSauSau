CREATE OR REPLACE FUNCTION dbo.ufn_stats_itemsummary(p_docdate1 date DEFAULT '2018-11-11'::date, p_docdate2 date DEFAULT '2021-11-11'::date,
    p_warehouseid character varying DEFAULT ''::character varying, p_factoryid character varying DEFAULT ''::character varying,
    p_warehouseownerid character varying DEFAULT ''::character varying, p_itemid character varying DEFAULT ''::character varying,
    p_nuserid integer DEFAULT '-1'::integer, p_langid integer DEFAULT 0, p_branchcode character varying DEFAULT 'A01'::character varying,
    p_currencycode0 character DEFAULT 'VND'::character(1), p_groupbylistfield character varying DEFAULT 'WarehouseId'::character varying,
    pout_layout_xml text DEFAULT NULL::text)
RETURNS SETOF refcursor
LANGUAGE plpgsql AS $function$
    -- ======================================================
    -- Coder: ThanhND
    -- Manager: ThangNH
    -- Description	 : Tổng hợp Nhập - Xuất - Tồn tại xưởng
    -- ======================================================
    DECLARE
        _ref_out refcursor := 'ref_out';
        _ref1 refcursor := 'ref1';
        _KeyCd TEXT := '';
        _Key TEXT := '';
        _LinkCommand TEXT;
        _rec RECORD;
    BEGIN
        -- Tự động lấy thông tin theo AppName khi thực hiện trong chương trình, không theo tham số truyền vào
        p_nUserId := dbo.ufn_sys_getvaluefromappname('UserId', p_nUserId::VARCHAR);

        IF p_WarehouseId <> '' THEN
            _Key := dbo.ufn_sys_GenKey(p_Code => p_WarehouseId, p_ColGen => 'WarehouseId', p_ColName => 'Id',
                p_TableName => 'B20Warehouse', p_AndOrKey => 'AND ', p_Key => _Key);

            _KeyCd := dbo.ufn_sys_GenKey(p_Code => p_WarehouseId, p_ColGen => 'WarehouseId', p_ColName => 'Id',
                p_TableName => 'B20Warehouse', p_AndOrKey => 'AND ', p_Key => _KeyCd);
        ELSE
            _Key := _Key || ' AND WarehouseId IS NOT NULL';
        END IF;

        IF p_WarehouseOwnerId <> '' THEN
            _Key := _Key || ' AND WarehouseId IN (SELECT Id FROM dbo.B20Warehouse WHERE OwnerId IN (' || p_WarehouseOwnerId || '))';
            _KeyCd := _KeyCd || ' AND WarehouseId IN (SELECT Id FROM dbo.B20Warehouse WHERE OwnerId IN (' || p_WarehouseOwnerId || '))';
        END IF;

        IF p_ItemId <> '' THEN
            _Key := dbo.ufn_sys_GenKey(p_Code => p_ItemId, p_ColGen => 'ItemId', p_ColName => 'Id', p_TableName => 'B20Item',
                p_AndOrKey => 'AND ', p_Key => _Key);

            _KeyCd := dbo.ufn_sys_GenKey(p_Code => p_ItemId, p_ColGen => 'ItemId', p_ColName => 'Id', p_TableName => 'B20Item',
                p_AndOrKey => 'AND ', p_Key => _KeyCd);
        END IF;

        IF p_FactoryId <> '' THEN
            _Key := dbo.ufn_sys_GenKey(p_Code => p_FactoryId, p_ColGen => 'FactoryId', p_ColName => 'Id', p_TableName => 'B20Factory',
                p_AndOrKey => 'AND ', p_Key => _Key);

            _KeyCd := dbo.ufn_sys_GenKey(p_Code => p_FactoryId, p_ColGen => 'FactoryId', p_ColName => 'Id', p_TableName => 'B20Factory',
                p_AndOrKey => 'AND ', p_Key => _KeyCd);
        END IF;

        IF
        LEFT (_Key, 5) = ' AND ' THEN
            _Key := SUBSTRING(_Key, 6, LENGTH(RTRIM(_Key)) - 5);
        END IF;

        IF
        LEFT (_KeyCd, 5) = ' AND ' THEN
            _KeyCd := SUBSTRING(_KeyCd, 6, LENGTH(RTRIM(_KeyCd)) - 5);
        END IF;

        -- Lấy giá trị tồn đầu kỳ
        DROP TABLE
        IF EXISTS Tmp_OpenInventory_Data;
        CREATE TEMP TABLE Tmp_OpenInventory_Data AS
        SELECT WarehouseId,
            ItemId,
            FactoryId,
            Quantity AS OpenInventory,
            Amount AS OpenAmount,
            OriginalAmount AS OriginalOpenAmount,
            Quantity AS ReceiptQuantity,
            Quantity AS DeliveryQuantity,
            Amount AS ReceiptAmount,
            Amount AS DeliveryAmount,
            Amount AS OriginalReceiptAmount,
            Amount AS OriginalDeliveryAmount,
            Quantity AS CloseInventory,
            Amount AS CloseAmount,
            OriginalAmount AS OriginalCloseAmount,
            WarehouseCode,
            WarehouseName,
            ItemCode,
            ItemName,
            Unit,
            Code AS FactoryCode,
            Name AS FactoryName,
            itemserialno,
            locationid
        FROM B00CtTmp
        LIMIT 0;

        CALL dbo.usp_B30StatsOpenInventory_GetData(p_DocDate0 => p_DocDate1, p_Key => _KeyCd, p_CtTmp => 'Tmp_OpenInventory_Data',
            p_nUserId => p_nUserId, p_LangId => p_LangId, p_BranchCode => p_BranchCode, p_CurrencyCode0 => p_CurrencyCode0);

        -- Lấy giá trị phát sinh trong kỳ
        DROP TABLE
        IF EXISTS Tmp_V_CtTmp0;
        CREATE TEMP TABLE Tmp_V_CtTmp0 AS
        SELECT StatsDocId,
            RowId,
            ItemId,
            DocGroup,
            DocDate,
            DocCode,
            DocNo,
            WarehouseId,
            Quantity,
            Unit,
            FactoryId,
            itemserialno,
            locationid
        FROM dbo.B00CtTmp
        LIMIT 0;

        CALL dbo.usp_sys_DefaultTable(p_Table := 'Tmp_V_CtTmp0');

        CALL dbo.usp_B30StatsStockLedger_GetData(p_DocDate1 => p_DocDate1, p_DocDate2 => p_DocDate2, p_CtTmp => 'Tmp_V_CtTmp0'::TEXT,
            p_Key => _Key, p_nUserId => p_nUserId, p_LangId => p_LangId, p_BranchCode => p_BranchCode, p_GroupByCols => 'ItemId,WarehouseId,DocGroup,FactoryId'::TEXT,
            p_printexec := 1::SMALLINT);

        INSERT INTO Tmp_OpenInventory_Data(WarehouseId, ItemId, FactoryId, ReceiptQuantity, DeliveryQuantity)
        SELECT WarehouseId,
            ItemId,
            FactoryId,
            CASE WHEN DocGroup = '1' THEN
            Quantity
        ELSE
            0
        END AS ReceiptQuantity,
            CASE WHEN DocGroup = '2' THEN
            Quantity
        ELSE
            0
        END AS DeliveryQuantity
        FROM Tmp_V_CtTmp0;

        IF COALESCE(p_groupbylistfield, '') = 'WarehouseId' THEN
            UPDATE Tmp_OpenInventory_Data
            SET locationid = NULL;
        END IF;

        -- Tạo bảng tổng hợp
        DROP TABLE
        IF EXISTS Tmp_V_SoTmp;
        CREATE TEMP TABLE Tmp_V_SoTmp(Id SERIAL, WarehouseId INT, ItemId INT, itemserialno varchar(24), locationid int,
            FactoryId INT, OpenInventory NUMERIC(16, 5), ReceiptQuantity NUMERIC(16, 5), DeliveryQuantity NUMERIC(16, 5),
            CloseInventory NUMERIC(16, 5), _FormatStyleKey VARCHAR(48), ItemCode VARCHAR(24), ItemName VARCHAR(256),
            locationCode VARCHAR(24), locationName VARCHAR(256), Unit VARCHAR(8), WarehouseCode VARCHAR(24),
            WarehouseName VARCHAR(256), FactoryCode VARCHAR(24), FactoryName VARCHAR(256));

        INSERT INTO Tmp_V_SoTmp(WarehouseId, ItemId, locationid, OpenInventory, ReceiptQuantity, DeliveryQuantity,
            CloseInventory, ItemCode, ItemName, Unit, WarehouseCode, WarehouseName)
        SELECT WarehouseId,
            ItemId,
            locationid,
            SUM(OpenInventory) AS OpenInventory,
            SUM(ReceiptQuantity) AS ReceiptQuantity,
            SUM(DeliveryQuantity) AS DeliveryQuantity,
            SUM(OpenInventory + ReceiptQuantity - DeliveryQuantity) AS CloseInventory,
            MAX(ItemCode) AS ItemCode,
            MAX(ItemName) AS ItemName,
            MAX(Unit) AS Unit,
            MAX(WarehouseCode) AS WarehouseCode,
            MAX(WarehouseName) AS WarehouseName
        FROM Tmp_OpenInventory_Data
        WHERE (ABS(OpenInventory) + ABS(ReceiptQuantity) + ABS(DeliveryQuantity) <> 0)
        GROUP BY ItemId,
            WarehouseId,
            locationid;

        WITH updates AS (SELECT tb.Id, COALESCE(item.Code, '') AS NewItemCode, COALESCE(item.Name, '') AS NewItemName,
            COALESCE(item.Unit, '') AS NewUnit, COALESCE(wh.Code, '<<No Code>>') AS NewWarehouseCode, wh.Code || ' - ' || wh.Name AS NewWarehouseName,
            COALESCE(loca.Code, '') AS NewLocationCode, COALESCE(loca.Name, '') AS NewLocationName, CASE WHEN tb.CloseInventory < 0 THEN 'RedColor' ELSE NULL END AS NewFormatStyleKey FROM Tmp_V_SoTmp AS tb LEFT OUTER JOIN dbo.B20Item AS item ON tb.ItemId = item.Id LEFT OUTER JOIN dbo.B20Warehouse AS wh ON tb.WarehouseId = wh.Id LEFT OUTER JOIN dbo.b20location AS loca ON tb.locationid = loca.Id)
        UPDATE Tmp_V_SoTmp
        SET ItemCode = u.NewItemCode,
            ItemName = u.NewItemName,
            Unit = u.NewUnit,
            WarehouseCode = u.NewWarehouseCode,
            WarehouseName = u.NewWarehouseName,
            LocationCode = u.NewLocationCode,
            LocationName = u.NewLocationName,
            _FormatStyleKey = u.NewFormatStyleKey
        FROM updates u
        WHERE Tmp_V_SoTmp.Id = u.Id;

        SELECT '<DefaultReport><Content>' 
|| CHR(13) || ' <Cols>' 
|| CHR(13) || '		<WarehouseName>' 
|| CHR(13) || '			<Visible>False</Visible>' 
|| CHR(13) || '			<Width>80</Width>' 
|| CHR(13) || '		</WarehouseName>' 
|| (CASE WHEN p_groupbylistfield = 'WarehoueId' THEN ''
ELSE CHR(13) || '		<LocationName>' 
|| CHR(13) || '			<Visible>False</Visible>' 
|| CHR(13) || '			<Width>80</Width>' 
|| CHR(13) || '		</LocationName>' END)
|| CHR(13) || '	</Cols>' 
|| CHR(13) || '<Groups>' 
|| CHR(13) || '	<WarehouseName>' 
|| CHR(13) || '		<Text>' 
|| CHR(13) || '			<Vietnamese>Kho hàng: {=WarehouseName}</Vietnamese>' 
|| CHR(13) || '			<English>Warehouse: {=WarehouseName}</English>' 
|| CHR(13) || '			<Japanese>倉庫: {=WarehouseName}</Japanese>' 
|| CHR(13) || '			<Chinese>仓库: {=WarehouseName}</Chinese>' 
|| CHR(13) || '			<Korean>창고: {=WarehouseName}</Korean>' 
|| CHR(13) || '		</Text>' 
|| CHR(13) || '	</WarehouseName>' 
|| (CASE WHEN p_groupbylistfield = 'WarehoueId' THEN ''
ELSE CHR(13) || '	<LocationName>' 
|| CHR(13) || '		<Text>' 
|| CHR(13) || '			<Vietnamese>Vị trí: {=LocationName}</Vietnamese>' 
|| CHR(13) || '			<English>Location: {=LocationName}</English>' 
|| CHR(13) || '			<Japanese>倉庫: {=LocationName}</Japanese>' 
|| CHR(13) || '			<Chinese>仓库: {=LocationName}</Chinese>' 
|| CHR(13) || '			<Korean>창고: {=LocationName}</Korean>' 
|| CHR(13) || '		</Text>' 
|| CHR(13) || '	</LocationName>' END)
|| CHR(13) || '</Groups>' 
|| CHR(13) || '</Content></DefaultReport>' 
        INTO pout_LAYOUT_XML;

        OPEN _ref_out FOR
        SELECT pout_LAYOUT_XML AS pout_LAYOUT_XML;
        RETURN NEXT _ref_out;

        --_LinkCommand := 'REP_Stats_InventoryList DocDate1=''{=@_DocDate1}'';DocDate2=''{=@_DocDate2}'';'|| 'WarehouseId=''{=WarehouseId}'';ItemId=''{=ItemId}'';';
        IF COALESCE(p_groupbylistfield, '') = '' THEN
            OPEN _ref1 FOR
            SELECT s.*
            --, _LinkCommand AS _LinkCommand
            FROM Tmp_V_SoTmp AS s;
        ELSE
            open _ref1 FOR
            SELECT s.*
            --, _LinkCommand AS _LinkCommand
            FROM Tmp_V_SoTmp AS s;
        END IF;

        RETURN NEXT _ref1;
    END;
$function$;

BEGIN
    ;

    SELECT *
    FROM dbo.ufn_Stats_ItemSummary(p_docdate1 := '2026-01-01'::date, p_docdate2 := '2026-11-11'::date, p_nuserid := 1011::integer,
        p_langid := 0::integer, p_branchcode := 'A01'::text, p_currencycode0 := 'VND'::text);

    FETCH ALL IN ref1;
    COMMIT;
END 