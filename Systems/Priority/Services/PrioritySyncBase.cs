using Maba.Core.Entities;
using Maba.Core.Enums;
using Maba.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Maba.Api.Services;

/// <summary>
/// Shared <see cref="SyncLog"/> bookkeeping for the Priority sync transports
/// (direct SQL Server and OData REST). Keeps the log lifecycle identical so the
/// Settings page and <c>SyncController</c> behave the same regardless of transport.
/// </summary>
public abstract class PrioritySyncBase(MabaDbContext db, ILogger logger)
{
    /// <summary>Shared EF context — use this in derived services instead of capturing your own.</summary>
    protected MabaDbContext Db => db;

    protected async Task<SyncLog> StartLog(SyncType type, string initiatedBy, CancellationToken ct)
    {
        var log = new SyncLog
        {
            SyncType = type,
            Status = SyncStatus.Running,
            InitiatedBy = initiatedBy
        };
        db.SyncLogs.Add(log);
        await db.SaveChangesAsync(ct);
        return log;
    }

    protected async Task<SyncLog> CompleteLog(SyncLog log, int count, CancellationToken ct)
    {
        log.Status = SyncStatus.Success;
        log.ItemsSynced = count;
        log.CompletedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Sync {Type} completed: {Count} items", log.SyncType, count);
        return log;
    }

    protected async Task<SyncLog> FailLog(SyncLog log, Exception ex, CancellationToken ct) =>
        await FailLog(log, ex.Message, 0, ct);

    protected async Task<SyncLog> FailLog(SyncLog log, string error, int count, CancellationToken ct)
    {
        // The failed operation may have left poisoned/duplicate pending changes tracked
        // on the context. Discard them so persisting the failure log doesn't re-trigger
        // the same DB error (which would mask the real failure as an unhandled 500).
        db.ChangeTracker.Clear();

        log.Status = SyncStatus.Failed;
        log.ItemsSynced = count;
        log.ErrorMessage = error.Length > 2000 ? error[..2000] : error;
        log.CompletedAt = DateTimeOffset.UtcNow;
        db.SyncLogs.Update(log);          // re-attach: ChangeTracker.Clear() detached it
        await db.SaveChangesAsync(ct);
        logger.LogError("Sync {Type} failed: {Error}", log.SyncType, error);
        return log;
    }

    public async Task<IReadOnlyList<SyncLog>> GetRecentLogsAsync(int count, CancellationToken ct = default) =>
        await db.SyncLogs
            .OrderByDescending(s => s.StartedAt)
            .Take(count)
            .ToListAsync(ct);
}
