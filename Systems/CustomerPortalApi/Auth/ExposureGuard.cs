namespace Maba.VCT.CustomerPortalApi.Auth;

/// <summary>
/// Refuses to start an unauthenticated service on a public address.
/// </summary>
/// <remarks>
/// <see cref="ProxyApiKey.Matches"/> treats an empty configured key as "check disabled", which is
/// the right default for a developer running on localhost. It is the wrong default the moment the
/// service answers on portal.qcc.co.il: the OTP endpoint replies differently for a registered and
/// an unregistered address, so an open service lets anyone enumerate who is a customer.
///
/// Rather than leave that as a footgun, binding beyond loopback without a key is a startup
/// failure. Same fail-safe direction as the remote-access guard in customer-analysis: absent
/// configuration must close the door, not open it.
/// </remarks>
public static class ExposureGuard
{
    /// <summary>
    /// Null when the configuration is safe; otherwise the reason to abort with.
    /// </summary>
    /// <param name="urls">Listen URLs, as ASPNETCORE_URLS spells them (semicolon separated).</param>
    /// <param name="proxyApiKey">The configured shared secret.</param>
    public static string? Check(string? urls, string? proxyApiKey)
    {
        if (!string.IsNullOrWhiteSpace(proxyApiKey))
        {
            return null;
        }

        var exposed = PublicBindings(urls).ToList();

        return exposed.Count == 0
            ? null
            : $"CustomerPortal:ProxyApiKey is empty while the service listens on {string.Join(", ", exposed)}. "
              + "An unauthenticated portal API lets anyone enumerate which e-mail addresses belong to customers. "
              + "Set CustomerPortal__ProxyApiKey (machine-scope environment variable) before exposing the service.";
    }

    /// <summary>
    /// True when nothing in <paramref name="urls"/> is reachable from another machine.
    /// Exposed so other guards can ask the same question and cannot drift from this answer.
    /// </summary>
    public static bool IsLoopbackOnly(string? urls) => !PublicBindings(urls).Any();

    /// <summary>Listen URLs that are reachable from outside this machine.</summary>
    private static IEnumerable<string> PublicBindings(string? urls)
    {
        foreach (var raw in (urls ?? string.Empty).Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            // "http://+:5312" and "http://*:5312" are wildcard binds; Uri cannot parse them.
            if (raw.Contains("//+") || raw.Contains("//*") || raw.Contains("//0.0.0.0"))
            {
                yield return raw;
                continue;
            }

            if (!Uri.TryCreate(raw, UriKind.Absolute, out var uri))
            {
                continue;
            }

            var isLoopback = uri.IsLoopback
                || string.Equals(uri.Host, "localhost", StringComparison.OrdinalIgnoreCase);

            if (!isLoopback)
            {
                yield return raw;
            }
        }
    }
}
