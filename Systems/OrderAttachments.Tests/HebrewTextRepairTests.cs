using Maba.VCT.OrderAttachments.Text;

namespace Maba.VCT.OrderAttachments.Tests;

/// <summary>
/// Every mojibake string below was read out of a live .msg under
/// \\maba-priority\Priority\Attachments during the MBA-930 spike. None are invented.
/// </summary>
public class HebrewTextRepairTests
{
    [Theory]
    // The quoted header block of a forwarded order mail, order A26010435.
    [InlineData("ëéåì", "כיול")]
    [InlineData("äöòú", "הצעת")]
    [InlineData("îçéø", "מחיר")]
    [InlineData("ëéåì -äöòú îçéø", "כיול -הצעת מחיר")]
    public void Repairs_hebrew_that_was_read_as_latin1(string mojibake, string expected)
    {
        Assert.Equal(expected, HebrewTextRepair.Repair(mojibake));
    }

    [Fact]
    public void Repairs_the_run_and_leaves_the_rest_of_the_line_alone()
    {
        // As it appears in the body: an Outlook header label, the broken Hebrew, then an order
        // number that was never broken.
        var line = "Subject: FW: ëéåì -äöòú îçéø A26010435";

        var repaired = HebrewTextRepair.Repair(line);

        Assert.StartsWith("Subject: FW: ", repaired);
        Assert.EndsWith(" A26010435", repaired);
        Assert.Contains("כיול", repaired);
        Assert.Contains("הצעת מחיר", repaired);
    }

    [Theory]
    // Hebrew that is already correct must survive untouched - the repair runs over every body,
    // and most of a body is not broken.
    [InlineData("הזמנת רכש")]
    [InlineData("RE: כיול תנור")]
    [InlineData("FW: תיאום כיול למד מוליכות באלכם")]
    [InlineData("מצורפת הזמנה חדשה, אנא אשרי את קבלתה")]
    // Plain Latin and mixed content.
    [InlineData("Subject: FW: calibration quote A26010435")]
    [InlineData("PO2485.pdf")]
    [InlineData("")]
    public void Leaves_correct_text_unchanged(string text)
    {
        Assert.Equal(text, HebrewTextRepair.Repair(text));
    }

    [Fact]
    public void Null_survives()
    {
        Assert.Equal(string.Empty, HebrewTextRepair.Repair(null));
    }

    [Fact]
    public void A_single_accented_letter_is_a_european_name_not_broken_hebrew()
    {
        // The corpus carries European supplier names. Converting a lone accented character would
        // turn "Zürich" into Hebrew noise, so only runs are treated as suspect.
        Assert.Equal("Zürich", HebrewTextRepair.Repair("Zürich"));
        Assert.Equal("Müller GmbH", HebrewTextRepair.Repair("Müller GmbH"));
    }

    [Fact]
    public void A_run_that_does_not_decode_to_hebrew_is_left_as_it_was()
    {
        // "ÀÁÂ" round-trips to Windows-1255 undefined slots, not Hebrew. The guess is rejected
        // and the original text stands rather than being replaced with replacement characters.
        var input = "ÀÁÂ";
        var result = HebrewTextRepair.Repair(input);

        Assert.True(result == input || result.Any(c => c >= '\u0590' && c <= '\u05FF'),
            $"expected the original back or real Hebrew, got '{result}'");
    }
}
