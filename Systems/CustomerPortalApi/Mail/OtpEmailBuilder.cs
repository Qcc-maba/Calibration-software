using System.Reflection;
using MimeKit;
using MimeKit.Utils;

namespace Maba.VCT.CustomerPortalApi.Mail;

/// <summary>
/// Builds the one-time-code message. The layout is plain inline-styled RTL HTML: mail clients strip
/// &lt;style&gt; blocks and honour `dir` only on the elements that carry it, so direction is set on
/// every block holding Hebrew. The logo is attached by content id rather than linked, because most
/// clients block remote images by default.
/// </summary>
public static class OtpEmailBuilder
{
    private const string LogoResourceName = "Maba.VCT.CustomerPortalApi.Assets.Logo.png";

    public static MimeMessage Build(string toAddress, string code, string? contactName, int expiresInMinutes)
    {
        var greeting = string.IsNullOrWhiteSpace(contactName) ? "שלום," : $"שלום {contactName.Trim()},";

        var builder = new BodyBuilder
        {
            TextBody = string.Join(
                Environment.NewLine,
                greeting,
                string.Empty,
                $"קוד הכניסה שלך לפורטל הלקוחות של מב\"א: {code}",
                $"הקוד תקף ל-{expiresInMinutes} דקות וניתן לשימוש חד פעמי.",
                string.Empty,
                "אם לא ביקשת את הקוד, אפשר להתעלם מהודעה זו.",
                string.Empty,
                "מב\"א מעבדות כיול"),
        };

        var logoBlock = TryAttachLogo(builder, out var logoCid)
            ? $"""
               <div style="margin:0 0 24px;text-align:center;">
                   <img src="cid:{logoCid}" alt="QCC Hazorea" width="260"
                        style="width:260px;max-width:100%;height:auto;display:inline-block;" />
                 </div>
               """
            : string.Empty;

        builder.HtmlBody = $"""
            <div dir="rtl" style="font-family:Arial,Helvetica,sans-serif;background-color:#f4f6f8;padding:24px;">
              <div style="max-width:480px;margin:0 auto;background-color:#ffffff;border-radius:12px;padding:32px;text-align:right;">
                {logoBlock}
                <p style="margin:0 0 16px;font-size:16px;color:#1f2933;">{greeting}</p>
                <p style="margin:0 0 24px;font-size:16px;color:#1f2933;">להלן קוד הכניסה שלך לפורטל הלקוחות של מב"א:</p>
                <div style="margin:0 0 24px;padding:16px;background-color:#f0f4ff;border-radius:8px;text-align:center;">
                  <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#123a8c;">{code}</span>
                </div>
                <p style="margin:0 0 8px;font-size:14px;color:#52606d;">הקוד תקף ל-{expiresInMinutes} דקות וניתן לשימוש חד פעמי.</p>
                <p style="margin:0 0 24px;font-size:14px;color:#52606d;">אם לא ביקשת את הקוד, אפשר להתעלם מהודעה זו.</p>
                <p style="margin:0;font-size:14px;color:#9aa5b1;">מב"א מעבדות כיול</p>
              </div>
            </div>
            """;

        var message = new MimeMessage
        {
            Subject = $"קוד כניסה לפורטל הלקוחות: {code}",
            Body = builder.ToMessageBody(),
        };

        message.To.Add(MailboxAddress.Parse(toAddress));

        return message;
    }

    /// <summary>
    /// Adds the embedded logo. A missing resource must not stop a login, so the caller falls back to
    /// a message without the header image.
    /// </summary>
    private static bool TryAttachLogo(BodyBuilder builder, out string contentId)
    {
        contentId = string.Empty;

        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(LogoResourceName);

        if (stream is null)
        {
            return false;
        }

        var image = builder.LinkedResources.Add("logo.png", stream);
        image.ContentId = MimeUtils.GenerateMessageId();
        contentId = image.ContentId;

        return true;
    }
}
