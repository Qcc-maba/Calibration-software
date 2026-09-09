namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>
/// Picks the converter for a file. First registration that claims the extension wins, so the
/// passthrough sits ahead of anything that would re-render a PDF that is already fine.
/// </summary>
public sealed class PdfConverterRegistry(IEnumerable<IPdfConverter> converters)
{
    private readonly IReadOnlyList<IPdfConverter> _converters = converters.ToList();

    public IPdfConverter? For(string extension) =>
        _converters.FirstOrDefault(c => c.CanConvert(extension));

    public bool CanConvert(string extension) => For(extension) is not null;

    /// <summary>
    /// Converts, or throws <see cref="PdfConversionException"/> naming the file and why. The
    /// caller turns that into a visible failed entry — a document the calibrator cannot open must
    /// still appear in the list, or they have no way to know it exists.
    /// </summary>
    public Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct)
    {
        var converter = For(source.Extension)
            ?? throw new PdfConversionException(
                source.Extension.Length == 0
                    ? $"'{source.FileName}' has no file extension, so its type is unknown."
                    : $"'{source.FileName}' is a .{source.Extension} file, which cannot be converted to PDF.");

        return converter.ConvertAsync(source, ct);
    }
}
