using System.Diagnostics.CodeAnalysis;

namespace Maba.VCT.ReportArchiveSync.Archive;

/// <summary>
/// A MABA calibration report number, split into the document base and the line index.
/// </summary>
/// <remarks>
/// The same number is spelled three different ways depending on where it lives:
/// <list type="bullet">
///   <item><description><c>OrderDetailsItems.MbaReportNumber</c> — <c>2603086\4</c> (backslash)</description></item>
///   <item><description><c>stg_Orders</c> / <c>amaba.dbo.MBA_DOCUMENTS.MBANUM</c> — <c>2603086/4</c> (slash)</description></item>
///   <item><description>the archive file name — <c>2603086-4.pdf</c> (hyphen)</description></item>
/// </list>
/// Both separators are accepted on input.
/// </remarks>
public readonly record struct ReportNumber(string Base, int Index)
{
    /// <summary>The report number as the archive spells it, without extension: <c>2603086-4</c>.</summary>
    public string ArchivePrefix => $"{Base}-{Index}";

    /// <summary>
    /// The archive folder a file for this number is MOST LIKELY to sit in — <c>20</c> plus the
    /// first two digits of the base.
    /// </summary>
    /// <remarks>
    /// This is a hint for ordering the search, never a filter. Re-issues are filed under the year
    /// they were produced, not the year of the report: report <c>2412012-77</c> exists as
    /// <c>2025\2412012-77.PDF</c>, <c>2024\2412012-77u1.PDF</c> and <c>2026\2412012-77_XXu1.PDF</c>.
    /// The locator must sweep every year folder.
    /// </remarks>
    public int? LikelyYear =>
        Base.Length >= 2 && int.TryParse(Base.AsSpan(0, 2), out var yy) ? 2000 + yy : null;

    /// <summary>
    /// Parses a stored report number. Returns false for the malformed values that really do occur
    /// in production — <c>OrderDetailsItems</c> on PROD contains both <c>123</c> (no separator, no
    /// index) and <c>\1</c> (separator and index but no base). Neither can be resolved to a file,
    /// and guessing would attach the wrong PDF to a device.
    /// </summary>
    public static bool TryParse(string? value, [NotNullWhen(true)] out ReportNumber? number)
    {
        number = null;

        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var text = value.Trim();
        var separator = text.IndexOfAny(['\\', '/']);

        if (separator <= 0 || separator == text.Length - 1)
        {
            return false;
        }

        var basePart = text[..separator].Trim();
        var indexPart = text[(separator + 1)..].Trim();

        // The base is the document number as Priority mints it — all digits. Anything else is
        // hand-entered noise.
        if (basePart.Length == 0 || !basePart.All(char.IsAsciiDigit))
        {
            return false;
        }

        if (!int.TryParse(indexPart, out var index) || index <= 0)
        {
            return false;
        }

        number = new ReportNumber(basePart, index);
        return true;
    }
}
