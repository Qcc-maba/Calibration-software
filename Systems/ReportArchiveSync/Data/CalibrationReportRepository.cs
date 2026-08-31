using Maba.VCT.ReportArchiveSync.Options;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.Data;

/// <summary>A device that has a report number but no indexed report file yet.</summary>
public sealed record PendingItem(int OrderDetailsItemId, string OrderNumber, string MbaReportNumber);

public sealed class CalibrationReportRepository(IOptions<ReportArchiveSyncOptions> options)
{
    private readonly ReportArchiveSyncOptions _options = options.Value;

    /// <summary>
    /// Devices to resolve this cycle: they carry a report number, and nothing is registered for
    /// them in dbo.CalibrationReportFile yet.
    /// </summary>
    /// <remarks>
    /// Restricted to one Priority source — see <see cref="ReportArchiveSyncOptions.SourceId"/> for
    /// why joining on Doc across both companies is unsafe.
    /// </remarks>
    public async Task<IReadOnlyList<PendingItem>> GetPendingAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (@BatchSize)
                 itm.OrderDetailsItemId
                ,wp.OrderNumber
                ,itm.MbaReportNumber
            FROM dbo.OrderDetailsItems AS itm
            JOIN dbo.OrderDetails      AS od ON od.OrderDetailId   = itm.OrderDetailId
            JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
            WHERE itm.IsDeleted = 0
              AND od.IsDeleted  = 0
              AND wp.SourceId   = @SourceId
              AND NULLIF(itm.MbaReportNumber, N'') IS NOT NULL
              AND (@OnlyOrderNumber IS NULL OR wp.OrderNumber = @OnlyOrderNumber)
              AND NOT EXISTS (SELECT 1
                              FROM dbo.CalibrationReportFile AS f
                              WHERE f.OrderDetailsItemId = itm.OrderDetailsItemId
                                AND f.IsDeleted = 0)
            ORDER BY itm.OrderDetailsItemId DESC;
            """;

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@BatchSize", _options.BatchSize);
        command.Parameters.AddWithValue("@SourceId", _options.SourceId);
        command.Parameters.AddWithValue(
            "@OnlyOrderNumber", (object?)_options.OnlyOrderNumber ?? DBNull.Value);

        var pending = new List<PendingItem>();

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            pending.Add(new PendingItem(
                reader.GetInt32(0),
                reader.IsDBNull(1) ? string.Empty : reader.GetString(1),
                reader.GetString(2)));
        }

        return pending;
    }

    /// <summary>
    /// Registers one resolved report against one device. Idempotent — see
    /// dbo.UpsertCalibrationReportFile.
    /// </summary>
    public async Task UpsertAsync(
        int orderDetailsItemId,
        string mbaReportNumber,
        string storageKey,
        string variant,
        int updateLevel,
        int coversFrom,
        int coversTo,
        string archivePath,
        byte[]? fileHash,
        long fileSize,
        DateTime archiveModifiedAtUtc,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand("dbo.UpsertCalibrationReportFile", connection)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
        };

        command.Parameters.AddWithValue("@OrderDetailsItemId", orderDetailsItemId);
        command.Parameters.AddWithValue("@MbaReportNumber", mbaReportNumber);
        command.Parameters.AddWithValue("@SourceKind", 2); // 2 = Tomax archive
        command.Parameters.AddWithValue("@StorageKey", storageKey);
        command.Parameters.AddWithValue("@Variant", variant);
        command.Parameters.AddWithValue("@UpdateLevel", updateLevel);
        command.Parameters.AddWithValue("@CoversFrom", coversFrom);
        command.Parameters.AddWithValue("@CoversTo", coversTo);
        command.Parameters.AddWithValue("@ArchivePath", archivePath);
        command.Parameters.AddWithValue("@FileHash", (object?)fileHash ?? DBNull.Value);
        command.Parameters.AddWithValue("@FileSize", fileSize);
        command.Parameters.AddWithValue("@ArchiveModifiedAt", archiveModifiedAtUtc);
        command.Parameters.AddWithValue("@SyncedBy", "Maba.VCT.ReportArchiveSync");

        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
