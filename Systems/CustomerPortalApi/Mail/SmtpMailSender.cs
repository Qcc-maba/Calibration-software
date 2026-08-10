using MailKit.Net.Smtp;
using MailKit.Security;
using Maba.VCT.CustomerPortalApi.Options;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Maba.VCT.CustomerPortalApi.Mail;

public interface IMailSender
{
    Task SendAsync(MimeMessage message, CancellationToken cancellationToken);
}

/// <summary>
/// Sends through the configured SMTP relay (Microsoft 365 in production).
///
/// A fresh connection per message: portal logins are infrequent, and a pooled connection to
/// Office 365 gets dropped by the server long before the next one is needed.
/// </summary>
public sealed class SmtpMailSender(IOptions<CustomerPortalOptions> options, ILogger<SmtpMailSender> logger)
    : IMailSender
{
    private readonly CustomerPortalOptions _options = options.Value;

    public async Task SendAsync(MimeMessage message, CancellationToken cancellationToken)
    {
        var smtp = _options.Smtp;

        message.From.Add(new MailboxAddress(smtp.FromDisplayName, smtp.From));

        using var client = new SmtpClient();

        /* On 587 Microsoft 365 expects STARTTLS; StartTlsWhenAvailable would let the session stay
           in plaintext if the greeting omitted the capability, so the upgrade is made mandatory. */
        var socketOptions = smtp.UseImplicitTls
            ? SecureSocketOptions.SslOnConnect
            : SecureSocketOptions.StartTls;

        await client.ConnectAsync(smtp.Host, smtp.Port, socketOptions, cancellationToken);
        await client.AuthenticateAsync(smtp.User, smtp.Password, cancellationToken);
        await client.SendAsync(message, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);

        logger.LogInformation("Sent portal OTP mail to {Recipient}", message.To.ToString());
    }
}
