using System.Data;
using System.Text.Json;
using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.ReportArchiveSync.Options;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.OrderAttachments;

/// <summary>What dbo.CrmOrderAttachmentConversion.Outcome records for one attempt (MBA-930).</summary>
public enum OrderAttachmentOutcome : byte
{
    Converted = 1,
    Unreadable = 2,
    NotFound = 3,
}

/// <summary>One part as dbo.SaveOrderAttachmentConversion receives it in @PartsJson.</summary>
public sealed record SavedPart(
    string PartId, int Seq, string Name, string Kind, string? Error, string? StorageKey, long? FileSize);

/// <summary>Reads and records Priority order-attachment conversions (MBA-930).</summary>
public sealed class OrderAttachmentRepository(IOptions<ReportArchiveSyncOptions> options)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly ReportArchiveSyncOptions _options = options.Value;

    /// <summary>
    /// Tops up dbo.CrmOrderAttachments from Priority. Incremental adds orders not cached yet; a
    /// full run also drops files Priority removed. One OPENQUERY either way, ~6 s on PROD.
    /// </summary>
    public async Task<(int Orders, int Files)> RefreshCacheAsync(bool incrementalOnly, CancellationToken ct)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(ct);

        await using var command = new SqlCommand("dbo.RefreshOrderAttachmentsCache", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300,
        };
        command.Parameters.Add("@IncrementalOnly", SqlDbType.Bit).Value = incrementalOnly;

        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct)
            ? (reader.GetInt32(reader.GetOrdinal("CachedOrders")), reader.GetInt32(reader.GetOrdinal("CachedFiles")))
            : (0, 0);
    }

    public async Task<IReadOnlyList<OrderAttachmentSource>> GetPendingAsync(CancellationToken ct)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(ct);

        await using var command = new SqlCommand("dbo.GetOrderAttachmentsToConvert", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120,
        };
        command.Parameters.Add("@BatchSize", SqlDbType.Int).Value = _options.OrderAttachmentBatchSize;
        command.Parameters.Add("@RetryAfterHours", SqlDbType.Int).Value = _options.OrderAttachmentRetryAfterHours;
        command.Parameters.Add("@RetryNotFoundDays", SqlDbType.Int).Value = _options.OrderAttachmentRetryNotFoundDays;
        command.Parameters.Add("@RetryErrorPartsDays", SqlDbType.Int).Value = _options.OrderAttachmentRetryErrorPartsDays;

        var pending = new List<OrderAttachmentSource>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            pending.Add(new OrderAttachmentSource(
                reader.GetInt32(reader.GetOrdinal("ORD")),
                reader.GetInt32(reader.GetOrdinal("EXTFILENUM")),
                reader.GetString(reader.GetOrdinal("FilePath")),
                Str(reader, "FileExtension"),
                reader.GetString(reader.GetOrdinal("SourceKind")),
                Str(reader, "Description")));
        }

        return pending;
    }

    /// <summary>
    /// Records one attempt. For <see cref="OrderAttachmentOutcome.Converted"/> it is called only
    /// after every PDF is in S3, so the screen never offers a part that opens nothing.
    /// </summary>
    public async Task SaveAsync(
        OrderAttachmentSource source,
        OrderAttachmentOutcome outcome,
        string? detail,
        string? mergedStorageKey,
        IReadOnlyList<SavedPart>? parts,
        CancellationToken ct)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(ct);

        await using var command = new SqlCommand("dbo.SaveOrderAttachmentConversion", connection)
        {
            CommandType = CommandType.StoredProcedure,
        };
        AddSaveParameters(command.Parameters, source, outcome, detail, mergedStorageKey, parts);

        await command.ExecuteNonQueryAsync(ct);
    }

    /// <summary>
    /// Typed, not AddWithValue, for the reason MBA-998 found: a null sent untyped goes out as
    /// NVARCHAR and does not always convert to the parameter's type.
    /// </summary>
    public static void AddSaveParameters(
        SqlParameterCollection parameters,
        OrderAttachmentSource source,
        OrderAttachmentOutcome outcome,
        string? detail,
        string? mergedStorageKey,
        IReadOnlyList<SavedPart>? parts)
    {
        parameters.Add("@ORD", SqlDbType.Int).Value = source.Ord;
        parameters.Add("@EXTFILENUM", SqlDbType.Int).Value = source.FileNumber;
        parameters.Add("@SourcePath", SqlDbType.NVarChar, 200).Value = source.FilePath;
        parameters.Add("@Outcome", SqlDbType.TinyInt).Value = (byte)outcome;
        parameters.Add("@Detail", SqlDbType.NVarChar, 400).Value = (object?)Truncate(detail, 400) ?? DBNull.Value;
        parameters.Add("@MergedStorageKey", SqlDbType.NVarChar, 400).Value = (object?)mergedStorageKey ?? DBNull.Value;
        parameters.Add("@PartsJson", SqlDbType.NVarChar, -1).Value =
            parts is null ? DBNull.Value : JsonSerializer.Serialize(parts, Json);
    }

    private static string? Str(SqlDataReader reader, string column)
    {
        var i = reader.GetOrdinal(column);
        return reader.IsDBNull(i) ? null : reader.GetString(i).Trim();
    }

    private static string? Truncate(string? value, int length) =>
        value is null || value.Length <= length ? value : value[..length];
}
