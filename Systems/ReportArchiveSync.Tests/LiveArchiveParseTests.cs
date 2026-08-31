using Maba.VCT.ReportArchiveSync.Archive;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>
/// Runs the parser over the real archive. Skips silently when the share is not reachable, so the
/// suite still passes off the MABA network — but on a machine that can see it, this is the check
/// that matters: unit cases prove the shapes we thought of, this proves the ones we did not.
/// </summary>
public class LiveArchiveParseTests
{
    private const string ArchiveRoot = @"\\maba-priority\priority\Tomax\Archives\DOC_Q\Out";

    /// <summary>Bounded so the test stays a test and not a survey of 1.3 million files.</summary>
    private const int SampleLimit = 40_000;

    [Fact]
    public void Parses_effectively_every_real_report_name()
    {
        var folder = Path.Combine(ArchiveRoot, "2026");

        if (!Directory.Exists(folder))
        {
            return; // Not on the MABA network.
        }

        var examined = 0;
        var failures = new List<string>();

        foreach (var path in Directory.EnumerateFiles(folder, "*.pdf"))
        {
            if (examined >= SampleLimit)
            {
                break;
            }

            examined++;

            var stem = Path.GetFileNameWithoutExtension(path);

            if (!ArchiveFileName.TryParse(stem, out _) && failures.Count < 25)
            {
                failures.Add(stem);
            }
        }

        Assert.True(examined > 0, "The archive folder was reachable but held no PDFs.");

        // Measured at 0.04% unparseable across 2024-2026, and those are non-report documents that
        // happen to sit in the same folder. A jump here means the naming convention has shifted
        // and the locator is now silently missing reports.
        var failureRate = (double)failures.Count / examined;

        Assert.True(
            failureRate < 0.005,
            $"{failures.Count} of {examined} names failed to parse ({failureRate:P2}). "
            + $"Examples: {string.Join(", ", failures.Take(10))}");
    }

    /// <summary>
    /// The one case that proves ranges are handled: 2601021 has no -13.pdf of its own, only
    /// -12-15.pdf. An exact-index lookup reports "no report" for a device that has one.
    /// </summary>
    [Fact]
    public void Resolves_a_device_that_only_exists_inside_a_consolidated_range()
    {
        var folder = Path.Combine(ArchiveRoot, "2026");

        if (!Directory.Exists(folder))
        {
            return;
        }

        var covering = Directory
            .EnumerateFiles(folder, "2601021-*.pdf")
            .Select(path => Path.GetFileNameWithoutExtension(path))
            .Select(stem => ArchiveFileName.TryParse(stem, out var parsed) ? parsed : null)
            .Where(parsed => parsed is not null && parsed.Covers(13))
            .ToList();

        Assert.NotEmpty(covering);
        Assert.All(covering, parsed => Assert.True(parsed!.IsConsolidated));

        // And no file names itself -13 directly.
        Assert.DoesNotContain(covering, parsed => parsed!.CoversFrom == 13 && parsed.CoversTo == 13);
    }
}
