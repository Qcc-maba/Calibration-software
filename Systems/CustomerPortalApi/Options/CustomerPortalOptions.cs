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
    /// Shared secret the front end must send in the X-Portal-Api-Key header. The login endpoints
    /// are otherwise open to anyone who can reach the service, and request-otp answers differently
    /// for a registered and an unregistered address - enough to enumerate the customer list.
    /// Empty disables the check, which is intended only for local development.
    /// </summary>
    public string ProxyApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Reverse proxies whose X-Forwarded-For may be believed. Leave empty unless the service sits
    /// behind one: trusting the header from an arbitrary caller lets it forge its own address and
    /// walk straight through the per-IP limit.
    /// </summary>
    public string[] TrustedProxies { get; set; } = [];

    public RateLimitOptions RateLimit { get; set; } = new();

    /// <summary>
    /// Set false only for local HTTP development; the session cookie is otherwise marked Secure.
    /// </summary>
    public bool SecureCookies { get; set; } = true;

    public SmtpOptions Smtp { get; set; } = new();
}

/// <summary>
/// Caps how often one caller may hit the login endpoints. The database already limits codes per
/// e-mail address, which does nothing against a caller walking a list of different addresses.
/// </summary>
public sealed class RateLimitOptions
{
    public int PermitPerWindow { get; set; } = 20;

    public int WindowSeconds { get; set; } = 300;
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

    /// <summary>Sender name shown in the recipient's inbox. Keep it identical to the signature in
    /// <see cref="Mail.OtpEmailBuilder"/> and to the logo, so one message never carries two names.</summary>
    public string FromDisplayName { get; set; } = "מ.ב.א הזורע טכנולוגיות כיול";
}
