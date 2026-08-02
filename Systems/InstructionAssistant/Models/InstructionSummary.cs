namespace Maba.VCT.InstructionAssistant.Models;

/// <summary>A source document, trimmed to what the UI needs to cite it.</summary>
public sealed record SourceRef(string Title, InstructionSourceType Source, string? Reference, string? MatchReason);

/// <summary>
/// The assistant's answer for one instrument: a Hebrew summary of the relevant customer
/// instructions, plus structured key points / warnings and the list of source documents.
/// </summary>
public sealed class InstructionSummary
{
    public required InstrumentContext Context { get; init; }

    /// <summary>Free-text Hebrew summary (Markdown).</summary>
    public string SummaryMarkdown { get; set; } = "";

    /// <summary>Bulleted key instructions the calibrator must follow.</summary>
    public List<string> KeyPoints { get; set; } = [];

    /// <summary>Safety / do-not warnings pulled from the instructions.</summary>
    public List<string> Warnings { get; set; } = [];

    /// <summary>The documents the summary was built from.</summary>
    public List<SourceRef> Sources { get; set; } = [];

    /// <summary>True when no relevant instructions were found in any source.</summary>
    public bool NoInstructionsFound { get; set; }

    /// <summary>How the summary was produced ("claude:&lt;model&gt;" or "extractive").</summary>
    public string? GeneratedBy { get; set; }

    public DateTimeOffset GeneratedAt { get; init; } = DateTimeOffset.UtcNow;

    /// <summary>Non-fatal notes (e.g. "PDF extraction not yet supported", "customer names redacted").</summary>
    public List<string> Notices { get; set; } = [];
}
