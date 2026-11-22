-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- DROP VIEW IF EXISTS dbo.vb30bizdocdetail_getdatapo_item;

CREATE OR REPLACE VIEW dbo.vb30bizdocdetail_getdatapo_item AS
SELECT detail.id
       ,detail.bizdocid
       ,detail.rowid
       ,detail.parentrowid
       ,detail.builtinorder
       ,doc.branchcode
       ,doc.doccode
       ,doc.docstatus
       ,doc.docno
       ,doc.docdate
       ,doc.description
       ,detail.itemid
       ,detail.unit
       ,detail.quantity
       ,detail.quantity9
       ,detail.convertrate9
       ,detail.purchaseunitprice
       ,detail.timediscount
       ,detail.invoiceunitprice
       ,detail.amount9
       ,detail.taxcode
       ,detail.amount3
       ,detail.amount
       ,detail.receiptdate_eo
       ,detail.discountrate_eo
       ,detail.closeddate
       ,detail.ispromotionitem
       ,CASE WHEN detail.speakerbomtype::text = '1'::text THEN
    'Ghi nợ'::character varying WHEN detail.speakerbomtype::text = '2'::text THEN
        'Trả nợ'::character varying
    ELSE
        NULL::character varying
    END AS speakerbomtype
       ,detail.speakerbomcode
       ,detail.remark
       ,detail.bizdocid_prs
       ,doc.customerid
       ,doc.employeeid
       ,doc.deptid
       ,doc.transtype
       ,doc.isactive
       ,doc.id AS id_po
    FROM b30bizdocdetailpo detail
    JOIN b30bizdocpo doc ON detail.bizdocid::text = doc.bizdocid::text
    WHERE doc.docstatus = 4 AND doc.isactive = TRUE AND detail.isactive = TRUE;
