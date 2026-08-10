using System.Text;
using System.Text.RegularExpressions;
using Maba.VCT.InstructionAssistant.Models;
using UglyToad.PdfPig;
using UglyToad.PdfPig.DocumentLayoutAnalysis.WordExtractor;

namespace Maba.VCT.InstructionAssistant.Extraction;

/// <summary>
/// Extracts text from PDF instruction files with PdfPig (github.com/UglyToad/PdfPig, Apache-2.0).
///
/// The ECS PDFs are exports of the Word originals, so their content is mostly tables. Words are
/// pulled with the nearest-neighbour extractor and grouped into lines by their vertical position,
/// which keeps a test-point row on one line instead of scattering the cells — the same shape the
/// .docx extractor produces.
///
/// A PDF that is a pure scan has no text layer and yields nothing; that is reported as an
/// extraction note (OCR would be needed) rather than as an error.
/// </summary>
public sealed partial class PdfTextExtractor : IDocumentTextExtractor
{
    /// <summary>Words whose baselines differ by less than this are treated as the same line.</summary>
    private const double LineTolerance = 3.0;

    public bool CanHandle(string extension) =>
        extension.Equals(".pdf", StringComparison.OrdinalIgnoreCase);

    public Task ExtractAsync(string path, InstructionDocument doc, int maxChars, CancellationToken ct = default)
    {
        // Shared read — these files live on a drive where they may be open elsewhere.
        using var file = new FileStream(path, FileMode.Open, FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        using var pdf = PdfDocument.Open(file);

        var sb = new StringBuilder();
        foreach (var page in pdf.GetPages())
        {
            ct.ThrowIfCancellationRequested();
            if (sb.Length >= maxChars) break;

            var words = page.GetWords(NearestNeighbourWordExtractor.Instance).ToList();
            if (words.Count == 0) continue;

            foreach (var line in words
                .GroupBy(w => Math.Round(w.BoundingBox.Bottom / LineTolerance))
                .OrderByDescending(g => g.Key))
            {
                // PdfPig hands back words that often carry their own padding, and these exports
                // are full of wide letter spacing — collapse it so the prompt is not mostly blanks.
                var text = Whitespace().Replace(
                    string.Join(' ', line.OrderBy(w => w.BoundingBox.Left).Select(w => w.Text)),
                    " ").Trim();

                if (text.Length > 0) sb.Append(text).Append('\n');
            }
        }

        var result = sb.ToString().Trim();
        doc.Text = result.Length > maxChars ? result[..maxChars] : result;
        return Task.CompletedTask;
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();
}
