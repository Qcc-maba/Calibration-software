using System.Text;
using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Extraction;

/// <summary>Handles plain-text formats (.txt, .md, .csv). Reads with encoding detection.</summary>
public sealed class PlainTextExtractor : IDocumentTextExtractor
{
    private static readonly string[] Handled = [".txt", ".md", ".csv", ".log"];

    public bool CanHandle(string extension) => Handled.Contains(extension.ToLowerInvariant());

    public async Task ExtractAsync(string path, InstructionDocument doc, int maxChars, CancellationToken ct = default)
    {
        var text = await File.ReadAllTextAsync(path, Encoding.UTF8, ct);
        doc.Text = text.Length > maxChars ? text[..maxChars] : text;
    }
}
