namespace Maba.VCT.CustomerPortalApi.Auth;

/// <summary>
/// A fixed one-time code for local development, so working on the portal does not mean waiting
/// for an e-mail on every reload.
/// </summary>
/// <remarks>
/// <para>
/// It is deliberately applied at code GENERATION, not at verification: the stored value is still
/// an HMAC of the fixed code, and <c>VerifyOtpAsync</c> is completely untouched. There is no
/// "if development, skip the check" branch anywhere near the comparison — the login still goes
/// through the database, the expiry and the attempt counter. The only thing that changes is that
/// the code is predictable.
/// </para>
/// <para>
/// Three conditions must all hold before it activates, because a predictable login code on a
/// reachable service is a full account takeover for every customer:
/// </para>
/// <list type="number">
///   <item><description>an explicit code is configured — absent by default;</description></item>
///   <item><description>the host environment is Development;</description></item>
///   <item><description>every listen address is loopback.</description></item>
/// </list>
/// <para>
/// The third is what makes the first two safe to rely on. Environment names are easy to set
/// wrongly; "is this socket reachable from another machine" is a fact.
/// </para>
/// </remarks>
public static class DevLoginCode
{
    /// <summary>
    /// The code to issue, or null when the bypass must not apply.
    /// </summary>
    /// <param name="configured">CustomerPortal:DevLoginCode.</param>
    /// <param name="isDevelopment">Whether the host environment is Development.</param>
    /// <param name="urls">Listen URLs, as ASPNETCORE_URLS spells them.</param>
    public static string? Resolve(string? configured, bool isDevelopment, string? urls)
    {
        if (string.IsNullOrWhiteSpace(configured))
        {
            return null;
        }

        if (!isDevelopment)
        {
            return null;
        }

        // Reuse the exposure guard's notion of "reachable from outside", so the two cannot drift
        // apart and disagree about what counts as local.
        if (!ExposureGuard.IsLoopbackOnly(urls))
        {
            return null;
        }

        var code = configured.Trim();

        return OtpCode.IsWellFormed(code) ? code : null;
    }
}
