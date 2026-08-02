using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>
/// Pulls instruction/notes fields for the customer from Priority. Disabled by default:
/// it needs the real field mapping (which Priority entity + field names hold customer
/// instructions — see PLAN.md §"מה עדיין נדרש ממך"). When enabled, it queries the running
/// Maba.VCT.Priority service over HTTP so this project stays decoupled from the OData client.
///
/// TODO(once field names are provided): call
///   GET {PriorityServiceBaseUrl}/api/priority/customers?number={CustomerId}&amp;select={fields}
/// and turn each non-empty instruction field into an InstructionDocument.
/// </summary>
public sealed class PriorityInstructionSource(
    IOptions<InstructionAssistantOptions> options,
    ILogger<PriorityInstructionSource> logger) : IInstructionSourceProvider
{
    private readonly PriorityInstructionOptions _opt = options.Value.Priority;

    public string Name => "priority";

    public Task<IReadOnlyList<InstructionDocument>> FindAsync(InstrumentContext ctx, CancellationToken ct = default)
    {
        if (!_opt.Enabled)
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);

        if (_opt.CustomerInstructionFields.Count == 0)
        {
            logger.LogInformation(
                "Priority instruction source enabled but no CustomerInstructionFields configured — skipping.");
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);
        }

        // Intentionally not implemented until the Priority field mapping is confirmed.
        // Kept as an explicit, honest no-op rather than a guess against the live ERP.
        logger.LogWarning(
            "PriorityInstructionSource is a stub pending field mapping (customer {Customer}).",
            ctx.CustomerId ?? ctx.CustomerName);
        return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);
    }
}
