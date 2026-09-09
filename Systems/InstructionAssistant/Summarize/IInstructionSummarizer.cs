using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Summarize;

/// <summary>Turns the retrieved instruction documents into a calibrator-facing summary.</summary>
public interface IInstructionSummarizer
{
    Task SummarizeAsync(InstrumentContext ctx, IReadOnlyList<InstructionDocument> docs, InstructionSummary result, CancellationToken ct = default);
}
