using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>
/// Turns a MABA number (מספר מבא, e.g. "2601047/7") into the full instrument context, so the
/// calibrator does not have to type customer / manufacturer / model by hand. Reads
/// <c>amaba.dbo.MBA_DOCLOAD</c>, which carries exactly the fields the instruction sources match on:
///
///   MBANUM ──► CUST (+CUSTOMERS), SERNDES, SERNUM, MNFDES, MODEL, MANUFC_SERIAL
///
/// **Field orientation** (verified against the live DB, 2026-08-04): storage is inconsistent per
/// column. <c>MNFDES</c>, <c>SERNDES</c> and <c>CUSTOMERS.CUSTDES</c> are legacy visual Hebrew
/// (HIOKI stored "IKOIH", Lumenis stored "CSB DTL SINEMUL") and are un-scrambled by
/// <see cref="FixVisualHebrew"/>; <c>MODEL</c>, <c>SERNUM</c> and <c>MANUFC_SERIAL</c> are stored
/// forward and read as-is. See <see cref="PriorityInstructionOptions.VisualHebrewFields"/>.
/// </summary>
public sealed class PriorityRecordResolver(
    IOptions<InstructionAssistantOptions> options,
    ILogger<PriorityRecordResolver> logger)
{
    private readonly PriorityInstructionOptions _opt = options.Value.Priority;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_opt.ConnectionString);

    private const string SelectColumns = """
        d.MBANUM, d.CUST, d.SERNDES, d.SERNUM, d.MNFDES, d.MODEL, d.MANUFC_SERIAL,
        c.CUSTNAME, c.CUSTDES
        """;

    /// <summary>Resolve one MABA number to an instrument context, or null when it is unknown.</summary>
    public async Task<InstrumentContext?> ResolveAsync(string mabaNum, CancellationToken ct = default)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(mabaNum)) return null;

        var sql = $"""
            SELECT TOP 1 {SelectColumns}
            FROM MBA_DOCLOAD d
            LEFT JOIN CUSTOMERS c ON c.CUST = d.CUST
            WHERE d.MBANUM = @m
            ORDER BY d.DOCLOAD DESC
            """;

        try
        {
            await using var conn = new SqlConnection(_opt.ConnectionString);
            await conn.OpenAsync(ct);
            await using var cmd = new SqlCommand(sql, conn);
            cmd.Parameters.Add("@m", SqlDbType.VarChar, 20).Value = mabaNum.Trim();

            await using var r = await cmd.ExecuteReaderAsync(ct);
            return await r.ReadAsync(ct) ? MapContext(r, mabaNum.Trim()) : null;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to resolve MABA number {MabaNum}", mabaNum);
            return null;
        }
    }

    /// <summary>
    /// Manual fallback: find candidate records by serial, model or customer name so the
    /// calibrator can pick the right MABA number.
    /// </summary>
    public async Task<IReadOnlyList<InstrumentContext>> SearchAsync(
        string query, int max = 20, CancellationToken ct = default)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(query) || query.Trim().Length < 2) return [];

        var q = query.Trim();
        var reversed = Reverse(q);

        // The visual-Hebrew columns are matched against both orientations: a Latin query ("HIOKI")
        // only hits them reversed, while a Hebrew query ("מולטימטר") only hits them as typed.
        var sql = $"""
            SELECT DISTINCT TOP (@n) {SelectColumns}
            FROM MBA_DOCLOAD d
            LEFT JOIN CUSTOMERS c ON c.CUST = d.CUST
            WHERE d.MBANUM = @q
               OR d.SERNUM LIKE @like
               OR d.MANUFC_SERIAL LIKE @like
               OR d.MODEL LIKE @like
               OR d.MNFDES LIKE @likeRev  OR d.MNFDES LIKE @like
               OR d.SERNDES LIKE @likeRev OR d.SERNDES LIKE @like
               OR c.CUSTNAME = @q
               OR c.CUSTDES LIKE @likeRev OR c.CUSTDES LIKE @like
            ORDER BY d.MBANUM DESC
            """;

        try
        {
            await using var conn = new SqlConnection(_opt.ConnectionString);
            await conn.OpenAsync(ct);
            await using var cmd = new SqlCommand(sql, conn);
            cmd.Parameters.Add("@n", SqlDbType.Int).Value = max;
            cmd.Parameters.Add("@q", SqlDbType.VarChar, 48).Value = q;
            cmd.Parameters.Add("@like", SqlDbType.VarChar, 52).Value = $"%{q}%";
            cmd.Parameters.Add("@likeRev", SqlDbType.VarChar, 52).Value = $"%{reversed}%";

            var list = new List<InstrumentContext>();
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                // Rows exist with a blank MBANUM (not yet assigned) — they can't be picked, skip them.
                var num = Str(r, "MBANUM");
                if (!string.IsNullOrWhiteSpace(num)) list.Add(MapContext(r, num));
            }
            return list;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Priority search failed for {Query}", query);
            return [];
        }
    }

    private InstrumentContext MapContext(SqlDataReader r, string mabaNum) => new()
    {
        CalibRecordId = mabaNum,
        CustomerId = Str(r, "CUSTNAME"),                    // Priority customer code (e.g. "9732")
        CustomerName = Orient(Str(r, "CUSTDES"), "CUSTDES"),
        Manufacturer = Orient(Str(r, "MNFDES"), "MNFDES"),
        Model = Orient(Str(r, "MODEL"), "MODEL"),
        DeviceType = Orient(Str(r, "SERNDES"), "SERNDES"),
        SerialNumber = Orient(Str(r, "SERNUM"), "SERNUM"),
        CustomerAssetNumber = Orient(Str(r, "MANUFC_SERIAL"), "MANUFC_SERIAL"),
    };

    private string? Orient(string? value, string field)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;

        return _opt.VisualHebrewFields.Contains(field, StringComparer.OrdinalIgnoreCase)
            ? FixVisualHebrew(value).Trim()
            : value.Trim();
    }

    /// <summary>
    /// Un-scrambles a legacy visual-Hebrew value:
    /// <list type="bullet">
    /// <item>no Hebrew at all → the whole value is reversed, word order included
    ///       ("CSB DTL SINEMUL" → "LUMENIS LTD BSC")</item>
    /// <item>otherwise the Hebrew is already in logical order and only each Latin/digit token is
    ///       backwards, so those are reversed in place, leaving whitespace where it is
    ///       ("רב מודד MMD מולטימטר" → "רב מודד DMM מולטימטר";
    ///        "מוט אורך מסטר 521" → "מוט אורך מסטר 125")</item>
    /// </list>
    /// </summary>
    internal static string FixVisualHebrew(string value)
    {
        if (!ContainsHebrew(value)) return Reverse(value);

        var chars = value.ToCharArray();
        int runStart = -1;
        for (int i = 0; i <= chars.Length; i++)
        {
            var inRun = i < chars.Length && !IsHebrew(chars[i]) && !char.IsWhiteSpace(chars[i]);
            if (inRun)
            {
                if (runStart < 0) runStart = i;
            }
            else if (runStart >= 0)
            {
                Array.Reverse(chars, runStart, i - runStart);
                runStart = -1;
            }
        }
        return new string(chars);
    }

    private static bool IsHebrew(char c) => c is >= '֐' and <= '׿';

    private static bool ContainsHebrew(string s) => s.Any(IsHebrew);

    private static string? Str(SqlDataReader r, string name)
    {
        var i = r.GetOrdinal(name);
        return r.IsDBNull(i) ? null : r.GetValue(i)?.ToString();
    }

    internal static string Reverse(string s)
    {
        var chars = s.ToCharArray();
        Array.Reverse(chars);
        return new string(chars);
    }
}
