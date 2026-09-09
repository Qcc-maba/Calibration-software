using System.Diagnostics;
using System.Text;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>
/// Already a PDF. 62 of the ~15,300 order attachments are, plus most of what comes inside the
/// mails — the purchase orders and quality forms the calibrator actually wants.
/// </summary>
public sealed class PdfPassthroughConverter : IPdfConverter
{
    public bool CanConvert(string extension) => extension == "pdf";

    public Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct)
    {
        // Cheapest possible check that this really is a PDF: the %PDF- signature. A file renamed
        // to .pdf would otherwise be handed to the calibrator as a broken document.
        if (source.Content.Length < 5 ||
            source.Content[0] != 0x25 || source.Content[1] != 0x50 ||
            source.Content[2] != 0x44 || source.Content[3] != 0x46)
        {
            throw new PdfConversionException(
                $"'{source.FileName}' is named .pdf but does not start with the %PDF- signature.");
        }

        return Task.FromResult(source.Content);
    }
}

/// <summary>Images, wrapped in a page and rendered by the same browser rather than a new library.</summary>
public sealed class ImagePdfConverter(ChromiumRenderer renderer) : IPdfConverter
{
    private static readonly Dictionary<string, string> MediaTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["jpg"] = "image/jpeg",
        ["jpeg"] = "image/jpeg",
        ["png"] = "image/png",
        ["gif"] = "image/gif",
        ["bmp"] = "image/bmp",
        ["webp"] = "image/webp",
        // TIFF is in the corpus but no browser renders it. Left out on purpose so it falls
        // through to a clear "unsupported" rather than a blank page.
    };

    public bool CanConvert(string extension) => MediaTypes.ContainsKey(extension);

    public Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct) =>
        renderer.RenderImageAsync(source.Content, MediaTypes[source.Extension], ct);
}

/// <summary>Plain text and HTML files attached to a mail.</summary>
public sealed class TextPdfConverter(ChromiumRenderer renderer) : IPdfConverter
{
    public bool CanConvert(string extension) => extension is "htm" or "html" or "txt";

    public Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct)
    {
        var text = Encoding.UTF8.GetString(source.Content);

        if (source.Extension is "htm" or "html")
            return renderer.RenderAsync(text, ct);

        var html = new StringBuilder()
            .Append("<!doctype html><html><head><meta charset=\"utf-8\"><style>")
            // dir=auto so a Hebrew note lands right-aligned and a Latin one does not.
            .Append("body{font:12pt/1.5 system-ui,sans-serif;white-space:pre-wrap}")
            .Append("</style></head><body dir=\"auto\">")
            .Append(System.Net.WebUtility.HtmlEncode(text))
            .Append("</body></html>")
            .ToString();

        return renderer.RenderAsync(html, ct);
    }
}

/// <summary>
/// Word and Excel, converted by LibreOffice running headless.
///
/// The MBA-930 ticket originally deferred this, on the grounds that only 4 Office files are
/// attached to orders directly. The spike showed that count is misleading: Office documents ride
/// INSIDE the mails. Two of ten samples carried one, and in one of them the mail body was
/// boilerplate and the entire content was a .xlsx. Deferring would have shipped a feature that
/// silently loses the document in those cases.
///
/// LibreOffice is a second engine and that is accepted deliberately — Chromium cannot open these
/// formats, and pulling in a commercial document library for a handful of files a week is not
/// worth the licence.
/// </summary>
public sealed class OfficePdfConverter(
    string sofficePath,
    ILogger<OfficePdfConverter> log) : IPdfConverter
{
    public bool CanConvert(string extension) =>
        extension is "doc" or "docx" or "xls" or "xlsx" or "rtf" or "odt" or "ods" or "ppt" or "pptx";

    public async Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sofficePath) || !File.Exists(sofficePath))
        {
            throw new PdfConversionException(
                $"'{source.FileName}' needs LibreOffice but it is not installed at " +
                $"'{sofficePath}'. Set OrderAttachments:LibreOfficePath.");
        }

        // LibreOffice converts files on disk, and it will not accept two concurrent conversions
        // sharing a user profile, so each run gets its own directory.
        var work = Directory.CreateTempSubdirectory("maba-soffice-");
        try
        {
            var input = Path.Combine(work.FullName, SafeName(source.FileName));
            await File.WriteAllBytesAsync(input, source.Content, ct);

            var psi = new ProcessStartInfo(sofficePath)
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };
            psi.ArgumentList.Add("--headless");
            psi.ArgumentList.Add("--norestore");
            psi.ArgumentList.Add($"-env:UserInstallation=file:///{work.FullName.Replace('\\', '/')}/profile");
            psi.ArgumentList.Add("--convert-to");
            psi.ArgumentList.Add("pdf");
            psi.ArgumentList.Add("--outdir");
            psi.ArgumentList.Add(work.FullName);
            psi.ArgumentList.Add(input);

            using var proc = Process.Start(psi)
                ?? throw new PdfConversionException("Could not start LibreOffice.");

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromMinutes(2));

            try
            {
                await proc.WaitForExitAsync(timeout.Token);
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                TryKill(proc);
                throw new PdfConversionException($"LibreOffice timed out converting '{source.FileName}'.");
            }

            var pdf = Path.Combine(work.FullName, Path.GetFileNameWithoutExtension(input) + ".pdf");
            if (!File.Exists(pdf))
            {
                var err = await proc.StandardError.ReadToEndAsync(ct);
                log.LogWarning("LibreOffice produced no PDF for {File}: {Error}", source.FileName, err);
                throw new PdfConversionException($"LibreOffice produced no PDF for '{source.FileName}'.");
            }

            return await File.ReadAllBytesAsync(pdf, ct);
        }
        finally
        {
            try { work.Delete(recursive: true); }
            catch (Exception ex) { log.LogDebug(ex, "Could not clean {Dir}", work.FullName); }
        }
    }

    private static void TryKill(Process p)
    {
        try { if (!p.HasExited) p.Kill(entireProcessTree: true); }
        catch { /* already gone */ }
    }

    private static string SafeName(string name) =>
        string.Join("_", Path.GetFileName(name).Split(Path.GetInvalidFileNameChars()));
}
