using Maba.VCT.ReportArchiveSync.Options;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.Invoices;

/// <summary>An invoice whose PDF should be copied this cycle (dbo.GetInvoiceDocumentsToSync).</summary>
public sealed record PendingInvoice(int Iv, string InvoiceNumber, int ExtFileNum, string ExtFileName, long? FileSize);

/// <summary>Reads and records invoice documents in dbo.CustomerInvoiceDocument (MBA-998).</summary>
public sealed class InvoiceDocumentRepository(IOptions<ReportArchiveSyncOptions> options)
{
    private readonly ReportArchiveSyncOptions _options = options.Value;

    public async Task<IReadOnlyList<PendingInvoice>> GetPendingAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand("dbo.GetInvoiceDocumentsToSync", connection)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
            // One OPENQUERY over ~20,000 rows: seconds normally, but the linked server can be slow.
            CommandTimeout = 300,
        };

        command.Parameters.AddWithValue("@BatchSize", _options.InvoiceBatchSize);
        command.Parameters.AddWithValue("@RetryAfterDays", _options.InvoiceRetryAfterDays);

        var pending = new List<PendingInvoice>();

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            pending.Add(new PendingInvoice(
                reader.GetInt32(reader.GetOrdinal("IV")),
                reader.GetString(reader.GetOrdinal("InvoiceNumber")).Trim(),
                reader.GetInt32(reader.GetOrdinal("ExtFileNum")),
                reader.GetString(reader.GetOrdinal("ExtFileName")),
                reader.IsDBNull(reader.GetOrdinal("FileSize")) ? null : reader.GetInt64(reader.GetOrdinal("FileSize"))));
        }

        return pending;
    }

    /// <summary>
    /// Records one attempt. Called after the upload for a success, so the portal never shows an
    /// icon that opens nothing.
    /// </summary>
    public async Task RecordAsync(
        PendingInvoice invoice,
        InvoiceFileStatus outcome,
        string? detail,
        string? storageKey,
        byte[]? fileHash,
        long? fileSize,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand("dbo.UpsertCustomerInvoiceDocument", connection)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
        };

        command.Parameters.AddWithValue("@IV", invoice.Iv);
        command.Parameters.AddWithValue("@InvoiceNumber", invoice.InvoiceNumber);
        command.Parameters.AddWithValue("@ExtFileNum", invoice.ExtFileNum);
        command.Parameters.AddWithValue("@SourcePath", Truncate(invoice.ExtFileName, 400));
        command.Parameters.AddWithValue("@Outcome", (byte)outcome);
        command.Parameters.AddWithValue("@Detail", (object?)Truncate(detail, 400) ?? DBNull.Value);
        command.Parameters.AddWithValue("@StorageKey", (object?)storageKey ?? DBNull.Value);
        command.Parameters.AddWithValue("@FileHash", (object?)fileHash ?? DBNull.Value);
        command.Parameters.AddWithValue("@FileSize", (object?)fileSize ?? DBNull.Value);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static string? Truncate(string? value, int length) =>
        value is null || value.Length <= length ? value : value[..length];
}
