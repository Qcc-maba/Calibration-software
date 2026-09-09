using Maba.VCT.OrderAttachments.Msg;

namespace Maba.VCT.OrderAttachments.Tests;

/// <summary>
/// The cid values here are taken verbatim from a live body that carried 20 of them
/// (MBA-930 spike, sample 06).
/// </summary>
public class InlineImageRewriterTests
{
    [Theory]
    [InlineData("cid:image003.jpg@01DD2B02.4B001B10", "image003.jpg")]
    [InlineData("image005.gif@01DD2B02.4B001B10", "image005.gif")]
    [InlineData("<image001.png@01DC9A11.0000>", "image001.png")]
    [InlineData("image002.jpg", "image002.jpg")]
    [InlineData("", "")]
    public void KeyOf_takes_the_stable_half_before_the_at_sign(string contentId, string expected)
    {
        Assert.Equal(expected, InlineImageRewriter.KeyOf(contentId.Replace("cid:", "")));
    }

    [Fact]
    public void Rewrites_a_cid_src_to_the_resolved_url()
    {
        var html = """<img width=142 height=59 src="cid:image003.jpg@01DD2B02.4B001B10" alt=logo>""";

        var result = InlineImageRewriter.Rewrite(html, _ => "/inline/image003.jpg");

        Assert.Contains("""src="/inline/image003.jpg" """.TrimEnd(), result);
        Assert.DoesNotContain("cid:", result);
        // Everything else on the tag survives.
        Assert.Contains("width=142", result);
        Assert.Contains("alt=logo", result);
    }

    [Fact]
    public void Rewrites_every_reference_in_a_signature_block()
    {
        var html = """
            <img src="cid:image003.jpg@01DD2B02.4B001B10">
            <img src='cid:image004.jpg@01DD2B02.4B001B10'>
            <img src=cid:image005.gif@01DD2B02.4B001B10>
            """;

        var seen = new List<string>();
        var result = InlineImageRewriter.Rewrite(html, cid =>
        {
            seen.Add(InlineImageRewriter.KeyOf(cid));
            return "/inline/" + InlineImageRewriter.KeyOf(cid);
        });

        Assert.DoesNotContain("cid:", result);
        Assert.Equal(["image003.jpg", "image004.jpg", "image005.gif"], seen);
    }

    [Fact]
    public void An_unresolvable_cid_is_left_visible_rather_than_blanked()
    {
        // A broken image the reader can see beats an empty src that hides the loss.
        var html = """<img src="cid:missing.png@01DD2B02">""";

        var result = InlineImageRewriter.Rewrite(html, _ => null);

        Assert.Equal(html, result);
    }

    [Fact]
    public void Bodies_without_images_are_returned_as_they_were()
    {
        var html = "<p>מצורפת הזמנה חדשה, אנא אשרי את קבלתה</p>";
        Assert.Equal(html, InlineImageRewriter.Rewrite(html, _ => "/inline/x"));
        Assert.Equal(string.Empty, InlineImageRewriter.Rewrite(null, _ => "/inline/x"));
    }

    [Fact]
    public void Matching_ignores_the_generated_half_of_the_content_id()
    {
        // Outlook regenerates the part after '@' per message part, so the body and the attachment
        // record disagree often enough that whole-string matching loses images.
        var html = """<img src="cid:image001.png@01DD2B02.4B001B10">""";

        var result = InlineImageRewriter.Rewrite(html, cid =>
            InlineImageRewriter.KeyOf(cid) == "image001.png" ? "/inline/image001.png" : null);

        Assert.Contains("/inline/image001.png", result);
    }
}
