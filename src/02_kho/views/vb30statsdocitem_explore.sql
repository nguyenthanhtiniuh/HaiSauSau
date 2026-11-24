-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- DROP VIEW IF EXISTS dbo.vb30statsdocitem_explore;

CREATE OR REPLACE VIEW dbo.vb30statsdocitem_explore AS
SELECT ct.id
       ,ct.branchcode
       ,ct.fiscalyear
       ,ct.statsdocid
       ,ct.docgroup
       ,ct.doccode
       ,ct.ma_nvu
       ,ct.docdate
       ,ct.docno
       ,ct.currencycode
       ,ct.exchangerate
       ,ct.person
       ,ct.address
       ,ct.transcode
       ,ct.customerid
       ,cust.code AS customercode
       ,cust.name AS customername
       ,ct.deptid
       ,ct.statsdocid_wo
       ,ct.workprocessid
       ,ct.employeeid
       ,empl.code AS employeecode
       ,empl.name AS employeename
       ,empl2.code AS employeecode2
       ,empl2.name AS employeename2
       ,ct.warehouseid
       ,wh.code AS warehousecode
       ,wh.name AS warehousename
       ,ct.receiptwarehouseid
       ,rw.code AS receiptwarehousecode
       ,rw.name AS receiptwarehousename
       ,ct.driver
       ,ct.vehicleid
       ,vhc.code AS vehiclecode
       ,vhc.name AS vehiclename
       ,ct.factoryid
       ,fac.code AS factorycode
       ,fac.name AS factoryname
       ,ct.machineid
       ,machine.code AS machinecode
       ,machine.name AS machinename
       ,ct.shiftid
       ,hrmshift.code AS shiftcode
       ,hrmshift.name AS shiftname
       ,ct.receiptstatsdocid_wo
       ,(w.docno::text || ' - '::text) || w.description::text AS receiptwoinfo
       ,ct.totalquantity
       ,ct.description
       ,ct.documentviewstyle
       ,ct.docstatus
       ,ct.posted
       ,ct.loai_ps
       ,ct.ws_id0
       ,ct.isactive
       ,ct.createdby
       ,ct.createdat
       ,ct.modifiedby
       ,ct.modifiedat
       ,ct."timestamp"
       ,ct.rowid_docprocess
       ,ct.docprocessid
       ,doc.postsl
       ,doc.lock
       ,(w1.docno::text || ' - '::text) || w1.description::text AS statsdocwoinfo
       ,emp.name AS managername
       ,ct.approvalstatus
       ,ct.outsourceddriver
       ,ct.outsourcedvehicle
       ,ct.totaloriginalamount0
       ,ct.totaloriginalamount3
       ,ct.totaloriginalamount
       ,ct.totalamount0
       ,ct.totalamount3
       ,ct.totalamount
       ,crd.FullName AS CreatedName
       ,mdf.FullName AS ModifiedName
FROM b30statsdocitem ct
LEFT JOIN b00docstatus doc ON ct.docstatus = doc.docstatuskey
LEFT JOIN b20customer cust ON ct.customerid = cust.id
LEFT JOIN b20factory fac ON ct.factoryid = fac.id
LEFT JOIN b20machine machine ON ct.machineid = machine.id
LEFT JOIN b20hrmshift hrmshift ON ct.shiftid = hrmshift.id
LEFT JOIN b20employee empl ON ct.employeeid = empl.id
LEFT JOIN b20employee empl2 ON ct.employeeid2 = empl2.id
LEFT JOIN b30statsdoc w ON w.statsdocid::text = ct.receiptstatsdocid_wo::text
LEFT JOIN b30statsdoc w1 ON w1.statsdocid::text = ct.statsdocid_wo::text
LEFT JOIN b20warehouse rw ON rw.id = ct.receiptwarehouseid
LEFT JOIN b20warehouse wh ON wh.id = ct.warehouseid
LEFT JOIN b20employee emp ON ct.managerid = emp.id
LEFT JOIN b20vehicle vhc ON ct.vehicleid = vhc.id
LEFT JOIN dbo.B00UserList AS crd ON crd.Id = ct.CreatedBy
LEFT JOIN dbo.B00UserList AS mdf ON mdf.Id = ct.ModifiedBy
