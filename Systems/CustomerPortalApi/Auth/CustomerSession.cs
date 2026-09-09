using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Maba.VCT.CustomerPortalApi.Auth;

/// <summary>
/// Identity of a signed-in portal visitor. Serialised into the session cookie, so the property
/// names are part of a contract with the web front end, which verifies the same cookie.
/// </summary>
public sealed record CustomerSession
{
    [JsonPropertyName("email")]
    public required string Email { get; init; }

    [JsonPropertyName("customerId")]
    public int? CustomerId { get; init; }

    [JsonPropertyName("customerContactId")]
    public required int CustomerContactId { get; init; }

    [JsonPropertyName("contactName")]
    public string? ContactName { get; init; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; init; }

    /// <summary>Expiry, seconds since the Unix epoch.</summary>
    [JsonPropertyName("exp")]
    public long Exp { get; init; }
}

/// <summary>
/// Issues and verifies the portal session cookie: base64url(payload).base64url(HMAC-SHA256).
///
/// The format is deliberately identical to the one the Next.js front end already reads, so page
/// guards there can keep validating the cookie locally without a round trip to this service. Both
/// sides must be configured with the same secret.
/// </summary>
public sealed class CustomerSessionService(string secret)
{
    public const string CookieName = "MABA_CUSTOMER_SESSION";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    private readonly byte[] _key = Encoding.UTF8.GetBytes(secret);

    public string Issue(CustomerSession session)
    {
        var payload = ToBase64Url(JsonSerializer.SerializeToUtf8Bytes(session, JsonOptions));

        return $"{payload}.{ToBase64Url(Sign(payload))}";
    }

    /// <summary>
    /// Verifies the signature before the payload is parsed, so tampered content never reaches the
    /// deserialiser, and rejects anything past its expiry.
    /// </summary>
    /// <returns>The session, or null for every failure mode.</returns>
    public CustomerSession? Read(string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return null;
        }

        var separator = token.IndexOf('.');

        if (separator <= 0 || separator == token.Length - 1)
        {
            return null;
        }

        var payload = token[..separator];

        byte[] received;

        try
        {
            received = FromBase64Url(token[(separator + 1)..]);
        }
        catch (FormatException)
        {
            return null;
        }

        var expected = Sign(payload);

        if (!CryptographicOperations.FixedTimeEquals(received, expected))
        {
            return null;
        }

        CustomerSession? session;

        try
        {
            session = JsonSerializer.Deserialize<CustomerSession>(FromBase64Url(payload), JsonOptions);
        }
        catch (Exception exception) when (exception is JsonException or FormatException)
        {
            return null;
        }

        if (session is null || session.Exp <= DateTimeOffset.UtcNow.ToUnixTimeSeconds())
        {
            return null;
        }

        return session;
    }

    private byte[] Sign(string payload)
    {
        using var hmac = new HMACSHA256(_key);

        return hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
    }

    /* Node emits base64url without padding; these keep both sides byte-compatible. */
    private static string ToBase64Url(byte[] value) =>
        Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] FromBase64Url(string value)
    {
        var padded = value.Replace('-', '+').Replace('_', '/');

        return Convert.FromBase64String(padded.PadRight(padded.Length + ((4 - (padded.Length % 4)) % 4), '='));
    }
}
