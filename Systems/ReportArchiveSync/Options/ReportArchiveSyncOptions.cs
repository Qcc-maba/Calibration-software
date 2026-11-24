namespace Maba.VCT.ReportArchiveSync.Options;

public sealed class ReportArchiveSyncOptions
{
    public const string SectionName = "ReportArchiveSync";

    /// <summary>
    /// UNC root of Priority's Tomax archive. Must be a UNC path, never a mapped drive letter:
    /// drive mappings are per-user and do not exist in the session a Windows service runs in, so
    /// "P:\Tomax\..." resolves to nothing under a service account.
    /// No default (MBA-1028): STAGE and PROD read different Priority servers, and a default would
    /// let a STAGE install that forgot this setting read production's archive. Startup refuses an
    /// empty value.
    /// </summary>
    public string ArchiveRoot { get; set; } = string.Empty;

    /// <summary>Connection string for CalibratorProd / Calibrator. Supplied per environment.</summary>
    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>S3 bucket the web app reads report PDFs from.</summary>
    public string BucketName { get; set; } = string.Empty;

    /// <summary>
    /// AWS region of <see cref="BucketName"/>. Set explicitly rather than left to the SDK's
    /// discovery chain: on a domain server with no AWS profile the default constructor throws
    /// "No RegionEndpoint or ServiceURL configured" at startup.
    /// </summary>
    public string Region { get; set; } = "il-central-1";

    /// <summary>
    /// Only items from this Priority source are processed. 1 = MABA (amaba), 2 = SEPHARM (sepharm).
    /// The two companies keep independent DOC sequences in the same numeric range, so processing
    /// both against one archive would be free to attach one company's report to the other's
    /// device. SEPHARM is deliberately out of scope until its archive layout is confirmed.
    /// </summary>
    public int SourceId { get; set; } = 1;

    /// <summary>
    /// When set, only devices on this order are processed. Operational escape hatch: the normal
    /// batch works newest-first, so piloting one specific customer or order would otherwise mean
    /// grinding through thousands of unrelated items to reach it.
    /// </summary>
    public string? OnlyOrderNumber { get; set; }

    public TimeSpan Interval { get; set; } = TimeSpan.FromHours(1);

    /// <summary>
    /// When true (the default) the service resolves archive files and logs what it would do, but
    /// uploads nothing and writes nothing. Deploying with the default cannot change any state —
    /// turn it off deliberately, per environment, once the log looks right.
    /// </summary>
    public bool DryRun { get; set; } = true;

    /// <summary>
    /// Page size for pending reports. Keeps a first run over ~7,600 items off one long transaction.
    /// A cycle examines up to two pages - the newest one and the next one of the sweep (MBA-1054) -
    /// so up to twice this many items.
    /// </summary>
    public int BatchSize { get; set; } = 250;

    /// <summary>
    /// UNC root of Priority's own files - the folder EXTFILES paths such as
    /// <c>..\..\system\mail\26\9\...</c> are relative to. PROD: <c>\\maba-priority\Priority</c>;
    /// STAGE: <c>\\priority-test\Priority</c>. Empty turns invoice mirroring off (MBA-998), and there
    /// is deliberately no default (MBA-1028): a STAGE install must never read production's files
    /// by omission.
    /// </summary>
    public string InvoiceRoot { get; set; } = string.Empty;

    /// <summary>
    /// Invoices copied per cycle. PROD holds ~19,800 invoice PDFs, so the first copy takes about
    /// 20 hourly cycles at the default; after that a cycle only carries the new ones.
    /// </summary>
    public int InvoiceBatchSize { get; set; } = 1000;

    /// <summary>Days before an invoice whose PDF was not found is tried again.</summary>
    public int InvoiceRetryAfterDays { get; set; } = 7;

    /// <summary>
    /// UNC folder of Priority's order attachments (MBA-930). PROD:
    /// <c>\\maba-priority\Priority\Attachments</c>; STAGE: <c>\\priority-test\Priority\Attachments</c>.
    /// priority-test's rows still name <c>\\maba-priority</c>, and this root replaces it when a file is
    /// opened. Empty turns order-attachment conversion off, and there is deliberately no default
    /// (MBA-1028): a STAGE install must never read production's files by omission.
    /// </summary>
    public string OrderAttachmentShare { get; set; } = string.Empty;

    /// <summary>Attachment files converted per cycle. PROD's cache held 3,078 on 22/11/2026.</summary>
    public int OrderAttachmentBatchSize { get; set; } = 200;

    /// <summary>Hours before a file that could not be read (locked, denied) is tried again.</summary>
    public int OrderAttachmentRetryAfterHours { get; set; } = 6;

    /// <summary>Days before a file that was not found is tried again.</summary>
    public int OrderAttachmentRetryNotFoundDays { get; set; } = 7;

    /// <summary>
    /// Days before a converted file that still has parts listed as errors is converted again. The
    /// error may have been the server's (LibreOffice not installed yet, Chromium down for one part),
    /// and installing the missing piece has to reach files already converted (review of PR #69).
    /// </summary>
    public int OrderAttachmentRetryErrorPartsDays { get; set; } = 7;

    /// <summary>
    /// How often the attachment cache gets a full rebuild, which also drops files Priority removed.
    /// Every other cycle only adds new orders. The first cycle after a start is always a full one.
    /// </summary>
    public TimeSpan OrderAttachmentFullRefreshInterval { get; set; } = TimeSpan.FromHours(24);

    /// <summary>
    /// Chromium for rendering mail bodies. Set for this process only, never machine-wide: another
    /// Playwright on the same box pins a different browser build (incident 07/09/2026).
    /// </summary>
    public string BrowsersPath { get; set; } = @"C:\ProgramData\ms-playwright";

    /// <summary>LibreOffice, for Word/Excel inside a mail. Missing = those parts are listed as errors.</summary>
    public string LibreOfficePath { get; set; } = @"C:\Program Files\LibreOffice\program\soffice.exe";
}
