using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Extraction;

/// <summary>
/// Dispatches to the first registered extractor that handles the file's extension.
/// Formats without an extractor yet (PDF/Word/scans) get a clear <see cref="InstructionDocument.ExtractionNote"/>
/// instead of failing — so a lookup still returns the file as a citable source, and the
/// summary flags that its body was not read. Wire real PDF/DOCX/OCR extractors here once
/// the actual network file formats are confirmed (see PLAN.md).
/// </summary>
public sealed class CompositeTextExtractor(IEnumerable<IDocumentTextExtractor> extractors, ILogger<CompositeTextExtractor> logger)
{
    private readonly IReadOnlyList<IDocumentTextExtractor> _extractors = extractors.ToList();

    public async Task ExtractAsync(string path, InstructionDocument doc, int maxChars, CancellationToken ct = default)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        var extractor = _extractors.FirstOrDefault(e => e.CanHandle(ext));
        if (extractor is null)
        {
            doc.ExtractionNote = $"חילוץ טקסט לפורמט '{ext}' עדיין לא נתמך — הקובץ מצוין כמקור אך תוכנו לא נקרא.";
            return;
        }

        try
        {
            await extractor.ExtractAsync(path, doc, maxChars, ct);
            if (!doc.HasText)
                doc.ExtractionNote = "הקובץ נקרא אך לא נמצא בו טקסט (ייתכן מסמך סרוק — נדרש OCR).";
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Extraction failed for {Path}", path);
            doc.ExtractionNote = $"שגיאת חילוץ: {ex.Message}";
        }
    }
}
