/*
    dbo.GetCalibrationItems                                                            MBA-666
    ---------------------------------------------------------------------------------------------
    The list a calibrator picks the "פריט כיול" from.

    MBA-666 asks for the list to come from Priority's "תיאור מכשיר". Three columns could be read
    that way, and MBA-901 settled which:

      DeviceFamily      too coarse - every scale is the single word "מאזניים", and product asked
                        for "מאזניים אנליטיים" / "מאזניים חצי אנליטיים" to be distinguishable.
      PartDescription   the raw Priority value, and unusable: Priority stores it in visual order,
                        so a 100 kg scale reads "מאזניים עד 001 ק'ג" and 1,000 reads "עד 000,1".
                        Putting that on a report would misstate the instrument.
      OrdersProductType what this uses. Our sync already un-reverses it, so the digits are right,
                        and it carries the granularity product wanted.

    What it strips
    --------------
    A product type is a sales line, not a device: "מאזניים עד 100 ק'ג-כיול בהסמכה-באתרכם". The
    device is the part before the commercial tail. The tail is cut at the FIRST of these markers,
    whichever appears earliest:

        בהסמכה · ק.משנה · קבלן משנה · באתרכם · במבא · מכירת ציוד · תיקון · כיול חוזר · כיוון

    Cutting at one fixed separator is not enough - the markers appear with a dash, with a space,
    or with neither, and an earlier attempt keyed only on "-כיול" left the tail attached on 86
    items. After the cut, trailing separators and a dangling "כיול" are peeled off, which is what
    collapses "מאזניים חצי אנליטיים-כיול" and "מאזניים חצי אנליטיים" into one entry rather than
    two.

    Result on STAGE: 586 product types collapse to 460 items. "מאזניים חצי אנליטיים" merges seven
    sales variants, "מאזניים עד 30 ק'ג" merges five.

    Service lines
    -------------
    58 of the 460 are not devices at all - נסיעת טכנאי, הובלה בתשלום, הדרכה, שרותי איכות. They are
    billing lines and product already agreed (MBA-901) they carry no category. @IncludeServiceLines
    defaults to 0 so they stay out of a calibrator's picker; pass 1 if a screen genuinely needs the
    full catalogue.

    @UsedOnly = 1 narrows to items that actually appear on an order, which is almost all of them -
    464 of 465 under the earlier rule - so it is off by default and exists for a screen that wants
    to hide catalogue entries nobody has ever ordered.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationItems
    @Search              NVARCHAR(200) = NULL,
    @IncludeServiceLines BIT           = 0,
    @UsedOnly            BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Marker TABLE (Marker NVARCHAR(40) COLLATE DATABASE_DEFAULT);
    INSERT @Marker VALUES
        (N'בהסמכה'), (N'ק.משנה'), (N'קבלן משנה'), (N'באתרכם'),
        (N'במבא'), (N'מכירת ציוד'), (N'תיקון'), (N'כיול חוזר'), (N'כיוון');

    /* the earliest commercial marker in each product type */
    DROP TABLE IF EXISTS #Cut;
    SELECT pt.OrdersProductTypeId,
           CutAt = MIN(NULLIF(CHARINDEX(m.Marker, pt.OrdersProductTypeName COLLATE DATABASE_DEFAULT), 0))
    INTO #Cut
    FROM dbo.OrdersProductTypes AS pt
    CROSS JOIN @Marker AS m
    GROUP BY pt.OrdersProductTypeId;

    DROP TABLE IF EXISTS #Item;
    SELECT pt.OrdersProductTypeId,
           pt.OrdersProductTypeName AS ProductTypeName,
           CalibrationItem = LTRIM(RTRIM(
               CASE WHEN c.CutAt IS NULL THEN pt.OrdersProductTypeName
                    ELSE LEFT(pt.OrdersProductTypeName, c.CutAt - 1) END))
    INTO #Item
    FROM dbo.OrdersProductTypes AS pt
    JOIN #Cut AS c ON c.OrdersProductTypeId = pt.OrdersProductTypeId;

    /* peel the leftovers: a trailing separator, or a "כיול" the cut left dangling.
       Four passes because a tail can be several of these in a row. */
    DECLARE @Pass INT = 0;
    WHILE @Pass < 4
    BEGIN
        UPDATE #Item
        SET CalibrationItem = LTRIM(RTRIM(
            CASE WHEN RIGHT(CalibrationItem, 1) IN (N'-', N',', N' ')
                   THEN LEFT(CalibrationItem, LEN(CalibrationItem) - 1)
                 WHEN RIGHT(CalibrationItem, 4) = N'כיול'
                   THEN LEFT(CalibrationItem, LEN(CalibrationItem) - 4)
                 ELSE CalibrationItem END));
        SET @Pass += 1;
    END

    DELETE FROM #Item WHERE NULLIF(LTRIM(RTRIM(CalibrationItem)), N'') IS NULL;

    SELECT i.CalibrationItem,
           SalesVariants = COUNT(DISTINCT i.OrdersProductTypeId),
           OrderLines    = COUNT(DISTINCT od.OrderDetailId)
    FROM #Item AS i
    LEFT JOIN dbo.OrderDetails AS od
           ON od.OrdersProductTypeId = i.OrdersProductTypeId
          AND ISNULL(od.IsDeleted, 0) = 0
    WHERE (@Search IS NULL OR i.CalibrationItem LIKE N'%' + @Search + N'%')
      AND (@IncludeServiceLines = 1
           OR NOT (i.CalibrationItem LIKE N'%נסיע%'
                OR i.CalibrationItem LIKE N'%הובלה%'
                OR i.CalibrationItem LIKE N'%הדרכה%'
                OR i.CalibrationItem LIKE N'%שרותי איכות%'
                OR i.CalibrationItem LIKE N'%שירותי איכות%'))
    GROUP BY i.CalibrationItem
    HAVING (@UsedOnly = 0 OR COUNT(DISTINCT od.OrderDetailId) > 0)
    ORDER BY i.CalibrationItem;
END
