using Maba.VCT.CustomerPortalApi.Auth;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class CustomerSessionTests
{
    private const string Secret = "test-session-secret-at-least-32-characters";

    private static CustomerSession NewSession(long? exp = null) => new()
    {
        Email = "yossi@tamhash.co.il",
        CustomerId = 5,
        CustomerContactId = 347,
        ContactName = "יוסי ראלי",
        CustomerName = "תמחש תעשיית מתכת וחשמל בע\"מ",
        Exp = exp ?? DateTimeOffset.UtcNow.AddHours(12).ToUnixTimeSeconds(),
    };

    [Fact]
    public void Read_RoundTripsAnIssuedSession()
    {
        var service = new CustomerSessionService(Secret);

        var session = service.Read(service.Issue(NewSession()));

        Assert.NotNull(session);
        Assert.Equal("yossi@tamhash.co.il", session.Email);
        Assert.Equal(347, session.CustomerContactId);
        Assert.Equal("יוסי ראלי", session.ContactName);
    }

    [Fact]
    public void Read_RejectsATamperedPayload()
    {
        var service = new CustomerSessionService(Secret);
        var token = service.Issue(NewSession());
        var parts = token.Split('.');

        var tampered = $"{parts[0][..^1]}X.{parts[1]}";

        Assert.Null(service.Read(tampered));
    }

    [Fact]
    public void Read_RejectsATokenSignedWithAnotherSecret()
    {
        var token = new CustomerSessionService("a-completely-different-secret-32-chars").Issue(NewSession());

        Assert.Null(new CustomerSessionService(Secret).Read(token));
    }

    [Fact]
    public void Read_RejectsAnExpiredSession()
    {
        var service = new CustomerSessionService(Secret);

        var token = service.Issue(NewSession(DateTimeOffset.UtcNow.AddSeconds(-1).ToUnixTimeSeconds()));

        Assert.Null(service.Read(token));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("no-separator")]
    [InlineData("payload.")]
    [InlineData(".signature")]
    [InlineData("!!!.!!!")]
    public void Read_RejectsMalformedTokensWithoutThrowing(string? token)
    {
        Assert.Null(new CustomerSessionService(Secret).Read(token));
    }

    /// <summary>
    /// The web front end verifies this cookie with its own HMAC implementation, so the token has to
    /// stay base64url without padding and the payload has to keep its camelCase property names.
    /// </summary>
    [Fact]
    public void Issue_ProducesAnUnpaddedBase64UrlTokenTheFrontEndCanParse()
    {
        var token = new CustomerSessionService(Secret).Issue(NewSession());
        var parts = token.Split('.');

        Assert.Equal(2, parts.Length);
        Assert.DoesNotContain('=', token);
        Assert.DoesNotContain('+', token);
        Assert.DoesNotContain('/', token);

        var payload = System.Text.Encoding.UTF8.GetString(
            Convert.FromBase64String(parts[0].Replace('-', '+').Replace('_', '/')
                .PadRight(parts[0].Length + ((4 - (parts[0].Length % 4)) % 4), '=')));

        Assert.Contains("\"customerContactId\":347", payload);
        Assert.Contains("\"email\":", payload);
    }
}
