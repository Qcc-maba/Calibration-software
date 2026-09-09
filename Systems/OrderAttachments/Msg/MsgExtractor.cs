using Maba.VCT.OrderAttachments.Text;
using MsgReader.Outlook;

namespace Maba.VCT.OrderAttachments.Msg;

/// <summary>
/// Opens one of Priority's .msg files and returns its body and attachments.
///
/// 99.3% of the documents Priority hangs off an order are Outlook messages, so this is the main
/// path through the service, not a special case. Everything here is shaped by what the MBA-930
/// spike found against ten live files:
///
///   * Windows-1255 must be registered first, or every file fails (<see cref="MsgEncoding"/>).
///   * The body's cid: images have to be re-pointed at the extracted files
///     (<see cref="InlineImageRewriter"/>).
///   * Quoted header blocks arrive as Latin-1-misread Hebrew (<see cref="HebrewTextRepair"/>).
///   * Inline signature images must not be presented as documents.
/// </summary>
public sealed class MsgExtractor
{
    private readonly ILogger<MsgExtractor> _log;

    public MsgExtractor(ILogger<MsgExtractor> log)
    {
        _log = log;
        MsgEncoding.EnsureRegistered();
    }

    /// <param name="path">Full UNC path to the .msg, as held in dbo.CrmOrderAttachments.FilePath.</param>
    /// <param name="inlineUrl">
    /// Maps an extracted inline image to something the renderer can load — a data: URI, or a URL
    /// this service serves. Called only for parts the body actually references.
    /// </param>
    public ExtractedMessage Extract(string path, Func<ExtractedFile, string> inlineUrl)
    {
        MsgEncoding.EnsureRegistered();

        using var msg = new Storage.Message(path);

        var files = new List<ExtractedFile>();
        foreach (var part in msg.Attachments)
        {
            switch (part)
            {
                case Storage.Attachment a:
                    files.Add(new ExtractedFile(
                        FileName: SafeName(a.FileName),
                        Data: a.Data,
                        ContentId: a.ContentId,
                        IsInline: a.IsInline));
                    break;

                // A forwarded chain carries the previous mail as a nested message rather than a
                // file. Not flattened here: the body already quotes it, and expanding it would
                // multiply one order into an unbounded tree of PDFs.
                case Storage.Message nested:
                    _log.LogDebug("Nested message {Subject} in {Path} left unexpanded", nested.Subject, path);
                    break;
            }
        }

        var html = msg.BodyHtml;
        if (html is not null)
        {
            html = HebrewTextRepair.Repair(html);

            var byKey = files
                .Where(f => !string.IsNullOrEmpty(f.ContentId))
                .GroupBy(f => InlineImageRewriter.KeyOf(f.ContentId!))
                .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

            // Fall back to the file name: some parts carry no content id at all but the body
            // still references them as cid:image001.png.
            var byName = files
                .GroupBy(f => Path.GetFileNameWithoutExtension(f.FileName))
                .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

            html = InlineImageRewriter.Rewrite(html, cid =>
            {
                var key = InlineImageRewriter.KeyOf(cid);
                if (byKey.TryGetValue(key, out var hit)) return inlineUrl(hit);
                if (byName.TryGetValue(Path.GetFileNameWithoutExtension(key), out hit)) return inlineUrl(hit);
                return null;
            });
        }

        return new ExtractedMessage
        {
            SourcePath = path,
            Subject = HebrewTextRepair.Repair(msg.Subject),
            SentOn = msg.SentOn,
            From = msg.Sender?.DisplayName,
            BodyHtml = html,
            BodyText = html is null ? HebrewTextRepair.Repair(msg.BodyText) : null,
            Files = files,
        };
    }

    /// <summary>
    /// Outlook file names carry directory separators, RTL marks and other characters that are
    /// illegal or dangerous in a path. One spike sample was named with a long run of U+200F.
    /// </summary>
    private static string SafeName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "unnamed";

        var cleaned = new string(name
            .Where(c => !char.IsControl(c) && c is not ('‎' or '‏' or '‪' or '‫' or '‬'))
            .ToArray());

        cleaned = string.Join("_", cleaned.Split(Path.GetInvalidFileNameChars()));
        cleaned = cleaned.Trim();

        return cleaned.Length == 0 ? "unnamed" : cleaned;
    }
}
