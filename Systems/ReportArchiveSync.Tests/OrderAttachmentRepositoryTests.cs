using System.Data;
using System.Text.Json;
using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.ReportArchiveSync.OrderAttachments;
using Microsoft.Data.SqlClient;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>MBA-930: what the sync sends dbo.SaveOrderAttachmentConversion.</summary>
public class OrderAttachmentRepositoryTests
{
    private static readonly OrderAttachmentSource Source = new(
        109130, 1, @"\\maba-priority\Priority\Attachments\Documents\2026\10\202610051715552.msg",
        "msg", "OutlookMessage", "RE: quote");

    private static SqlParameterCollection Build(
        OrderAttachmentOutcome outcome, string? detail, string? merged, IReadOnlyList<SavedPart>? parts)
    {
        var command = new SqlCommand();
        OrderAttachmentRepository.AddSaveParameters(command.Parameters, Source, outcome, detail, merged, parts);
        return command.Parameters;
    }

    [Fact]
    public void The_parts_json_uses_the_names_the_procedure_reads()
    {
        // dbo.SaveOrderAttachmentConversion reads $.partId, $.seq, $.name, $.kind, $.error,
        // $.storageKey, $.fileSize. A PascalCase name would arrive as NULL and fail the NOT NULLs.
        var parts = new[]
        {
            new SavedPart("body", 0, "RE: quote", "MailBody", null, "order-attachments/109130/1/body.pdf", 1200),
            new SavedPart("485e01bb86ab11f9", 1, "PO.docx", "Error", "LibreOffice is not installed", null, null),
        };

        var json = (string)Build(OrderAttachmentOutcome.Converted, null, "k", parts)["@PartsJson"].Value;
        var first = JsonDocument.Parse(json).RootElement[0];

        foreach (var name in new[] { "partId", "seq", "name", "kind", "error", "storageKey", "fileSize" })
            Assert.True(first.TryGetProperty(name, out _), $"missing {name} in {json}");
    }

    [Fact]
    public void A_failed_attempt_sends_typed_nulls()
    {
        var parameters = Build(OrderAttachmentOutcome.Unreadable, "IOException: locked", null, null);

        Assert.Equal((byte)2, parameters["@Outcome"].Value);
        Assert.Equal(SqlDbType.NVarChar, parameters["@PartsJson"].SqlDbType);
        Assert.Equal(DBNull.Value, parameters["@PartsJson"].Value);
        Assert.Equal(DBNull.Value, parameters["@MergedStorageKey"].Value);
        Assert.Equal(Source.FilePath, parameters["@SourcePath"].Value);
    }

    [Fact]
    public void Keys_are_per_order_file_and_part()
    {
        Assert.Equal("order-attachments/109130/1/body.pdf", OrderAttachmentMirror.PartKey(109130, 1, "body"));
        Assert.Equal("order-attachments/109130/1/all.pdf", OrderAttachmentMirror.MergedKey(109130, 1));
    }
}
