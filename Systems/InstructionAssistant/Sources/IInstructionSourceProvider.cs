using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>A source of customer instructions (a file share, Priority, …).</summary>
public interface IInstructionSourceProvider
{
    /// <summary>Short name for logging/health (e.g. "file-share", "priority").</summary>
    string Name { get; }

    /// <summary>Find instruction documents relevant to <paramref name="ctx"/>.</summary>
    Task<IReadOnlyList<InstructionDocument>> FindAsync(InstrumentContext ctx, CancellationToken ct = default);
}
