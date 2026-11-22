CREATE OR REPLACE PROCEDURE dbo.usp_b30statsdocitem_post(IN p_statsdocid character varying DEFAULT NULL::character varying, IN p_branchcode character varying DEFAULT NULL::character varying, IN p_docdate date DEFAULT NULL::date, IN p_doccode character varying DEFAULT NULL::character varying, IN p_docstatus smallint DEFAULT NULL::smallint, IN p_ispostwhensavenewdoc smallint DEFAULT 0, IN p_statsdocidlistxml text DEFAULT NULL::text, IN p_nuserid integer DEFAULT 0, IN p_langid integer DEFAULT 0, IN p_fiscalyear character varying DEFAULT ''::character varying)
 LANGUAGE plpgsql
AS $procedure$
-- ==============================================
-- Coder: VũLA
-- Created date: 03/07/2024
-- Description: Thủ tục post thẻ kho tại xưởng
-- ==============================================
DECLARE
	_ErrMsg TEXT;
	_FromValidDate DATE;
	_ToValidDate DATE;
BEGIN
	p_nUserId := dbo.ufn_sys_getvaluefromappname('UserId', p_nUserId::VARCHAR);

	-- Không thỏa mãn không chạy post
	IF COALESCE(p_StatsDocId, '') = '' AND p_StatsDocIdListXML IS NULL THEN
		RAISE NOTICE 'Không có điều kiện để post dữ liệu';
		RETURN;
	END IF;

	IF COALESCE(p_StatsDocId, '') <> '' AND p_DocDate IS NOT NULL THEN
		IF COALESCE(p_FiscalYear, '') = '' THEN
			p_FiscalYear := EXTRACT(YEAR FROM p_DocDate)::TEXT;
		END IF;

		SELECT FirstDayOfYear, LastDayOfYear INTO _FromValidDate, _ToValidDate
		FROM dbo.vB00FiscalYear
		WHERE BranchCode = p_BranchCode AND Name = p_FiscalYear;

		IF p_DocDate NOT BETWEEN _FromValidDate AND _ToValidDate THEN
			_ErrMsg := dbo.ufn_sys_MessageText('DATEERROR', p_LangId);
			RAISE EXCEPTION '%', _ErrMsg;
			RETURN;
		END IF;
	END IF;

	DROP TABLE IF EXISTS Tmp_Inserted;
	CREATE TEMP TABLE Tmp_Inserted (
		StatsDocId VARCHAR(16),
		DocStatus SMALLINT
	);

	IF COALESCE(p_StatsDocId, '') = '' AND p_StatsDocIdListXML IS NOT NULL THEN
		INSERT INTO Tmp_Inserted(StatsDocId, DocStatus)
		SELECT x.StatsDocId, x.DocStatus
		FROM (SELECT * FROM jsonb_each(dbo.ufn_sys_json_lowerkey(p_StatsDocIdListXML::jsonb)) LIMIT 1) AS j,
			LATERAL jsonb_to_recordset(CASE WHEN jsonb_typeof(j.value) = 'array' THEN j.value ELSE NULL END) AS x(
				StatsDocId VARCHAR(16),
				DocStatus SMALLINT
			);
