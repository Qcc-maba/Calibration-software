using Maba.Core.Entities;
using Maba.Core.Interfaces;

namespace Maba.Api.Services;

/// <summary>
/// <see cref="IPrioritySyncService"/> facade that delegates to the SQL or OData
/// implementation based on the runtime "PrioritySync:Mode" config value
/// (editable from the Settings page). Defaults to the SQL transport.
/// </summary>
public class PrioritySyncDispatcher(
    IServiceProvider sp,
    IAppConfigService config,
    IConfiguration appConfig) : IPrioritySyncService
{
    private async Task<IPrioritySyncService> ResolveAsync(CancellationToken ct)
    {
        var mode = await config.GetValueAsync("PrioritySync", "Mode", ct)
                   ?? appConfig["PrioritySync:Mode"]
                   ?? "Sql";

        return mode.Equals("OData", StringComparison.OrdinalIgnoreCase)
            ? sp.GetRequiredService<PriorityODataSyncService>()
            : sp.GetRequiredService<PrioritySyncService>();
    }

    public async Task<SyncLog> PullUsersAsync(string initiatedBy, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).PullUsersAsync(initiatedBy, ct);

    public async Task<SyncLog> PullCustomersAsync(string initiatedBy, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).PullCustomersAsync(initiatedBy, ct);

    public async Task<SyncLog> PullDocumentsAsync(string initiatedBy, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).PullDocumentsAsync(initiatedBy, ct);

    public async Task<SyncLog> PullAllAsync(string initiatedBy, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).PullAllAsync(initiatedBy, ct);

    public async Task<SyncLog> PushCalibStatusAsync(int recordId, CalibStatusEntry entry, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).PushCalibStatusAsync(recordId, entry, ct);

    public async Task<bool> TestConnectionAsync(CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).TestConnectionAsync(ct);

    public async Task<IReadOnlyList<SyncLog>> GetRecentLogsAsync(int count, CancellationToken ct = default) =>
        await (await ResolveAsync(ct)).GetRecentLogsAsync(count, ct);
}
