using Maba.VCT.ReportArchiveSync.Data;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>
/// MBA-1054: STAGE examined the same newest 250 of 2,637 pending items every cycle, because items
/// with no file in the archive stay pending. The sweep must reach every item, wrap at the bottom,
/// and still look at the newest page every cycle.
/// </summary>
public class PendingSweepTests
{
    private const int Batch = 250;

    /// <summary>A pending set the fake repository pages over, the way GetPendingAsync does.</summary>
    private sealed class FakePending(IEnumerable<int> ids)
    {
        public SortedSet<int> Ids { get; } = new(ids);

        public List<int?> Calls { get; } = [];

        public List<int> Takes { get; } = [];

        public Task<IReadOnlyList<PendingItem>> FetchAsync(int? beforeId, int take, CancellationToken _)
        {
            Calls.Add(beforeId);
            Takes.Add(take);
            IReadOnlyList<PendingItem> page = Ids
                .Reverse()
                .Where(id => beforeId is null || id < beforeId)
                .Take(take)
                .Select(id => new PendingItem(id, "SO000001", $"2610103\\{id}"))
                .ToList();
            return Task.FromResult(page);
        }
    }

    private static List<int> IdsOf(PendingBatch batch) =>
        batch.Items.Select(item => item.OrderDetailsItemId).ToList();

    /// <summary>One cycle that runs to the end: read the batch, then commit it.</summary>
    private static async Task<PendingBatch> Next(PendingSweep sweep, FakePending pending)
    {
        var batch = await sweep.NextAsync(pending.FetchAsync, CancellationToken.None);
        sweep.Commit(batch);
        return batch;
    }

    [Fact]
    public async Task At_the_top_one_query_serves_as_newest_and_first_sweep_page()
    {
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(Batch);

        var batch = await Next(sweep, pending);

        Assert.Equal([null], pending.Calls);
        Assert.Equal(Enumerable.Range(351, 250).Reverse(), IdsOf(batch));
        Assert.Equal(250, batch.NewestCount);
        Assert.Equal(0, batch.SweepCount);
        Assert.Null(batch.SweepFrom);
        Assert.Equal(351, batch.NextCursor);
        Assert.Equal(351, sweep.Cursor);
    }

    [Fact]
    public async Task The_cursor_advances_then_a_short_page_wraps_to_the_top()
    {
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(Batch);

        await Next(sweep, pending);                 // 600..351, cursor 351

        var second = await Next(sweep, pending);    // newest + 350..101
        Assert.Equal(351, second.SweepFrom);
        Assert.Equal(250, second.SweepCount);
        Assert.Equal(101, second.NextCursor);

        var third = await Next(sweep, pending);     // newest + 100..1, short
        Assert.Equal(101, third.SweepFrom);
        Assert.Equal(100, third.SweepCount);
        Assert.Equal(Enumerable.Range(1, 100).Reverse(), IdsOf(third).Skip(250));
        Assert.Null(third.NextCursor);

        var fourth = await Next(sweep, pending);    // back at the top
        Assert.Null(fourth.SweepFrom);
        Assert.Equal(351, fourth.NextCursor);
    }

    [Fact]
    public async Task One_sweep_examines_every_pending_item()
    {
        // STAGE's shape on 24/11/2026: 2,637 pending, none of them ever registered.
        var pending = new FakePending(Enumerable.Range(6, 2637));
        var sweep = new PendingSweep(Batch);
        var examined = new HashSet<int>();
        var cycles = 0;

        do
        {
            var batch = await Next(sweep, pending);
            examined.UnionWith(IdsOf(batch));
            cycles++;
        }
        while (sweep.Cursor is not null);

        Assert.Equal(pending.Ids, examined);
        Assert.Equal(11, cycles); // ceil(2637 / 250)
    }

    [Fact]
    public async Task The_newest_page_is_examined_every_cycle()
    {
        var pending = new FakePending(Enumerable.Range(1, 1000));
        var sweep = new PendingSweep(Batch);

        await Next(sweep, pending);
        pending.Ids.Add(1001);                      // a device given a report number since

        var batch = await Next(sweep, pending);

        Assert.Equal([null, null, 751], pending.Calls);
        Assert.Equal(1001, batch.Items[0].OrderDetailsItemId);
        Assert.Contains(1000, IdsOf(batch));        // the newest page again, not only the sweep
        Assert.Equal(Enumerable.Range(501, 250).Reverse(), IdsOf(batch).Skip(250));
    }

