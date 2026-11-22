-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- DROP VIEW IF EXISTS dbo.vb30bizdoc_explore;

CREATE OR REPLACE VIEW dbo.vb30bizdoc_explore AS
SELECT bizdoc.id
       ,bizdoc.parentid
       ,bizdoc.branchcode
       ,bizdoc.bizdocid
       ,bizdoc.parentbizdocid
       ,bizdoc.doccode
       ,bizdoc.costcentreid
       ,bizdoc.docno
       ,bizdoc.docdate
       ,bizdoc.currencycode
       ,bizdoc.contactid
       ,bizdoc.contactperson
       ,bizdoc.exchangerate
       ,bizdoc.customerid
       ,dmdt.code AS customercode
       ,bizdoc.employeeid
       ,bizdoc.employeeid2
       ,bizdoc.address
       ,bizdoc.description
       ,bizdoc.transcode
       ,bizdoc.paymenttermscode
       ,paymentterms.name AS paymentterms
       ,bizdoc.issinglerowindetail
       ,bizdoc.shipviacode
       ,shipvia.name AS shipvia
       ,bizdoc.portofloading
       ,bizdoc.handoverdate
       ,bizdoc.conditionpayment
       ,bizdoc.conditionwarranty
       ,bizdoc.fobpointcode
       ,fobpoint.name AS fob
       ,bizdoc.freighttermscode
       ,fobpoint.name AS freighttermsname
       ,employee.code AS employeecode
       ,employee.name AS employeename
       ,employee2.name AS employeename2
       ,dmdt.name AS customername
       ,dmdt.taxregno AS ma_so_thue
       ,bizdoc.totaloriginalamount0
       ,bizdoc.totalamount0
       ,bizdoc.totaloriginalamount3
       ,bizdoc.totalamount3
       ,bizdoc.totaloriginalamount
       ,bizdoc.totalamount
       ,bizdoc.isactive
       ,bizdoc.effectivedate
       ,bizdoc.finisheddate
       ,bizdoc.loanamount
       ,bizdoc.loanoriginalamount
       ,bizdoc.account
       ,bizdoc.bizdocid_lc
       ,bizdoc.loancontracttype
       ,bizdoc.duedate
       ,CASE WHEN bizdoc.duedate <> 0 THEN
    bizdoc.duedate::double precision * '1 day'::interval + bizdoc.docdate
ELSE
    NULL::timestamp WITHOUT time zone
END AS duedate_tt
       ,lct.name AS loancontracttypename
       ,bizdoc.closed
       ,bizdoc.closeddate
       ,bizdoc.rowid_docprocess
       ,bizdoc.docprocessid
       ,bizdoc.territoryid
       ,territory.code AS territorycode
       ,territory.name AS territoryname
       ,bizdoc.discounttypecode
       ,bizdoc.discountpromocode
       ,(((rtrim(bizdoc.docno::text) || ' - '::text) || bizdoc.description::text))::character varying(128) AS docinfo
       ,bizdoc.docstatus
       ,doc.lock
       ,doc.postgl
       ,doc.postsl
       ,doc.iscancelled
       ,bizdoc.createdby
       ,bizdoc.createdat
       ,bizdoc.modifiedby
       ,bizdoc.modifiedat
       ,bizdoc.deptid
       ,dept.code AS deptcode
       ,dept.name AS deptname
       ,COALESCE(bizdoc.isdataimported::integer,0) AS isdataimported
       ,bizdoc.bizdocid_cr
       ,bizdoc.ordertypeid
       ,bizdoc.transtype
       ,classpr.name AS transtypename
       ,bizdoc.itemcatgid
       ,beneficiary.name AS beneficiaryname
       ,bizdoc.beneficiarycustomerid

       ,(((rtrim(cr.docno::text) || ' - '::text) || cr.description::text))::character varying(84) AS docinfo_cr
       ,bizdoc.saleschannelid
       ,sc.code AS saleschannelcode
       ,sc.name AS saleschannelname
       ,bizdoc.approvalstatus
       ,bizdoc.effectiveyear
       ,bizdoc.expirationdate
       ,bizdoc.customerkind
       ,customerkind.name AS customerkindname
       ,bizdoc.pricekind
       ,pricekind.name AS pricekindname
       ,bizdoc.scopetype
       ,scopetype.name AS scopetypename
       ,bizdoc.discounttype
       ,discounttype.name AS discounttypename
       ,bizdoc.classify
       ,classify.name AS classifyname
       ,bizdoc.bizdocid_rr
       ,bizdoc.bizdocid_do
       ,bizdoc.statsdocid_sn
       ,bizdoc.manufacturerid
       ,mfr.code AS manufacturercode
       ,mfr.name AS manufacturername
       ,bizdoc.bizdocid_so
       ,so.docno AS docno_so
       ,bizdoc.driver
       ,bizdoc.vehicleid
       ,vhc.code AS vehiclecode
       ,bizdoc.outsourceddriver
       ,bizdoc.outsourcedvehicle
       ,bizdoc.totalquantity
       ,crd.FullName AS CreatedName
       ,mdf.FullName AS ModifiedName
