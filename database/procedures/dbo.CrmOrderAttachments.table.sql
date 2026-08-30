/*
    dbo.CrmOrderAttachments                                                            MBA-930
    ---------------------------------------------------------------------------------------------
    Local cache of the documents Priority hangs off an order — the "נספחים" sub-form of
    "אישור הזמנה". Filled by dbo.RefreshOrderAttachmentsCache over the existing linked server
    [31.168.173.93], read by dbo.GetOrderAttachmentsByOrder and dbo.GetOrderAttachmentCounts.

    Same reasoning as dbo.CrmCatalogText / CrmDeviceText / CrmOrderInstructions: the screens are
    served from here so no page request ever pays for a linked-server round-trip.

    Source (verified on PROD, 30/08/2026):

        amaba.dbo.EXTFILES  WHERE TYPE = 'O'   ->   IV = ORDERS.ORD = OrderWorkPlans.OrderSourceId

        13,175 orders carry attachments, 15,251 files, up to 4 per order (LINE 0-3).

    Two properties of the source that this table is shaped around:

    * FilePath is Priority's own EXTFILENAME, a UNC path under
      \\maba-priority\Priority\Attachments\Documents\YYYY\MM\. The source column is varchar(80)
      and Priority TRUNCATES anything longer, so 35 of the 15,251 rows are cut mid-name and can
      never be opened. IsPathTruncated marks them; the UI must show them as an error rather than
      hide them, otherwise a calibrator has no way to know a document exists.

    * Description is EXTFILEDES with its digit and Latin runs un-reversed. Priority stores this
      text in visual order: Hebrew reads correctly but Latin and digits come out backwards
      ("...redrOesahc"). DescriptionRaw keeps Priority's text verbatim so nothing is lost.
      Same defect and same repair as dbo.CrmDeviceDescription.

    99.3% of the files are .msg (Outlook messages) and only 62 are already PDF, which is why
    FileExtension is stored and indexed — the conversion layer keys off it.
*/
IF OBJECT_ID('dbo.CrmOrderAttachments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrmOrderAttachments
    (
        ORD              INT            NOT NULL,  /* = OrderWorkPlans.OrderSourceId */
        LINE             INT            NOT NULL,  /* 0-3, Priority's own ordering  */
        EXTFILENUM       INT            NULL,
        FilePath         NVARCHAR(200)  NULL,      /* source is varchar(80); widened for safety */
        FileExtension    NVARCHAR(20)   NULL,      /* lower case, no dot                        */
        Description      NVARCHAR(200)  NULL,      /* un-reversed, for display                  */
        DescriptionRaw   NVARCHAR(200)  NULL,      /* Priority's text, verbatim                 */
        FileSize         INT            NULL,
        IsPathTruncated  BIT            NOT NULL
            CONSTRAINT DF_CrmOrderAttachments_IsPathTruncated DEFAULT (0),
        FetchedAt        DATETIME2(3)   NOT NULL
            CONSTRAINT DF_CrmOrderAttachments_FetchedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CrmOrderAttachments PRIMARY KEY CLUSTERED (ORD, LINE)
    );

    /* The grid asks "does this order have any files" for a page of orders at a time. */
    CREATE NONCLUSTERED INDEX IX_CrmOrderAttachments_ORD
        ON dbo.CrmOrderAttachments (ORD)
        INCLUDE (IsPathTruncated);
END
GO
