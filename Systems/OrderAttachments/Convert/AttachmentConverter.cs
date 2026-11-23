using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.OrderAttachments.Msg;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>One openable piece of an order attachment.</summary>
/// <param name="PartId">Stable within the attachment; the S3 object name. "body" for the mail itself.</param>
/// <param name="Seq">Display order: the mail body first, then its documents as the mail lists them.</param>
/// <param name="Name">What the calibrator sees.</param>
/// <param name="Kind">MailBody | Document | Error.</param>
/// <param name="Error">Why this part could not be produced. The part is still listed (AC #6).</param>
/// <param name="Pdf">The PDF; null exactly when <paramref name="Error"/> is set.</param>
/// <param name="IsInfrastructureFailure">
/// The part failed because a converter was not available (see
/// <see cref="PdfConversionException.IsInfrastructure"/>), not because of the document.
/// </param>
public sealed record ConvertedPart(
    string PartId, int Seq, string Name, string Kind, string? Error, byte[]? Pdf, bool IsInfrastructureFailure = false);

/// <summary>Everything one Priority file turned into.</summary>
/// <param name="MergedPdf">
/// All successful parts as one document, body first. Null when fewer than two parts succeeded:
/// then the single part (if any) already is the whole attachment.
/// </param>
public sealed record ConvertedAttachment(IReadOnlyList<ConvertedPart> Parts, byte[]? MergedPdf);

/// <summary>
/// The file could not be read at all - missing, locked, access denied, network error. Says
/// nothing about the document, so the caller retries it later instead of recording it as broken.
/// </summary>
public sealed class AttachmentSourceUnreadableException(string message, bool notFound, Exception? inner = null)
    : Exception(message, inner)
{
    /// <summary>The file (or its folder) does not exist, as opposed to being unreadable now.</summary>
    public bool NotFound { get; } = notFound;
}

/// <summary>
/// Nothing in the file could be converted because a converter was not available (Chromium would
/// not start, LibreOffice missing). Says nothing about the document, so the sync retries it after
/// hours instead of recording it as converted.
/// </summary>
public sealed class AttachmentConversionUnavailableException(string message) : Exception(message);