FROM b30bizdoc bizdoc
LEFT JOIN b20employee employee ON bizdoc.employeeid = employee.id
LEFT JOIN b20employee employee2 ON bizdoc.employeeid2 = employee2.id
LEFT JOIN b20customer dmdt ON bizdoc.customerid = dmdt.id
LEFT JOIN b20customer beneficiary ON bizdoc.beneficiarycustomerid = beneficiary.id
LEFT JOIN b20territory territory ON bizdoc.territoryid = territory.id
LEFT JOIN b00docstatus doc ON bizdoc.docstatus = doc.docstatuskey
LEFT JOIN b20dept dept ON dept.id = bizdoc.deptid
LEFT JOIN b20vehicle vhc ON bizdoc.vehicleid = vhc.id
LEFT JOIN b20class fobpoint ON bizdoc.fobpointcode::text = fobpoint.code::text AND fobpoint.parentcode::text = 'FOB_POINT'::text
LEFT JOIN b20class paymentterms ON bizdoc.paymenttermscode::text = paymentterms.code::text AND paymentterms.parentcode::text = 'PAYMENT_TERMS'::text
LEFT JOIN b20class shipvia ON bizdoc.shipviacode::text = shipvia.code::text AND shipvia.parentcode::text = 'SHIP_VIA'::text
LEFT JOIN b20class freightterms ON bizdoc.freighttermscode::text = freightterms.code::text AND freightterms.parentcode::text = 'FREIGHT_TERMS'::text
LEFT JOIN b20class lct ON bizdoc.loancontracttype::text = lct.code::text AND lct.parentcode::text = 'LOANCONTRACT_TYPE'::text
LEFT JOIN b20class classpr ON classpr.code::text = bizdoc.transtype::text AND classpr.parentcode::text = 'PRType'::text
LEFT JOIN b30bizdoc cr ON bizdoc.bizdocid_cr::text = cr.bizdocid::text AND cr.doccode::text = 'CR'::text
LEFT JOIN b20saleschannel sc ON sc.id = bizdoc.saleschannelid
LEFT JOIN b20class customerkind ON customerkind.code::text = bizdoc.customerkind::text AND customerkind.parentcode::text = 'CustomerKind'::text
LEFT JOIN b20class pricekind ON pricekind.code::text = bizdoc.pricekind::text AND pricekind.parentcode::text = 'PriceKind'::text
LEFT JOIN b20class scopetype ON scopetype.code::text = bizdoc.scopetype::text AND scopetype.parentcode::text = 'ScopeType'::text
LEFT JOIN b20class discounttype ON discounttype.code::text = bizdoc.discounttype::text AND discounttype.parentcode::text = 'DiscountType'::text
LEFT JOIN b20class classify ON classify.code::text = bizdoc.classify::text AND classify.parentcode::text = 'Classify'::text
LEFT JOIN b20manufacturer mfr ON mfr.id = bizdoc.manufacturerid
LEFT JOIN b30bizdocso so ON bizdoc.bizdocid_so::text = so.bizdocid::text
LEFT JOIN dbo.B00UserList AS crd ON crd.Id = bizdoc.CreatedBy
LEFT JOIN dbo.B00UserList AS mdf ON mdf.Id = bizdoc.ModifiedBy
