using System.Net.Mail;
using Maba.VCT.CustomerPortalApi.Auth;
using Maba.VCT.CustomerPortalApi.Data;
using Maba.VCT.CustomerPortalApi.Mail;
using Maba.VCT.CustomerPortalApi.Models;
using Maba.VCT.CustomerPortalApi.Options;
using Microsoft.Extensions.Options;

namespace Maba.VCT.CustomerPortalApi;

/// <summary>
/// The customer-portal login: prove an e-mail belongs to a customer contact, mail a one-time code,
/// then trade that code for a session. The plaintext code lives only here and in the e-mail - the
/// database sees a peppered HMAC of it, and nothing about it ever reaches the browser.
/// </summary>
public sealed class CustomerAuthService(
    CustomerPortalRepository repository,
    IMailSender mailSender,
    IOptions<CustomerPortalOptions> options,
    IHostEnvironment environment,
    IConfiguration configuration,
    ILogger<CustomerAuthService> logger)
{
    private const int MaxEmailLength = 100;   /* matches the nvarchar(100) e-mail columns */
    private const int SecondsPerMinute = 60;

    private readonly CustomerPortalOptions _options = options.Value;

    /* Non-null only for a Development host bound to loopback with a code configured; null in every
       other case, including a mis-set environment name on a reachable service. */
    private readonly string? _devLoginCode = DevLoginCode.Resolve(
        options.Value.DevLoginCode,
        environment.IsDevelopment(),
        /* Same expression the exposure guard uses in Program.cs: the listen address can come from
           either place, and reading only one of them would let the two guards disagree. */
        configuration["Urls"] ?? Environment.GetEnvironmentVariable("ASPNETCORE_URLS"));

    public static bool TryNormalizeEmail(string? value, out string email)
    {
        email = string.Empty;

        if (string.IsNullOrWhiteSpace(value) || value.Trim().Length > MaxEmailLength)
        {
            return false;
        }

        var candidate = OtpCode.Normalize(value);

        if (!MailAddress.TryCreate(candidate, out var parsed) || parsed.Address != candidate)
        {
            return false;
        }

        email = candidate;

        return true;
    }

    public async Task<RequestOtpResponse> RequestOtpAsync(
        string email,
        string? requestIp,
        CancellationToken cancellationToken)
    {
        /* A configured development code replaces the random one here, at generation. Verification
           is deliberately left untouched: the digest, the expiry and the attempt counter all still
           apply - the code is merely predictable. Resolve() returns null unless the service is in
           Development AND bound to loopback only. */
        var code = _devLoginCode ?? OtpCode.Generate();
        var codeHash = OtpCode.Hash(_options.OtpPepper, email, code);

        var result = await repository.CreateOtpAsync(email, codeHash, requestIp, cancellationToken);

        switch (result.Status)
        {
            case "EmailNotFound":
                return RequestOtpResponse.EmailNotFound();

            case "RateLimited":
                return RequestOtpResponse.RateLimited(result.RetryAfterSeconds);
        }

        if (result.MatchCount > 1)
        {
            // The portal treats an e-mail as a unique customer identifier; this one is not.
            logger.LogWarning(
                "{Email} is linked to {MatchCount} customers - using CustomerId {CustomerId}",
                email,
                result.MatchCount,
                result.CustomerId);
        }

        if (result.IdentitySource == "Priority")
        {
            // Missing from the local mirror; the procedure has just pulled it in from Priority.
            logger.LogInformation("{Email} resolved from Priority and added to CustomerContacts", email);
        }

        try
        {
            var message = OtpEmailBuilder.Build(
                email,
                code,
                result.CustomerContactName,
                _options.OtpTtlSeconds / SecondsPerMinute);

            await mailSender.SendAsync(message, cancellationToken);
        }
        catch (Exception exception)
        {
            /* The code row is already in place; the visitor simply asks for another one. Failing the
               whole request would leak nothing useful and read as a server error in the UI. */
            logger.LogError(exception, "Failed to send the OTP e-mail to {Email}", email);

            return RequestOtpResponse.SendFailed();
        }

        return RequestOtpResponse.Sent(_options.OtpTtlSeconds);
    }

    public async Task<(VerifyOtpResponse Response, string? SessionToken)> VerifyOtpAsync(
        string email,
        string code,
        CustomerSessionService sessions,
        CancellationToken cancellationToken)
    {
        var result = await repository.VerifyOtpAsync(
            email,
            OtpCode.Hash(_options.OtpPepper, email, code),
            cancellationToken);

        if (result.Status != "Verified" || result.CustomerContactId is null)
        {
            var status = result.Status switch
            {
                "Invalid" => "invalid",
                "Expired" => "expired",
                "TooManyAttempts" => "tooManyAttempts",
                _ => "notFound",
            };

            return (new VerifyOtpResponse(status, result.AttemptsLeft, null), null);
        }

        var session = new CustomerSession
        {
            Email = result.Email ?? email,
            CustomerId = result.CustomerId,
            CustomerContactId = result.CustomerContactId.Value,
            ContactName = result.CustomerContactName,
            CustomerName = result.CustomerName,
            Exp = DateTimeOffset.UtcNow.AddSeconds(_options.SessionTtlSeconds).ToUnixTimeSeconds(),
        };

        return (new VerifyOtpResponse("verified", 0, session), sessions.Issue(session));
    }
}
