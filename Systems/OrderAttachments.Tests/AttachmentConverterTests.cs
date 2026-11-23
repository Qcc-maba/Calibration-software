using Maba.VCT.OrderAttachments.Convert;
using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.OrderAttachments.Msg;
using Microsoft.Extensions.Logging.Abstractions;

namespace Maba.VCT.OrderAttachments.Tests;

/// <summary>MBA-930: the paths through the converter that need no browser.</summary>
public sealed class AttachmentConverterTests : IAsyncDisposable
{
    private readonly ChromiumRenderer _renderer = new(NullLogger<ChromiumRenderer>.Instance);

    private AttachmentConverter Converter(string shareRoot) => new(
        new MsgExtractor(NullLogger<MsgExtractor>.Instance),
        new PdfConverterRegistry([new PdfPassthroughConverter()]),
        _renderer,
        new PdfCombiner(NullLogger<PdfCombiner>.Instance),
        new AttachmentShareMap(shareRoot),
        NullLogger<AttachmentConverter>.Instance);

    private static OrderAttachmentSource Source(string path, string ext, string kind) =>
        new(1, 1, path, ext, kind, "desc");

    [Fact]
    public async Task A_pdf_is_read_through_the_configured_share()
    {
        // Stored under the live server's name, read from the configured root - as on STAGE.
        var root = Directory.CreateTempSubdirectory("oa-share-").FullName;
        Directory.CreateDirectory(Path.Combine(root, "Documents"));
        await File.WriteAllBytesAsync(Path.Combine(root, "Documents", "a.pdf"), "%PDF-1.4 test"u8.ToArray());

        var result = await Converter(root).ConvertAsync(
            Source(@"\\maba-priority\Priority\Attachments\Documents\a.pdf", "pdf", "Pdf"), default);

        var part = Assert.Single(result.Parts);
        Assert.Equal("body", part.PartId);
        Assert.Equal("Document", part.Kind);
        Assert.NotNull(part.Pdf);
        Assert.Null(result.MergedPdf); // one part already is the whole attachment
    }

    [Fact]
    public async Task A_missing_file_is_reported_as_not_found_not_as_a_broken_document()
    {
        var root = Directory.CreateTempSubdirectory("oa-share-").FullName;

        var ex = await Assert.ThrowsAsync<AttachmentSourceUnreadableException>(() => Converter(root).ConvertAsync(
            Source(@"\\maba-priority\Priority\Attachments\Documents\gone.msg", "msg", "OutlookMessage"), default));

        Assert.True(ex.NotFound);
    }

    [Fact]
    public async Task An_unconvertible_type_is_listed_with_its_reason()
    {
        var result = await Converter(Path.GetTempPath()).ConvertAsync(
            Source(@"\\maba-priority\Priority\Attachments\Documents\drawing.dwg", "dwg", "Other"), default);

        var part = Assert.Single(result.Parts);
        Assert.Equal("Error", part.Kind);
        Assert.Contains(".dwg", part.Error);
        Assert.Null(part.Pdf);
    }

    public async ValueTask DisposeAsync() => await _renderer.DisposeAsync();
}
