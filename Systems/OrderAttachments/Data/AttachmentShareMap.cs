namespace Maba.VCT.OrderAttachments.Data;

/// <summary>
/// Maps the path Priority stored for a file onto the share this installation reads.
///
/// Priority writes an absolute UNC path into EXTFILES.EXTFILENAME, and the server STAGE reads
/// (priority-test) is a clone of the live one, so its rows carry the same
/// <c>\\maba-priority\Priority\Attachments\...</c> as PROD's. Opening that path as written would
/// make a STAGE service read the live share for every document. priority-test has its own copy
/// of the files, in the same layout (checked 22/11/2026: 300 of the newest rows and 100 from
/// 2023, all found under <c>\\priority-test\Priority\Attachments</c>).
///
/// So the stored root is swapped for <c>OrderAttachments:AttachmentShare</c>, which is the
/// share /health already reports. On PROD the two are the same and nothing changes.
/// A path outside the stored root (old <c>K:\</c>, <c>P:\Tomax</c> or <c>C:/Users/...</c>
/// rows, a few dozen in all) is left as is: it cannot be opened on either server, and the
/// conversion reports that.
/// </summary>
public sealed class AttachmentShareMap
{
    /// <summary>The root Priority writes into EXTFILES, on the live server and on its clones.</summary>
    public const string PriorityStoredRoot = @"\\maba-priority\Priority\Attachments";

    public AttachmentShareMap(string? shareRoot)
    {
        ShareRoot = string.IsNullOrWhiteSpace(shareRoot)
            ? PriorityStoredRoot
            : shareRoot.Trim().TrimEnd('\\', '/');
    }

    /// <summary>The share this installation reads.</summary>
    public string ShareRoot { get; }

    public string Resolve(string storedPath)
    {
        ArgumentNullException.ThrowIfNull(storedPath);

        // Only a whole path segment matches: \\maba-priority\Priority\AttachmentsOld is not
        // under the root.
        if (storedPath.Length > PriorityStoredRoot.Length
            && storedPath.StartsWith(PriorityStoredRoot, StringComparison.OrdinalIgnoreCase)
            && storedPath[PriorityStoredRoot.Length] is '\\' or '/')
        {
            return ShareRoot + storedPath[PriorityStoredRoot.Length..];
        }

        return storedPath;
    }
}
