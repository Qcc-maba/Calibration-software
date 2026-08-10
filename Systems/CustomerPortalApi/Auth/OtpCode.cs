using System.Security.Cryptography;
using System.Text;

namespace Maba.VCT.CustomerPortalApi.Auth;

/// <summary>
/// Generates the one-time codes and turns them into the digest that is stored in
/// dbo.CustomerPortalOtp. The plaintext code exists only in memory and in the e-mail.
/// </summary>
public static class OtpCode
{
    public const int Length = 6;

    private static readonly int CodeSpace = (int)Math.Pow(10, Length);

    /// <summary>
    /// Cryptographically uniform six-digit code. RandomNumberGetInt32 rejection-samples, so unlike
    /// a modulo of a random int every code in 000000-999999 is equally likely.
    /// </summary>
    public static string Generate() =>
        RandomNumberGenerator.GetInt32(0, CodeSpace).ToString($"D{Length}");

    /// <summary>
    /// HMAC-SHA256 over "&lt;normalised e-mail&gt;:&lt;code&gt;" keyed by the server pepper. Binding the
    /// e-mail into the digest stops a code issued for one address being redeemed against another.
    /// </summary>
    public static byte[] Hash(string pepper, string email, string code)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(pepper));

        return hmac.ComputeHash(Encoding.UTF8.GetBytes($"{Normalize(email)}:{code}"));
    }

    public static string Normalize(string email) => email.Trim().ToLowerInvariant();

    public static bool IsWellFormed(string code) =>
        code.Length == Length && code.All(char.IsAsciiDigit);
}
