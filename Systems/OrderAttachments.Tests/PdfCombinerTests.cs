using Maba.VCT.OrderAttachments.Convert;
using Microsoft.Extensions.Logging.Abstractions;
using UglyToad.PdfPig;

namespace Maba.VCT.OrderAttachments.Tests;

public class PdfCombinerTests
{
    private static PdfCombiner Combiner => new(NullLogger<PdfCombiner>.Instance);

    [Fact]
    public void Merging_nothing_is_an_error_not_an_empty_pdf()
    {
        Assert.Throws<PdfConversionException>(() => Combiner.Merge([]));
    }

    [Fact]
    public void A_single_part_is_returned_as_it_was()
    {
        // Round-tripping one file through the writer would re-encode it for no reason.
        var only = "%PDF-1.7 pretend"u8.ToArray();

        Assert.Same(only, Combiner.Merge([only]));
    }

    [Fact]
    public void Rubbish_input_fails_with_a_message_that_says_the_parts_are_still_available()
    {
        var ex = Assert.Throws<PdfConversionException>(() =>
            Combiner.Merge(["not a pdf"u8.ToArray(), "nor this"u8.ToArray()]));

        Assert.Contains("individually", ex.Message);
    }

    [Fact]
    public async Task Merges_real_pdfs_and_keeps_every_page()
    {
        await using var renderer = new ChromiumRenderer(NullLogger<ChromiumRenderer>.Instance);

        byte[] first, second;
        try
        {
            // Two documents of different lengths, so the page count proves both survived rather
            // than one silently replacing the other.
            first = await renderer.RenderAsync(
                "<html><body><p>הזמנת רכש PO2485</p></body></html>", CancellationToken.None);
            second = await renderer.RenderAsync(
                "<html><body><p>page one</p><div style='page-break-before:always'>page two</div></body></html>",
                CancellationToken.None);
        }
        catch (PdfConversionException ex)
            when (ex.InnerException?.Message.Contains("Executable doesn't exist") == true)
        {
            return;   // Chromium not installed here - see LiveMsgPipelineTests
        }

        var firstPages = PageCount(first);
        var secondPages = PageCount(second);

        var merged = Combiner.Merge([first, second]);

        Assert.Equal("%PDF-"u8.ToArray(), merged.Take(5).ToArray());
        Assert.Equal(firstPages + secondPages, PageCount(merged));
    }

    [Fact]
    public async Task The_merge_keeps_the_order_it_was_given()
    {
        // The mail body has to come first; its attachments follow. A reader opening the combined
        // document expects the covering message before the enclosure.
        await using var renderer = new ChromiumRenderer(NullLogger<ChromiumRenderer>.Instance);

        byte[] body, attachment;
        try
        {
            body = await renderer.RenderAsync(
                "<html><body><p>BODYMARKER</p></body></html>", CancellationToken.None);
            attachment = await renderer.RenderAsync(
                "<html><body><p>ATTACHMENTMARKER</p></body></html>", CancellationToken.None);
        }
        catch (PdfConversionException ex)
            when (ex.InnerException?.Message.Contains("Executable doesn't exist") == true)
        {
            return;
        }

        var merged = Combiner.Merge([body, attachment]);

        using var doc = PdfDocument.Open(merged);
        var pageOne = doc.GetPage(1).Text;

        Assert.Contains("BODYMARKER", pageOne);
        Assert.DoesNotContain("ATTACHMENTMARKER", pageOne);
    }

    private static int PageCount(byte[] pdf)
    {
        using var doc = PdfDocument.Open(pdf);
        return doc.NumberOfPages;
    }
}
