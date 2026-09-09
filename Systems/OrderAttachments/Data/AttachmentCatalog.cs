using Microsoft.Data.SqlClient;

namespace Maba.VCT.OrderAttachments.Data;

/// <summary>One row of dbo.GetOrderAttachmentsByOrder.</summary>
public sealed record OrderAttachmentRow(
    int OrderWorkPlanId,
    string OrderNumber,
    int FileNumber,
    string? FileName,
    string? FilePath,
    string? FileExtension,
    string SourceKind,
    string? Description,
    bool CanBeServed,
    bool IsPathTruncated);

/// <summary>One row of dbo.GetOrderAttachmentCounts — what the grid needs per order.</summary>
public sealed record OrderAttachmentCount(
    int OrderWorkPlanId,
    string OrderNumber,
    int FileCount,
    int ServableFiles,
    int TruncatedFiles);

/// <summary>
/// Reads the attachment catalogue from Calibrator. Both procedures serve from
/// dbo.CrmOrderAttachments, a local cache of Priority's EXTFILES, so no request here reaches
/// across the linked server.
/// </summary>
public sealed class AttachmentCatalog(string connectionString)
{
    public async Task<IReadOnlyList<OrderAttachmentRow>> GetForOrderAsync(
        int orderWorkPlanId, CancellationToken ct = default)
    {
        await using var cn = new SqlConnection(connectionString);
        await cn.OpenAsync(ct);

        await using var cmd = new SqlCommand("dbo.GetOrderAttachmentsByOrder", cn)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
        };
        cmd.Parameters.AddWithValue("@OrderWorkPlanId", orderWorkPlanId);

        var rows = new List<OrderAttachmentRow>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            rows.Add(new OrderAttachmentRow(
                OrderWorkPlanId: r.GetInt32(r.GetOrdinal("OrderWorkPlanId")),
                OrderNumber: r.GetString(r.GetOrdinal("OrderNumber")).Trim(),
                FileNumber: r.GetInt32(r.GetOrdinal("FileNumber")),
                FileName: Str(r, "FileName"),
                FilePath: Str(r, "FilePath"),
                FileExtension: Str(r, "FileExtension"),
                SourceKind: Str(r, "SourceKind") ?? "Other",
                Description: Str(r, "Description"),
                CanBeServed: r.GetBoolean(r.GetOrdinal("CanBeServed")),
                IsPathTruncated: r.GetBoolean(r.GetOrdinal("IsPathTruncated"))));
        }
        return rows;
    }

    /// <param name="orderWorkPlanIds">
    /// Null for every order that has files. The grid passes the page it is rendering: this is a
    /// deliberately batched call so the screen does not issue one request per row.
    /// </param>
    public async Task<IReadOnlyList<OrderAttachmentCount>> GetCountsAsync(
        IEnumerable<int>? orderWorkPlanIds, CancellationToken ct = default)
    {
        await using var cn = new SqlConnection(connectionString);
        await cn.OpenAsync(ct);

        await using var cmd = new SqlCommand("dbo.GetOrderAttachmentCounts", cn)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
        };
        cmd.Parameters.AddWithValue(
            "@OrderWorkPlanIds",
            orderWorkPlanIds is null ? DBNull.Value : string.Join(',', orderWorkPlanIds));

        var rows = new List<OrderAttachmentCount>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            rows.Add(new OrderAttachmentCount(
                r.GetInt32(r.GetOrdinal("OrderWorkPlanId")),
                r.GetString(r.GetOrdinal("OrderNumber")).Trim(),
                r.GetInt32(r.GetOrdinal("FileCount")),
                r.GetInt32(r.GetOrdinal("ServableFiles")),
                r.GetInt32(r.GetOrdinal("TruncatedFiles"))));
        }
        return rows;
    }

    private static string? Str(SqlDataReader r, string column)
    {
        var i = r.GetOrdinal(column);
        return r.IsDBNull(i) ? null : r.GetString(i).Trim();
    }
}
