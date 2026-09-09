using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;

namespace Maba.VCT.ReportArchiveSync.Archive;

/// <summary>
/// One parsed file name from Priority's Tomax archive.
/// </summary>
/// <remarks>
/// <para>
/// Names follow <c>{base}-{from}[modifiers][-{to}[modifiers]][_tail]</c>. Measured over the
/// 265,035 PDFs filed in 2024-2026, this parser accepts every name that belongs to a calibration
/// report; the ~0.04% it rejects are unrelated documents.
/// </para>
/// <para><b>The three things a name can encode, and why they are not interchangeable:</b></para>
/// <list type="number">
///   <item><description>
///     <b>Update level</b> — <c>u1</c>, <c>u2</c>: a re-issue of the SAME report, after a
///     recalibration or a calibration following an adjustment (כיול אחרי כיוון). The highest
///     number supersedes everything below it.
///   </description></item>
///   <item><description>
///     <b>Variant</b> — a trailing <c>a</c>, <c>b</c>, <c>c</c>...: a SEPARATE report, issued to
///     split measurement domains (הפרדת תחומים). Variants coexist; picking one loses the others.
///     Rare but real — 202 devices carry more than one, the record holder has 12.
///   </description></item>
///   <item><description>
///     <b>Coverage range</b> — <c>-63-75</c>: a consolidated report holding the results of several
///     instruments in one PDF. When one exists the individual per-index files typically do not.
///   </description></item>
/// </list>
/// <para><b>The <c>XX</c> marker</b> is part of the update notation, not a meaning of its own, so
/// <c>_XXu1</c> ranks exactly as <c>u1</c> does. Confirmed with the business twice, and consistent
/// with the archive: across 2024-2026 only ONE base+index has both an <c>_XX</c> file and a plain
/// one, and there the <c>_XX</c> file is the newer of the two.</para>
/// </remarks>
public sealed record ArchiveFileName
{
    /// <summary>
    /// Splits the name into the base, the index (or index range), and the raw modifier text
    /// trailing each index. The modifiers are interpreted afterwards, because an update level can
    /// appear in any of them — including inside the underscore tail, as in <c>-77_XXu1</c>.
    /// </summary>
    private static readonly Regex Pattern = new(
        """
        ^
        (?<base>\d{6,8})
        -
        (?<from>\d+) (?<fromMods>[A-Za-z]*\d*)
        (?: - (?<to>\d+) (?<toMods>[A-Za-z]*\d*) )?
        (?<tail>_.*)?
        $
        """,
        RegexOptions.IgnorePatternWhitespace | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    /// <summary>Finds every <c>u&lt;digits&gt;</c> (or a bare trailing <c>u</c>) in a modifier run.</summary>
    private static readonly Regex UpdateMarker = new(
        @"u(?<level>\d*)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private ArchiveFileName(
        string fileName, string @base, int coversFrom, int coversTo, string variant, int updateLevel)
    {
        FileName = fileName;
        Base = @base;
        CoversFrom = coversFrom;
        CoversTo = coversTo;
        Variant = variant;
        UpdateLevel = updateLevel;
    }

    /// <summary>The file name as it appears on disk, without directory or extension.</summary>
    public string FileName { get; }

    public string Base { get; }

    public int CoversFrom { get; }

    public int CoversTo { get; }

    /// <summary>Empty for the plain report; <c>"a"</c>, <c>"b"</c>... for a domain-split sibling.</summary>
    public string Variant { get; }

    /// <summary>0 for the original, 1 for <c>u1</c>, 2 for <c>u2</c>...</summary>
    public int UpdateLevel { get; }

    /// <summary>True when this single PDF covers more than one report index.</summary>
    public bool IsConsolidated => CoversTo > CoversFrom;

    /// <summary>Whether this file is the report for <paramref name="index"/>.</summary>
    /// <remarks>
    /// Range containment, not string matching. A device whose report number is <c>2601021\13</c>
    /// is served by <c>2601021-12-15.pdf</c> and has no file of its own — and conversely a prefix
    /// match on <c>2601001-4</c> would wrongly swallow <c>2601001-40</c>…<c>-49</c>.
    /// </remarks>
    public bool Covers(int index) => index >= CoversFrom && index <= CoversTo;

    /// <summary>
    /// Parses an archive file name. <paramref name="name"/> is the file name without its
    /// extension; callers filter to <c>.pdf</c>/<c>.PDF</c> beforehand.
    /// </summary>
    public static bool TryParse(string? name, [NotNullWhen(true)] out ArchiveFileName? parsed)
    {
        parsed = null;

        if (string.IsNullOrWhiteSpace(name))
        {
            return false;
        }

        var match = Pattern.Match(name.Trim());

        if (!match.Success)
        {
            return false;
        }

        if (!int.TryParse(match.Groups["from"].Value, out var from))
        {
            return false;
        }

        var to = from;

        if (match.Groups["to"].Success && int.TryParse(match.Groups["to"].Value, out var parsedTo))
        {
            // Guard against a name like "2601021-15-12" — and also against the "-{n}-{n}" shape
            // that is a second index rather than a range. Treating an inverted pair as a range
            // would attach one PDF to every device in between.
            if (parsedTo < from)
            {
                return false;
            }

            to = parsedTo;
        }

        // An update level may sit after the first index (77u1), after the second (12u1-15u1), or
        // inside the tail (_XXu1, _u1). Take the highest seen: the file is that re-issue.
        var mods = new[]
        {
            match.Groups["fromMods"].Value,
            match.Groups["toMods"].Value,
            match.Groups["tail"].Value,
        };

        var updateLevel = 0;
        var variant = string.Empty;

        foreach (var mod in mods)
        {
            if (string.IsNullOrEmpty(mod))
            {
                continue;
            }

            // "XX" is notation, not content. Strip it first, or "_XXA" would read as variant "x".
            var cleaned = mod.Replace("XX", string.Empty, StringComparison.OrdinalIgnoreCase);

            foreach (Match marker in UpdateMarker.Matches(cleaned))
            {
                // A bare trailing "u" with no digits means the first update — 243 such files exist.
                var level = marker.Groups["level"].Value.Length == 0
                    ? 1
                    : int.Parse(marker.Groups["level"].Value);

                updateLevel = Math.Max(updateLevel, level);
            }

            if (variant.Length != 0)
            {
                continue;
            }

            // Whatever letters remain once the update markers are removed identify the variant.
            var withoutUpdates = UpdateMarker.Replace(cleaned, string.Empty);
            var letter = withoutUpdates.FirstOrDefault(char.IsAsciiLetter);

            if (letter != default)
            {
                variant = char.ToLowerInvariant(letter).ToString();
            }
        }

        parsed = new ArchiveFileName(name.Trim(), match.Groups["base"].Value, from, to, variant, updateLevel);
        return true;
    }
}
