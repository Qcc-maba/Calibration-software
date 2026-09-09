using System.Text.RegularExpressions;

namespace Maba.VCT.OrderAttachments.Msg;

/// <summary>
/// Points a mail body's inline images at the files we extracted for them.
///
/// An Outlook body references its own images by content id — <c>src="cid:image003.jpg@01DD2B02"</c>
/// — and MsgReader hands those images back as separate attachments. Nothing joins the two, so a
/// body rendered as-is is full of broken-image boxes. One sample in the MBA-930 spike carried 20
/// such references; the rendered page showed the sender's whole e-mail signature as empty frames.
///
/// The match is on the part before '@'. Outlook's content id is
/// <c>&lt;filename&gt;@&lt;generated-id&gt;</c> and the generated half differs between the body and
/// the attachment record often enough that matching the whole string loses images.
/// </summary>
public static partial class InlineImageRewriter
{
    [GeneratedRegex("""(?<attr>src\s*=\s*)(?<quote>["']?)cid:(?<cid>[^"'\s>]+)\2""",
        RegexOptions.IgnoreCase)]
    private static partial Regex CidReference();

    /// <summary>
    /// Rewrites every <c>cid:</c> src in <paramref name="html"/> using
    /// <paramref name="resolve"/>, which maps a content id to a URL or path the renderer can
    /// load. A cid with no match is left untouched so the failure stays visible in the output
    /// rather than turning into a silently empty <c>src</c>.
    /// </summary>
    public static string Rewrite(string? html, Func<string, string?> resolve)
    {
        if (string.IsNullOrEmpty(html)) return html ?? string.Empty;

        return CidReference().Replace(html, m =>
        {
            var cid = m.Groups["cid"].Value;
            var replacement = resolve(cid) ?? resolve(KeyOf(cid));
            if (replacement is null) return m.Value;

            var quote = m.Groups["quote"].Value;
            if (quote.Length == 0) quote = "\"";
            return $"{m.Groups["attr"].Value}{quote}{replacement}{quote}";
        });
    }

    /// <summary>
    /// The stable half of a content id: everything before the '@'. Outlook regenerates the part
    /// after it per message part.
    /// </summary>
    public static string KeyOf(string contentId)
    {
        if (string.IsNullOrEmpty(contentId)) return string.Empty;

        var trimmed = contentId.Trim().Trim('<', '>');
        var at = trimmed.IndexOf('@');
        return at < 0 ? trimmed : trimmed[..at];
    }
}
