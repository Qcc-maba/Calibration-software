using Microsoft.Extensions.Logging;

namespace Maba.VCT.ReportArchiveSync.Archive;

/// <summary>One archive file that serves a given report number.</summary>
public sealed record ArchiveCandidate(
    ArchiveFileName Name,
    string FullPath,
    long Length,
    DateTime LastWriteTimeUtc);

/// <summary>
/// Finds the report PDFs for a report number in Priority's Tomax archive.
/// </summary>
/// <remarks>
/// The archive is an SMB share holding ~1.3 million files spread over per-year folders plus the
/// root. A full sweep is far too slow to do per device, so every lookup is a server-side pattern
/// match on <c>{base}-*</c> — measured at ~230 ms cold and ~7 ms warm against a folder of 58,743
/// files. Twenty folders per lookup still lands under a second.
/// <para>
/// The share is opened READ-ONLY. Nothing in this service may write to it: it is Priority's own
/// document archive.
/// </para>
/// </remarks>
public sealed class ArchiveLocator(string archiveRoot, ILogger<ArchiveLocator> logger)
{
    private readonly ILogger<ArchiveLocator> _logger = logger;

    /// <summary>
    /// Directories to search, ordered so the report's likely year comes first. Resolved per call
    /// rather than cached, so a new year folder appearing on 1 January needs no restart.
    /// </summary>
    private IEnumerable<string> SearchDirectories(ReportNumber number)
    {
        var likely = number.LikelyYear;

        var years = Directory.Exists(archiveRoot)
            ? Directory.EnumerateDirectories(archiveRoot).ToList()
            : [];

        // The root itself holds files too (older material that was never foldered).
        var ordered = years
            .OrderByDescending(dir => likely is not null
                && Path.GetFileName(dir) == likely.Value.ToString());

        return ordered.Prepend(archiveRoot);
    }

    /// <summary>
    /// Every archive file that covers <paramref name="number"/>, across all year folders.
    /// </summary>
    /// <remarks>
    /// All folders are swept, never just the one the base implies: a re-issue is filed under the
    /// year it was produced. Report <c>2412012-77</c> genuinely lives in three different folders.
    /// </remarks>
    public IReadOnlyList<ArchiveCandidate> FindAll(ReportNumber number)
    {
        var found = new Dictionary<string, ArchiveCandidate>(StringComparer.OrdinalIgnoreCase);

        foreach (var directory in SearchDirectories(number))
        {
            // Two passes, because they fail differently. The wildcard sweep is the only way to
            // discover variants, updates and consolidated ranges — but a dry run against STAGE
            // showed it returning nothing for files that provably existed at the time and were
            // found again half an hour later. The cause is not established; a directory scan over
            // SMB against a folder of ~58,000 live files is simply not something to stake a
            // customer's report on. An exact-name stat is a single, far more dependable call, and
            // it covers the overwhelmingly common case of one plain report per device.
            var exact = ProbeExactName(directory, number, found);
            var swept = SweepWildcard(directory, number, found);

            if (exact && !swept)
            {
                // Worth shouting about: the sweep missed a file the stat could see, so any
                // variant or update of it would have been missed too.
                _logger.LogWarning(
                    "Wildcard sweep of {Directory} returned nothing for {Prefix} but the file "
                    + "exists. Variants or updates of this report may have been missed this cycle.",
                    directory, number.ArchivePrefix);
            }
        }

        return found.Values.ToList();
    }

    /// <summary>
    /// Stats <c>{base}-{index}.pdf</c> directly. Returns true when it was found.
    /// </summary>
    private bool ProbeExactName(
        string directory, ReportNumber number, Dictionary<string, ArchiveCandidate> found)
    {
        // The share holds both casings; NTFS is case-insensitive but the check is cheap and this
        // code also has to behave on a case-sensitive mount.
        foreach (var extension in (string[])[".pdf", ".PDF"])
        {
            var path = Path.Combine(directory, number.ArchivePrefix + extension);

            try
            {
                var file = new FileInfo(path);

                if (!file.Exists)
                {
                    continue;
                }

                if (ArchiveFileName.TryParse(Path.GetFileNameWithoutExtension(file.Name), out var parsed)
                    && parsed.Base == number.Base
                    && parsed.Covers(number.Index))
                {
                    found[file.FullName] =
                        new ArchiveCandidate(parsed, file.FullName, file.Length, file.LastWriteTimeUtc);
                    return true;
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                _logger.LogWarning(ex, "Archive file {Path} could not be read", path);
            }
        }

        return false;
    }

    /// <summary>
    /// Sweeps <c>{base}-*</c> to pick up variants, updates and consolidated ranges. Returns true
    /// when at least one covering file was found.
    /// </summary>
    private bool SweepWildcard(
        string directory, ReportNumber number, Dictionary<string, ArchiveCandidate> found)
    {
        IEnumerable<FileInfo> matches;

        try
        {
            // Enumerating FileInfo (not paths) carries Length and timestamps along from the
            // directory listing; a later stat per file would be another round-trip each, which is
            // what makes a naive implementation crawl over SMB.
            matches = new DirectoryInfo(directory).EnumerateFiles($"{number.Base}-*");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // A single unreachable folder must not fail the whole lookup — the share can be
            // briefly unavailable, and permissions differ between year folders.
            _logger.LogWarning(ex, "Archive folder {Directory} could not be listed", directory);
            return false;
        }

        var any = false;

        foreach (var file in matches)
        {
            if (!file.Extension.Equals(".pdf", StringComparison.OrdinalIgnoreCase))
            {
                // .xls / .doc / .prn also live here. They are not calibration reports.
                continue;
            }

            var stem = Path.GetFileNameWithoutExtension(file.Name);

            if (!ArchiveFileName.TryParse(stem, out var parsed))
            {
                _logger.LogInformation(
                    "Archive file {File} does not match the report naming convention; skipped",
                    file.FullName);
                continue;
            }

            if (parsed.Base != number.Base || !parsed.Covers(number.Index))
            {
                // The wildcard also returns 2601001-40..49 when looking for -4. Range containment
                // is what actually decides.
                continue;
            }

            found[file.FullName] = new ArchiveCandidate(parsed, file.FullName, file.Length, file.LastWriteTimeUtc);
            any = true;
        }

        return any;
    }

    /// <summary>
    /// The reports currently valid for <paramref name="number"/> — one per variant, each at its
    /// highest update level.
    /// </summary>
    /// <remarks>
    /// Two different rules, applied on two different axes, and collapsing them loses data:
    /// variants (<c>a</c>/<c>b</c>/<c>c</c>) are separate reports and are ALL returned; update
    /// levels (<c>u1</c>/<c>u2</c>) are revisions and only the highest is returned. Ties within a
    /// variant and level fall back to the newer file, then to the name for determinism.
    /// </remarks>
    public IReadOnlyList<ArchiveCandidate> FindCurrent(ReportNumber number) =>
        FindAll(number)
            .GroupBy(candidate => candidate.Name.Variant, StringComparer.OrdinalIgnoreCase)
            .Select(group => group
                .OrderByDescending(candidate => candidate.Name.UpdateLevel)
                .ThenByDescending(candidate => candidate.LastWriteTimeUtc)
                .ThenBy(candidate => candidate.Name.FileName, StringComparer.OrdinalIgnoreCase)
                .First())
            .OrderBy(candidate => candidate.Name.Variant, StringComparer.OrdinalIgnoreCase)
            .ToList();
}
