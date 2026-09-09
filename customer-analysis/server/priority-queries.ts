// GENERATED FILE — do not edit by hand.
// Extracted verbatim from sync-operational-query.py / sync-financial-query.py so the live
// dashboard and the sync scripts cannot drift apart. ORDER BY is stripped (these are wrapped
// as subqueries) and the TOP cap is applied by the caller.
// Regenerate: python scripts/gen-priority-queries.py

/** תעודות משלוח (type D) המקושרות לקריאות שירות (type Q) */
export const OPERATIONAL_SQL = String.raw`
SELECT
    DOCUMENTS.DOCNO                  AS [תעודת משלוח]
  , FORMAT(DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך תעודת משלוח]
  , CUSTOMERS.CUSTNAME               AS [מספר לקוח]
  , CUSTOMERS.CUSTDES                AS [שם לקוח]
  , CUSTOMERS.MBA_NOINVOICE          AS [ללא חשבונית לפריט]
  , AGENTS.AGENTCODE                 AS [מספר סוכן]
  , AGENTS.AGENTNAME                 AS [שם סוכן]
  , CUSTOMERS1.CUSTNAME              AS [מספר לקוח מרכז]
  , CUSTOMERS1.CUSTDES               AS [שם לקוח מרכז]
  , ZONES.ZONECODE                   AS [קוד אזור]
  , ZONES.ZONEDES                    AS [תאור אזור]
  , CTYPE.CTYPECODE                  AS [קוד סוג לקוח]
  , CTYPE.CTYPENAME                  AS [תאור סוג לקוח]
  , CTYPE2.CTYPE2CODE                AS [קוד סיווג נוסף]
  , CTYPE2.CTYPE2NAME                AS [תיאור סיווג נוסף]
  , PART.PARTNAME                    AS [מקט]
  , PART.PARTDES                     AS [תאור מקט]
  , PART.MBA_PARTSET                 AS [מקט סט]
  , TRANSORDER6.MBA_PARTSET          AS [מקט סט קליטה]
  , TRANSORDER.TQUANT/1000           AS [כמות]
  , CASE WHEN (TRANSORDER6.MBA_PARTSET = 'Y') THEN (TRANSORDER.TQUANT/1000) ELSE 1 END AS [כמות מחושבת]
  , FAMILY.FAMILYNAME                AS [קוד משפחת מוצר]
  , FAMILY.FAMILYDES                 AS [שם משפחת מוצר]
  , DEPT.DEPTNAME                    AS [מספר מחלקה]
  , DEPT.DEPTDES                     AS [שם מחלקה]
  , PARTPRICE.PRICE                  AS [מחיר מחירון]
  , DOCUMENTS_Q.DOCNO                AS [קריאת שרות]
  , SERNUMBERS.FREE1                 AS [מספר סידורי]
  , FORMAT(DATEADD(minute, TRANSORDER_QW.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך הכיול]
  , USERS.USERNAME                   AS [שם כייל]

  FROM amaba.dbo.DOCUMENTS
  INNER JOIN amaba.dbo.CUSTOMERS       ON (DOCUMENTS.CUST = CUSTOMERS.CUST)
  INNER JOIN amaba.dbo.TRANSORDER      ON (DOCUMENTS.DOC = TRANSORDER.DOC)
  INNER JOIN amaba.dbo.PART            ON (TRANSORDER.PART = PART.PART)
  INNER JOIN amaba.dbo.FAMILY          ON (PART.FAMILY = FAMILY.FAMILY)
  LEFT  JOIN amaba.dbo.MBA_PART        ON (PART.PART = MBA_PART.PART)
  INNER JOIN amaba.dbo.AGENTS          ON (CUSTOMERS.AGENT = AGENTS.AGENT)
  INNER JOIN amaba.dbo.CUSTOMERS AS CUSTOMERS1 ON (CUSTOMERS.MCUST = CUSTOMERS1.CUST)
  INNER JOIN amaba.dbo.ZONES           ON (CUSTOMERS.ZONE = ZONES.ZONE)
  INNER JOIN amaba.dbo.CTYPE           ON (CUSTOMERS.CTYPE = CTYPE.CTYPE)
  INNER JOIN amaba.dbo.CTYPE2          ON (CUSTOMERS.CTYPE2 = CTYPE2.CTYPE2)
  LEFT  JOIN amaba.dbo.DEPT            ON (MBA_PART.DEPT = DEPT.DEPT)
  LEFT  JOIN amaba.dbo.PARTPRICE       ON (PART.PART = PARTPRICE.PART
                                           AND PARTPRICE.QUANT = 1000
                                           AND PARTPRICE.PLIST = -1
                                           AND PARTPRICE.PLDATE = (
                                             SELECT amaba.dbo.PRICELISTDATE.PLDATE
                                             FROM   amaba.dbo.PRICELISTDATE
                                             WHERE  PRICELISTDATE.PLIST = -1
                                             AND    PRICELISTDATE.VALID = 'Y'))
  LEFT  JOIN amaba.dbo.SERNTRANS       ON (TRANSORDER.DOC  = SERNTRANS.DOC
                                           AND TRANSORDER.TYPE  = SERNTRANS.TYPE
                                           AND TRANSORDER.KLINE = SERNTRANS.KLINE)
  LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL ON (SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
                                           AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
                                           AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
                                           AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN)
  LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q ON (MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLS       ON (DOCUMENTS_Q.DOC = SERVCALLS.DOC)
  LEFT  JOIN amaba.dbo.SERNUMBERS      ON (SERVCALLS.SERN  = SERNUMBERS.SERN)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER_QW ON (DOCUMENTS_Q.DOC = TRANSORDER_QW.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLITEMS   ON (TRANSORDER_QW.TRANS = SERVCALLITEMS.TRANS)
  LEFT  JOIN system.dbo.USERS          ON (SERVCALLITEMS.MBA_TECHNICIAN = USERS.T$USER)
  LEFT  JOIN amaba.dbo.MBA_TRANSORDER  ON (TRANSORDER.TRANS = MBA_TRANSORDER.TRANS)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER6 ON (MBA_TRANSORDER.NTRANS = TRANSORDER6.TRANS)

  WHERE  DOCUMENTS.TYPE = 'D'
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') >= @dateFrom
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') <= @dateTo
  AND    DOCUMENTS_Q.TYPE = 'Q'
`;

