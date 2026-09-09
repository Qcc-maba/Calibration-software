using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Extraction;

/// <summary>Extracts plain text from an instruction document, in place.</summary>
public interface IDocumentTextExtractor
{
    /// <summary>True if this extractor handles the given file extension (lowercase, with dot).</summary>
    bool CanHandle(string extension);

    /// <summary>
    /// Read <paramref name="path"/> and fill <see cref="InstructionDocument.Text"/>
    /// (or <see cref="InstructionDocument.ExtractionNote"/> if it cannot).
    /// </summary>
    Task ExtractAsync(string path, InstructionDocument doc, int maxChars, CancellationToken ct = default);
}
