using Microsoft.Data.SqlClient;
using System.Data;
using Maba.VCT.CustomerPortalApi.Options;
using Microsoft.Extensions.Options;

namespace Maba.VCT.CustomerPortalApi.Data;

/// <summary>Outcome of dbo.CreateCustomerPortalOtp.</summary>
public sealed record CreateOtpResult(
    string Status,
    DateTime? ExpiresAt,
    int? RetryAfterSeconds,
    int? CustomerId,
    int? CustomerContactId,
    string? CustomerContactName,
    string? CustomerName,
    int MatchCount,
    string? IdentitySource);

/// <summary>Outcome of dbo.VerifyCustomerPortalOtp.</summary>
public sealed record VerifyOtpResult(
    string Status,
    int AttemptsLeft,
    string? Email,
    int? CustomerId,
    int? CustomerContactId,
    string? CustomerContactName,
    string? CustomerName);

/// <summary>
/// The only place that talks to Calibrator. All work is done by stored procedures, which own the
/// hybrid identity lookup (local CustomerContacts first, then Priority PHONEBOOK over the linked
/// server) and the rate limiting.
/// </summary>
public sealed class CustomerPortalRepository(IOptions<CustomerPortalOptions> options)
{
    private readonly CustomerPortalOptions _options = options.Value;

    public async Task<CreateOtpResult> CreateOtpAsync(
        string email,
        byte[] codeHash,
        string? requestIp,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await using var command = new SqlCommand("dbo.CreateCustomerPortalOtp", connection)
        {
            CommandType = CommandType.StoredProcedure,
            /* the Priority fallback crosses a linked server; the mirror path returns in milliseconds */
            CommandTimeout = 30,
        };

        command.Parameters.Add("@Email", SqlDbType.NVarChar, 100).Value = email;
        command.Parameters.Add("@CodeHash", SqlDbType.VarBinary, 32).Value = codeHash;
        command.Parameters.Add("@TtlSeconds", SqlDbType.Int).Value = _options.OtpTtlSeconds;
        command.Parameters.Add("@MaxAttempts", SqlDbType.TinyInt).Value = _options.OtpMaxAttempts;
        command.Parameters.Add("@MaxPerWindow", SqlDbType.Int).Value = _options.OtpMaxPerWindow;
        command.Parameters.Add("@WindowSeconds", SqlDbType.Int).Value = _options.OtpWindowSeconds;
        command.Parameters.Add("@RequestIp", SqlDbType.NVarChar, 45).Value =
            (object?)requestIp ?? DBNull.Value;

        await connection.OpenAsync(cancellationToken);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return new CreateOtpResult("EmailNotFound", null, null, null, null, null, null, 0, null);
        }

        return new CreateOtpResult(
            reader.GetString(reader.GetOrdinal("Status")),
            GetValue<DateTime>(reader, "ExpiresAt"),
            GetValue<int>(reader, "RetryAfterSec"),
            GetValue<int>(reader, "CustomerId"),
            GetValue<int>(reader, "CustomerContactId"),
            GetText(reader, "CustomerContactName"),
            GetText(reader, "CustomerName"),
            GetValue<int>(reader, "MatchCount") ?? 0,
            GetText(reader, "IdentitySource"));
    }

    public async Task<VerifyOtpResult> VerifyOtpAsync(
        string email,
        byte[] codeHash,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await using var command = new SqlCommand("dbo.VerifyCustomerPortalOtp", connection)
        {
            CommandType = CommandType.StoredProcedure,
        };

        command.Parameters.Add("@Email", SqlDbType.NVarChar, 100).Value = email;
        command.Parameters.Add("@CodeHash", SqlDbType.VarBinary, 32).Value = codeHash;

        await connection.OpenAsync(cancellationToken);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return new VerifyOtpResult("NotFound", 0, null, null, null, null, null);
        }

        return new VerifyOtpResult(
            reader.GetString(reader.GetOrdinal("Status")),
            GetValue<byte>(reader, "AttemptsLeft") ?? 0,
            GetText(reader, "Email"),
            GetValue<int>(reader, "CustomerId"),
            GetValue<int>(reader, "CustomerContactId"),
            GetText(reader, "CustomerContactName"),
            GetText(reader, "CustomerName"));
    }

    private static T? GetValue<T>(SqlDataReader reader, string column)
        where T : struct
    {
        var ordinal = reader.GetOrdinal(column);

        return reader.IsDBNull(ordinal) ? null : reader.GetFieldValue<T>(ordinal);
    }

    private static string? GetText(SqlDataReader reader, string column)
    {
        var ordinal = reader.GetOrdinal(column);

        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }
}