/** חשבוניות ופירוט שורות */
export const FINANCIAL_SQL = String.raw`
SELECT
    INVOICES.IVNUM      AS [חשבונית]
  , FORMAT(DATEADD(minute, INVOICES.IVDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך החשבונית]
  , CUSTOMERS.CUSTNAME  AS [מספר לקוח]
  , CUSTOMERS.CUSTDES   AS [שם לקוח]
  , INVOICEITEMS.KLINE  AS [שורה בחשבונית]
  , INVOICEITEMS.TQUANT/1000  AS [כמות בפירוט החשבונית]
  , CASE
      WHEN (PART.MBA_COSTING = 'Y' AND TRANSORDER6.MBA_PARTSET <> 'Y' AND DOCUMENTS_Q.DOC IS NULL)
        THEN (INVOICEITEMS.TQUANT/1000)
      ELSE
        CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR TRANSORDER6.MBA_PARTSET = 'Y' OR DOCUMENTS_Q.DOC = 0)
          THEN (INVOICEITEMS.TQUANT/1000)
          ELSE 1
        END
    END                 AS [כמות מיוחדת בפירוט חשבונית]
  , PART.PARTNAME       AS [מק"ט]
  , PART.PARTDES        AS [תאור מוצר]
  , PART.MBA_COSTING    AS [לתמחור בלבד]
  , TRANSORDER6.MBA_COSTING  AS [לתמחור בלבד קליטה]
  , PART.MBA_PARTSET    AS [מקט סט?]
  , TRANSORDER6.MBA_PARTSET  AS [מק"ט סט קליטה]
  , CURRENCIES.CODE     AS [מטבע]
  , CURRENCIES.EXCHANGE AS [שער חליפין]
  , INVOICEITEMS.PRICE  AS [מחיר ליחידה]
  , INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE  AS [מחיר ליחידיה (בשקלים)]
  , INVOICEITEMS.TOTPERCENT   AS [הנחה כללית]
  , INVOICEITEMS.T$PERCENT    AS [הנחה לשורה]
  , INVOICEITEMS.PRICE * (100.0 - INVOICEITEMS.T$PERCENT)/100.0  AS [מחיר ליחידה אחרי הנחה]
  , (INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE) * (100.0 - INVOICEITEMS.T$PERCENT)/100.0  AS [מחיר ליחידה אחרי הנחה (בשקלים)]
  , INVOICEITEMS.QPRICE AS [סה"כ מחיר]
  , INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE  AS [סהכ מחיר (בשקלים)]
  , INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100)  AS [סהכ מחיר לשורה כולל הנחה כללית]
  , (INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100)  AS [סהכ לשורה כולל הנחה כללית (בשקלים)]
  , (INVOICEITEMS.PRICE * (100.0 - INVOICEITEMS.T$PERCENT)/100.0) * (100 - INVOICEITEMS.TOTPERCENT)/100.0  AS [מחיר ליחידה אחרי כל ההנחות]
  , ((INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE) * (100.0 - INVOICEITEMS.T$PERCENT)/100.0) * (100 - INVOICEITEMS.TOTPERCENT)/100.0  AS [מחיר ליחידה אחרי כל ההנחות (בשקלים)]
  , CASE
      WHEN (INVOICEITEMS.TQUANT/1000 = (CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR DOCUMENTS_Q.DOC = 0 OR DOCUMENTS_Q.DOC IS NULL) THEN (INVOICEITEMS.TQUANT/1000) ELSE 1 END))
        THEN (INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100))
      ELSE ((INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100)) / ABS(INVOICEITEMS.TQUANT/1000))
    END  AS [סהכ לשורה בחשבונית כולל חריגים]
  , CASE
      WHEN (INVOICEITEMS.TQUANT/1000 = (CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR TRANSORDER6.MBA_PARTSET = 'Y' OR DOCUMENTS_Q.DOC = 0 OR DOCUMENTS_Q.DOC IS NULL) THEN (INVOICEITEMS.TQUANT/1000) ELSE 1 END))
        THEN ((INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100))
      ELSE (((INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100)) / ABS(INVOICEITEMS.TQUANT/1000))
    END  AS [סהכ לשורה בחשבונית כולל חריגים (בשקלים)]
  , DOCUMENTS_Q.DOC     AS [ק.ש]
  , INVOICES.DISPRICE   AS [סהכ כותרת]
  , INVOICES.DISPRICE * CURRENCIES.EXCHANGE  AS [סהכ כותרת (בשקלים)]
  , DOCUMENTS.DOCNO     AS [תעודת משלוח]
  , PART.MBA_OUTCALIB   AS [כיול חוץ]
  , PART.MBA_INCALIB    AS [כיול פנים]
  , FAMILY.FAMILYNAME   AS [קוד משפחת מוצר]
  , FAMILY.FAMILYDES    AS [שם משפחת מוצר]
  , DEPT.DEPTNAME       AS [מספר מחלקה]
  , DEPT.DEPTDES        AS [שם מחלקה]
  , PARTPRICE.PRICE     AS [מחיר מחירון בסיס]
  , AGENTS.AGENTCODE    AS [מספר סוכן]
  , AGENTS.AGENTNAME    AS [שם סוכן]
  , CUSTOMERS1.CUSTNAME AS [מספר לקוח מרכז]
  , CUSTOMERS1.CUSTDES  AS [שם לקוח מרכז]
  , ZONES.ZONECODE      AS [קוד אזור]
  , ZONES.ZONEDES       AS [תאור אזור]
  , CTYPE.CTYPECODE     AS [קוד סוג לקוח]
  , CTYPE.CTYPENAME     AS [תאור סוג לקוח]
  , CTYPE2.CTYPE2CODE   AS [קוד סיווג נוסף ללקוח]
  , CTYPE2.CTYPE2NAME   AS [תיאור סיווג נוסף ללקוח]
  , DOCUMENTS_Q.DOCNO   AS [קריאת שרות]
  , SERNUMBERS.FREE1    AS [מספר סידורי]
  , FORMAT(DATEADD(minute, TRANSORDER_QW.CURDATE, '01/01/1988'), 'dd/MM/yy')  AS [תאריך הכיול]
  , USERS.USERNAME      AS [שם כייל בעברית]

FROM amaba.dbo.INVOICES
INNER JOIN amaba.dbo.FNCTRANS      ON (FNCTRANS.FNCTRANS = INVOICES.FNCTRANS)
INNER JOIN amaba.dbo.CUSTOMERS     ON (CUSTOMERS.CUST = INVOICES.CUST)
INNER JOIN amaba.dbo.CURRENCIES    ON (CURRENCIES.CURRENCY = INVOICES.CURRENCY)
LEFT  JOIN amaba.dbo.CURREGITEMS   ON (CURREGITEMS.CURRENCY = INVOICES.CURRENCY
                                    AND CURREGITEMS.CURDATE = CASE WHEN (INVOICES.CURRENCY = -1) THEN 0 ELSE INVOICES.IVDATE END)
INNER JOIN amaba.dbo.INVOICEITEMS  ON (INVOICEITEMS.IV = INVOICES.IV)
INNER JOIN amaba.dbo.PART          ON (INVOICEITEMS.PART = PART.PART)
INNER JOIN amaba.dbo.FAMILY        ON (PART.FAMILY = FAMILY.FAMILY)
LEFT  JOIN amaba.dbo.MBA_PART      ON (PART.PART = MBA_PART.PART)
INNER JOIN amaba.dbo.DEPT          ON (MBA_PART.DEPT = DEPT.DEPT)
LEFT  JOIN amaba.dbo.PARTPRICE     ON (PART.PART = PARTPRICE.PART
                                    AND PARTPRICE.QUANT = 1000
                                    AND PARTPRICE.PLIST = -1
                                    AND PARTPRICE.PLDATE = (
                                      SELECT amaba.dbo.PRICELISTDATE.PLDATE
                                      FROM   amaba.dbo.PRICELISTDATE
                                      WHERE  amaba.dbo.PRICELISTDATE.PLIST = -1
                                      AND    amaba.dbo.PRICELISTDATE.VALID = 'Y'))
INNER JOIN amaba.dbo.TRANSORDER    ON (INVOICEITEMS.TRANS = TRANSORDER.TRANS)
INNER JOIN amaba.dbo.DOCUMENTS     ON (TRANSORDER.DOC = DOCUMENTS.DOC)
INNER JOIN amaba.dbo.AGENTS        ON (CUSTOMERS.AGENT = AGENTS.AGENT)
INNER JOIN amaba.dbo.CUSTOMERS AS CUSTOMERS1 ON (CUSTOMERS.MCUST = CUSTOMERS1.CUST)
INNER JOIN amaba.dbo.ZONES         ON (CUSTOMERS.ZONE = ZONES.ZONE)
INNER JOIN amaba.dbo.CTYPE         ON (CUSTOMERS.CTYPE = CTYPE.CTYPE)
INNER JOIN amaba.dbo.CTYPE2        ON (CUSTOMERS.CTYPE2 = CTYPE2.CTYPE2)
LEFT  JOIN amaba.dbo.SERNTRANS     ON (TRANSORDER.DOC   = SERNTRANS.DOC
                                    AND TRANSORDER.TYPE  = SERNTRANS.TYPE
                                    AND TRANSORDER.KLINE = SERNTRANS.KLINE)
LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL ON (SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
                                    AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
                                    AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
                                    AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN)
LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q ON (MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC)
LEFT  JOIN amaba.dbo.SERVCALLS     ON (DOCUMENTS_Q.DOC = SERVCALLS.DOC)
LEFT  JOIN amaba.dbo.SERNUMBERS    ON (SERVCALLS.SERN  = SERNUMBERS.SERN)
LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER_QW ON (DOCUMENTS_Q.DOC = TRANSORDER_QW.DOC
                                    AND TRANSORDER_QW.TYPE = 'Q')
LEFT  JOIN amaba.dbo.SERVCALLITEMS ON (TRANSORDER_QW.TRANS = SERVCALLITEMS.TRANS)
LEFT  JOIN system.dbo.USERS        ON (SERVCALLITEMS.MBA_TECHNICIAN = USERS.T$USER)
LEFT  JOIN amaba.dbo.MBA_TRANSORDER ON (TRANSORDER.TRANS = MBA_TRANSORDER.TRANS)
LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER6 ON (MBA_TRANSORDER.NTRANS = TRANSORDER6.TRANS)

WHERE (INVOICES.TYPE = 'C' OR INVOICES.TYPE = 'F')
AND   DATEADD(minute, INVOICES.IVDATE, '01/01/1988') >= @dateFrom
AND   DATEADD(minute, INVOICES.IVDATE, '01/01/1988') <= @dateTo
AND   INVOICES.IVNUM NOT LIKE 'T%'
AND   INVOICEITEMS.TQUANT <> 0
`;