    [Fact]
    public async Task Items_are_not_examined_twice_when_the_pages_overlap()
    {
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(Batch);

        await Next(sweep, pending);                 // cursor 351

        // Most of the newest page got registered, so the newest page now reaches below the cursor.
        pending.Ids.RemoveWhere(id => id >= 400);

        var batch = await Next(sweep, pending);

        // Newest = 399..150; sweep below 351 = 350..101, of which only 149..101 is new.
        Assert.Equal(IdsOf(batch).Distinct().Count(), batch.Items.Count);
        Assert.Equal(250, batch.NewestCount);
        Assert.Equal(49, batch.SweepCount);
        Assert.Equal(Enumerable.Range(101, 299).Reverse(), IdsOf(batch));
        Assert.Equal(101, batch.NextCursor);        // the sweep page itself was full
    }

    [Fact]
    public async Task Fewer_items_than_a_page_are_all_examined_every_cycle_with_one_query()
    {
        var pending = new FakePending(Enumerable.Range(1, 40));
        var sweep = new PendingSweep(Batch);

        var first = await Next(sweep, pending);
        var second = await Next(sweep, pending);

        Assert.Equal(40, first.Items.Count);
        Assert.Equal(40, second.Items.Count);
        Assert.Null(sweep.Cursor);
        Assert.Equal([null, null], pending.Calls);
    }

    [Fact]
    public async Task An_exact_multiple_of_the_page_wraps_on_the_empty_page_after_it()
    {
        var pending = new FakePending(Enumerable.Range(1, 500));
        var sweep = new PendingSweep(Batch);

        await Next(sweep, pending);                 // 500..251, cursor 251
        var second = await Next(sweep, pending);    // sweep 250..1, full
        Assert.Equal(1, second.NextCursor);

        var third = await Next(sweep, pending);     // sweep below 1: empty
        Assert.Equal(0, third.SweepCount);
        Assert.Null(third.NextCursor);
    }

    [Fact]
    public async Task Nothing_pending_returns_nothing_and_stays_at_the_top()
    {
        var pending = new FakePending([]);
        var sweep = new PendingSweep(Batch);

        var batch = await Next(sweep, pending);

        Assert.Empty(batch.Items);
        Assert.Null(sweep.Cursor);
    }

    [Fact]
    public async Task Reading_a_batch_does_not_move_the_cursor_until_it_is_committed()
    {
        // Review of PR #71: a cycle that fails part-way must not skip the rest of its sweep page.
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(Batch);
        await Next(sweep, pending);                 // cursor 351

        var failedCycle = await sweep.NextAsync(pending.FetchAsync, CancellationToken.None);
        Assert.Equal(101, failedCycle.NextCursor);
        Assert.Equal(351, sweep.Cursor);            // not committed: the cycle threw

        var retry = await Next(sweep, pending);
        Assert.Equal(351, retry.SweepFrom);         // the same sweep page again
        Assert.Equal(101, sweep.Cursor);
    }

    [Fact]
    public async Task A_stale_batch_cannot_move_the_cursor()
    {
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(Batch);

        var stale = await sweep.NextAsync(pending.FetchAsync, CancellationToken.None);
        await Next(sweep, pending);                 // committed: cursor 351
        await Next(sweep, pending);                 // committed: cursor 101

        sweep.Commit(stale);                        // read at the top, cursor has moved since

        Assert.Equal(101, sweep.Cursor);
    }

    [Fact]
    public async Task The_query_is_asked_for_the_same_page_size_the_wrap_test_uses()
    {
        // Review of PR #71: TOP and the "short page = bottom" test must be one number.
        var pending = new FakePending(Enumerable.Range(1, 600));
        var sweep = new PendingSweep(100);

        await Next(sweep, pending);
        await Next(sweep, pending);

        Assert.All(pending.Takes, take => Assert.Equal(100, take));
        Assert.Equal(401, sweep.Cursor);            // 600..501, then 500..401: both full pages
    }

    [Fact]
    public void A_page_size_of_zero_is_refused()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new PendingSweep(0));
    }
}
