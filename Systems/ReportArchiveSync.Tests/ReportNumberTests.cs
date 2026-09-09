using Maba.VCT.ReportArchiveSync.Archive;

namespace Maba.VCT.ReportArchiveSync.Tests;

public class ReportNumberTests
{
    /// <summary>
    /// The database spells the number with a backslash, Priority with a slash, and the archive
    /// with a hyphen. All three refer to the same report.
    /// </summary>
    [Theory]
    [InlineData(@"2603086\4", "2603086", 4)]
    [InlineData("2608737/1", "2608737", 1)]
    [InlineData("2608438/12", "2608438", 12)]
    [InlineData(@"  2601001\63  ", "2601001", 63)]
    public void Parses_both_separators(string stored, string expectedBase, int expectedIndex)
    {
        Assert.True(ReportNumber.TryParse(stored, out var number));
        Assert.Equal(expectedBase, number.Value.Base);
        Assert.Equal(expectedIndex, number.Value.Index);
    }

    [Fact]
    public void Builds_the_archive_prefix()
    {
        Assert.True(ReportNumber.TryParse(@"2603086\4", out var number));
        Assert.Equal("2603086-4", number.Value.ArchivePrefix);
    }

    /// <summary>
    /// A hint for search ordering only. Re-issues are filed under the year they were produced, so
    /// the locator still has to sweep every folder.
    /// </summary>
    [Fact]
    public void Derives_the_likely_year_from_the_base()
    {
        Assert.True(ReportNumber.TryParse("2603086/4", out var number));
        Assert.Equal(2026, number.Value.LikelyYear);
    }

    /// <summary>
    /// Both of these are real values sitting in OrderDetailsItems on PROD. Neither can be resolved
    /// to a file, and inventing a base or an index would attach some other customer's report to
    /// the device.
    /// </summary>
    [Theory]
    [InlineData("123")]      // no separator, no index
    [InlineData(@"\1")]      // index but no base
    [InlineData("20054")]    // hand-entered, not a report number
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(@"2603086\")] // separator with nothing after it
    [InlineData(@"2603086\0")] // index is 1-based
    [InlineData(@"abc\1")]     // non-numeric base
    public void Rejects_malformed_stored_values(string? stored)
    {
        Assert.False(ReportNumber.TryParse(stored, out _));
    }
}
