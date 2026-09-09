using Maba.VCT.CustomerPortalApi.Auth;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class ExposureGuardTests
{
    [Theory]
    [InlineData("http://localhost:5312")]
    [InlineData("http://127.0.0.1:5312")]
    [InlineData("http://[::1]:5312")]
    [InlineData("http://localhost:5312;https://localhost:5313")]
    [InlineData(null)]
    [InlineData("")]
    public void Allows_loopback_without_a_key(string? urls)
    {
        Assert.Null(ExposureGuard.Check(urls, string.Empty));
    }

    /// <summary>
    /// The reason the guard exists: request-otp answers differently for a registered and an
    /// unregistered address, so an open service is a customer-list oracle.
    /// </summary>
    [Theory]
    [InlineData("http://0.0.0.0:5312")]
    [InlineData("http://+:5312")]
    [InlineData("http://*:5312")]
    [InlineData("https://portal.qcc.co.il")]
    [InlineData("http://10.0.0.5:5312")]
    [InlineData("http://localhost:5312;https://portal.qcc.co.il")]
    public void Refuses_a_public_binding_without_a_key(string urls)
    {
        var reason = ExposureGuard.Check(urls, string.Empty);

        Assert.NotNull(reason);
        Assert.Contains("ProxyApiKey", reason);
    }

    [Theory]
    [InlineData("https://portal.qcc.co.il")]
    [InlineData("http://0.0.0.0:5312")]
    public void Allows_a_public_binding_once_a_key_is_set(string urls)
    {
        Assert.Null(ExposureGuard.Check(urls, "a-real-shared-secret"));
    }

    [Fact]
    public void Whitespace_is_not_a_key()
    {
        Assert.NotNull(ExposureGuard.Check("https://portal.qcc.co.il", "   "));
    }
}
