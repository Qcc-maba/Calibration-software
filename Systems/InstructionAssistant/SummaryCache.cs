using System.Text;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant;

/// <summary>
/// Caches finished summaries per instrument.
///
/// A lookup costs 40–48s, almost all of it the Claude call, and a calibrator moves back and forth
/// between the instruments of one order — so without this they pay that wait again for every
/// revisit. The inputs barely change (the ECS files and the order text are edited rarely), which
/// makes a time-based cache the right trade: stale by at most <see cref="InstructionAssistantOptions.CacheSeconds"/>.
///
/// Only successful summaries are stored — a failed Claude call or an empty result must not be
/// pinned for half an hour.
/// </summary>
public sealed class SummaryCache(
    IMemoryCache cache,
    IOptions<InstructionAssistantOptions> options,
    ILogger<SummaryCache> logger)
{
    private readonly InstructionAssistantOptions _opt = options.Value;

    /// <summary>
    /// Returns the cached summary for this instrument, or runs <paramref name="factory"/> and
    /// caches a successful result.
    /// </summary>
    /// <param name="ctx">The instrument being looked up — forms the cache key.</param>
    /// <param name="refresh">True to bypass any cached entry and recompute.</param>
    /// <param name="factory">Produces the summary on a miss.</param>
    public async Task<InstructionSummary> GetOrCreateAsync(
        InstrumentContext ctx, bool refresh, Func<Task<InstructionSummary>> factory)
    {
        if (_opt.CacheSeconds <= 0) return await factory();

        var key = BuildKey(ctx);

        if (!refresh && cache.TryGetValue(key, out InstructionSummary? cached) && cached is not null)
        {
            logger.LogInformation("Summary cache hit for {Ctx}", ctx);
            return cached;
        }

        var summary = await factory();

        if (IsCacheable(summary))
        {
            cache.Set(key, summary, TimeSpan.FromSeconds(_opt.CacheSeconds));
        }
        else
        {
            logger.LogInformation(
                "Not caching summary for {Ctx} (generatedBy={By}, noInstructions={None})",
                ctx, summary.GeneratedBy, summary.NoInstructionsFound);
        }

        return summary;
    }

    /// <summary>A summary is worth keeping only if it actually carries instructions.</summary>
    private static bool IsCacheable(InstructionSummary summary)
    {
        if (summary.NoInstructionsFound) return false;

        // "claude:error" / "none" mean the summarizer did not run — retry on the next request
        // instead of serving an answer stripped of its key points and warnings.
        if (summary.GeneratedBy is null || summary.GeneratedBy.Contains("error", StringComparison.OrdinalIgnoreCase))
            return false;

        return summary.SummaryMarkdown.Length > 0 || summary.Requirements.Count > 0;
    }

    /// <summary>
    /// Key over every field that changes the answer. The MABA number alone is not enough: the same
    /// request may arrive with explicit overrides that steer the match.
    /// </summary>
    private static string BuildKey(InstrumentContext ctx)
    {
        var sb = new StringBuilder("summary|");
        foreach (var part in new[]
                 {
                     ctx.CalibRecordId, ctx.CustomerId, ctx.CustomerName, ctx.Manufacturer,
                     ctx.Model, ctx.SerialNumber, ctx.CustomerAssetNumber, ctx.DeviceType,
                 })
        {
            sb.Append(part?.Trim().ToLowerInvariant()).Append('|');
        }
        return sb.ToString();
    }
}
