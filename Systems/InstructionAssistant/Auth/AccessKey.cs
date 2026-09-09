using System.Security.Cryptography;
using System.Text;

namespace Maba.VCT.InstructionAssistant.Auth;

/// <summary>
/// Shared-secret gate for the API. The service answers with customer calibration instructions and
/// every miss spends money on the Anthropic API, so once it is reachable beyond localhost it must
/// not be open to the whole network.
///
/// An empty configured key disables the check — that is the local-development case, and it keeps
/// the service behaving exactly as before for anyone who has not configured a key.
/// </summary>
public static class AccessKey
{
    /// <summary>Header carrying the key. A query parameter is also accepted, see <see cref="Extract"/>.</summary>
    public const string HeaderName = "X-Api-Key";

    /// <summary>Query parameter form, so a person can bookmark a working URL.</summary>
    public const string QueryName = "key";

    /// <summary>
    /// Compares the presented key against the configured one.
    /// Both sides are hashed first: that keeps the comparison constant-time even when the lengths
    /// differ, which a bare FixedTimeEquals cannot do without leaking the expected length.
    /// </summary>
    /// <param name="presented">Value from the request, if any.</param>
    /// <param name="expected">Configured key. Empty means the check is disabled.</param>
    /// <returns>True when the request may proceed.</returns>
    public static bool Matches(string? presented, string? expected)
    {
        if (string.IsNullOrEmpty(expected)) return true;
        if (string.IsNullOrEmpty(presented)) return false;

        return CryptographicOperations.FixedTimeEquals(Digest(presented), Digest(expected));
    }

    /// <summary>Reads the key from the header, falling back to the query string.</summary>
    public static string? Extract(HttpRequest request)
    {
        var header = request.Headers[HeaderName].ToString();
        if (!string.IsNullOrEmpty(header)) return header;

        return request.Query.TryGetValue(QueryName, out var fromQuery) ? fromQuery.ToString() : null;
    }

    private static byte[] Digest(string value) => SHA256.HashData(Encoding.UTF8.GetBytes(value));
}
