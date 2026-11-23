namespace Maba.VCT.OrderAttachments.Data;

/// <summary>
/// One file Priority attached to an order, as dbo.GetOrderAttachmentsToConvert returns it.
/// </summary>
/// <param name="Ord">ORDERS.ORD (= OrderWorkPlans.OrderSourceId).</param>
/// <param name="FileNumber">EXTFILES.EXTFILENUM, the file's key within the order. Not LINE.</param>
/// <param name="FilePath">The path exactly as Priority stored it.</param>
/// <param name="FileExtension">Lower case, without the dot. Null when Priority truncated the path.</param>
/// <param name="SourceKind">OutlookMessage | Pdf | Image | Document | Other.</param>
/// <param name="Description">Priority's description, un-reversed.</param>
public sealed record OrderAttachmentSource(
    int Ord,
    int FileNumber,
    string FilePath,
    string? FileExtension,
    string SourceKind,
    string? Description)
{
    public string FileName => Path.GetFileName(FilePath.Replace('/', '\\').TrimEnd('\\'));
}
