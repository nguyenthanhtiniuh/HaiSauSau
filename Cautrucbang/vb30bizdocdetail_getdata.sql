-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- DROP VIEW IF EXISTS dbo.vb30bizdocdetail_getdata;

CREATE OR REPLACE VIEW dbo.vb30bizdocdetail_getdata AS
SELECT doc.id
       ,0::boolean AS isgroup
       ,'-1'::integer AS parentid
       ,detail.bizdocid
       ,detail.rowid
       ,detail.builtinorder
       ,doc.branchcode
       ,dmct.nh_ct AS docgroup
       ,doc.parentbizdocid
       ,doc.parentbizdocid1
       ,doc.doccode
       ,doc.docno
       ,doc.docdate
       ,doc.description
       ,doc.address
       ,CASE WHEN COALESCE(detail.description,''::character varying)::text <> ''::text THEN
    detail.description
ELSE
    dmvt.name
END AS description0
       ,doc.freighttermscode
       ,doc.currencycode
       ,doc.exchangerate
       ,doc.customerid
       ,doc.employeeid
       ,doc.territoryid
       ,doc.deptid
       ,doc.paymenttype
       ,detail.factoryid
       ,detail.machineid
       ,detail.warehouseid
       ,detail.productid
       ,detail.purchaseemployeeid
       ,doc.saleschannelid
       ,doc.paymenttermscode
       ,doc.fobpointcode
       ,doc.portofloading
       ,doc.shipviacode
       ,''::character varying(16) AS bizdocid_prs
       ,''::character varying(16) AS bizdocid_pq
       ,detail.bizdocid_po
       ,detail.bizdocid_so
       ,detail.bizdocid_pr
       ,detail.bizdocid_ar
       ,detail.rowid_atchpurchase
       ,detail.stt_hd
       ,detail.stt_nm
       ,detail.rowid_sum
       ,detail.spec
       ,detail.itemid
       ,detail.unit
       ,detail.quantity
       ,detail.quantity9
       ,detail.convertrate9
       ,detail.requiredquantity
       ,detail.unitcost
       ,detail.originalunitcost
       ,detail.amount
       ,detail.originalamount
       ,detail.amount3
       ,detail.originalamount3
       ,detail.amount9
       ,detail.originalamount9
       ,detail.settlementamount
       ,dmvt.code AS itemcode
       ,COALESCE(dmvt.name,''::character varying) AS itemname
       ,COALESCE(dmvt.unit,''::character varying) AS unit_dmvt
       ,detail.estimatedtimedelivery
       ,detail.mfgleadtime
       ,detail.taxcode
       ,COALESCE(thue.rate,0::numeric) AS taxrate
       ,COALESCE(thue.type::integer,1) AS taxtype
       ,COALESCE(thue.priceincludetax::integer,0) AS priceincludetax
       ,detail.jobid
       ,detail.remark
       ,doc.closed
       ,0::smallint AS finished
       ,doc.docstatus
       ,doc.isactive
       ,status.postgl
       ,status.postsl
       ,status.iscancelled
       ,doc.ordertypeid
       ,doc.handoverdate
       ,doc.transtype
       ,detail.crmtransid
       ,detail.id AS id_detail
       ,detail.parentrowid
       ,detail.createdby
       ,detail.createdat
       ,detail.modifiedby
       ,detail.modifiedat
       ,detail."timestamp"
       ,0::numeric(16,5) AS transferedquantity
       ,0 AS ishold
       ,COALESCE(detail.estimatedtimedelivery,doc.docdate::timestamp WITHOUT time zone)::date AS docdate0
       ,detail.rowid_po
       ,detail.bizdocid_rc
       ,detail.bizdocid_rr
       ,detail.statsdocid_sn
FROM b30bizdocdetail detail
JOIN b30bizdoc doc ON detail.bizdocid::text = doc.bizdocid::text
LEFT JOIN b20item dmvt ON detail.itemid = dmvt.id
LEFT JOIN b00docstatus status ON doc.docstatus = status.docstatuskey
LEFT JOIN b00dmct dmct ON doc.doccode::text = dmct.ma_ct::text
LEFT JOIN b20tax thue ON detail.taxcode::text = thue.code::text;
