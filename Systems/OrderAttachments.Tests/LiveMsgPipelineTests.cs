using Maba.VCT.OrderAttachments.Convert;
using Maba.VCT.OrderAttachments.Msg;
using Microsoft.Extensions.Logging.Abstractions;

namespace Maba.VCT.OrderAttachments.Tests;

/// <summary>
/// Runs the real extractor and the real renderer against real files on
/// \\maba-priority\Priority\Attachments. Skipped automatically when the share is not reachable,
/// so it does not break a build on a machine outside the network.
///
/// The unit tests cover the logic; this one covers the thing the spike actually proved — that a
/// live Outlook message with Hebrew in it comes out the far end as a PDF.
/// </summary>
public class LiveMsgPipelineTests
{
    private const string Share = @"\\maba-priority\Priority\Attachments\Documents";

    private static bool ShareAvailable => Directory.Exists(Share);

    private static string? FirstMessage()
    {
        if (!ShareAvailable) return null;

        // Newest year folder first: those files are the ones the calibrators actually open.
        foreach (var year in Directory.EnumerateDirectories(Share).OrderDescending())
        foreach (var month in Directory.EnumerateDirectories(year).OrderDescending())
        {
            var msg = Directory.EnumerateFiles(month, "*.msg").FirstOrDefault();
            if (msg is not null) return msg;
        }
        return null;
    }

    [Fact]
    public void Extracts_a_live_outlook_message()
    {
        var path = FirstMessage();
        if (path is null) return;   // share unreachable - see the class comment

        var extractor = new MsgExtractor(NullLogger<MsgExtractor>.Instance);

        var msg = extractor.Extract(path, _ => "data:image/gif;base64,R0lGODlhAQABAAAAACw=");

        // A body of some form is the whole point; every one of the ten spike samples had HTML.
        Assert.True(msg.BodyHtml is not null || msg.BodyText is not null,
            $"'{path}' produced no body at all.");

        // Whatever the body references must have been re-pointed. A surviving cid: means the
        // rendered page would show a broken image.
        if (msg.BodyHtml is not null)
            Assert.DoesNotContain("src=\"cid:", msg.BodyHtml, StringComparison.OrdinalIgnoreCase);

        // Inline signature images are files but never documents.
        Assert.All(msg.Documents, f => Assert.False(f.IsInline));
    }

    [Fact]
    public async Task Renders_a_live_message_body_to_a_real_pdf()
    {
        var path = FirstMessage();
        if (path is null) return;   // share unreachable - see the class comment

        var extractor = new MsgExtractor(NullLogger<MsgExtractor>.Instance);
        var msg = extractor.Extract(path, f =>
            $"data:image/{(f.Extension == "png" ? "png" : "jpeg")};base64," +
            System.Convert.ToBase64String(f.Data));

        if (msg.BodyHtml is null) return;

        await using var renderer = new ChromiumRenderer(NullLogger<ChromiumRenderer>.Instance);

        byte[] pdf;
        try
        {
            pdf = await renderer.RenderAsync(msg.BodyHtml!, CancellationToken.None);
        }
        catch (PdfConversionException ex)
            when (ex.InnerException?.Message.Contains("Executable doesn't exist") == true)
        {
            // Chromium is not installed for Microsoft.Playwright here. Install it with
            // 'pwsh bin/Debug/net10.0/playwright.ps1 install chromium'.
            return;
        }

        Assert.NotEmpty(pdf);
        // %PDF- signature: proves a PDF came out, not an empty file or an error page.
        Assert.Equal("%PDF-"u8.ToArray(), pdf.Take(5).ToArray());
    }
}
