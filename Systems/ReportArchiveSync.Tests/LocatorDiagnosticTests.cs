using Maba.VCT.ReportArchiveSync.Archive;
using Microsoft.Extensions.Logging.Abstractions;

namespace Maba.VCT.ReportArchiveSync.Tests;

public class LocatorDiagnosticTests
{
    private const string ArchiveRoot = @"\\maba-priority\priority\Tomax\Archives\DOC_Q\Out";

    /// <summary>
    /// 2608531-1..17 exist in the 2026 folder and the database wants exactly indices 1..17, yet a
    /// dry run reported "no file" for all seventeen. This pins where the chain breaks.
    /// </summary>
    [Fact]
    public void Diagnose_2608531()
    {
        if (!Directory.Exists(ArchiveRoot))
        {
            return;
        }

        Assert.True(ReportNumber.TryParse("2608531/17", out var number));

        var raw = new DirectoryInfo(Path.Combine(ArchiveRoot, "2026"))
            .EnumerateFiles("2608531-*")
            .Select(f => f.Name)
            .ToList();

        var locator = new ArchiveLocator(ArchiveRoot, NullLogger<ArchiveLocator>.Instance);
        var found = locator.FindAll(number.Value);

        Assert.True(
            found.Count > 0,
            $"""
             Base={number.Value.Base} Index={number.Value.Index} LikelyYear={number.Value.LikelyYear}
             Raw wildcard hits in 2026 = {raw.Count}: {string.Join(", ", raw.Take(5))}
             Directories seen by locator = {string.Join(" | ", Directory.EnumerateDirectories(ArchiveRoot).Select(Path.GetFileName))}
             Parse of first raw name -> {(raw.Count > 0 && ArchiveFileName.TryParse(Path.GetFileNameWithoutExtension(raw[0]), out var p) ? $"base={p.Base} from={p.CoversFrom} to={p.CoversTo} variant='{p.Variant}' u={p.UpdateLevel}" : "PARSE FAILED")}
             """);
    }
}