--		FROM XMLTABLE('/*/*'
--			PASSING p_StatsDocIdListXML
--			COLUMNS
--				StatsDocId VARCHAR(16) PATH '@statsdocid|@StatsDocId',
--				DocStatus SMALLINT PATH '@docstatus|@DocStatus'
--		) AS x;
	ELSE
		INSERT INTO Tmp_Inserted(StatsDocId, DocStatus)
		VALUES (p_StatsDocId, p_DocStatus);
	END IF;

	IF NOT EXISTS(SELECT 1 FROM Tmp_Inserted ins INNER JOIN dbo.B00DocStatus d ON ins.DocStatus = d.DocStatusKey AND d.PostSL = 1) THEN
		DELETE FROM dbo.B30StatsStockLedger
		WHERE StatsDocId IN (SELECT StatsDocId FROM Tmp_Inserted);

		DELETE FROM dbo.B30StatsStockLedgerPhys
		WHERE StatsDocId IN (SELECT StatsDocId FROM Tmp_Inserted);
	ELSE
		IF p_IsPostWhenSaveNewDoc = 1 AND COALESCE(p_StatsDocId, '') <> '' THEN
			INSERT INTO dbo.B30StatsStockLedger(Id, BranchCode, FiscalYear, StatsDocId, RowId, DocCode, DocGroup, DocDate, DocNo, Description,
				FactoryId, WarehouseId, ReceiptWarehouseId, StatsDocId_WO, ReceiptStatsDocId_WO, ItemId, Unit, Quantity,
				ProductionProcessId, ProductionLineId, ShiftId, BizDocId_SO, DeptId, EmployeeId,
				CustomFieldId1, CustomFieldId2, CustomFieldId3, Quantity9, ConvertRate9,itemserialno,BizdocId_DO,rowid_po,bizdocid_po,BizDocId_RR)
			SELECT Ct.Id, Ct.BranchCode, Ct.FiscalYear, Ct.StatsDocId, Ct.RowId, Ct.DocCode, Ct.DocGroup, Ct.DocDate, Ct.DocNo, Ct.Description, Ct.FactoryId,
				Ct.WarehouseId, Ct.ReceiptWarehouseId, Ct.StatsDocId_WO, Ct.ReceiptStatsDocId_WO, Ct.ItemId, Ct.Unit, Ct.Quantity,
				Ct.ProductionProcessId, Ct.ProductionLineId, Ct.ShiftId, Ct.BizDocId_SO, Ct.DeptId, Ct.EmployeeId, Ct.CustomFieldId1,
				Ct.CustomFieldId2, Ct.CustomFieldId3, Ct.Quantity9, Ct.ConvertRate9,itemserialno,BizdocId_DO,rowid_po,bizdocid_po,BizDocId_RR
			FROM dbo.vB30StatsStockLedger_Post Ct
			WHERE Ct.StatsDocId = p_StatsDocId;
		ELSE
			MERGE INTO dbo.B30StatsStockLedger AS sl
			USING (
				SELECT Ct.Id, Ct.BranchCode, Ct.FiscalYear, Ct.StatsDocId, Ct.RowId, Ct.DocCode, Ct.DocGroup, Ct.DocDate, Ct.DocNo, Ct.Description, Ct.FactoryId,
					Ct.WarehouseId, Ct.ReceiptWarehouseId, Ct.StatsDocId_WO, Ct.ReceiptStatsDocId_WO, Ct.ItemId, Ct.Unit, Ct.Quantity,
					Ct.ProductionProcessId, Ct.ProductionLineId, Ct.ShiftId, Ct.BizDocId_SO, Ct.DeptId, Ct.EmployeeId, Ct.CustomFieldId1,
					Ct.CustomFieldId2, Ct.CustomFieldId3, Ct.Quantity9, Ct.ConvertRate9,itemserialno,BizdocId_DO,rowid_po,bizdocid_po,BizDocId_RR
				FROM dbo.vB30StatsStockLedger_Post Ct
				INNER JOIN Tmp_Inserted tb ON tb.StatsDocId = Ct.StatsDocId
			) AS ins ON sl.StatsDocId = ins.StatsDocId AND sl.RowId = ins.RowId AND sl.DocGroup = ins.DocGroup
				AND sl.BranchCode = ins.BranchCode AND sl.FiscalYear = ins.FiscalYear AND sl.DocCode = ins.DocCode
			WHEN MATCHED THEN
				UPDATE SET Id = ins.Id, BranchCode = ins.BranchCode, DocDate = ins.DocDate, DocNo = ins.DocNo, Description = ins.Description, FactoryId = ins.FactoryId,
					WarehouseId = ins.WarehouseId, ReceiptWarehouseId = ins.ReceiptWarehouseId, StatsDocId_WO = ins.StatsDocId_WO, ReceiptStatsDocId_WO = ins.ReceiptStatsDocId_WO,
					ItemId = ins.ItemId, Unit = ins.Unit, Quantity = ins.Quantity, ProductionProcessId = ins.ProductionProcessId, ProductionLineId = ins.ProductionLineId,
					ShiftId = ins.ShiftId, BizDocId_SO = ins.BizDocId_SO, DeptId = ins.DeptId, EmployeeId = ins.EmployeeId, CustomFieldId1 = ins.CustomFieldId1,
					CustomFieldId2 = ins.CustomFieldId2, CustomFieldId3 = ins.CustomFieldId3, Quantity9 = ins.Quantity9, ConvertRate9 = ins.ConvertRate9,
					itemserialno=ins.itemserialno,BizdocId_DO=ins.BizdocId_DO,rowid_po=ins.rowid_po,bizdocid_po=ins.bizdocid_po,BizDocId_RR=ins.BizDocId_RR
			WHEN NOT MATCHED BY SOURCE AND sl.StatsDocId IN (SELECT StatsDocId FROM Tmp_Inserted) THEN
				DELETE
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (Id, BranchCode, FiscalYear, StatsDocId, RowId, DocCode, DocGroup, DocDate, DocNo, Description,
					FactoryId, WarehouseId, ReceiptWarehouseId, StatsDocId_WO, ReceiptStatsDocId_WO, ItemId, Unit, Quantity,
					ProductionProcessId, ProductionLineId, ShiftId, BizDocId_SO, DeptId, EmployeeId,
					CustomFieldId1, CustomFieldId2, CustomFieldId3, Quantity9, ConvertRate9,itemserialno,BizdocId_DO,rowid_po,bizdocid_po,BizDocId_RR)
				VALUES (ins.Id, ins.BranchCode, ins.FiscalYear, ins.StatsDocId, ins.RowId, ins.DocCode, ins.DocGroup, ins.DocDate, ins.DocNo, ins.Description,
					ins.FactoryId, ins.WarehouseId, ins.ReceiptWarehouseId, ins.StatsDocId_WO, ins.ReceiptStatsDocId_WO, ins.ItemId, ins.Unit, ins.Quantity,
					ins.ProductionProcessId, ins.ProductionLineId, ins.ShiftId, ins.BizDocId_SO, ins.DeptId, ins.EmployeeId,
					ins.CustomFieldId1, ins.CustomFieldId2, ins.CustomFieldId3, ins.Quantity9, ins.ConvertRate9,ins.itemserialno,BizdocId_DO,rowid_po,bizdocid_po,BizDocId_RR);
		END IF;

		IF EXISTS (
			SELECT 1
			FROM Tmp_Inserted i
			INNER JOIN dbo.B30StatsStockLedgerPhys phys ON i.StatsDocId = phys.StatsDocId
		) THEN
			DELETE FROM dbo.B30StatsStockLedgerPhys
			WHERE StatsDocId IN (SELECT StatsDocId FROM Tmp_Inserted);
		END IF;

		INSERT INTO dbo.B30StatsStockLedgerPhys(Id, BranchCode, FiscalYear, DocGroup, DocCode, DocDate, StatsDocId, RowId,
			FactoryId, WarehouseId, StatsDocId_WO, ItemId, ItemLotCode, ItemSerialNo, ColorCode, SizeCode, ItemQualityCode,
			Quantity, ReceiptQuantity, IssueQuantity, LocationId, Unit, Quantity9, ConvertRate9)
		SELECT a.Id, a.BranchCode, a.FiscalYear, a.DocGroup, a.DocCode, a.DocDate, a.StatsDocId, a.RowId,
			a.FactoryId, a.WarehouseId, a.StatsDocId_WO, a.ItemId, a.ItemLotCode, a.ItemSerialNo, a.ColorCode, a.SizeCode,
			a.ItemQualityCode, a.Quantity, a.ReceiptQuantity, a.IssueQuantity, a.LocationId,
			a.Unit, a.Quantity9, a.ConvertRate9
		FROM dbo.vB30StatsStockLedgerPhys_Posting a
			INNER JOIN Tmp_Inserted inserted ON a.StatsDocId = inserted.StatsDocId;

	END IF;

	DROP TABLE IF EXISTS Tmp_Inserted;
END;
$procedure$
