/*
    dbo.RefreshDeviceDescriptions                                                      MBA-666
    ---------------------------------------------------------------------------------------------
    Rebuilds dbo.CrmDeviceDescription from Priority's device description, MBA_DOCLOAD.SERNDES -
    "תאור מכשיר" on the Priority form. 3,000 distinct values over 3.8M device records.

    This is the list a calibrator picks a פריט כיול from. It is NOT the product description
    (PART.PARTDES / OrdersProductType), which is one value per catalogue item: item 110102 reads
    "תנור עד 550C" as a product but covers "תנור שריפה" and "תנור לטיפול תרמי" as devices.

    Two columns, on purpose. DescriptionRaw is Priority's own text, kept verbatim so nothing is
    lost. Description is that text with its digit and Latin runs un-reversed - see
    dbo.fnUnreverseVisualText. NeedsReview flags the rows where the un-reversal cannot be trusted
    without a human: Latin letters, whose case is gone, or several runs, whose order is ambiguous.

    Reading only. Bounded to one aggregated pull, so it does not drag 3.8M rows across the link.
    Safe to re-run; it replaces the table's contents in a transaction.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshDeviceDescriptions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #D;
    SELECT * INTO #D FROM OPENQUERY([31.168.173.93], '
      SELECT SERNDES = LTRIM(RTRIM(dl.SERNDES)),
             Devices = COUNT(*),
             Parts   = COUNT(DISTINCT dl.PART)
      FROM amaba.dbo.MBA_DOCLOAD dl
      WHERE LTRIM(RTRIM(ISNULL(dl.SERNDES, ''''))) <> ''''
      GROUP BY LTRIM(RTRIM(dl.SERNDES))
    ');

    IF NOT EXISTS (SELECT 1 FROM #D)
    BEGIN
        SELECT Descriptions = 0, Note = N'Priority returned nothing - existing rows left alone.';
        RETURN;
    END

    BEGIN TRANSACTION;

        DELETE FROM dbo.CrmDeviceDescription;

        INSERT INTO dbo.CrmDeviceDescription
              (DescriptionRaw, Description, NeedsReview, Devices, Parts, RefreshedAt)
        SELECT LEFT(d.SERNDES, 200),
               LEFT(dbo.fnUnreverseVisualText(d.SERNDES), 200),
               /* what the un-reversal cannot be trusted to get right on its own */
               CAST(CASE WHEN d.SERNDES LIKE N'%[A-Za-z]%'         THEN 1  /* Latin case is lost: MN -> Nm */
                         WHEN d.SERNDES LIKE N'%[0-9]% %[0-9]%'    THEN 1  /* two runs, order is a guess */
                         WHEN d.SERNDES LIKE N'%[0-9]%-%[0-9]%'    THEN 1  /* a range: 05-1.5 is ambiguous */
                         WHEN d.SERNDES LIKE N'%[*]%'              THEN 1  /* ערוצי*21 must read *12 */
                         ELSE 0 END AS BIT),

               d.Devices,
               d.Parts,
               SYSUTCDATETIME()
        FROM #D AS d;

    COMMIT TRANSACTION;

    SELECT Descriptions = COUNT(*),
           SafeAsIs     = SUM(IIF(NeedsReview = 0, 1, 0)),
           NeedsReview  = SUM(IIF(NeedsReview = 1, 1, 0)),
           DeviceRecords= SUM(Devices)
    FROM dbo.CrmDeviceDescription;
END
