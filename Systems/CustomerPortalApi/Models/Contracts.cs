using System.Text.Json.Serialization;
using Maba.VCT.CustomerPortalApi.Auth;

namespace Maba.VCT.CustomerPortalApi.Models;

public sealed record RequestOtpRequest(
    [property: JsonPropertyName("email")] string Email);

public sealed record VerifyOtpRequest(
    [property: JsonPropertyName("email")] string Email,
    [property: JsonPropertyName("code")] string Code);

/// <summary>
/// Outcome of asking for a code. The status strings match the ones the web front end already
/// branches on, so its error messages need no translation layer.
/// </summary>
public sealed record RequestOtpResponse(
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("expiresInSeconds")] int? ExpiresInSeconds,
    [property: JsonPropertyName("retryAfterSeconds")] int? RetryAfterSeconds)
{
    public static RequestOtpResponse Sent(int ttlSeconds) => new("sent", ttlSeconds, null);

    public static RequestOtpResponse EmailNotFound() => new("emailNotFound", null, null);

    public static RequestOtpResponse RateLimited(int? retryAfterSeconds) =>
        new("rateLimited", null, retryAfterSeconds);

    public static RequestOtpResponse SendFailed() => new("sendFailed", null, null);
}

public sealed record VerifyOtpResponse(
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("attemptsLeft")] int AttemptsLeft,
    [property: JsonPropertyName("session")] CustomerSession? Session);

/// <summary>Current session, or null when the visitor is not signed in.</summary>
public sealed record MeResponse(
    [property: JsonPropertyName("session")] CustomerSession? Session);
