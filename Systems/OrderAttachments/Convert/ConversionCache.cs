using System.Security.Cryptography;
using System.Text;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>
/// Keeps converted PDFs on disk so a file is converted once, the first time somebody opens it.
///
/// Conversion is on demand by design. There are ~13,200 orders carrying ~15,300 files, and most
/// of them will never be opened — a calibrator looks at the order in front of them. Converting the
/// whole corpus up front would burn hours of LibreOffice and Chromium time to produce documents
/// nobody asks for, and would have to be redone as Priority keeps adding files through the day.
///
/// The key includes the source file's last-write time, so a document Priority replaces in place
/// produces a different key and is re-converted rather than served stale from the cache.
/// </summary>
public sealed class ConversionCache(string directory, ILogger<ConversionCache> log)
{
    /// <param name="sourcePath">The .msg or document on the share.</param>
    /// <param name="partId">
    /// Which piece of it — the body, or an attachment name. One .msg produces several PDFs and
    /// they must not collide.
    /// </param>
    public async Task<byte[]> GetOrCreateAsync(
        string sourcePath,
        string partId,
        Func<CancellationToken, Task<byte[]>> convert,
        CancellationToken ct = default)
    {
        var path = PathFor(sourcePath, partId);

        if (File.Exists(path))
        {
            try
            {
                return await File.ReadAllBytesAsync(path, ct);
            }
            catch (IOException ex)
            {
                // A half-written entry from a crashed run, or a concurrent write. Convert again
                // rather than serving a truncated PDF.
                log.LogWarning(ex, "Cache entry {Path} unreadable; reconverting", path);
            }
        }

        var pdf = await convert(ct);

        Directory.CreateDirectory(Path.GetDirectoryName(path)!);

        // Write to a temporary name and move into place, so a reader never sees a partial file.
        var temp = path + "." + Guid.NewGuid().ToString("N")[..8] + ".tmp";
        try
        {
            await File.WriteAllBytesAsync(temp, pdf, ct);
            File.Move(temp, path, overwrite: true);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Could not cache {Path}; serving the conversion directly", path);
            TryDelete(temp);
        }

        return pdf;
    }

    private string PathFor(string sourcePath, string partId)
    {
        var stamp = File.Exists(sourcePath)
            ? File.GetLastWriteTimeUtc(sourcePath).Ticks.ToString()
            : "missing";

        var key = Hash($"{sourcePath}|{stamp}|{partId}");

        // Two levels of fan-out: a flat directory of tens of thousands of files is slow to
        // enumerate and unpleasant to look at on a server.
        return Path.Combine(directory, key[..2], key[2..4], key + ".pdf");
    }

    private static string Hash(string value)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return System.Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); }
        catch { /* best effort */ }
    }
}
