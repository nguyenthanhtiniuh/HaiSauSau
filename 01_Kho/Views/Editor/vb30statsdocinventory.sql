-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- DROP VIEW IF EXISTS dbo.vb30statsdocinventory;

CREATE OR REPLACE VIEW dbo.vb30statsdocinventory AS
SELECT ct0.id,
    ct0.branchcode,
    ct0.statsdocid,
    ct0.rowid,
    ct0.builtinorder,
    ct0.doccode,
    ct0.docdate,
    ct0.docgroup,
    ct0.transcode,
    ct0.workprocessid,
    ct0.shiftid,
    ct0.employeeid,
    ct0.warehouseid,
    ct0.factoryid,
    ct0.machineid,
    m.code AS machinecode,
    ct0.deptid,
    ct0.itemid,
    ct0.customerid,
    ct0.description,
    CASE WHEN COALESCE(ct0.description, ''::character varying)::text <> ''::text THEN
    ct0.description
ELSE
    item.name
END AS itemname,
    item.code AS itemcode,
    item.name AS name_item,
    item.unit AS unit_item,
    item.itemtype AS originalitemtype,
    item.itemtype,
    item.itemgroupid,
    ct0.unit,
    ct0.quantity9,
    ct0.convertrate9,
    ct0.quantity,
    ct0.remark,
    ct0.statsdocid_wo,
    wo.docno AS docno_wo,
    ct0.isactive,
    ct0.createdby,
    ct0.createdat,
    ct0.modifiedby,
    ct0.modifiedat,
    ct0."timestamp",
    wh.code AS warehousecode,
    wh.allowissuewhennotenough,
    wh.isitemwithlocation AS isitemwithlocation_wh,
    COALESCE((iteminfo.isitemwithlocation * wh.isitemwithlocation)::integer, 0) AS isitemwithlocation,
    iteminfo.weight,
    iteminfo.isitemwithserialno,
    iteminfo.isitemwithlocation AS isitemwithlocation_item,
    iteminfo.isitemwithlot,
    iteminfo.isitemwithcolor,
    iteminfo.isitemwithsize,
    iteminfo.isitemwithquality,
    iteminfo._physicalinventory + COALESCE((iteminfo.isitemwithlocation * wh.isitemwithlocation)::integer, 0) AS _physicalinventory,
    ct0.quantity AS remainphysquantity,
    ct0.quantity9 AS remainphysquantity9,
    ct0.itemid0,
    ct0.productionprocessid,
    ct0.productionlineid,
    ct0.bizdocid_so,
    so.docno AS docno_so,
    ct0.statsdocid_md,
    ct0.rowid_md,
    ct0.openquantity,
    ct0.receiptquantity,
    ct0.issuequantity,
    ct0.closequantity,
    ct0.receiptwarehouseid,
    ct0.receiptstatsdocid_wo,
    process.code AS productionprocesscode,
    line.code AS productionlinecode,
    hrmshift.code AS shiftcode,
    hrmshift.name AS shiftname,
    rw.code AS receiptwarehousecode,
    rw.name AS receiptwarehousename,
    iteminfo.shelflife,
    (so.docno::text || ' - '::text) || so.description::text AS docinfo_so,
    item0.code AS itemcode0,
    ct0.locationid,
    ct0.bizdocid_do,
    d0.vehicleid,
    bv.code AS vehiclecode,
    ct0.BizDocId_RC,
    ct0.PurchaseUnitPrice,
    TimeDiscount,
    InvoiceUnitPrice,
    OriginalUnitCost,
    OriginalAmount9,
    Amount9,
    TaxCode,
    OriginalAmount3,
    Amount3,
    AtchDocDate,
    AtchDocNo,
    AtchDocFormNo,
    ReceiptDate_EO,
    DiscountRate_EO,
    BizDocId_PO,
    SpeakerBOMType,
    CASE ct0.speakerbomtype WHEN '1'::text THEN
    'Ghi nợ'::bpchar WHEN '2'::text THEN
        'Trả nợ'::bpchar
    ELSE
        ''::bpchar
    END AS speakerbomtypename,
        SpeakerBOMId,
        SpeakerBOMCode,    
    ct0.StatsDocId_SN
    FROM b30statsdocinventory ct0
    LEFT JOIN b20item item ON ct0.itemid = item.id
    LEFT JOIN b20iteminfo iteminfo ON ct0.itemid = iteminfo.itemid
    LEFT JOIN b20warehouse wh ON ct0.warehouseid = wh.id
    LEFT JOIN b20warehouse rw ON rw.id = ct0.receiptwarehouseid
    LEFT JOIN b20productionprocess process ON ct0.productionprocessid = process.id
    LEFT JOIN b20productionline line ON ct0.productionlineid = line.id
    LEFT JOIN b20hrmshift hrmshift ON ct0.shiftid = hrmshift.id
    LEFT JOIN b30statsdoc wo ON wo.statsdocid::text = ct0.statsdocid_wo::text
    LEFT JOIN b30bizdocso so ON so.bizdocid::text = ct0.bizdocid_so::text
    LEFT JOIN b20machine m ON m.id = ct0.machineid
    LEFT JOIN b20item item0 ON ct0.itemid0 = item0.id
    LEFT JOIN b30bizdoc d0 ON d0.bizdocid::text = ct0.bizdocid_do::text
    LEFT JOIN dbo.b20vehicle bv ON bv.id = d0.vehicleid;
