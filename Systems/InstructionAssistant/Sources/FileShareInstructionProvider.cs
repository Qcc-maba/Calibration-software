using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Extraction;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>
/// Scans the configured network roots for instruction files relevant to the instrument.
/// Matching is heuristic and intentionally conservative until the real folder convention
/// is known (see PLAN.md): a file matches when its path contains the customer id/name,
/// the serial number, or the device type. Serial-number matches rank highest.
/// </summary>
public sealed class FileShareInstructionProvider(
    IOptions<InstructionAssistantOptions> options,
    CompositeTextExtractor extractor,
    ILogger<FileShareInstructionProvider> logger) : IInstructionSourceProvider
{
    private readonly FileShareOptions _fs = options.Value.FileShare;

    public string Name => "file-share";

    public async Task<IReadOnlyList<InstructionDocument>> FindAsync(InstrumentContext ctx, CancellationToken ct = default)
    {
        var keys = BuildMatchKeys(ctx);
        if (keys.Count == 0 || _fs.Roots.Count == 0) return [];

        var scored = new List<(int score, string reason, string path)>();
        foreach (var root in _fs.Roots)
        {
            if (!Directory.Exists(root))
            {
                logger.LogWarning("Instruction root not found: {Root}", root);
                continue;
            }

            IEnumerable<string> files;
            try
            {
                var opt = _fs.Recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
                files = Directory.EnumerateFiles(root, "*.*", opt)
                    .Where(f => _fs.Extensions.Contains(Path.GetExtension(f).ToLowerInvariant()));
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to enumerate {Root}", root);
                continue;
            }

            foreach (var file in files)
            {
                ct.ThrowIfCancellationRequested();
                var (score, reason) = ScorePath(file, keys);
                if (score > 0) scored.Add((score, reason, file));
            }
        }

        // The share keeps revised copies of the same instruction (there is a "מעודכן 2025"
        // sub-folder holding newer versions under the same file names), so equally-scoring
        // candidates are broken by modification time — newest first — not alphabetically.
        var top = scored
            .OrderByDescending(s => s.score)
            .ThenByDescending(s => LastWriteOrMin(s.path))
            .ThenBy(s => s.path)
            .Take(_fs.MaxFiles)
            .ToList();

        var docs = new List<InstructionDocument>(top.Count);
        foreach (var (_, reason, path) in top)
        {
            var doc = new InstructionDocument
            {
                Source = InstructionSourceType.FileShare,
                Title = Path.GetFileName(path),
                Reference = path,
                MediaType = MediaTypeOf(Path.GetExtension(path)),
                MatchReason = reason,
            };
            await extractor.ExtractAsync(path, doc, _fs.MaxCharsPerFile, ct);
            docs.Add(doc);
        }
        return docs;
    }

    private static DateTime LastWriteOrMin(string path)
    {
        try { return File.GetLastWriteTimeUtc(path); }
        catch { return DateTime.MinValue; }
    }

    /// <summary>Match keys ordered so the caller can weight serial &gt; customer &gt; device.</summary>
    private static List<(string value, int weight, string label)> BuildMatchKeys(InstrumentContext ctx)
    {
        var keys = new List<(string, int, string)>();
        void Add(string? v, int w, string label)
        {
            if (!string.IsNullOrWhiteSpace(v) && v!.Trim().Length >= 3)
                keys.Add((v.Trim(), w, label));
        }
        Add(ctx.SerialNumber, 100, "מס' סידורי");
        // The ECS files on the share are named after the customer's own asset number.
        Add(ctx.CustomerAssetNumber, 90, "מספר נכס של הלקוח");
        Add(ctx.CustomerId, 40, "מספר לקוח");
        Add(ctx.CustomerName, 30, "שם לקוח");
        Add(ctx.Model, 15, "דגם");
        Add(ctx.DeviceType, 10, "סוג מכשיר");
        return keys;
    }

    private static (int score, string reason) ScorePath(string path, List<(string value, int weight, string label)> keys)
    {
        var hay = path.Replace('\\', '/');
        int best = 0; string reason = "";
        foreach (var (value, weight, label) in keys)
        {
            if (hay.Contains(value, StringComparison.OrdinalIgnoreCase) && weight > best)
            {
                best = weight;
                reason = $"התאמה לפי {label}";
            }
        }
        return (best, reason);
    }

    private static string MediaTypeOf(string ext) => ext.ToLowerInvariant() switch
    {
        ".txt" or ".log" => "text/plain",
        ".md" => "text/markdown",
        ".csv" => "text/csv",
        ".pdf" => "application/pdf",
        ".doc" => "application/msword",
        ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        _ => "application/octet-stream",
    };
}
