using Amazon.S3;
using Maba.VCT.ReportArchiveSync;
using Maba.VCT.ReportArchiveSync.Archive;
using Maba.VCT.ReportArchiveSync.Data;
using Maba.VCT.ReportArchiveSync.Options;
using Maba.VCT.ReportArchiveSync.Storage;
using Microsoft.Extensions.Options;

var builder = Host.CreateApplicationBuilder(args);

// Runs as a Windows service in production and as a console app during development.
builder.Services.AddWindowsService(service => service.ServiceName = "MabaReportArchiveSync");

builder.Services
    .AddOptions<ReportArchiveSyncOptions>()
    .Bind(builder.Configuration.GetSection(ReportArchiveSyncOptions.SectionName))
    .Validate(
        options => !string.IsNullOrWhiteSpace(options.ConnectionString),
        "ReportArchiveSync:ConnectionString is required.")
    .Validate(
        options => !string.IsNullOrWhiteSpace(options.ArchiveRoot),
        "ReportArchiveSync:ArchiveRoot is required.")
    .Validate(
        // A drive letter here would work when a developer runs the console app and then silently
        // find nothing once installed as a service, because drive mappings are per-user.
        options => !(options.ArchiveRoot.Length > 1 && options.ArchiveRoot[1] == ':'),
        "ReportArchiveSync:ArchiveRoot must be a UNC path, not a mapped drive letter — "
        + "a Windows service account has no drive mappings.")
    .Validate(
        options => options.SourceId is 1 or 2,
        "ReportArchiveSync:SourceId must be 1 (MABA) or 2 (SEPHARM).")
    .ValidateOnStart();

builder.Services
    .AddOptions<ReportArchiveSyncOptions>()
    .Validate(
        options => options.DryRun || !string.IsNullOrWhiteSpace(options.BucketName),
        "ReportArchiveSync:BucketName is required once DryRun is off.");

builder.Services.AddSingleton<CalibrationReportRepository>();

// Credentials come from the standard AWS environment variables (AWS_ACCESS_KEY_ID /
// AWS_SECRET_ACCESS_KEY), the same ones the web app uses; the region is configured explicitly.
//
// Wrapped in Lazy so a dry run starts on a machine with no AWS configuration at all. Resolving
// this eagerly made the whole service fail at startup with "No RegionEndpoint or ServiceURL
// configured" even though DryRun never touches S3.
builder.Services.AddSingleton(provider => new Lazy<IAmazonS3>(() =>
{
    var region = provider.GetRequiredService<IOptions<ReportArchiveSyncOptions>>().Value.Region;
    return new AmazonS3Client(Amazon.RegionEndpoint.GetBySystemName(region));
}));

builder.Services.AddSingleton<ReportBlobStore>();

builder.Services.AddSingleton(provider => new ArchiveLocator(
    provider.GetRequiredService<IOptions<ReportArchiveSyncOptions>>().Value.ArchiveRoot,
    provider.GetRequiredService<ILogger<ArchiveLocator>>()));

builder.Services.AddHostedService<SyncWorker>();

await builder.Build().RunAsync();
