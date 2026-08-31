using Maba.VCT.ReportArchiveSync.Archive;

namespace Maba.VCT.ReportArchiveSync.Storage;

/// <summary>
/// Builds the S3 object keys the web app reads report PDFs from.
/// </summary>
/// <remarks>
/// <para>
/// The app decides whether to show the report icon by listing
/// <c>orders/{orderNumber}/reports/{itemId}</c> and looking for a key containing the literal
/// <c>report.pdf</c> — see <c>ValidatorDeviceCard</c> and <c>ValidatorReportPopup</c>. So the file
/// name is not a free choice: put an archive report anywhere else and the existing UI simply does
/// not see it.
/// </para>
/// <para>
/// Hence the split below. The device's primary report takes the canonical name, which lights up
/// today's UI with no frontend change at all. Extra variants — the rare a/b/c domain-split
/// siblings — go under <c>archive/</c>, where they wait for the UI work that can show more than
/// one report per device.
/// </para>
/// </remarks>
public static class ReportStorageKey
{
    /// <summary>
    /// The name the app looks for. Must stay in step with the frontend constant
    /// <c>calibrationReportFilename</c>.
    /// </summary>
    public const string CanonicalFileName = "report.pdf";

    /// <summary>Folder holding one device's reports.</summary>
    public static string Folder(string orderNumber, int orderDetailsItemId) =>
        $"orders/{orderNumber}/reports/{orderDetailsItemId}";

    /// <summary>
    /// Where the calibration wizard puts a report it rendered, and where the archive sync puts a
    /// device's primary report so the existing UI finds it.
    /// </summary>
    public static string Canonical(string orderNumber, int orderDetailsItemId) =>
        $"{Folder(orderNumber, orderDetailsItemId)}/{CanonicalFileName}";

    /// <summary>
    /// Key for a secondary archive report — a domain-split variant beyond the primary one. The
    /// archive file name is reused verbatim so the object is traceable back to its source.
    /// </summary>
    public static string Secondary(string orderNumber, int orderDetailsItemId, ArchiveFileName name) =>
        $"{Folder(orderNumber, orderDetailsItemId)}/archive/{name.FileName}.pdf";

    /// <summary>
    /// Key for a consolidated report covering several devices.
    /// </summary>
    /// <remarks>
    /// Deliberately NOT per device, and deliberately not the canonical name: one such PDF can
    /// cover 151 instruments, and copying it under each device's canonical key would multiply a
    /// multi-megabyte blob 151 times. The single object is shared and
    /// <c>dbo.CalibrationReportFile</c> holds one row per covered device pointing at it — which
    /// means a consolidated report only becomes visible once the UI reads that table rather than
    /// listing S3. Rare in practice: 689 such files across 2024-2026.
    /// </remarks>
    public static string Consolidated(string orderNumber, ArchiveFileName name) =>
        $"orders/{orderNumber}/reports/_shared/{name.FileName}.pdf";

    /// <summary>
    /// The key for one resolved candidate.
    /// </summary>
    /// <param name="isPrimary">
    /// True for the device's main report — the first variant returned by the locator. Only the
    /// primary claims the canonical name; giving it to a second variant would have the two
    /// overwrite each other.
    /// </param>
    public static string For(
        string orderNumber, int orderDetailsItemId, ArchiveFileName name, bool isPrimary) =>
        name.IsConsolidated
            ? Consolidated(orderNumber, name)
            : isPrimary
                ? Canonical(orderNumber, orderDetailsItemId)
                : Secondary(orderNumber, orderDetailsItemId, name);
}
