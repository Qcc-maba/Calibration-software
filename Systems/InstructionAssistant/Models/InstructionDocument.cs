namespace Maba.VCT.InstructionAssistant.Models;

public enum InstructionSourceType
{
    FileShare,
    Priority
}

/// <summary>
/// One retrieved instruction document (a network file, or a Priority notes field),
/// resolved as relevant to a given <see cref="InstrumentContext"/>. <see cref="Text"/>
/// is the extracted plain text; it may be empty when extraction of the format is not
/// yet supported (see <see cref="ExtractionNote"/>).
/// </summary>
public sealed class InstructionDocument
{
    public required InstructionSourceType Source { get; init; }

    /// <summary>Display title (file name, or "Priority: &lt;field&gt;").</summary>
    public required string Title { get; init; }

    /// <summary>Where it came from — a UNC/file path, or a Priority entity key.</summary>
    public string? Reference { get; init; }

    /// <summary>MIME-ish hint: "text/plain", "application/pdf", "application/vnd...docx".</summary>
    public string? MediaType { get; init; }

    /// <summary>Extracted plain text (may be truncated by the extractor).</summary>
    public string Text { get; set; } = "";

    /// <summary>Set when the format could not be extracted, explaining why.</summary>
    public string? ExtractionNote { get; set; }

    /// <summary>Why this doc was considered relevant (matched serial / customer folder / etc.).</summary>
    public string? MatchReason { get; init; }

    /// <summary>
    /// Structured calibration-requirement rows, when the source is the central Excel matrix.
    /// Null/empty for free-text sources. Carried through so the response can render an exact
    /// table in addition to the AI summary.
    /// </summary>
    public List<CalibrationRequirement>? Requirements { get; set; }

    public DateTimeOffset RetrievedAt { get; init; } = DateTimeOffset.UtcNow;

    public bool HasText => !string.IsNullOrWhiteSpace(Text);
}
