-- Uncomment the DROP to remove columns or change their names, order or types. DROP removes the GRANTs on the view.
-- 
--DROP VIEW IF EXISTS dbo.vb00command;

CREATE OR REPLACE VIEW dbo.vb00command AS
WITH cte_Logging AS (SELECT DISTINCT commandkey,tablename FROM B00Logging WHERE isactive = TRUE AND commandkey IS NOT NULL),
cte_dmct AS (SELECT ma_ct FROM dbo.b00dmct dmct GROUP BY dmct.ma_ct)
,cte_layout AS (SELECT * FROM dbo.b00layout tab    )

SELECT c.id,
    c.parentid,
    c.isgroup,
    c.commandkey,
    c.text,
    c.text_english,
    c.text_french,
    c.text_japanese,
    c.text_chinese,
    c.text_korean,
    c.text_custom,
    c.dllname,
    c.classname,
    c.ctorargs,
    c.methodname,
    c.invokeargs,
    c.commandtype,
    c.defaultenabledstate,
    c.shortkeytext,
    c.shortkeyvalue,
    c.image,
    c.commandclass,
    c.altercommandclass,
    c.customflags,
    c.categoryflags,
    c.isactive,
    c.createdby,
    c.createdat,
    c.modifiedby,
    c.modifiedat,
    crd.fullname AS createdname,
    mdf.fullname AS modifiedname
    ,t.TableName,dmct.ma_ct
    ,layout.modifiedat AS layoutmodifiedat
    ,layout.modifiedby AS layoutmodifiedby
FROM b00command c
LEFT JOIN b00userlist crd ON crd.id = c.createdby
LEFT JOIN b00userlist mdf ON mdf.id = c.modifiedby
LEFT OUTER JOIN LATERAL 
(
    SELECT *
    FROM cte_Logging t2
    WHERE t2.commandkey = c.commandkey
    LIMIT 1
) AS t ON TRUE

LEFT OUTER JOIN LATERAL 
(
    SELECT *
    FROM cte_dmct t2
    WHERE t2.ma_ct = c.commandkey
    LIMIT 1
) AS dmct ON TRUE


LEFT OUTER JOIN LATERAL 
(
    SELECT *
    FROM cte_layout t2
    WHERE t2.formname = c.commandkey
    ORDER BY modifiedat DESC 
    LIMIT 1 
) AS layout ON TRUE
;
 
SELECT * FROM vb00command
--SELECT * FROM B00Logging

-- SELECT count(commandkey),commandkey
-- FROM vb00command
-- GROUP BY commandkey
-- ORDER BY count(commandkey) DESC 