/// <summary>
/// Turns one Priority file into the PDFs behind it, all in one pass (MBA-930).
///
/// A .msg is not one document. It is a body plus its real attachments, and the spike showed the
/// content is often in the attachment rather than the body - one sample was a boilerplate mail
/// wrapped around the .xlsx that mattered. So one file legitimately expands into several parts,
/// and AC #4 (body AND enclosed attachments) and AC #6 (nothing silently dropped) both depend on
/// that expansion being complete.
///
/// A part that cannot be converted comes back with its Error and no PDF. Only a file that cannot
/// be read at all throws, as <see cref="AttachmentSourceUnreadableException"/>.
/// </summary>
public sealed class AttachmentConverter(
    MsgExtractor extractor,
    PdfConverterRegistry converters,
    ChromiumRenderer renderer,
    PdfCombiner combiner,
    AttachmentShareMap shares,
    ILogger<AttachmentConverter> log)
{
    public const string BodyPartId = "body";

    public async Task<ConvertedAttachment> ConvertAsync(OrderAttachmentSource source, CancellationToken ct)
    {
        // Priority's stored path names the live share; STAGE reads priority-test's copy. A path on
        // the live server that this install must not read comes back null.
        var path = shares.Resolve(source.FilePath)
            ?? throw new AttachmentSourceUnreadableException(
                "This path is on the live Priority server, which this installation does not read.",
                notFound: true);

        var parts = source.SourceKind == "OutlookMessage"
            ? await ConvertMessageAsync(source, path, ct)
            : [await ConvertSingleFileAsync(source, path, ct)];

        if (parts.All(p => p.Pdf is null) && parts.Any(p => p.IsInfrastructureFailure))
        {
            throw new AttachmentConversionUnavailableException(
                parts.First(p => p.IsInfrastructureFailure).Error ?? "A converter was not available.");
        }

        var good = parts.Where(p => p.Pdf is not null).Select(p => p.Pdf!).ToList();

        byte[]? merged = null;
        if (good.Count >= 2)
        {
            try
            {
                merged = combiner.Merge(good);
            }
            catch (Exception ex)
            {
                // The parts are still there one by one; only the combined view is lost.
                log.LogWarning(ex, "Could not merge the parts of {Path}", path);
            }
        }

        return new ConvertedAttachment(parts, merged);
    }

    private async Task<ConvertedPart> ConvertSingleFileAsync(
        OrderAttachmentSource source, string path, CancellationToken ct)
    {
        var name = source.FileName;

        if (!converters.CanConvert(source.FileExtension ?? ""))
        {
            return Failed(BodyPartId, 0, name, string.IsNullOrEmpty(source.FileExtension)
                ? "This file has no extension, so its type is unknown."
                : $"A .{source.FileExtension} file cannot be converted to PDF.");
        }

        var bytes = await ReadSourceAsync(path, ct);

        try
        {
            var pdf = await converters.ConvertAsync(new ConversionSource(name, bytes), ct);
            return new ConvertedPart(BodyPartId, 0, name, "Document", null, pdf);
        }
        catch (PdfConversionException ex)
        {
            return Failed(BodyPartId, 0, name, ex.Message, ex.IsInfrastructure);
        }
    }

    private async Task<List<ConvertedPart>> ConvertMessageAsync(
        OrderAttachmentSource source, string path, CancellationToken ct)
    {
        // Read first, so a missing or locked file is told apart from a corrupt one.
        await EnsureReadableAsync(path, ct);

        ExtractedMessage msg;
        try
        {
            // Inline images become data: URIs, so the rendered page needs no file or network access.
            msg = extractor.Extract(path, DataUri);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // The probe read one byte; the reader can still lose the file halfway (locked, network).
            throw Unreadable(path, ex);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Could not open {Path} as an Outlook message", path);
            return [Failed("unavailable", 0, source.Description ?? source.FileName,
                "This Outlook message could not be opened: " + ex.Message)];
        }

        var parts = new List<ConvertedPart>();
        var seq = 0;

        var html = msg.BodyHtml ?? WrapPlainText(msg.BodyText);
        if (html is not null)
        {
            var subject = !string.IsNullOrWhiteSpace(msg.Subject) ? msg.Subject!
                : !string.IsNullOrWhiteSpace(source.Description) ? source.Description!
                : "(no subject)";
            try
            {
                parts.Add(new ConvertedPart(BodyPartId, seq, subject, "MailBody", null,
                    await renderer.RenderAsync(html, ct)));
            }
            catch (PdfConversionException ex)
            {
                parts.Add(Failed(BodyPartId, seq, subject, ex.Message, ex.IsInfrastructure));
            }
            seq++;
        }

        // Documents only: inline signature logos are not documents and must not be listed, or
        // every mail looks like it carries four attachments that are somebody's logo.
        var used = new HashSet<string>(StringComparer.Ordinal) { BodyPartId };
        foreach (var file in msg.Documents)
        {
            var partId = UniquePartId(file.FileName, used);

            if (!converters.CanConvert(file.Extension))
            {
                parts.Add(Failed(partId, seq++, file.FileName, file.Extension.Length == 0
                    ? "This attachment has no file extension, so its type is unknown."
                    : $"A .{file.Extension} attachment cannot be converted to PDF."));
                continue;
            }

            try
            {
                parts.Add(new ConvertedPart(partId, seq++, file.FileName, "Document", null,
                    await converters.ConvertAsync(new ConversionSource(file.FileName, file.Data), ct)));
            }
            catch (PdfConversionException ex)
            {
                parts.Add(Failed(partId, seq - 1, file.FileName, ex.Message, ex.IsInfrastructure));
            }
        }

        if (parts.Count == 0)
            parts.Add(Failed("unavailable", 0, source.Description ?? source.FileName,
                "This Outlook message has neither a body nor attachments."));

        return parts;
    }

    private static async Task<byte[]> ReadSourceAsync(string path, CancellationToken ct)
    {
        try
        {
            return await File.ReadAllBytesAsync(path, ct);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            throw Unreadable(path, ex);
        }
    }

    private static async Task EnsureReadableAsync(string path, CancellationToken ct)
    {
        try
        {
            await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1, true);
            var probe = new byte[1];
            _ = await stream.ReadAsync(probe, ct);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            throw Unreadable(path, ex);
        }
    }

    private static AttachmentSourceUnreadableException Unreadable(string path, Exception ex) =>
        new($"{ex.GetType().Name}: {ex.Message}",
            notFound: ex is FileNotFoundException or DirectoryNotFoundException,
            ex);

    private static ConvertedPart Failed(
        string partId, int seq, string name, string error, bool isInfrastructure = false) =>
        new(partId, seq, name, "Error", error, null, isInfrastructure);

    /// <summary>
    /// A URL-safe id for an attachment name. Hebrew file names are common here, so the name itself
    /// cannot be an S3 key segment. Two attachments with the same name in one mail get -2, -3, ...
    /// so neither overwrites the other.
    /// </summary>
    public static string PartIdFor(string fileName) =>
        System.Convert.ToHexString(
            System.Security.Cryptography.SHA256.HashData(
                System.Text.Encoding.UTF8.GetBytes(fileName)))[..16].ToLowerInvariant();

    private static string UniquePartId(string fileName, HashSet<string> used)
    {
        var id = PartIdFor(fileName);
        var candidate = id;
        for (var n = 2; !used.Add(candidate); n++) candidate = $"{id}-{n}";
        return candidate;
    }

    private static string DataUri(ExtractedFile file)
    {
        var media = file.Extension switch
        {
            "jpg" or "jpeg" => "image/jpeg",
            "png" => "image/png",
            "gif" => "image/gif",
            "bmp" => "image/bmp",
            _ => "application/octet-stream",
        };
        return $"data:{media};base64,{System.Convert.ToBase64String(file.Data)}";
    }

    private static string? WrapPlainText(string? text) =>
        text is null
            ? null
            : "<!doctype html><html><head><meta charset=\"utf-8\"></head>" +
              "<body dir=\"auto\" style=\"font:12pt/1.5 system-ui,sans-serif;white-space:pre-wrap\">" +
              System.Net.WebUtility.HtmlEncode(text) + "</body></html>";
}
