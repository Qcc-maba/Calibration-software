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
                "Invoices: {Root} is not reachable; cycle skipped, nothing recorded", _options.InvoiceRoot);
            return;
        }

        var pending = await repository.GetPendingAsync(cancellationToken);

        if (pending.Count == 0)
        {
            logger.LogInformation("Invoices: nothing pending");
            return;
        }

        int found = 0, uploaded = 0, unchanged = 0, noFile = 0, ambiguous = 0, refused = 0, unreadable = 0;

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

            if (result.Status == InvoiceFileStatus.Unreadable)
            {
                // Temporary: left pending, not recorded, so the next cycle tries again.
                logger.LogWarning(
                    "Invoice {Invoice} (IV {Iv}): {Detail}; left pending",
                    invoice.InvoiceNumber, invoice.Iv, result.Detail);
                continue;
            }

            if (result.Status != InvoiceFileStatus.Found)
            {
                logger.LogInformation(
                    "Invoice {Invoice} (IV {Iv}): {Status} - {Detail}",
                    invoice.InvoiceNumber, invoice.Iv, result.Status, result.Detail);
                await repository.RecordAsync(invoice, result.Status, result.Detail, null, null, null, cancellationToken);
                continue;
            }

            var upload = await blobStore.MirrorAsync(result.FullPath!, key, cancellationToken);

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
            + "NoFile={NoFile} Ambiguous={Ambiguous} Refused={Refused} Unreadable={Unreadable} DryRun={DryRun}",
            pending.Count, found, uploaded, unchanged, noFile, ambiguous, refused, unreadable, _options.DryRun);
    }
}
