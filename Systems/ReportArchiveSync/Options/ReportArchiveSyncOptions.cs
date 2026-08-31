namespace Maba.VCT.ReportArchiveSync.Options;

public sealed class ReportArchiveSyncOptions
{
    public const string SectionName = "ReportArchiveSync";

    /// <summary>
    /// UNC root of Priority's Tomax archive. Must be a UNC path, never a mapped drive letter:
    /// drive mappings are per-user and do not exist in the session a Windows service runs in, so
    /// "P:\Tomax\..." resolves to nothing under a service account.
    /// </summary>
    public string ArchiveRoot { get; set; } = @"\\maba-priority\priority\Tomax\Archives\DOC_Q\Out";

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

    /// <summary>Items to resolve per cycle. Keeps a first run over ~7,600 items off one long transaction.</summary>
    public int BatchSize { get; set; } = 250;
}
