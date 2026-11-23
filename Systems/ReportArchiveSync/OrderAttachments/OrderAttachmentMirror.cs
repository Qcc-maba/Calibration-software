using Amazon.S3;
using Maba.VCT.OrderAttachments.Convert;
using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.ReportArchiveSync.Options;
using Maba.VCT.ReportArchiveSync.Storage;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.OrderAttachments;

/// <summary>
/// Converts the documents Priority attaches to an order into PDFs and puts them in S3, so the
/// work-assignment screen can show them to the calibrator (MBA-930).
/// </summary>
/// <remarks>
/// The app runs on Vercel, which cannot reach Priority's share, so the conversion happens here,
/// on-prem, ahead of time - the same reason invoices are copied (MBA-998). One cycle:
/// <list type="number">
/// <item>top up dbo.CrmOrderAttachments from Priority (full once a day, else new orders only);</item>
/// <item>take the files not converted yet, newest order first;</item>
/// <item>convert each into its parts (mail body + each enclosed document), upload every PDF and
/// the merged one, then record the file and its parts - including parts that failed, with their
/// reason (AC #6).</item>
/// </list>
/// DryRun, the service default, converts and logs but neither uploads nor writes, the cache
/// refresh included.
/// </remarks>
public sealed class OrderAttachmentMirror(
    OrderAttachmentRepository repository,
    AttachmentConverter converter,
    AttachmentShareMap shares,
    ReportBlobStore blobStore,
    IOptions<ReportArchiveSyncOptions> options,
    ILogger<OrderAttachmentMirror> logger)
{
    private readonly ReportArchiveSyncOptions _options = options.Value;
    private DateTime? _lastFullRefreshUtc;

    private const int MaxS3FailuresInARow = 3;

    public bool IsEnabled => !string.IsNullOrWhiteSpace(_options.OrderAttachmentShare);

    public static string KeyPrefix(int ord, int fileNumber) => $"order-attachments/{ord}/{fileNumber}/";

    public static string PartKey(int ord, int fileNumber, string partId) =>
        KeyPrefix(ord, fileNumber) + partId + ".pdf";

    public static string MergedKey(int ord, int fileNumber) => KeyPrefix(ord, fileNumber) + "all.pdf";

    public async Task RunCycleAsync(CancellationToken ct)
    {
        if (!IsEnabled)
        {
            return;
        }

        if (!Directory.Exists(shares.ShareRoot))
        {
            // Judging files against a share that cannot be seen would record every one as missing.
            logger.LogWarning(
                "Order attachments: {Share} is not reachable; cycle skipped, nothing recorded", shares.ShareRoot);
            return;
        }

        if (!_options.DryRun)
        {
            var full = _lastFullRefreshUtc is null
                       || DateTime.UtcNow - _lastFullRefreshUtc >= _options.OrderAttachmentFullRefreshInterval;
            var (orders, files) = await repository.RefreshCacheAsync(incrementalOnly: !full, ct);
            if (full) _lastFullRefreshUtc = DateTime.UtcNow;
            logger.LogInformation(
                "Order attachments: cache {Kind} refresh, {Orders} orders / {Files} files",
                full ? "full" : "incremental", orders, files);
        }

        var pending = await repository.GetPendingAsync(ct);
        if (pending.Count == 0)
        {
            logger.LogInformation("Order attachments: nothing pending");
            return;
        }

        int converted = 0, partsOk = 0, partsFailed = 0, uploaded = 0, unreadable = 0, notFound = 0;
        int unavailable = 0, failedOther = 0;
        int s3Failed = 0, s3FailedInARow = 0;

        foreach (var source in pending)
        {
            ct.ThrowIfCancellationRequested();

            ConvertedAttachment result;
            try
            {
                result = await converter.ConvertAsync(source, ct);
            }
            catch (AttachmentSourceUnreadableException ex)
            {
                if (!Directory.Exists(shares.ShareRoot))
                {
                    logger.LogWarning(
                        "Order attachments: {Share} stopped being reachable at ORD {Ord}; cycle stopped",
                        shares.ShareRoot, source.Ord);
                    break;
                }

                var outcome = ex.NotFound ? OrderAttachmentOutcome.NotFound : OrderAttachmentOutcome.Unreadable;
                if (ex.NotFound) notFound++; else unreadable++;
                logger.LogInformation(
                    "ORD {Ord} file {File}: {Outcome} - {Detail}", source.Ord, source.FileNumber, outcome, ex.Message);

                if (!_options.DryRun)
                    await repository.SaveAsync(source, outcome, ex.Message, null, null, ct);
                continue;
            }
            catch (AttachmentConversionUnavailableException ex)
            {
                // No converter, so nothing converted: retried after hours, not recorded as done.
                unavailable++;
                logger.LogWarning(
                    "ORD {Ord} file {File}: no converter available - {Detail}", source.Ord, source.FileNumber, ex.Message);

                if (!_options.DryRun)
                    await repository.SaveAsync(source, OrderAttachmentOutcome.Unreadable, ex.Message, null, null, ct);
                continue;
            }
            catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
            {
                // Anything else is this file's problem, never the batch's: recorded as a retryable
                // failure so the next file still gets its turn. Unhandled, it aborted the cycle on
                // the same newest file every hour and nothing older ever converted (review of #69).
                failedOther++;
                logger.LogWarning(ex, "ORD {Ord} file {File}: conversion failed", source.Ord, source.FileNumber);

                if (!_options.DryRun)
                    await repository.SaveAsync(
                        source, OrderAttachmentOutcome.Unreadable, $"{ex.GetType().Name}: {ex.Message}", null, null, ct);
                continue;
            }

            partsOk += result.Parts.Count(p => p.Pdf is not null);
            partsFailed += result.Parts.Count(p => p.Pdf is null);

            if (_options.DryRun)
            {
                logger.LogInformation(
                    "[dry run] ORD {Ord} file {File} ({Name}): {Parts}",
                    source.Ord, source.FileNumber, source.FileName,
                    string.Join("; ", result.Parts.Select(p => p.Error is null
                        ? $"{p.Kind} '{p.Name}' {p.Pdf!.Length:N0} B"
                        : $"ERROR '{p.Name}': {p.Error}")));
                converted++;
                continue;
            }

            try
            {
                var saved = new List<SavedPart>(result.Parts.Count);
                foreach (var part in result.Parts)
                {
                    if (part.Pdf is null)
                    {
                        saved.Add(new SavedPart(part.PartId, part.Seq, part.Name, "Error", part.Error, null, null));
                        continue;
                    }

                    var upload = await blobStore.MirrorBytesAsync(
                        part.Pdf, PartKey(source.Ord, source.FileNumber, part.PartId), ct);
                    if (upload.Uploaded) uploaded++;
                    saved.Add(new SavedPart(part.PartId, part.Seq, part.Name, part.Kind, null,
                        upload.StorageKey, upload.Length));
                }

                string? mergedKey = null;
                if (result.MergedPdf is not null)
                {
                    var upload = await blobStore.MirrorBytesAsync(
                        result.MergedPdf, MergedKey(source.Ord, source.FileNumber), ct);
                    if (upload.Uploaded) uploaded++;
                    mergedKey = upload.StorageKey;
                }
                else if (saved.Count(p => p.StorageKey is not null) == 1)
                {
                    // Exactly one part opens: that part already is the whole attachment. With more,
                    // the merge failed, and offering one of them as "all" would hide the others.
                    mergedKey = saved.Single(p => p.StorageKey is not null).StorageKey;
                }

                s3FailedInARow = 0;

                // Recorded only after every blob is in place.
                await repository.SaveAsync(source, OrderAttachmentOutcome.Converted, null, mergedKey, saved, ct);
                converted++;
            }
            catch (AmazonS3Exception ex)
            {
                // Not recorded: S3 trouble says nothing about the document, so it stays pending.
                s3Failed++;
                logger.LogWarning(
                    "ORD {Ord} file {File}: S3 refused the upload: {Status} {Code}",
                    source.Ord, source.FileNumber, (int)ex.StatusCode, ex.ErrorCode);

                if (++s3FailedInARow >= MaxS3FailuresInARow)
                {
                    logger.LogError("Order attachments: {Count} S3 failures in a row; cycle stopped", s3FailedInARow);
                    break;
                }
            }
        }

        logger.LogInformation(
            "Order attachments cycle done. Examined={Examined} Converted={Converted} PartsOk={PartsOk} "
            + "PartsFailed={PartsFailed} Uploaded={Uploaded} Unreadable={Unreadable} NotFound={NotFound} "
            + "NoConverter={NoConverter} FailedOther={FailedOther} S3Failed={S3Failed} DryRun={DryRun}",
            pending.Count, converted, partsOk, partsFailed, uploaded, unreadable, notFound,
            unavailable, failedOther, s3Failed, _options.DryRun);
    }
}
