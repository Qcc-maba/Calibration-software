using System.Text;

namespace Maba.VCT.OrderAttachments.Msg;

/// <summary>
/// Registers the legacy single-byte code pages that Priority's .msg files depend on.
///
/// .NET Framework carried every Windows code page. .NET Core and everything after it ship only
/// the Unicode encodings, so <c>Encoding.GetEncoding(1255)</c> — Windows Hebrew — throws
/// "No data is available for encoding 1255" unless the CodePages provider is registered first.
///
/// This is a total-failure condition for this service, not an edge case. In the MBA-930 spike all
/// ten sample files failed before this call was added ("The type initializer for
/// 'MsgReader.Rtf.Font' threw an exception", and the 1255 message itself) and all ten parsed after
/// it. It must run before any MsgReader type is touched.
/// </summary>
public static class MsgEncoding
{
    /// <summary>
    /// Lazy rather than a flag-and-return.
    ///
    /// The obvious version — set a flag with Interlocked, then register — is wrong, and wrong in
    /// the way that only shows up under load: the first caller flips the flag BEFORE
    /// RegisterProvider has run, so a concurrent second caller sees "already done" and proceeds
    /// to Encoding.GetEncoding while the provider is still unregistered. That throws. It was
    /// caught here by xUnit running the repair tests in parallel; on the server it would have
    /// been an occasional failure under concurrent requests, which is far harder to diagnose.
    ///
    /// Lazy with ExecutionAndPublication makes every other caller wait for the registration to
    /// finish rather than race past it.
    /// </summary>
    private static readonly Lazy<bool> Initialiser = new(() =>
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        return true;
    }, LazyThreadSafetyMode.ExecutionAndPublication);

    public static void EnsureRegistered() => _ = Initialiser.Value;
}
