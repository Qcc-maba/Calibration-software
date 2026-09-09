using Maba.VCT.CustomerPortalApi.Auth;
using Maba.VCT.CustomerPortalApi.Options;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class ProxyApiKeyTests
{
    private const string Key = "a-shared-secret-between-proxy-and-service";

    [Fact]
    public void Matches_AcceptsTheConfiguredKey()
    {
        Assert.True(ProxyApiKey.Matches(Key, Key));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("wrong")]
    [InlineData("a-shared-secret-between-proxy-and-servic")]   // one character short
    [InlineData("a-shared-secret-between-proxy-and-serviceX")] // one character long
    [InlineData("A-SHARED-SECRET-BETWEEN-PROXY-AND-SERVICE")]  // case matters
    public void Matches_RejectsAnythingElse(string? presented)
    {
        Assert.False(ProxyApiKey.Matches(presented, Key));
    }

    [Fact]
    public void Matches_IsDisabledWhenNoKeyIsConfigured()
    {
        // Local development runs without one; production must set it.
        Assert.True(ProxyApiKey.Matches(null, string.Empty));
        Assert.True(ProxyApiKey.Matches("anything", string.Empty));
    }

    [Fact]
    public void Defaults_LeaveTheGateOpenButTheLimiterOn()
    {
        var options = new CustomerPortalOptions();

        // Nothing is enforced until the key is configured — an unset key must not lock out a
        // freshly cloned local checkout.
        Assert.Equal(string.Empty, options.ProxyApiKey);
        Assert.Empty(options.TrustedProxies);

        // The limiter, by contrast, applies out of the box.
        Assert.Equal(20, options.RateLimit.PermitPerWindow);
        Assert.Equal(300, options.RateLimit.WindowSeconds);
    }
}
