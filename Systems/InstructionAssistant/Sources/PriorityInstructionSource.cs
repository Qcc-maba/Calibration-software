using System.Data;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>
/// Reads the "הנחיות לביצוע" free text Priority stores per customer order, from
/// <c>amaba.dbo.ORDERSTEXT</c> (verified live 2026-08-04):
///
///   ORDERS.CUST ──► ORDERS.ORD ──► ORDERSTEXT.ORD (TEXT split over TEXTORD/TEXTLINE)
///
/// The stored TEXT is Word-pasted HTML, so it is tag-stripped before use. Most orders carry
/// the same standard terms verbatim, so identical texts across orders are collapsed into a
/// single document labelled as general terms — otherwise the summarizer prompt would be
/// filled with N copies of the same boilerplate.
///
/// Queries Priority read-only (SELECT only). Connection string comes from config/env, never git.
/// </summary>
public sealed partial class PriorityInstructionSource(
    IOptions<InstructionAssistantOptions> options,
    ILogger<PriorityInstructionSource> logger) : IInstructionSourceProvider
{
    private readonly PriorityInstructionOptions _opt = options.Value.Priority;

    public string Name => "priority";

    public async Task<IReadOnlyList<InstructionDocument>> FindAsync(InstrumentContext ctx, CancellationToken ct = default)
    {
        if (!_opt.Enabled) return [];

        if (string.IsNullOrWhiteSpace(_opt.ConnectionString))
        {
            logger.LogWarning("Priority source enabled but no ConnectionString configured — skipping.");
            return [];
        }

        if (string.IsNullOrWhiteSpace(ctx.CustomerId) && string.IsNullOrWhiteSpace(ctx.CustomerName))
            return [];

        try
        {
            await using var conn = new SqlConnection(_opt.ConnectionString);
            await conn.OpenAsync(ct);

            var cust = await ResolveCustomerAsync(conn, ctx, ct);
            if (cust is null)
            {
                logger.LogInformation("No Priority customer matched {Ctx}", ctx);
                return [];
            }

            var orders = await GetRecentOrdersWithTextAsync(conn, cust.Value.Cust, ct);
            if (orders.Count == 0) return [];

            // Group orders by the hash of their text: identical text = standard terms.
            var byHash = new Dictionary<string, (string Text, List<string> Orders)>();
            foreach (var (ord, ordName) in orders)
            {
                ct.ThrowIfCancellationRequested();
                var text = HtmlToPlain(await ReadOrderTextAsync(conn, ord, ct));
                if (text.Length < _opt.MinTextChars) continue;

                var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)))[..16];
                if (byHash.TryGetValue(hash, out var existing)) existing.Orders.Add(ordName);
                else byHash[hash] = (text, [ordName]);
            }

            var docs = new List<InstructionDocument>();
            foreach (var (_, (text, ordNames)) in byHash.OrderByDescending(e => e.Value.Orders.Count))
            {
                var shared = ordNames.Count > 1;
                docs.Add(new InstructionDocument
                {
                    Source = InstructionSourceType.Priority,
                    Title = shared
                        ? $"Priority — הנחיות לביצוע (תנאים קבועים, {ordNames.Count} הזמנות)"
                        : $"Priority — הנחיות לביצוע להזמנה {ordNames[0]}",
                    Reference = $"amaba.dbo.ORDERSTEXT · CUST={cust.Value.Cust} · ORD: {string.Join(", ", ordNames.Take(5))}",
                    MediaType = "text/plain",
                    MatchReason = $"טקסט הזמנה של הלקוח {cust.Value.Description}",
                    Text = text.Length > _opt.MaxCharsPerOrder ? text[.._opt.MaxCharsPerOrder] : text,
                });
            }

            return docs.Take(_opt.MaxDocuments).ToList();
        }
        catch (Exception ex)
        {
            // A dead ERP link must not fail the whole lookup — the Excel/file-share sources still answer.
            logger.LogWarning(ex, "Priority instruction lookup failed for {Ctx}", ctx);
            return [];
        }
    }

    /// <summary>Resolve to CUSTOMERS.CUST from the customer code (CUSTNAME) or a name fragment (CUSTDES).</summary>
    private static async Task<(int Cust, string Description)?> ResolveCustomerAsync(
        SqlConnection conn, InstrumentContext ctx, CancellationToken ct)
    {
        const string byCode = "SELECT TOP 1 CUST, CUSTDES FROM CUSTOMERS WHERE CUSTNAME = @v";
        // CUSTDES is visual Hebrew — a Latin name is stored reversed, so match either orientation.
        const string byName = """
            SELECT TOP 1 CUST, CUSTDES FROM CUSTOMERS
            WHERE CUSTDES LIKE @v OR CUSTDES LIKE @vRev
            ORDER BY CUST DESC
            """;

        if (!string.IsNullOrWhiteSpace(ctx.CustomerId))
        {
            var hit = await QueryCustomerAsync(conn, byCode, ctx.CustomerId!.Trim(), ct);
            if (hit is not null) return hit;
        }

        if (!string.IsNullOrWhiteSpace(ctx.CustomerName))
        {
            // Try the name as a code first (callers often pass the Priority code in either field).
            var asCode = await QueryCustomerAsync(conn, byCode, ctx.CustomerName!.Trim(), ct);
            if (asCode is not null) return asCode;
            return await QueryCustomerAsync(conn, byName, $"%{ctx.CustomerName!.Trim()}%", ct);
        }

        return null;
    }

    private static async Task<(int, string)?> QueryCustomerAsync(
        SqlConnection conn, string sql, string value, CancellationToken ct)
    {
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@v", SqlDbType.NVarChar, 100).Value = value;
        if (sql.Contains("@vRev", StringComparison.Ordinal))
            cmd.Parameters.Add("@vRev", SqlDbType.NVarChar, 100).Value =
                $"%{PriorityRecordResolver.Reverse(value.Trim('%'))}%";
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        // CUSTDES is stored visual-Hebrew; un-scramble it so the match reason is readable.
        return (r.GetInt32(0), r.IsDBNull(1) ? "" : PriorityRecordResolver.FixVisualHebrew(r.GetString(1)));
    }

    private async Task<List<(int Ord, string OrdName)>> GetRecentOrdersWithTextAsync(
        SqlConnection conn, int cust, CancellationToken ct)
    {
        // CURDATE is Priority's minutes-since-1988 integer; ordering by ORD desc is equivalent
        // and avoids the date conversion.
        var sql = $"""
            SELECT TOP (@n) o.ORD, o.ORDNAME
            FROM ORDERS o
            WHERE o.CUST = @cust
              AND EXISTS (SELECT 1 FROM ORDERSTEXT t WHERE t.ORD = o.ORD)
            ORDER BY o.ORD DESC
            """;

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@n", SqlDbType.Int).Value = _opt.MaxOrders;
        cmd.Parameters.Add("@cust", SqlDbType.Int).Value = cust;

        var list = new List<(int, string)>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add((r.GetInt32(0), r.IsDBNull(1) ? r.GetInt32(0).ToString() : r.GetString(1)));
        return list;
    }

    /// <summary>
    /// Reads an order's text. Verified live: Priority stores each ORDERSTEXT row
    /// character-reversed (legacy visual-Hebrew storage) — "&lt;style&gt;" comes back as
    /// "&gt;elyts&lt;". Each row is reversed back before the rows are concatenated in
    /// TEXTORD/TEXTLINE order; without this the HTML never parses and the text is gibberish.
    /// </summary>
    private static async Task<string> ReadOrderTextAsync(SqlConnection conn, int ord, CancellationToken ct)
    {
        const string sql = "SELECT TEXT FROM ORDERSTEXT WHERE ORD = @ord ORDER BY TEXTORD, TEXTLINE";
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add("@ord", SqlDbType.Int).Value = ord;

        var sb = new StringBuilder();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            if (r.IsDBNull(0)) continue;
            var chars = r.GetString(0).ToCharArray();
            Array.Reverse(chars);
            sb.Append(chars);
        }
        return sb.ToString();
    }

    /// <summary>Priority stores Word-pasted HTML; keep block boundaries as newlines, drop the markup.</summary>
    internal static string HtmlToPlain(string html)
    {
        if (string.IsNullOrWhiteSpace(html)) return "";

        var s = StyleOrScript().Replace(html, " ");
        s = BlockBreak().Replace(s, "\n");
        s = AnyTag().Replace(s, " ");
        s = WebUtility.HtmlDecode(s);
        s = s.Replace(' ', ' ').Replace('‏', ' ').Replace('‎', ' ');
        s = HorizontalWhitespace().Replace(s, " ");
        s = BlankLines().Replace(s, "\n");

        return string.Join('\n', s.Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0));
    }

    [GeneratedRegex(@"<(style|script)\b[^>]*>.*?</\1>", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex StyleOrScript();

    [GeneratedRegex(@"</?(p|br|div|tr|li|h[1-6]|table)\b[^>]*>", RegexOptions.IgnoreCase)]
    private static partial Regex BlockBreak();

    [GeneratedRegex(@"<[^>]+>")]
    private static partial Regex AnyTag();

    [GeneratedRegex(@"[^\S\n]+")]
    private static partial Regex HorizontalWhitespace();

    [GeneratedRegex(@"\n{2,}")]
    private static partial Regex BlankLines();
}
