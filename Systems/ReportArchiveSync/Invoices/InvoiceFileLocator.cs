namespace Maba.VCT.ReportArchiveSync.Invoices;

/// <summary>What the locator found for one invoice attachment.</summary>
public enum InvoiceFileStatus
{
    Found = 1,
    NoFile = 2,
    Ambiguous = 3,
    RefusedPath = 4,

    /// <summary>
    /// The directory or file could not be read (network error, access denied, locked). Recorded
    /// as its own outcome and retried after hours, not days (dbo.GetInvoiceDocumentsToSync), so
    /// a folder that stays unreadable cannot hold the front of the newest-first queue. A share
    /// that is down as a whole is caught earlier by <see cref="InvoiceFileLocator.RootIsReachable"/>
    /// and records nothing: recording that as NoFile parked every invoice for days on the first
    /// real STAGE run (2026-11-22).
    /// </summary>
    Unreadable = 5,
}

/// <param name="FullPath">The PDF to copy, when <see cref="Status"/> is <see cref="InvoiceFileStatus.Found"/>.</param>
/// <param name="Detail">Why nothing was found, for the other statuses.</param>
public sealed record InvoiceFileResult(InvoiceFileStatus Status, string? FullPath, string? Detail);

/// <summary>
/// Finds the PDF behind one Priority invoice attachment (EXTFILES, TYPE 'I') on Priority's share.
/// </summary>
/// <remarks>
/// <para>
/// Priority stores the path relative to a folder two levels below its root
/// (<c>..\..\system\mail\26\9\0\y\9bb7a8\name.pdf</c>), so dropping the leading hops gives a path
/// under the root itself.
/// </para>
/// <para>
/// Only the DIRECTORY is used. Priority keeps the file name in visual order, so its Hebrew is
/// reversed against what is on disk; the directory is ASCII and is a hash folder of its own, with
/// one PDF in it. When there are several, the one whose size Priority recorded wins - for invoice
/// attachments FILESIZE is the real byte count (measured 2026-11-22: never the path length, unlike
/// order attachments).
/// </para>
/// </remarks>
public sealed class InvoiceFileLocator(
    string root,
    Func<string, IReadOnlyList<(string Path, long Length)>>? listPdfs = null,
    Func<string, bool>? directoryExists = null)
{
    private readonly string _root = Path.TrimEndingDirectorySeparator(root);

    private readonly Func<string, IReadOnlyList<(string Path, long Length)>> _listPdfs = listPdfs ?? ListPdfsOnDisk;

    private readonly Func<string, bool> _directoryExists = directoryExists ?? Directory.Exists;

    /// <summary>
    /// False when <c>system\mail</c> under the root cannot be seen (host down, no network, no
    /// permission). A cycle stops there instead of judging every invoice against an unreachable
    /// share. It probes the folder the invoices live in, not the root: the service account is
    /// granted read on <c>system\mail</c>, and may have no access to the root itself.
    /// </summary>
    public bool RootIsReachable() => _directoryExists(MailFolder);

    /// <summary>The folder every invoice attachment lives under (19,837 of 19,838 on PROD).</summary>
    public string MailFolder => Path.Combine(_root, "system", "mail");

    /// <summary>The directory a stored EXTFILENAME points at, or null when the path is refused.</summary>
    public string? ResolveDirectory(string storedPath)
    {
        if (string.IsNullOrWhiteSpace(storedPath))
        {
            return null;
        }

        var cleaned = storedPath.Trim().Replace('/', '\\');

        while (cleaned.StartsWith(@"..\", StringComparison.Ordinal))
        {
            cleaned = cleaned[3..];
        }

        var lastSeparator = cleaned.LastIndexOf('\\');

        if (lastSeparator <= 0)
        {
            return null;
        }

        var directory = cleaned[..lastSeparator];

        // Anything still climbing, or rooted (a drive letter or another share), is not under the
        // root and is not followed.
        // A ".." segment, not any name with two dots in it (a folder such as "v1..2" is fine).
        if (directory.Split('\\').Contains("..") || Path.IsPathRooted(directory) || directory.Contains(':'))
        {
            return null;
        }

        var full = Path.GetFullPath(Path.Combine(_root, directory));
        var inside = Path.GetRelativePath(_root, full);

        return inside == "." || inside.StartsWith("..", StringComparison.Ordinal) || Path.IsPathRooted(inside)
            ? null
            : full;
    }

    public InvoiceFileResult Locate(string storedPath, long? recordedSize)
    {
        var directory = ResolveDirectory(storedPath);

        if (directory is null)
        {
            return new InvoiceFileResult(InvoiceFileStatus.RefusedPath, null, "Path is not under the Priority root");
        }

        IReadOnlyList<(string Path, long Length)> pdfs;

        try
        {
            pdfs = _listPdfs(directory);
        }
        catch (DirectoryNotFoundException)
        {
            // The folder is really not there: a real answer, recorded and retried after days.
            return new InvoiceFileResult(InvoiceFileStatus.NoFile, null, "Directory not found");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Must follow DirectoryNotFoundException, which is an IOException.
            return new InvoiceFileResult(
                InvoiceFileStatus.Unreadable, null, $"Directory not readable: {ex.GetType().Name}: {ex.Message}");
        }

        if (pdfs.Count == 0)
        {
            return new InvoiceFileResult(InvoiceFileStatus.NoFile, null, "No PDF in the directory");
        }

        if (pdfs.Count == 1)
        {
            return new InvoiceFileResult(InvoiceFileStatus.Found, pdfs[0].Path, null);
        }

        var bySize = pdfs.Where(p => recordedSize is > 0 && p.Length == recordedSize).ToList();

        return bySize.Count == 1
            ? new InvoiceFileResult(InvoiceFileStatus.Found, bySize[0].Path, null)
            : new InvoiceFileResult(InvoiceFileStatus.Ambiguous, null,
                $"{pdfs.Count} PDFs in the directory, {bySize.Count} of the recorded size {recordedSize}");
    }

    private static IReadOnlyList<(string Path, long Length)> ListPdfsOnDisk(string directory) =>
        new DirectoryInfo(directory)
            .EnumerateFiles("*", SearchOption.TopDirectoryOnly)
            .Where(f => f.Extension.Equals(".pdf", StringComparison.OrdinalIgnoreCase))
            .Select(f => (f.FullName, f.Length))
            .ToList();
}
