using Maba.VCT.ReportArchiveSync.Archive;
using Maba.VCT.ReportArchiveSync.Data;
using Maba.VCT.ReportArchiveSync.Options;
using Maba.VCT.ReportArchiveSync.Storage;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync;

/// <summary>
/// Mirrors calibration reports from Priority's Tomax archive into S3 and indexes them.
/// </summary>
/// <remarks>
/// One cycle: take a batch of devices that have a report number but no indexed file, resolve each
/// against the archive, then upload and register what was found.
/// <para>
/// While <see cref="ReportArchiveSyncOptions.DryRun"/> is set — the default — the resolution runs
/// in full and is logged, but nothing is uploaded and nothing is written. That makes a first
/// deployment safe to observe before it is allowed to act.
/// </para>
/// </remarks>
public sealed class SyncWorker(
    ArchiveLocator locator,
    CalibrationReportRepository repository,
    ReportBlobStore blobStore,
    IOptions<ReportArchiveSyncOptions> options,
    ILogger<SyncWorker> logger) : BackgroundService
{
    private readonly ReportArchiveSyncOptions _options = options.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "ReportArchiveSync starting. Archive={Archive} SourceId={SourceId} DryRun={DryRun} Interval={Interval}",
            _options.ArchiveRoot, _options.SourceId, _options.DryRun, _options.Interval);

        if (_options.DryRun)
        {
            logger.LogWarning(
                "DryRun is ON: files will be resolved and logged, but nothing will be uploaded or written. "
                + "Set ReportArchiveSync:DryRun=false to let the service act.");
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunCycleAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                // A cycle failing must not kill the service; the next one retries. The share can be
                // briefly unreachable and the database is restarted for maintenance.
                logger.LogError(ex, "Sync cycle failed; retrying at the next interval");
            }

            await Task.Delay(_options.Interval, stoppingToken);
        }
    }

    private async Task RunCycleAsync(CancellationToken cancellationToken)
    {
        var pending = await repository.GetPendingAsync(cancellationToken);

        if (pending.Count == 0)
        {
            logger.LogInformation("Nothing pending");
            return;
        }

        var resolved = 0;
        var unresolvedNumber = 0;
        var notInArchive = 0;
        var registered = 0;
        var uploaded = 0;

        foreach (var item in pending)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (!ReportNumber.TryParse(item.MbaReportNumber, out var number))
            {
                // Real values on PROD include "123" and "\1". Log and move on — attaching a
                // guessed file would be worse than showing no report.
                unresolvedNumber++;
                logger.LogWarning(
                    "Item {ItemId} has an unparseable report number {Number}; skipped",
                    item.OrderDetailsItemId, item.MbaReportNumber);
                continue;
            }

            var candidates = locator.FindCurrent(number.Value);

            if (candidates.Count == 0)
            {
                // Usually a report from the last few weeks that has not been filed yet.
                notInArchive++;
                logger.LogInformation(
                    "Item {ItemId} report {Number} has no file in the archive yet",
                    item.OrderDetailsItemId, item.MbaReportNumber);
                continue;
            }

            resolved++;

            for (var index = 0; index < candidates.Count; index++)
            {
                var candidate = candidates[index];

                // The first variant is the device's main report and takes the canonical
                // report.pdf name, which is the only name today's UI looks for. Later variants —
                // the rare a/b/c domain splits — go beside it and surface once the UI reads
                // dbo.CalibrationReportFile instead of listing S3.
                var isPrimary = index == 0;
                var storageKey = ReportStorageKey.For(
                    item.OrderNumber, item.OrderDetailsItemId, candidate.Name, isPrimary);

                if (string.IsNullOrWhiteSpace(item.OrderNumber))
                {
                    // The key is built from the order number; without it the object would land
                    // somewhere the app never looks.
                    logger.LogWarning(
                        "Item {ItemId} has no order number; cannot place its report", item.OrderDetailsItemId);
                    continue;
                }

                if (_options.DryRun)
                {
                    logger.LogInformation(
                        "[dry run] item {ItemId} -> {File} (variant '{Variant}' u{Update}, covers {From}-{To}) => {Key}",
                        item.OrderDetailsItemId, candidate.Name.FileName, candidate.Name.Variant,
                        candidate.Name.UpdateLevel, candidate.Name.CoversFrom, candidate.Name.CoversTo,
                        storageKey);
                    continue;
                }

                var upload = await blobStore.MirrorAsync(
                    candidate.FullPath,
                    storageKey,
                    cancellationToken,
                    // Only the canonical key can already hold a report the calibrator produced and
                    // signed in the app. That one wins over anything in the archive.
                    protectForeignObject: isPrimary && !candidate.Name.IsConsolidated);

                if (upload.Skipped)
                {
                    logger.LogInformation(
                        "Item {ItemId} already has an app-generated report at {Key}; archive copy not applied",
                        item.OrderDetailsItemId, storageKey);
                    continue;
                }

                if (upload.Uploaded)
                {
                    uploaded++;
                }

                // Registered only after the blob is in place. The reverse order would let the UI
                // show an icon that opens nothing.
                await repository.UpsertAsync(
                    item.OrderDetailsItemId,
                    item.MbaReportNumber,
                    storageKey,
                    candidate.Name.Variant,
                    candidate.Name.UpdateLevel,
                    candidate.Name.CoversFrom,
                    candidate.Name.CoversTo,
                    candidate.FullPath,
                    upload.Sha256,
                    upload.Length,
                    candidate.LastWriteTimeUtc,
                    cancellationToken);

                registered++;
            }
        }

        logger.LogInformation(
            "Cycle done. Examined={Examined} Resolved={Resolved} NoFile={NoFile} BadNumber={BadNumber} "
            + "Uploaded={Uploaded} Registered={Registered}",
            pending.Count, resolved, notInArchive, unresolvedNumber, uploaded, registered);
    }
}
