using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Sources;
using Maba.VCT.InstructionAssistant.Summarize;

namespace Maba.VCT.InstructionAssistant;

/// <summary>
/// Orchestrates a lookup: gather instruction documents from every source, then summarize.
/// Returns a fully-populated <see cref="InstructionSummary"/> the UI can render as-is.
/// </summary>
public sealed class InstructionAssistantService(
    IEnumerable<IInstructionSourceProvider> sources,
    IInstructionSummarizer summarizer,
    ILogger<InstructionAssistantService> logger)
{
    private readonly IReadOnlyList<IInstructionSourceProvider> _sources = sources.ToList();

    public async Task<InstructionSummary> GetSummaryAsync(InstrumentContext ctx, CancellationToken ct = default)
    {
        var result = new InstructionSummary { Context = ctx };

        if (!ctx.HasAnyKey)
        {
            result.Notices.Add("לא סופק מזהה מכשיר (לקוח / מס' סידורי) — לא ניתן לחפש הוראות.");
            result.NoInstructionsFound = true;
            return result;
        }

        var docs = new List<InstructionDocument>();
        foreach (var source in _sources)
        {
            try
            {
                var found = await source.FindAsync(ctx, ct);
                docs.AddRange(found);
                logger.LogInformation("{Source} returned {Count} docs for {Ctx}", source.Name, found.Count, ctx);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Source {Source} failed", source.Name);
                result.Notices.Add($"מקור '{source.Name}' נכשל: {ex.Message}");
            }
        }

        result.Sources = docs
            .Select(d => new SourceRef(d.Title, d.Source, d.Reference, d.MatchReason))
            .ToList();

        // Surface any structured requirement rows (central Excel) as an exact table.
        result.Requirements = docs
            .Where(d => d.Requirements is { Count: > 0 })
            .SelectMany(d => d.Requirements!)
            .ToList();

        if (docs.Count == 0)
        {
            result.NoInstructionsFound = true;
            result.Notices.Add("לא נמצאו מסמכי הוראות רלוונטיים במקורות הידועים.");
            return result;
        }

        await summarizer.SummarizeAsync(ctx, docs, result, ct);
        return result;
    }
}
