using Maba.VCT.CustomerPortalApi.Auth;

namespace Maba.VCT.CustomerPortalApi.Tests;

public class OtpCodeTests
{
    private const int SampleSize = 20_000;
    private const int Digits = 10;
    private const string Pepper = "test-pepper-at-least-32-characters-long";

    private static readonly string[] Codes =
        Enumerable.Range(0, SampleSize).Select(_ => OtpCode.Generate()).ToArray();

    [Fact]
    public void Generate_IsAlwaysSixDigits()
    {
        Assert.All(Codes, code =>
        {
            Assert.Equal(OtpCode.Length, code.Length);
            Assert.True(code.All(char.IsAsciiDigit), $"'{code}' is not all digits");
        });
    }

    [Fact]
    public void Generate_ReachesTheWholeRangeIncludingLeadingZeros()
    {
        var numeric = Codes.Select(int.Parse).ToArray();

        Assert.True(numeric.Min() < 100_000, "never produced a leading-zero code");
        Assert.True(numeric.Max() > 900_000, "never produced a high code");
    }

    [Fact]
    public void Generate_DoesNotRepeatInAWayAGuesserCouldExploit()
    {
        // 20k draws from a 1M space: the birthday paradox predicts ~200 collisions. A seeded PRNG
        // restarting, or any short cycle, would blow far past that.
        var unique = Codes.Distinct().Count();

        Assert.True(unique > SampleSize * 0.98, $"only {unique} unique codes out of {SampleSize}");
    }

    [Fact]
    public void Generate_DistributesEveryDigitUniformlyAcrossEveryPosition()
    {
        const double expected = (double)SampleSize / Digits;
        // Chi-square, 9 degrees of freedom: 27.88 is the 0.999 critical value, so a fair generator
        // trips this about once in a thousand runs per position while a biased one fails every time.
        const double criticalValue = 27.88;

        for (var position = 0; position < OtpCode.Length; position++)
        {
            var counts = new int[Digits];

            foreach (var code in Codes)
            {
                counts[code[position] - '0']++;
            }

            var chiSquare = counts.Sum(count => Math.Pow(count - expected, 2) / expected);

            Assert.True(chiSquare < criticalValue, $"position {position} is biased (chi-square {chiSquare:F2})");
        }
    }

    [Fact]
    public void Hash_ProducesA32ByteDigestThatDoesNotContainTheCode()
    {
        var digest = OtpCode.Hash(Pepper, "someone@example.com", "123456");

        Assert.Equal(32, digest.Length);
        Assert.DoesNotContain("123456", Convert.ToHexString(digest));
    }

    [Fact]
    public void Hash_IsStableHoweverTheAddressWasTyped()
    {
        Assert.Equal(
            OtpCode.Hash(Pepper, "Someone@Example.COM", "123456"),
            OtpCode.Hash(Pepper, "  someone@example.com  ", "123456"));
    }

    [Fact]
    public void Hash_BindsTheCodeToItsAddress()
    {
        Assert.NotEqual(
            OtpCode.Hash(Pepper, "me@example.com", "123456"),
            OtpCode.Hash(Pepper, "you@example.com", "123456"));
    }

    [Fact]
    public void Hash_ChangesWhenTheCodeChanges()
    {
        Assert.NotEqual(
            OtpCode.Hash(Pepper, "me@example.com", "123456"),
            OtpCode.Hash(Pepper, "me@example.com", "123457"));
    }
}
