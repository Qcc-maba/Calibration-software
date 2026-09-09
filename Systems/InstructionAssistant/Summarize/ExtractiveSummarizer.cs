using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Summarize;

/// <summary>
/// Offline fallback (Summarizer:Mode=Extractive): no cloud call. Surfaces lines that look
/// like instructions/warnings by keyword, so nothing leaves the network. Lower quality than
/// the Claude summarizer, but private and dependency-free.
/// </summary>
public sealed class ExtractiveSummarizer : IInstructionSummarizer
{
    private static readonly string[] WarningWords =
        ["אזהרה", "זהירות", "אין ל", "אסור", "סכנה", "warning", "caution", "do not", "danger"];
    private static readonly string[] InstructionWords =
        ["יש ל", "חובה", "נדרש", "לכייל", "לפי", "טולרנס", "דיוק", "must", "require", "shall", "tolerance"];

    public Task SummarizeAsync(
        InstrumentContext ctx, IReadOnlyList<InstructionDocument> docs, InstructionSummary result, CancellationToken ct = default)
    {
        var keyPoints = new List<string>();
        var warnings = new List<string>();

        foreach (var d in docs)
        {
            if (!d.HasText) continue;
            foreach (var rawLine in d.Text.Split('\n'))
            {
                var line = rawLine.Trim();
                if (line.Length is < 4 or > 300) continue;
                if (WarningWords.Any(w => line.Contains(w, StringComparison.OrdinalIgnoreCase)))
                    warnings.Add(line);
                else if (InstructionWords.Any(w => line.Contains(w, StringComparison.OrdinalIgnoreCase)))
                    keyPoints.Add(line);
            }
        }

        result.KeyPoints = keyPoints.Distinct().Take(20).ToList();
        result.Warnings = warnings.Distinct().Take(20).ToList();
        result.SummaryMarkdown = (result.KeyPoints.Count == 0 && result.Warnings.Count == 0)
            ? ""
            : "סיכום מבוסס-חילוץ (ללא AI). מבוסס על קטעים שאותרו לפי מילות-מפתח מתוך מסמכי המקור.";
        result.GeneratedBy = "extractive";
        result.Notices.Add("מצב חילוץ מקומי — לא בוצע סיכום ענן.");
        return Task.CompletedTask;
    }
}
