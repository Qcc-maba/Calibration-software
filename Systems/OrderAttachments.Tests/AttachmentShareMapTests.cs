using Maba.VCT.OrderAttachments.Data;

namespace Maba.VCT.OrderAttachments.Tests;

public class AttachmentShareMapTests
{
    // A real row from EXTFILES on priority-test (order 109130's neighbourhood), which a clone of
    // the live server stores with the live server's name.
    private const string Stored = @"\\maba-priority\Priority\Attachments\Documents\2026\10\202610051830123.msg";

    [Fact]
    public void Stage_reads_the_test_server_copy_of_a_file_priority_stored_on_the_live_share()
    {
        var map = new AttachmentShareMap(@"\\priority-test\Priority\Attachments");

        Assert.Equal(@"\\priority-test\Priority\Attachments\Documents\2026\10\202610051830123.msg",
                     map.Resolve(Stored));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(@"\\maba-priority\Priority\Attachments")]
    [InlineData(@"\\maba-priority\Priority\Attachments\")]
    public void Prod_paths_are_unchanged(string? configured)
    {
        Assert.Equal(Stored, new AttachmentShareMap(configured).Resolve(Stored));
    }

    [Fact]
    public void The_stored_root_matches_whatever_case_priority_used()
    {
        var map = new AttachmentShareMap(@"\\priority-test\Priority\Attachments");

        Assert.Equal(@"\\priority-test\Priority\Attachments\Documents\a.msg",
                     map.Resolve(@"\\MABA-PRIORITY\priority\attachments\Documents\a.msg"));
    }

    [Theory]
    [InlineData(@"K:\folder\file.pdf")]
    [InlineData(@"P:/Tomax/Archives/DOC_N/Out/2021/PO210.pdf")]
    public void Paths_on_no_server_are_left_alone(string stored)
    {
        Assert.Equal(stored, new AttachmentShareMap(@"\\priority-test\Priority\Attachments").Resolve(stored));
    }

    [Theory]
    [InlineData(@"\\maba-priority\Priority\AttachmentsOld\a.msg")]
    [InlineData(@"\\maba-priority\Priority\Attachments")]
    [InlineData(@"\\maba-priority\Priority\system\mail\26\9\x.msg")]
    [InlineData(@"\\MABA-PRIORITY\other\a.pdf")]
    public void Stage_never_opens_any_other_path_on_the_live_server(string stored)
    {
        // MBA-1028: a STAGE install must never read production's files, not even outside the
        // folder it maps (review of PR #69).
        Assert.Null(new AttachmentShareMap(@"\\priority-test\Priority\Attachments").Resolve(stored));
    }

    [Fact]
    public void Prod_opens_other_live_server_paths_as_stored()
    {
        const string stored = @"\\maba-priority\Priority\system\mail\26\9\x.msg";
        Assert.Equal(stored, new AttachmentShareMap(@"\\maba-priority\Priority\Attachments").Resolve(stored));
    }
}
