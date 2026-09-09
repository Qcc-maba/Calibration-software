using Maba.VCT.CustomerPortalApi.Auth;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class DevLoginCodeTests
{
    private const string Local = "http://localhost:5312";

    [Fact]
    public void Applies_on_a_loopback_development_host()
    {
        Assert.Equal("000000", DevLoginCode.Resolve("000000", isDevelopment: true, Local));
    }

    [Fact]
    public void Off_by_default()
    {
        Assert.Null(DevLoginCode.Resolve(null, isDevelopment: true, Local));
        Assert.Null(DevLoginCode.Resolve("", isDevelopment: true, Local));
        Assert.Null(DevLoginCode.Resolve("   ", isDevelopment: true, Local));
    }

    [Fact]
    public void Never_applies_outside_development()
    {
        Assert.Null(DevLoginCode.Resolve("000000", isDevelopment: false, Local));
    }

    /// <summary>
    /// The check that actually protects customers. An environment name is easy to set wrongly;
    /// whether the socket answers other machines is a fact, so a reachable service must never get
    /// a predictable login code even if someone stamps it "Development".
    /// </summary>
    [Theory]
    [InlineData("http://0.0.0.0:5312")]
    [InlineData("http://+:5312")]
    [InlineData("https://portal-api.qcc.co.il")]
    [InlineData("http://10.0.0.5:5312")]
    [InlineData("http://localhost:5312;https://portal-api.qcc.co.il")]
    public void Never_applies_when_the_service_is_reachable(string urls)
    {
        Assert.Null(DevLoginCode.Resolve("000000", isDevelopment: true, urls));
    }

    /// <summary>A malformed code would be rejected by verification anyway - fail loudly, not oddly.</summary>
    [Theory]
    [InlineData("12345")]
    [InlineData("1234567")]
    [InlineData("abcdef")]
    [InlineData("12a456")]
    public void Rejects_a_code_that_is_not_six_digits(string configured)
    {
        Assert.Null(DevLoginCode.Resolve(configured, isDevelopment: true, Local));
    }
}
