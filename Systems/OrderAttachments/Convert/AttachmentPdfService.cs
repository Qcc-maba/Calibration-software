using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.OrderAttachments.Msg;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>One openable piece of an order attachment, as offered to the calibrator.</summary>
/// <param name="PartId">Stable within the attachment; used as the cache key and in the URL.</param>
/// <param name="Name">What the calibrator sees.</param>
/// <param name="Kind">MailBody | Document | Error.</param>
/// <param name="Error">Set when this part could not be produced. The part is still listed.</param>
public sealed record AttachmentPart(string PartId, string Name, string Kind, string? Error = null);

/// <summary>
/// Turns one row of dbo.CrmOrderAttachments into the set of PDFs behind it.
///
/// A .msg is not one document. It is a body plus its real attachments, and the spike showed the
/// content is often in the attachment rather than the body — one sample was a boilerplate mail
/// wrapped around the .xlsx that mattered. So one row can legitimately expand into several parts,
/// and both AC #4 (body AND enclosed attachments) and AC #6 (nothing silently dropped) depend on
/// that expansion being complete.
/// </summary>
public sealed class AttachmentPdfService(
    MsgExtractor extractor,
    PdfConverterRegistry converters,
    ChromiumRenderer renderer,
    ConversionCache cache,
    PdfCombiner combiner,
    ILogger<AttachmentPdfService> log)
{
    public const string BodyPartId = "body";

    /// <summary>Part id for "everything in this attachment, as one document".</summary>
    public const string MergedPartId = "all";

    /// <summary>Lists what an attachment contains, without converting anything.</summary>
    public IReadOnlyList<AttachmentPart> Describe(OrderAttachmentRow row)
    {
        if (!row.CanBeServed)
        {
            return
            [
                new AttachmentPart("unavailable", row.Description ?? row.FileName ?? "(unnamed)", "Error",
                    "Priority stored a truncated path for this file, so it cannot be located on the share. " +
                    "The document exists but cannot be opened."),
            ];
        }

        var path = row.FilePath!;

        if (row.SourceKind != "OutlookMessage")
        {
            var name = row.FileName ?? Path.GetFileName(path);
            return
            [
                converters.CanConvert(row.FileExtension ?? "")
                    ? new AttachmentPart(BodyPartId, name, "Document")
                    : new AttachmentPart(BodyPartId, name, "Error",
                        $"A .{row.FileExtension} file cannot be converted to PDF."),
            ];
        }

        try
        {
            var msg = extractor.Extract(path, _ => string.Empty);
            var parts = new List<AttachmentPart>();

            if (msg.BodyHtml is not null || msg.BodyText is not null)
                parts.Add(new AttachmentPart(BodyPartId, Subject(msg, row), "MailBody"));

            // Documents only: inline signature logos are not documents and must not be listed,
            // or every mail looks like it carries four attachments that are somebody's logo.
            foreach (var file in msg.Documents)
            {
                parts.Add(converters.CanConvert(file.Extension)
                    ? new AttachmentPart(PartIdFor(file.FileName), file.FileName, "Document")
                    : new AttachmentPart(PartIdFor(file.FileName), file.FileName, "Error",
                        file.Extension.Length == 0
                            ? "This attachment has no file extension, so its type is unknown."
                            : $"A .{file.Extension} attachment cannot be converted to PDF."));
            }

            return parts;
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Could not open {Path}", path);
            return
            [
                new AttachmentPart("unavailable", row.Description ?? Path.GetFileName(path), "Error",
                    "This Outlook message could not be opened: " + ex.Message),
            ];
        }
    }

    /// <summary>
    /// Everything in one attachment as a single PDF: the mail body first, then each document
    /// inside it, in the order a reader expects.
    ///
    /// Parts that cannot be converted are SKIPPED here rather than failing the whole merge — one
    /// unreadable enclosure must not cost the calibrator the purchase order next to it. Those
    /// parts are still listed by <see cref="Describe"/> with their error, which is where the
    /// calibrator learns they exist.
    /// </summary>
    public async Task<byte[]> GetMergedPdfAsync(OrderAttachmentRow row, CancellationToken ct)
    {
        var convertible = Describe(row).Where(p => p.Kind != "Error").ToList();
        if (convertible.Count == 0)
            throw new PdfConversionException("Nothing in this attachment can be converted to PDF.");

        var parts = new List<byte[]>(convertible.Count);
        foreach (var part in convertible)
        {
            try
            {
                parts.Add(await GetPdfAsync(row, part.PartId, ct));
            }
            catch (PdfConversionException ex)
            {
                log.LogWarning(ex, "Skipping {Part} while merging {Path}", part.PartId, row.FilePath);
            }
        }

        if (parts.Count == 0)
            throw new PdfConversionException("Every part of this attachment failed to convert.");

        return combiner.Merge(parts);
    }

    /// <summary>Produces one part as PDF, from cache when it has been asked for before.</summary>
    public async Task<byte[]> GetPdfAsync(OrderAttachmentRow row, string partId, CancellationToken ct)
    {
        if (!row.CanBeServed)
            throw new PdfConversionException("Priority stored a truncated path for this file.");

        var path = row.FilePath!;

        return await cache.GetOrCreateAsync(path, partId, async token =>
        {
            if (row.SourceKind != "OutlookMessage")
            {
                var bytes = await File.ReadAllBytesAsync(path, token);
                return await converters.ConvertAsync(
                    new ConversionSource(row.FileName ?? Path.GetFileName(path), bytes), token);
            }

            // Inline images become data: URIs. The rendered page then needs no network and no
            // file access of its own, which is both faster and one less thing to get wrong.
            var msg = extractor.Extract(path, DataUri);

            if (partId == BodyPartId)
            {
                var html = msg.BodyHtml
                           ?? WrapPlainText(msg.BodyText)
                           ?? throw new PdfConversionException("This message has no body.");
                return await renderer.RenderAsync(html, token);
            }

            var file = msg.Documents.FirstOrDefault(f => PartIdFor(f.FileName) == partId)
                ?? throw new PdfConversionException($"No attachment '{partId}' in this message.");

            return await converters.ConvertAsync(new ConversionSource(file.FileName, file.Data), token);
        }, ct);
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

    private static string Subject(ExtractedMessage msg, OrderAttachmentRow row) =>
        !string.IsNullOrWhiteSpace(msg.Subject) ? msg.Subject!
        : !string.IsNullOrWhiteSpace(row.Description) ? row.Description!
        : "(no subject)";

    /// <summary>
    /// A URL-safe id for an attachment name. Hebrew file names are common here, so the name
    /// itself cannot go in a path segment unescaped.
    /// </summary>
    public static string PartIdFor(string fileName) =>
        System.Convert.ToHexString(
            System.Security.Cryptography.SHA256.HashData(
                System.Text.Encoding.UTF8.GetBytes(fileName)))[..16].ToLowerInvariant();
}
