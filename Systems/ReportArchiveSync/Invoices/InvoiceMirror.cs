using Amazon.S3;
using Maba.VCT.ReportArchiveSync.Options;
using Maba.VCT.ReportArchiveSync.Storage;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.Invoices;

/// <summary>
/// Copies Priority's printed invoice PDFs into S3 so the customer portal can serve them (MBA-998).
/// </summary>
/// <remarks>
/// The portal runs on Vercel, which cannot reach Priority's share. One cycle: ask the database
/// which invoices need a copy, find each PDF on the share, upload it to
/// <c>invoices/&lt;IV&gt;.pdf</c>, then record it. A file whose bytes are already in S3 is not
/// uploaded again (the SHA-256 is kept as object metadata, as for reports).
/// <para>
/// DryRun, the service default, resolves and logs but neither uploads nor records - so a dry run
/// leaves every invoice pending, and the first real run starts from the newest.
/// </para>
/// </remarks>
public sealed class InvoiceMirror(
    InvoiceDocumentRepository repository,
    ReportBlobStore blobStore,
    IOptions<ReportArchiveSyncOptions> options,
    ILogger<InvoiceMirror> logger)
{
    private readonly ReportArchiveSyncOptions _options = options.Value;

    private const int MaxS3FailuresInARow = 3;

    public static string StorageKeyFor(int iv) => $"invoices/{iv}.pdf";

    public bool IsEnabled => !string.IsNullOrWhiteSpace(_options.InvoiceRoot);

    public async Task RunCycleAsync(CancellationToken cancellationToken)
    {
        if (!IsEnabled)
        {
            return;
        }

        var locator = new InvoiceFileLocator(_options.InvoiceRoot);

        if (!locator.RootIsReachable())
        {
            // Judging invoices against a share that cannot be seen would record them all as
            // missing and park them for InvoiceRetryAfterDays.
            logger.LogWarning(
                "Invoices: {Folder} is not reachable; cycle skipped, nothing recorded", locator.MailFolder);
            return;
        }

        var pending = await repository.GetPendingAsync(cancellationToken);

        if (pending.Count == 0)
        {
            logger.LogInformation("Invoices: nothing pending");
            return;
        }

        int found = 0, uploaded = 0, unchanged = 0, noFile = 0, ambiguous = 0, refused = 0, unreadable = 0;
        int s3Failed = 0, s3FailedInARow = 0;

        foreach (var invoice in pending)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var result = locator.Locate(invoice.ExtFileName, invoice.FileSize);

            switch (result.Status)
            {
                case InvoiceFileStatus.NoFile: noFile++; break;
                case InvoiceFileStatus.Ambiguous: ambiguous++; break;
                case InvoiceFileStatus.RefusedPath: refused++; break;
                case InvoiceFileStatus.Found: found++; break;
                case InvoiceFileStatus.Unreadable: unreadable++; break;
            }

            var key = StorageKeyFor(invoice.Iv);

            if (_options.DryRun)
            {
                logger.LogInformation(
                    "[dry run] invoice {Invoice} (IV {Iv}): {Status} {Detail} => {Key}",
                    invoice.InvoiceNumber, invoice.Iv, result.Status, result.Detail, key);
                continue;
            }

            if (result.Status == InvoiceFileStatus.Unreadable && !locator.RootIsReachable())
            {
                // The share went away mid-cycle: not this invoice's fault, so nothing is recorded.
                logger.LogWarning(
                    "Invoices: {Root} stopped being reachable at invoice {Invoice}; cycle stopped",
                    _options.InvoiceRoot, invoice.InvoiceNumber);
                break;
            }

            if (result.Status != InvoiceFileStatus.Found)
            {
                logger.LogInformation(
                    "Invoice {Invoice} (IV {Iv}): {Status} - {Detail}",
                    invoice.InvoiceNumber, invoice.Iv, result.Status, result.Detail);
                await repository.RecordAsync(invoice, result.Status, result.Detail, null, null, null, cancellationToken);
                continue;
            }

            UploadResult upload;

            try
            {
                upload = await blobStore.MirrorAsync(result.FullPath!, key, cancellationToken);
                s3FailedInARow = 0;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // The file itself: locked while Priority writes it, denied, or gone since it was
                // listed. Recorded as unreadable (retried after hours) so it cannot block the batch.
                unreadable++;
                found--;
                var detail = $"File not readable: {ex.GetType().Name}: {ex.Message}";
                logger.LogWarning("Invoice {Invoice} (IV {Iv}): {Detail}", invoice.InvoiceNumber, invoice.Iv, detail);
                await repository.RecordAsync(
                    invoice, InvoiceFileStatus.Unreadable, detail, null, null, null, cancellationToken);
                continue;
            }
            catch (AmazonS3Exception ex)
            {
                // Not recorded: S3 trouble says nothing about the invoice. Skipped so one object
                // cannot stall the batch; several in a row is an outage or a permission problem.
                s3Failed++;
                logger.LogWarning(
                    "Invoice {Invoice} (IV {Iv}): S3 refused {Key}: {Status} {Code}",
                    invoice.InvoiceNumber, invoice.Iv, key, (int)ex.StatusCode, ex.ErrorCode);

                if (++s3FailedInARow >= MaxS3FailuresInARow)
                {
                    logger.LogError(
                        "Invoices: {Count} S3 failures in a row; cycle stopped", s3FailedInARow);
                    break;
                }

                continue;
            }

            if (upload.Uploaded)
            {
                uploaded++;
            }
            else
            {
                unchanged++;
            }

            // Recorded only after the blob is in place: the reverse order would let the portal
            // show an icon that opens nothing.
            await repository.RecordAsync(
                invoice, InvoiceFileStatus.Found, null, key, upload.Sha256, upload.Length, cancellationToken);
        }

        logger.LogInformation(
            "Invoices cycle done. Examined={Examined} Found={Found} Uploaded={Uploaded} Unchanged={Unchanged} "
            + "NoFile={NoFile} Ambiguous={Ambiguous} Refused={Refused} Unreadable={Unreadable} S3Failed={S3Failed} "
            + "DryRun={DryRun}",
            pending.Count, found, uploaded, unchanged, noFile, ambiguous, refused, unreadable, s3Failed,
            _options.DryRun);
    }
}
