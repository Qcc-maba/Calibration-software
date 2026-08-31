/*
    dbo.CrmOrderAttachments                                                            MBA-930
    ---------------------------------------------------------------------------------------------
    Local cache of the documents Priority hangs off an order — the "נספחים" sub-form of
    "אישור הזמנה". Filled by dbo.RefreshOrderAttachmentsCache over the existing linked server
    [31.168.173.93], read by dbo.GetOrderAttachmentsByOrder and dbo.GetOrderAttachmentCounts.

    Same reasoning as dbo.CrmCatalogText / CrmDeviceText / CrmOrderInstructions: the screens are
    served from here so no page request ever pays for a linked-server round-trip.

    Source (measured on PROD, 30/08/2026):

        amaba.dbo.EXTFILES  WHERE TYPE = 'O'   ->   IV = ORDERS.ORD = OrderWorkPlans.OrderSourceId

        13,237 orders carry attachments, 15,326 files. Priority is live, so both numbers drift
        upward through the day — they are a sanity check, not a constant.

    THE KEY IS (IV, EXTFILENUM), NOT (IV, LINE)
    -------------------------------------------
    This cost a failed run, so it is written down. EXTFILENUM is the file's sequence within the
    order (1..12). LINE is NOT a file index — it takes only 3 distinct values across the whole
    table and repeats within an order: order 106663 has two files, both LINE = 0, distinguished
    only by EXTFILENUM 1 and 2.

        distinct (IV, EXTFILENUM) = 15,326 = row count   <- unique
        distinct (IV, LINE)       = 13,239               <- NOT unique

    Most orders carry one file, but the tail is long: 215 orders have 3, 39 have 4, 8 have 5, and
    one has 12. Any UI that assumes "up to 4" will silently drop documents.

    Two properties of the source that this table is shaped around:

    * FilePath is Priority's own EXTFILENAME, a UNC path under
      \\maba-priority\Priority\Attachments\Documents\YYYY\MM\. The source column is varchar(80)
      and Priority TRUNCATES anything longer, so 35 rows are cut mid-name and can never be
      opened. IsPathTruncated marks them; the UI must show them as an error rather than hide
      them, otherwise a calibrator has no way to know a document exists.

    * Description is EXTFILEDES with its digit and Latin runs un-reversed. Priority stores this
      text in visual order: Hebrew reads correctly but Latin and digits come out backwards
      ("...redrOesahc"). DescriptionRaw keeps Priority's text verbatim so nothing is lost.
      Same defect and same repair as dbo.CrmDeviceDescription.


    EXTFILES.FILESIZE IS NOT A FILE SIZE — deliberately not cached
    --------------------------------------------------------------
    15,225 of the 15,326 rows report 74, which is the character length of EXTFILENAME, not the
    file. 29 report 81, 20 report 0, and only ~46 carry a plausible byte count. Measured against
    disk: a row reporting 74 is a 522,752-byte .msg. The column is meaningless, so it is not
    stored — a wrong size rendered in the UI is worse than no size. The conversion layer stats
    the file itself, where the truth is.

    99.3% of the files are .msg (Outlook messages) and only 62 are already PDF, which is why
    FileExtension is stored — the conversion layer keys off it.
*/
IF OBJECT_ID('dbo.CrmOrderAttachments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrmOrderAttachments
    (
        ORD              INT            NOT NULL,  /* = OrderWorkPlans.OrderSourceId          */
        EXTFILENUM       INT            NOT NULL,  /* file sequence within the order, 1..12    */
        LINE             INT            NULL,      /* Priority's own; NOT a file index         */
        FilePath         NVARCHAR(200)  NULL,      /* source is varchar(80); widened for safety */
        FileExtension    NVARCHAR(20)   NULL,      /* lower case, no dot                        */
        Description      NVARCHAR(200)  NULL,      /* un-reversed, for display                  */
        DescriptionRaw   NVARCHAR(200)  NULL,      /* Priority's text, verbatim                 */
        IsPathTruncated  BIT            NOT NULL
            CONSTRAINT DF_CrmOrderAttachments_IsPathTruncated DEFAULT (0),
        FetchedAt        DATETIME2(3)   NOT NULL
            CONSTRAINT DF_CrmOrderAttachments_FetchedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CrmOrderAttachments PRIMARY KEY CLUSTERED (ORD, EXTFILENUM)
    );

    /* The grid asks "does this order have any files" for a page of orders at a time. */
    CREATE NONCLUSTERED INDEX IX_CrmOrderAttachments_ORD
        ON dbo.CrmOrderAttachments (ORD)
        INCLUDE (IsPathTruncated);
END
GO
