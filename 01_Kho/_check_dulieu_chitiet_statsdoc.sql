SELECT statsdocid,
    rowid,
    itemid,
    quantity9,
    bizdocid_do,
    rowid_po
FROM b30statsstockledger sc
WHERE (BranchCode = 'A01') AND (DocDate BETWEEN '2026-11-01' AND '2026-11-22') AND (DocCode = 'SN');

SELECT statsdocid,
    rowid,
    itemid,
    quantity9,
    bizdocid_do,
    rowid_po
FROM vB30StatsStockLedger_Post
WHERE statsdocid = 'A010000127SN';

SELECT statsdocid,
    rowid,
    itemid,
    quantity9,
    bizdocid_do,
    rowid_po
FROM b30statsdocinventory
WHERE statsdocid = 'A010000127SN';
