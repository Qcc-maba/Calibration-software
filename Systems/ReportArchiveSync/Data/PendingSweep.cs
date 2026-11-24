namespace Maba.VCT.ReportArchiveSync.Data;

/// <summary>What one cycle examines, and where the sweep stands afterwards.</summary>
/// <param name="Items">Distinct items to examine, newest page first, then the sweep page.</param>
/// <param name="NewestCount">Items from the newest page.</param>
/// <param name="SweepCount">Items from the sweep page that were not already in the newest page.</param>
/// <param name="SweepFrom">The cursor this cycle read below; null when the sweep was at the top.</param>
/// <param name="NextCursor">The cursor for the next cycle; null means the next cycle starts again at the top.</param>
public sealed record PendingBatch(
    IReadOnlyList<PendingItem> Items,
    int NewestCount,
    int SweepCount,
    int? SweepFrom,
    int? NextCursor);

/// <summary>
/// Chooses the pending items for each cycle so that every one of them is reached (MBA-1054).
/// </summary>
/// <remarks>
/// Items whose report is not in the archive yet, or whose number cannot be parsed, are recorded
/// nowhere, so they stay pending. Taking the newest <c>BatchSize</c> every cycle therefore picked
/// the same items forever once that many were waiting: STAGE examined the newest 250 of 2,637 and
/// never reached the older ones, some of which are in the archive.
/// <para>
/// Each cycle now reads two pages, both newest first:
/// </para>
/// <list type="bullet">
///   <item><description>
///   the <b>newest page</b>, every cycle, so a report filed for a recent device is picked up at the
///   next cycle rather than after a full sweep (2,637 / 250 = 11 hourly cycles on STAGE);
///   </description></item>
///   <item><description>
///   the <b>sweep page</b>: the next <c>BatchSize</c> items below a cursor. The cursor moves to the
///   last id of each full page and returns to the top when a page comes back short.
///   </description></item>
/// </list>
/// When the cursor is at the top, the newest page <i>is</i> the first sweep page, so that cycle
/// reads only one page. With fewer than <c>BatchSize</c> items pending, every cycle is a single
/// query and examines all of them, as before.
/// <para>
/// Keyset paging over <c>OrderDetailsItemId</c> (<c>&lt; cursor</c>) rather than OFFSET: items
/// leave the pending set as they are registered, and an offset would then skip the ones that slid
/// into the gap. The cursor is kept in memory only; after a restart the sweep starts at the top
/// again, which costs at most one extra sweep and needs no schema.
/// </para>
/// </remarks>
public sealed class PendingSweep
{
    private readonly int _batchSize;

    public PendingSweep(int batchSize)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(batchSize);
        _batchSize = batchSize;
    }

    /// <summary>Exclusive upper bound of the next sweep page; null = start at the top.</summary>
    public int? Cursor { get; private set; }

    /// <param name="fetchPage">
    /// Returns up to <c>batchSize</c> pending items with an id below the given one (null = no bound),
    /// highest id first.
    /// </param>
    public async Task<PendingBatch> NextAsync(
        Func<int?, CancellationToken, Task<IReadOnlyList<PendingItem>>> fetchPage,
        CancellationToken cancellationToken)
    {
        var newest = await fetchPage(null, cancellationToken);
        var sweepFrom = Cursor;

        IReadOnlyList<PendingItem> sweep;

        if (sweepFrom is null)
        {
            // At the top: the newest page doubles as the first sweep page.
            sweep = newest;
        }
        else
        {
            sweep = await fetchPage(sweepFrom, cancellationToken);
        }

        // A short page means the bottom was reached: wrap. A full page may be followed by more.
        Cursor = sweep.Count < _batchSize ? null : sweep[^1].OrderDetailsItemId;

        if (sweepFrom is null)
        {
            return new PendingBatch(newest, newest.Count, 0, null, Cursor);
        }

        // The pages can overlap once registrations shrink the pending set below the cursor's
        // neighbourhood; examine each item once.
        var seen = new HashSet<int>(newest.Select(item => item.OrderDetailsItemId));
        var items = new List<PendingItem>(newest);

        foreach (var item in sweep)
        {
            if (seen.Add(item.OrderDetailsItemId))
            {
                items.Add(item);
            }
        }

        return new PendingBatch(items, newest.Count, items.Count - newest.Count, sweepFrom, Cursor);
    }
}
