using System.Security.Cryptography;
using System.Text;

namespace Maba.VCT.CustomerPortalApi.Auth;

/// <summary>
/// Shared secret between the front end and this service.
///
/// The login endpoints have no other caller-level authentication — the OTP flow authenticates the
/// *customer*, not the *client*. Since `request-otp` answers differently for a registered and an
/// unregistered address, anyone able to reach the service could walk a list of addresses and learn
/// who is a customer. Requiring a header the front end holds closes that off.
/// </summary>
public static class ProxyApiKey
{
    public const string HeaderName = "X-Portal-Api-Key";

    /// <summary>
    /// Compares the presented key with the configured one.
    ///
    /// Both sides are hashed first: it keeps the comparison constant-time even when the lengths
    /// differ, which a bare FixedTimeEquals cannot do without revealing the expected length.
    /// </summary>
    /// <param name="presented">Value of the request header, if any.</param>
    /// <param name="expected">Configured key. Empty means the check is disabled.</param>
    /// <returns>True when the request may proceed.</returns>
    public static bool Matches(string? presented, string expected)
    {
        if (string.IsNullOrEmpty(expected))
        {
            return true;   // unconfigured: local development
        }

        if (string.IsNullOrEmpty(presented))
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(Digest(presented), Digest(expected));
    }

    private static byte[] Digest(string value) => SHA256.HashData(Encoding.UTF8.GetBytes(value));
}
