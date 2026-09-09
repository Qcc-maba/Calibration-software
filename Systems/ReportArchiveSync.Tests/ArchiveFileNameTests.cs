using Maba.VCT.ReportArchiveSync.Archive;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>
/// Every name in these cases was taken from the live archive at
/// \\maba-priority\priority\Tomax\Archives\DOC_Q\Out — none are invented.
/// </summary>
public class ArchiveFileNameTests
{
    [Theory]
    // Plain reports. Index width varies from one to three digits.
    [InlineData("2601001-1", "2601001", 1, 1, "", 0)]
    [InlineData("2503003-20", "2503003", 20, 20, "", 0)]
    [InlineData("2601347-100", "2601347", 100, 100, "", 0)]
    // Update levels: a re-issue of the same report.
    [InlineData("2601003-3u1", "2601003", 3, 3, "", 1)]
    [InlineData("2601045-10u1", "2601045", 10, 10, "", 1)]
    [InlineData("2412012-77u1", "2412012", 77, 77, "", 1)]
    [InlineData("2404004-52_u1", "2404004", 52, 52, "", 1)]
    // Variants: separate reports splitting measurement domains.
    [InlineData("2601089-1a", "2601089", 1, 1, "a", 0)]
    [InlineData("2601089-1b", "2601089", 1, 1, "b", 0)]
    [InlineData("2601089-1c", "2601089", 1, 1, "c", 0)]
    [InlineData("2601131-1d", "2601131", 1, 1, "d", 0)]
    [InlineData("2603195-2g", "2603195", 2, 2, "g", 0)]
    [InlineData("2601622-10a", "2601622", 10, 10, "a", 0)]
    // Consolidated reports: one PDF, several instruments.
    [InlineData("2601001-63-75", "2601001", 63, 75, "", 0)]
    [InlineData("2601021-12-15", "2601021", 12, 15, "", 0)]
    // A consolidated report that was itself re-issued.
    [InlineData("2601021-12u1-15u1", "2601021", 12, 15, "", 1)]
    // Trailing underscore — noise, no meaning.
    [InlineData("2602112-2_", "2602112", 2, 2, "", 0)]
    public void Parses_real_archive_names(
        string name, string expectedBase, int from, int to, string variant, int updateLevel)
    {
        Assert.True(ArchiveFileName.TryParse(name, out var parsed));
        Assert.Equal(expectedBase, parsed.Base);
        Assert.Equal(from, parsed.CoversFrom);
        Assert.Equal(to, parsed.CoversTo);
        Assert.Equal(variant, parsed.Variant);
        Assert.Equal(updateLevel, parsed.UpdateLevel);
    }

    /// <summary>
    /// The XX marker is part of the update notation, so an update level hidden inside the
    /// underscore tail still has to be found. A parser that only looks at the modifiers directly
    /// attached to the index reads _XXu1 as update level 0 and then serves the superseded original
    /// instead of the re-issue.
    /// </summary>
    [Theory]
    [InlineData("2412012-77_XXu1", 77, 77, "", 1)]
    [InlineData("2108445-2_xxu2", 2, 2, "", 2)]
    public void Finds_the_update_level_inside_an_XX_tail(
        string name, int from, int to, string variant, int updateLevel)
    {
        Assert.True(ArchiveFileName.TryParse(name, out var parsed));
        Assert.Equal(from, parsed.CoversFrom);
        Assert.Equal(to, parsed.CoversTo);
        Assert.Equal(variant, parsed.Variant);
        Assert.Equal(updateLevel, parsed.UpdateLevel);
    }

    /// <summary>XX must be stripped before letters are read, or _XXA reads as variant "x".</summary>
    [Fact]
    public void Does_not_mistake_the_XX_marker_for_a_variant()
    {
        Assert.True(ArchiveFileName.TryParse("2001122-6_XXA", out var parsed));
        Assert.Equal("a", parsed.Variant);
        Assert.Equal(0, parsed.UpdateLevel);
    }

    /// <summary>A bare "u" with no digits is the first update — 243 such files exist.</summary>
    [Fact]
    public void Treats_a_bare_u_as_update_level_one()
    {
        Assert.True(ArchiveFileName.TryParse("2601045-10u", out var parsed));
        Assert.Equal(1, parsed.UpdateLevel);
    }

    /// <summary>
    /// The wildcard lookup for index 4 also returns 40-49. Coverage, not prefix matching, is what
    /// keeps the wrong PDF off the device.
    /// </summary>
    [Fact]
    public void Covers_only_its_own_index()
    {
        Assert.True(ArchiveFileName.TryParse("2601001-4", out var single));
        Assert.True(single.Covers(4));
        Assert.False(single.Covers(40));
        Assert.False(single.Covers(3));
        Assert.False(single.IsConsolidated);
    }

    /// <summary>
    /// A device inside a consolidated range has no file of its own: 2601021 has no -13.pdf, only
    /// -12-15.pdf. Exact-index matching would report "no report" for a device that has one.
    /// </summary>
    [Fact]
    public void A_consolidated_report_covers_every_index_in_its_range()
    {
        Assert.True(ArchiveFileName.TryParse("2601021-12-15", out var range));
        Assert.True(range.IsConsolidated);
        Assert.True(range.Covers(12));
        Assert.True(range.Covers(13));
        Assert.True(range.Covers(15));
        Assert.False(range.Covers(11));
        Assert.False(range.Covers(16));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("2601001")]          // no index at all
    [InlineData("-1")]               // no base
    [InlineData("abc-1")]            // non-numeric base
    [InlineData("2601021-15-12")]    // inverted range: would attach one PDF to 12..15 backwards
    public void Rejects_names_that_are_not_reports(string? name)
    {
        Assert.False(ArchiveFileName.TryParse(name, out _));
    }
}
