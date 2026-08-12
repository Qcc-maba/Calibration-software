namespace Maba.VCT.CustomerPortalApi.Options;

/// <summary>
/// Everything the customer-portal login needs from configuration. Bound from the
/// "CustomerPortal" section of appsettings / environment variables.
/// </summary>
public sealed class CustomerPortalOptions
{
    public const string SectionName = "CustomerPortal";

    /// <summary>Calibrator / CalibratorProd. The service is the only tier that holds it.</summary>
    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>
    /// Peppers the HMAC of every one-time code, so the digest stored in CustomerPortalOtp cannot be
    /// turned back into a live code by anyone reading the table.
    /// </summary>
    public string OtpPepper { get; set; } = string.Empty;

    /// <summary>Signs the session cookie. Must match the front end, which verifies the same cookie.</summary>
    public string SessionSecret { get; set; } = string.Empty;

    public int OtpTtlSeconds { get; set; } = 600;
    public int OtpMaxAttempts { get; set; } = 5;
    public int OtpMaxPerWindow { get; set; } = 5;
    public int OtpWindowSeconds { get; set; } = 900;
    public int SessionTtlSeconds { get; set; } = 12 * 60 * 60;

    /// <summary>Origins allowed to call the API with credentials, e.g. https://cal.qcc.co.il.</summary>
    public string[] AllowedOrigins { get; set; } = [];

    /// <summary>
    /// Set false only for local HTTP development; the session cookie is otherwise marked Secure.
    /// </summary>
    public bool SecureCookies { get; set; } = true;

    public SmtpOptions Smtp { get; set; } = new();
}

public sealed class SmtpOptions
{
    public string Host { get; set; } = "smtp.office365.com";

    public int Port { get; set; } = 587;

    /// <summary>
    /// False for the STARTTLS port (587), true for implicit TLS (465). On 587 the connection still
    /// upgrades to TLS - it is required, never optional.
    /// </summary>
    public bool UseImplicitTls { get; set; }

    public string User { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    /// <summary>Envelope sender. Microsoft 365 requires it to be the authenticated mailbox.</summary>
    public string From { get; set; } = string.Empty;

    public string FromDisplayName { get; set; } = "מ.ב.א מעבדות כיול";
}
