namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>One part of an order's paperwork, on its way to becoming a PDF.</summary>
/// <param name="FileName">Used for the extension and for the name shown to the calibrator.</param>
/// <param name="Content">The bytes as they came out of the .msg or off the share.</param>
public sealed record ConversionSource(string FileName, byte[] Content)
{
    public string Extension => Path.GetExtension(FileName).TrimStart('.').ToLowerInvariant();
}

/// <summary>
/// Turns one source file into a PDF. Implementations are tried in registration order and the
/// first that claims the extension wins, so the cheap passthrough sits ahead of the browser.
/// </summary>
public interface IPdfConverter
{
    /// <param name="extension">Lower case, no leading dot.</param>
    bool CanConvert(string extension);

    Task<byte[]> ConvertAsync(ConversionSource source, CancellationToken ct);
}

/// <summary>
/// Raised when a file cannot be turned into a PDF. Deliberately not swallowed: a document the
/// calibrator cannot see must surface as a failed entry in the list, never as a silent omission.
/// </summary>
public sealed class PdfConversionException(string message, Exception? inner = null)
    : Exception(message, inner);
