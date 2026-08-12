using Maba.VCT.CustomerPortalApi.Mail;
using Maba.VCT.CustomerPortalApi.Options;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class OtpEmailTests
{
    private const string Brand = "מ.ב.א";

    private static (string Html, string Text) Render(string code = "123456", string? name = "אלירן", int minutes = 10)
    {
        var message = OtpEmailBuilder.Build("someone@example.com", code, name, minutes);

        return (message.HtmlBody, message.TextBody);
    }

    [Fact]
    public void Build_SpellsTheBrandWithDots()
    {
        var (html, text) = Render();

        Assert.Contains(Brand, html);
        Assert.Contains(Brand, text);
        // The old spelling must not creep back in through either body.
        Assert.DoesNotContain("מב\"א", html);
        Assert.DoesNotContain("מב\"א", text);
    }

    [Fact]
    public void Build_StatesTheSameValidityTheServiceActuallyApplies()
    {
        // The wording is generated from the caller's number rather than hard-coded, so the mail
        // cannot promise ten minutes while the code expires on some other schedule.
        var (html, text) = Render(minutes: 7);

        Assert.Contains("תקף ל-7 דקות", html);
        Assert.Contains("תקף ל-7 דקות", text);
        Assert.DoesNotContain("תקף ל-10 דקות", html);
    }

    [Fact]
    public void DefaultTtl_IsTenMinutes()
    {
        // What the mail says and what CreateCustomerPortalOtp stores both come from here.
        Assert.Equal(600, new CustomerPortalOptions().OtpTtlSeconds);
    }

    [Fact]
    public void Build_PutsTheCodeInTheSubjectAndBothBodies()
    {
        var message = OtpEmailBuilder.Build("someone@example.com", "045821", "אלירן", 10);

        Assert.Contains("045821", message.Subject);
        Assert.Contains("045821", message.HtmlBody);
        Assert.Contains("045821", message.TextBody);
    }

    [Fact]
    public void Build_FallsBackToAPlainGreetingWhenTheContactHasNoName()
    {
        var (html, text) = Render(name: null);

        Assert.Contains("שלום,", html);
        Assert.Contains("שלום,", text);
    }

    [Fact]
    public void Build_LinksToTheCompanySite()
    {
        var (html, text) = Render();

        // Shown as the bare domain, because clients that strip anchors still leave the text.
        Assert.Contains("href=\"https://qcc.co.il\"", html);
        Assert.Contains(">qcc.co.il</a>", html);
        Assert.Contains("https://qcc.co.il", text);
    }

    [Fact]
    public void Build_AttachesTheLogoAsALinkedResource()
    {
        var message = OtpEmailBuilder.Build("someone@example.com", "123456", "אלירן", 10);

        // Referenced by cid, so it renders even when the client blocks remote images.
        Assert.Contains("cid:", message.HtmlBody);
    }
}
