using Maba.VCT.ReportArchiveSync.Invoices;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>
/// The invoice paths are the shapes Priority stores in EXTFILES (TYPE 'I'), measured 2026-11-22:
/// 19,837 of 19,838 start with ..\..\system\mail\, one is a K: drive path.
/// </summary>
public class InvoiceFileLocatorTests
{
    private const string Root = @"\\priority-test\Priority";

    private static InvoiceFileLocator With(params (string Path, long Length)[] pdfs) =>
        new(Root, _ => pdfs);

    [Fact]
    public void Drops_the_leading_hops_and_keeps_only_the_directory()
    {
        var locator = With();
        Assert.Equal(
            @"\\priority-test\Priority\system\mail\26\9\0\y\9bb7a8",
            locator.ResolveDirectory(@"..\..\system\mail\26\9\0\y\9bb7a8\(אבמ) תזכרמ תינובשח תספדה.pdf"));
    }

    [Theory]
    [InlineData(@"K:\םיקפס תוינובשח\file.pdf")]          // a workstation drive, not the share
    [InlineData(@"S:/תובשחוממ תוינובשח/עבט/D26010316.pdf")] // the slash rows, also a drive
    [InlineData(@"..\..\system\..\..\..\other\x.pdf")]      // climbs out after the hops
    [InlineData(@"\\otherserver\share\x.pdf")]               // another share
    [InlineData("file.pdf")]                                  // no directory at all
    [InlineData("")]
    public void Refuses_paths_that_are_not_under_the_root(string stored)
    {
        Assert.Null(With().ResolveDirectory(stored));
        Assert.Equal(InvoiceFileStatus.RefusedPath, With().Locate(stored, 100).Status);
    }

    [Fact]
    public void Leading_hops_cannot_reach_a_sibling_folder_because_they_are_all_dropped()
    {
        // Every leading ..\ goes, so however many there are the path lands under the root -
        // never in \\priority-test\Priority2, which merely shares the prefix.
        var locator = new InvoiceFileLocator(Root, _ => []);
        Assert.Equal(@"\\priority-test\Priority\Priority2\x", locator.ResolveDirectory(@"..\..\..\Priority2\x\a.pdf"));
    }

    [Fact]
    public void One_pdf_is_taken_whatever_its_size()
    {
        var result = With((@"\\priority-test\Priority\system\mail\a\x.pdf", 5)).Locate(@"..\..\system\mail\a\name.pdf", 999);
        Assert.Equal(InvoiceFileStatus.Found, result.Status);
        Assert.Equal(@"\\priority-test\Priority\system\mail\a\x.pdf", result.FullPath);
    }

    [Fact]
    public void Several_pdfs_are_told_apart_by_the_recorded_size()
    {
        var result = With(("a.pdf", 100), ("b.pdf", 101288)).Locate(@"..\..\system\mail\a\name.pdf", 101288);
        Assert.Equal(InvoiceFileStatus.Found, result.Status);
        Assert.Equal("b.pdf", result.FullPath);
    }

    [Fact]
    public void Several_pdfs_and_no_size_match_is_ambiguous_rather_than_a_guess()
    {
        var result = With(("a.pdf", 100), ("b.pdf", 200)).Locate(@"..\..\system\mail\a\name.pdf", 300);
        Assert.Equal(InvoiceFileStatus.Ambiguous, result.Status);
        Assert.Null(result.FullPath);
    }

    [Fact]
    public void An_empty_directory_has_no_file()
    {
        Assert.Equal(InvoiceFileStatus.NoFile, With().Locate(@"..\..\system\mail\a\name.pdf", 1).Status);
    }

    [Fact]
    public void A_missing_directory_counts_as_no_file()
    {
        var locator = new InvoiceFileLocator(Root, _ => throw new DirectoryNotFoundException());
        Assert.Equal(InvoiceFileStatus.NoFile, locator.Locate(@"..\..\system\mail\a\name.pdf", 1).Status);
    }

    [Fact]
    public void A_network_error_is_unreadable_not_missing()
    {
        // What an unreachable \\priority-test gave on the first real STAGE run (2026-11-22).
        var locator = new InvoiceFileLocator(Root, _ => throw new IOException("The network path was not found."));
        var result = locator.Locate(@"..\..\system\mail\a\name.pdf", 1);
        Assert.Equal(InvoiceFileStatus.Unreadable, result.Status);
        Assert.Contains("network path", result.Detail);
    }

    [Fact]
    public void Access_denied_is_unreadable_not_missing()
    {
        var locator = new InvoiceFileLocator(Root, _ => throw new UnauthorizedAccessException());
        Assert.Equal(InvoiceFileStatus.Unreadable, locator.Locate(@"..\..\system\mail\a\name.pdf", 1).Status);
    }

    [Fact]
    public void The_root_check_asks_about_the_root_itself()
    {
        string? asked = null;
        var locator = new InvoiceFileLocator(Root + @"\", directoryExists: path => { asked = path; return false; });
        Assert.False(locator.RootIsReachable());
        Assert.Equal(Root, asked);
    }

    [Fact]
    public void The_storage_key_is_per_invoice_id()
    {
        Assert.Equal("invoices/334036.pdf", InvoiceMirror.StorageKeyFor(334036));
    }
}
