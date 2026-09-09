using Maba.VCT.OrderAttachments.Convert;

namespace Maba.VCT.OrderAttachments.Tests;

public class PdfConverterRegistryTests
{
    private sealed class Fake(string[] extensions, byte[]? result = null) : IPdfConverter
    {
        public bool CanConvert(string extension) => extensions.Contains(extension);

        public Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct) =>
            Task.FromResult(result ?? [1, 2, 3]);
    }

    [Fact]
    public void First_registration_that_claims_the_extension_wins()
    {
        // The passthrough must sit ahead of anything that would re-render a PDF that is fine.
        var first = new Fake(["pdf"], [10]);
        var second = new Fake(["pdf"], [20]);

        var registry = new PdfConverterRegistry([first, second]);

        Assert.Same(first, registry.For("pdf"));
    }

    [Theory]
    [InlineData("pdf", true)]
    [InlineData("png", true)]
    [InlineData("docx", true)]
    [InlineData("tif", false)]   // in the corpus, but no browser renders TIFF
    [InlineData("exe", false)]
    [InlineData("", false)]
    public void CanConvert_reports_what_is_actually_registered(string extension, bool expected)
    {
        var registry = new PdfConverterRegistry([
            new Fake(["pdf"]),
            new Fake(["png", "jpg", "jpeg", "gif"]),
            new Fake(["doc", "docx", "xls", "xlsx"]),
        ]);

        Assert.Equal(expected, registry.CanConvert(extension));
    }

    [Fact]
    public async Task An_unconvertible_file_names_itself_in_the_error()
    {
        // The message reaches the calibrator, so it has to say which document failed and why -
        // AC #6: nothing is silently dropped.
        var registry = new PdfConverterRegistry([new Fake(["pdf"])]);

        var ex = await Assert.ThrowsAsync<PdfConversionException>(() =>
            registry.ConvertAsync(new ConversionSource("PO2485.tif", [0]), CancellationToken.None));

        Assert.Contains("PO2485.tif", ex.Message);
        Assert.Contains("tif", ex.Message);
    }

    [Fact]
    public async Task A_file_with_no_extension_says_so_rather_than_naming_an_empty_type()
    {
        // Spike sample 04 carried an attachment named as a bare GUID with no extension.
        var registry = new PdfConverterRegistry([new Fake(["pdf"])]);

        var ex = await Assert.ThrowsAsync<PdfConversionException>(() =>
            registry.ConvertAsync(
                new ConversionSource("4950af61-7faf-4f40-8933-70a74fcf9ef3", [0]), CancellationToken.None));

        Assert.Contains("no file extension", ex.Message);
    }

    [Fact]
    public void Extension_is_lower_cased_and_stripped_of_the_dot()
    {
        Assert.Equal("pdf", new ConversionSource("PO2485.PDF", []).Extension);
        Assert.Equal("xlsx", new ConversionSource("template_input (19)_OUTPUT.xlsx", []).Extension);
        Assert.Equal("", new ConversionSource("noextension", []).Extension);
    }
}

public class PdfPassthroughConverterTests
{
    private static readonly byte[] PdfHeader = "%PDF-1.7\n..."u8.ToArray();

    [Fact]
    public async Task A_real_pdf_is_returned_untouched()
    {
        var converter = new PdfPassthroughConverter();

        var result = await converter.ConvertAsync(
            new ConversionSource("PO2485.pdf", PdfHeader), CancellationToken.None);

        Assert.Same(PdfHeader, result);
    }

    [Fact]
    public async Task A_file_merely_named_pdf_is_rejected_rather_than_served_broken()
    {
        var notPdf = "<html>this is not a pdf</html>"u8.ToArray();

        var ex = await Assert.ThrowsAsync<PdfConversionException>(() =>
            new PdfPassthroughConverter().ConvertAsync(
                new ConversionSource("quote.pdf", notPdf), CancellationToken.None));

        Assert.Contains("quote.pdf", ex.Message);
        Assert.Contains("%PDF-", ex.Message);
    }

    [Fact]
    public async Task An_empty_file_is_rejected()
    {
        await Assert.ThrowsAsync<PdfConversionException>(() =>
            new PdfPassthroughConverter().ConvertAsync(
                new ConversionSource("empty.pdf", []), CancellationToken.None));
    }
}
