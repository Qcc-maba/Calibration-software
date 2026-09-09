using System.Text;
using Microsoft.Playwright;

namespace Maba.VCT.OrderAttachments.Convert;

/// <summary>
/// Renders HTML to PDF with headless Chromium.
///
/// This is the engine choice for MBA-930 and the reason is the input, not a preference: 99.3% of
/// what Priority hangs off an order is an Outlook .msg, so the thing actually being converted is
/// arbitrary HTML written by twenty years of Outlook versions — nested tables, broken CSS, mixed
/// encodings, Hebrew RTL. A browser is what renders that correctly. Verified in the spike on ten
/// live files: 10/10 rendered, 29-467 ms each, Hebrew right-aligned and correctly shaped.
///
/// One browser is launched for the life of the service and a fresh page is used per conversion.
/// Launching per request would dominate the cost — a page render is a few hundred milliseconds,
/// a browser launch is seconds.
/// </summary>
public sealed class ChromiumRenderer : IAsyncDisposable
{
    private readonly ILogger<ChromiumRenderer> _log;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private IPlaywright? _playwright;
    private IBrowser? _browser;

    public ChromiumRenderer(ILogger<ChromiumRenderer> log) => _log = log;

    private async Task<IBrowser> BrowserAsync()
    {
        if (_browser is { IsConnected: true }) return _browser;

        await _gate.WaitAsync();
        try
        {
            if (_browser is { IsConnected: true }) return _browser;

            // A crashed browser must not wedge the service - drop the old handles and relaunch.
            if (_browser is not null)
            {
                _log.LogWarning("Chromium disconnected; relaunching");
                await SafeDisposeAsync();
            }

            _playwright ??= await Playwright.CreateAsync();
            _browser = await _playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
            {
                Headless = true,
            });
            return _browser;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// Renders a complete HTML document to PDF.
    ///
    /// The HTML is set on the page directly rather than fetched over http, and the page is given
    /// no network access it needs: every inline image must already be a data: URI by this point
    /// (see <see cref="Maba.VCT.OrderAttachments.Msg.InlineImageRewriter"/>). A mail body that
    /// still reaches for a remote tracking pixel would otherwise stall the render until timeout.
    /// </summary>
    public async Task<byte[]> RenderAsync(string html, CancellationToken ct = default)
    {
        // The launch is inside the try on purpose. A missing browser throws PlaywrightException
        // ("Executable doesn't exist ... run playwright install"), and if that escapes raw it
        // reaches the endpoint as a 500 instead of the 422 that tells the caller which document
        // failed and why. Caught here so every failure leaves as a PdfConversionException.
        IPage? page = null;
        try
        {
            var browser = await BrowserAsync();
            page = await browser.NewPageAsync();

            await page.SetContentAsync(EnsureCharset(html), new PageSetContentOptions
            {
                WaitUntil = WaitUntilState.Load,
                Timeout = RenderTimeoutMs,
            });

            return await page.PdfAsync(new PagePdfOptions
            {
                Format = "A4",
                PrintBackground = true,
                Margin = new Margin { Top = "12mm", Bottom = "12mm", Left = "12mm", Right = "12mm" },
            });
        }
        catch (PdfConversionException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new PdfConversionException("Chromium failed to render the document.", ex);
        }
        finally
        {
            if (page is not null) await page.CloseAsync();
        }
    }

    private const float RenderTimeoutMs = 30_000;

    /// <summary>
    /// Mail bodies routinely declare no charset at all. Without one the browser guesses, and a
    /// guess on Hebrew text is a coin flip. This does not repair text that was already corrupted
    /// upstream — that is <see cref="Maba.VCT.OrderAttachments.Text.HebrewTextRepair"/>'s job, and
    /// the spike confirmed the two problems are separate.
    /// </summary>
    private static string EnsureCharset(string html)
    {
        if (html.Contains("charset", StringComparison.OrdinalIgnoreCase)) return html;

        const string meta = "<meta charset=\"utf-8\">";
        var head = html.IndexOf("<head", StringComparison.OrdinalIgnoreCase);
        if (head < 0) return meta + html;

        var close = html.IndexOf('>', head);
        return close < 0 ? meta + html : html[..(close + 1)] + meta + html[(close + 1)..];
    }

    /// <summary>Wraps a raw image in a page so the same engine converts it — no second dependency.</summary>
    public Task<byte[]> RenderImageAsync(byte[] image, string mediaType, CancellationToken ct = default)
    {
        var data = System.Convert.ToBase64String(image);
        var html = new StringBuilder()
            .Append("<!doctype html><html><head><meta charset=\"utf-8\"><style>")
            .Append("html,body{margin:0;padding:0}")
            .Append("img{max-width:100%;height:auto;display:block;margin:0 auto}")
            .Append("</style></head><body><img src=\"data:")
            .Append(mediaType).Append(";base64,").Append(data)
            .Append("\"></body></html>")
            .ToString();

        return RenderAsync(html, ct);
    }

    public async ValueTask DisposeAsync() => await SafeDisposeAsync();

    private async Task SafeDisposeAsync()
    {
        try
        {
            if (_browser is not null) await _browser.CloseAsync();
        }
        catch (Exception ex)
        {
            _log.LogDebug(ex, "Ignoring error while closing Chromium");
        }
        finally
        {
            _browser = null;
            _playwright?.Dispose();
            _playwright = null;
        }
    }
}
