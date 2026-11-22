using System.Data;
using Maba.VCT.ReportArchiveSync.Invoices;
using Microsoft.Data.SqlClient;

namespace Maba.VCT.ReportArchiveSync.Tests;

/// <summary>
/// The first real STAGE run (2026-11-22) failed on the first invoice without a PDF: its null hash
/// went out as NVARCHAR and SQL Server refused it for the BINARY(32) parameter (error 257).
/// </summary>
public class InvoiceDocumentRepositoryTests
{
    private static readonly PendingInvoice Invoice =
        new(334036, "I2606100", 7, @"..\..\system\mail\26\11\x.pdf", 1234);

    private static SqlParameterCollection Build(byte[]? hash, long? size, string? key, string? detail)
    {
        var command = new SqlCommand();
        InvoiceDocumentRepository.AddRecordParameters(
            command.Parameters, Invoice, InvoiceFileStatus.NoFile, detail, key, hash, size);
        return command.Parameters;
    }

    [Fact]
    public void A_missing_hash_is_still_sent_as_binary()
    {
        var parameters = Build(hash: null, size: null, key: null, detail: "Directory not readable");

        Assert.Equal(SqlDbType.Binary, parameters["@FileHash"].SqlDbType);
        Assert.Equal(DBNull.Value, parameters["@FileHash"].Value);
        Assert.Equal(SqlDbType.BigInt, parameters["@FileSize"].SqlDbType);
        Assert.Equal(DBNull.Value, parameters["@StorageKey"].Value);
    }

    [Fact]
    public void A_found_file_carries_its_hash_and_size()
    {
        var hash = new byte[32];
        var parameters = Build(hash, size: 1234, key: "invoices/334036.pdf", detail: null);

        Assert.Same(hash, parameters["@FileHash"].Value);
        Assert.Equal(1234L, parameters["@FileSize"].Value);
        Assert.Equal((byte)InvoiceFileStatus.NoFile, parameters["@Outcome"].Value);
        Assert.Equal(DBNull.Value, parameters["@Detail"].Value);
    }

    [Fact]
    public void A_long_source_path_is_cut_to_the_column_width()
    {
        var command = new SqlCommand();
        var longPath = new PendingInvoice(1, "I1", 1, new string('a', 500), null);
        InvoiceDocumentRepository.AddRecordParameters(
            command.Parameters, longPath, InvoiceFileStatus.NoFile, null, null, null, null);

        Assert.Equal(400, ((string)command.Parameters["@SourcePath"].Value).Length);
    }
}
