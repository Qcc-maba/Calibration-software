using UglyToad.PdfPig.Writer;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>
/// Joins several PDFs into one.
///
/// Uses PdfPig's <see cref="PdfMerger"/>. Apache 2.0, no licence cost, and already a dependency
/// elsewhere in this repository (Maba.VCT.InstructionAssistant uses it for text extraction) — so
/// this adds a capability without adding a vendor.
///
/// Both shapes are offered on purpose. AC #4 asks for one PDF per attachment containing the mail
/// body and everything inside it; the shape of the data argues the other way, because an order can
/// carry up to 12 files and one .msg up to 14 attachments, so a merged document can run to dozens
/// of pages with the purchase order buried among e-mail signatures. Rather than guess, the service
/// serves each part separately AND offers the merged document, and the screen picks. Building both
/// costs one class.
/// </summary>
public sealed class PdfCombiner(ILogger<PdfCombiner> log)
{
    /// <summary>
    /// Merges in the order given — the mail body first, then its attachments, which is the order
    /// a reader expects.
    /// </summary>
    /// <param name="parts">
    /// Each already a valid PDF. A part that failed conversion must be left out by the caller and
    /// reported separately; silently dropping it here would hide a document from the calibrator.
    /// </param>
    public byte[] Merge(IReadOnlyList<byte[]> parts)
    {
        if (parts.Count == 0)
            throw new PdfConversionException("There is nothing to merge.");

        // Merging one file is a copy. Going through the writer would re-encode it for no reason
        // and risks losing something the original had.
        if (parts.Count == 1) return parts[0];

        try
        {
            return PdfMerger.Merge(parts);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Merging {Count} PDFs failed", parts.Count);
            throw new PdfConversionException(
                "The documents were converted but could not be combined into a single PDF. " +
                "They are still available individually.", ex);
        }
    }
}
