using Maba.VCT.ReportArchiveSync.Archive;
using Maba.VCT.ReportArchiveSync.Data;
using Maba.VCT.ReportArchiveSync.Invoices;
using Maba.VCT.ReportArchiveSync.OrderAttachments;
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
    InvoiceMirror invoiceMirror,
    OrderAttachmentMirror orderAttachmentMirror,
    IOptions<ReportArchiveSyncOptions> options,
    ILogger<SyncWorker> logger) : BackgroundService
{
    private readonly ReportArchiveSyncOptions _options = options.Value;

    // In memory on purpose (MBA-1054): after a restart the sweep starts again at the top.
    private readonly PendingSweep _sweep = new(options.Value.BatchSize);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "ReportArchiveSync starting. Archive={Archive} SourceId={SourceId} DryRun={DryRun} Interval={Interval} "
            + "Invoices={Invoices} OrderAttachments={OrderAttachments}",
            _options.ArchiveRoot, _options.SourceId, _options.DryRun, _options.Interval,
            invoiceMirror.IsEnabled ? _options.InvoiceRoot : "off (InvoiceRoot not set)",
            orderAttachmentMirror.IsEnabled ? _options.OrderAttachmentShare : "off (OrderAttachmentShare not set)");

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

            // Invoices (MBA-998) run after the reports, in their own try: one failing must not
            // stop the other.
            try
            {
                await invoiceMirror.RunCycleAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Invoice cycle failed; retrying at the next interval");
            }

            // Order attachments (MBA-930), last and in their own try for the same reason.
            try
            {
                await orderAttachmentMirror.RunCycleAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Order-attachment cycle failed; retrying at the next interval");
            }

            await Task.Delay(_options.Interval, stoppingToken);
        }
    }

    private async Task RunCycleAsync(CancellationToken cancellationToken)
    {
        // Newest page plus the next page of the sweep (MBA-1054). NoFile and BadNumber items stay
        // pending, so a plain "newest N" would pick the same items every cycle.
        var batch = await _sweep.NextAsync(repository.GetPendingAsync, cancellationToken);
        var pending = batch.Items;

        if (pending.Count == 0)
        {
            _sweep.Commit(batch);
            logger.LogInformation("Nothing pending");
            return;
        }

        var resolved = 0;
        var unresolvedNumber = 0;
        var notInArchive = 0;
        var registered = 0;
        var uploaded = 0;
        var failed = 0;

        foreach (var item in pending)
        {
            cancellationToken.ThrowIfCancellationRequested();

            // One item failing - a path the share refuses, an object S3 will not take, a database
            // restart mid-upsert - must not end the cycle (review of PR #71). Otherwise an item in
            // the newest page that always throws would stop every cycle before the sweep page.
            try
            {
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
            catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
            {
                // Still pending, so it is examined again: next cycle if it is in the newest page,
                // otherwise on the next sweep.
                failed++;
                logger.LogError(ex, "Item {ItemId} report {Number} failed; skipped this cycle",
                    item.OrderDetailsItemId, item.MbaReportNumber);
            }
        }

        // Only now does the sweep move on. A cycle that threw before this line (the pending query,
        // cancellation) reads the same sweep page again next time. Items that failed one by one
        // are not a reason to hold it: they are logged above and come round again.
        _sweep.Commit(batch);

        logger.LogInformation(
            "Cycle done. Examined={Examined} (newest {Newest} + sweep {Sweep} below {SweepFrom}, ids {MaxId}-{MinId}) "
            + "Resolved={Resolved} NoFile={NoFile} BadNumber={BadNumber} Uploaded={Uploaded} Registered={Registered} "
            + "Failed={Failed} NextSweep={NextSweep}",
            pending.Count, batch.NewestCount, batch.SweepCount, batch.SweepFrom?.ToString() ?? "top",
            pending.Max(item => item.OrderDetailsItemId), pending.Min(item => item.OrderDetailsItemId),
            resolved, notInArchive, unresolvedNumber, uploaded, registered, failed,
            batch.NextCursor is { } next ? $"below {next}" : "top");
    }
}
