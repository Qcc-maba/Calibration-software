namespace Maba.VCT.OrderAttachments.Msg;

/// <summary>One file pulled out of a .msg.</summary>
/// <param name="FileName">Name as Outlook stored it, already stripped of path-hostile characters.</param>
/// <param name="Data">The bytes.</param>
/// <param name="ContentId">Set when the part is referenced from the body by <c>cid:</c>.</param>
/// <param name="IsInline">
/// True for parts the body displays itself — signature logos and the like. These are NOT documents
/// and must not be offered to the calibrator as such; see <see cref="ExtractedMessage.Documents"/>.
/// </param>
public sealed record ExtractedFile(string FileName, byte[] Data, string? ContentId, bool IsInline)
{
    public string Extension =>
        Path.GetExtension(FileName).TrimStart('.').ToLowerInvariant();
}

/// <summary>The usable content of one .msg: a body plus whatever came with it.</summary>
public sealed class ExtractedMessage
{
    public required string SourcePath { get; init; }
    public string? Subject { get; init; }
    public DateTimeOffset? SentOn { get; init; }
    public string? From { get; init; }

    /// <summary>The body as HTML, with inline images already re-pointed. Null when the mail has none.</summary>
    public string? BodyHtml { get; init; }

    /// <summary>Plain-text body, used only when <see cref="BodyHtml"/> is null.</summary>
    public string? BodyText { get; init; }

    public IReadOnlyList<ExtractedFile> Files { get; init; } = [];

    /// <summary>
    /// The attachments a person would call documents: everything that is not an inline body image.
    ///
    /// This distinction is the difference between showing a calibrator "PO2485.pdf" and showing
    /// them four copies of the sender's signature logo. Spike samples routinely carried
    /// image001.png / image002.jpg alongside the real purchase order.
    /// </summary>
    public IReadOnlyList<ExtractedFile> Documents =>
        Files.Where(f => !f.IsInline).ToList();

    /// <summary>
    /// True when the mail is only a wrapper — boilerplate body, content entirely in the
    /// attachments. One of the ten spike samples was exactly this: a Word-generated body and an
    /// .xlsx carrying everything that mattered.
    /// </summary>
    public bool IsWrapperOnly =>
        Documents.Count > 0 &&
        (BodyHtml is null || BodyHtml.Length < WrapperBodyThreshold);

    private const int WrapperBodyThreshold = 2_000;
}
