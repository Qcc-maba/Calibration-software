using Maba.Api.Dtos;
using Maba.Core.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Maba.Api.Controllers;

[ApiController]
[Route("api/sync")]
[Authorize]
public class SyncController(IPrioritySyncService sync) : ControllerBase
{
    // POST api/sync/pull/users
    [HttpPost("pull/users")]
    public async Task<ActionResult<SyncResultDto>> PullUsers(CancellationToken ct)
    {
        var log = await sync.PullUsersAsync("admin", ct);
        return Ok(MapResult(log));
    }

    // POST api/sync/pull/customers
    [HttpPost("pull/customers")]
    public async Task<ActionResult<SyncResultDto>> PullCustomers(CancellationToken ct)
    {
        var log = await sync.PullCustomersAsync("admin", ct);
        return Ok(MapResult(log));
    }

    // POST api/sync/pull/documents
    [HttpPost("pull/documents")]
    public async Task<ActionResult<SyncResultDto>> PullDocuments(CancellationToken ct)
    {
        var log = await sync.PullDocumentsAsync("admin", ct);
        return Ok(MapResult(log));
    }

    // POST api/sync/pull/all
    [HttpPost("pull/all")]
    public async Task<ActionResult<SyncResultDto>> PullAll(CancellationToken ct)
    {
        var log = await sync.PullAllAsync("admin", ct);
        return Ok(MapResult(log));
    }

    // GET api/sync/status
    [HttpGet("status")]
    public async Task<ActionResult<SyncStatusDto>> GetStatus(CancellationToken ct)
    {
        var connected = await sync.TestConnectionAsync(ct);
        var logs = await sync.GetRecentLogsAsync(100, ct);

        // Get the latest log per sync type
        var lastByType = logs
            .GroupBy(l => l.SyncType)
            .Select(g => g.First())
            .Select(MapResult)
            .ToList();

        return Ok(new SyncStatusDto(connected, lastByType));
    }

    // GET api/sync/logs?count=50
    [HttpGet("logs")]
    public async Task<ActionResult<IReadOnlyList<SyncLogDto>>> GetLogs(
        int count = 50, CancellationToken ct = default)
    {
        var logs = await sync.GetRecentLogsAsync(count, ct);
        return Ok(logs.Select(l => new SyncLogDto(
            l.Id, l.SyncType.ToString(), l.Status.ToString(),
            l.StartedAt, l.CompletedAt, l.ItemsSynced,
            l.ErrorMessage, l.InitiatedBy
        )).ToList());
    }

    private static SyncResultDto MapResult(Core.Entities.SyncLog log) => new(
        log.SyncType.ToString(),
        log.Status.ToString(),
        log.ItemsSynced,
        log.StartedAt,
        log.CompletedAt,
        log.ErrorMessage
    );
}
