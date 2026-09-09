using System.Text.Json;
using Maba.Api.Services.Priority;
using Maba.Core.Entities;
using Maba.Core.Enums;
using Maba.Core.Interfaces;
using Maba.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Maba.Api.Services;

/// <summary>
/// Priority sync over the OData REST API (the supported, non-SQL transport).
/// Drop-in replacement for <see cref="PrioritySyncService"/> — selected via
/// <c>PrioritySync:Mode = "OData"</c>. Pull/push semantics mirror the SQL
/// implementation so downstream behavior is unchanged.
/// </summary>
public class PriorityODataSyncService(
    MabaDbContext db,
    PriorityODataClient client,
    ILogger<PriorityODataSyncService> logger)
    : PrioritySyncBase(db, logger), IPrioritySyncService
{
    // ── Pull Users ──────────────────────────────────────────────────

    public async Task<SyncLog> PullUsersAsync(string initiatedBy, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PullUsers, initiatedBy, ct);
        try
        {
            var E = (await client.GetOptionsAsync(ct)).Entities;
            var rows = await client.QueryAsync(
                E.Users,
                filter: "ACTIVE eq 'Y'",
                select: "USERNAME,EUSERNAME",
                ct: ct);

            int count = 0;
            var seen = new HashSet<string>();   // same USERNAME may appear on multiple rows
            foreach (var row in rows)
            {
                var username = Str(row, "USERNAME");
                if (username is null) continue;
                if (!seen.Add(username)) continue;   // already handled this username in this batch
                var usernameEn = Str(row, "EUSERNAME");

                var existing = await Db.Users.FirstOrDefaultAsync(u => u.Username == username, ct);
                if (existing is null)
                {
                    Db.Users.Add(new MbaUser
                    {
                        Username = username,
                        UsernameEn = usernameEn,
                        PasswordHash = "$2a$11$rW8UECR0fzSmRmATvMg6UOq5r6.kM6SOeyHBbcz.rlWiRhYPJz8Jy", // Change123!
                        Active = true
                    });
                    count++;
                }
                else if (usernameEn is not null && existing.UsernameEn != usernameEn)
                {
                    existing.UsernameEn = usernameEn;
                    count++;
                }
            }

            await Db.SaveChangesAsync(ct);
            return await CompleteLog(log, count, ct);
        }
        catch (Exception ex)
        {
            return await FailLog(log, ex, ct);
        }
    }

    // ── Pull Customers ──────────────────────────────────────────────

    public async Task<SyncLog> PullCustomersAsync(string initiatedBy, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PullCustomers, initiatedBy, ct);
        try
        {
            var E = (await client.GetOptionsAsync(ct)).Entities;
            var rows = await client.QueryAsync(
                E.Customers,
                filter: "ACTIVE eq 'Y'",
                select: "CUST,LINE,CUSTDES,ECUSTDES,ADDRESS,EADDRESS",
                orderby: "CUST,LINE",
                ct: ct);

            int count = 0;
            // Keep only the highest-LINE row per CUST (mirrors the legacy MAX(LINE) join).
            foreach (var row in LatestPerKey(rows, "CUST"))
            {
                var nameHe = Str(row, "CUSTDES");
                if (nameHe is null) continue;
                var nameEn = Str(row, "ECUSTDES");
                var addrHe = Str(row, "ADDRESS");
                var addrEn = Str(row, "EADDRESS");

                var existing = await Db.Customers.FirstOrDefaultAsync(c => c.NameHe == nameHe, ct);
                if (existing is null)
                {
                    Db.Customers.Add(new Customer
                    {
                        NameHe = nameHe,
                        NameEn = nameEn,
                        AddressHe = addrHe,
                        AddressEn = addrEn
                    });
                    count++;
                }
                else
                {
                    bool changed = false;
                    if (nameEn is not null && existing.NameEn != nameEn) { existing.NameEn = nameEn; changed = true; }
                    if (addrHe is not null && existing.AddressHe != addrHe) { existing.AddressHe = addrHe; changed = true; }
                    if (addrEn is not null && existing.AddressEn != addrEn) { existing.AddressEn = addrEn; changed = true; }
                    if (changed) count++;
                }
            }

            await Db.SaveChangesAsync(ct);
            return await CompleteLog(log, count, ct);
        }
        catch (Exception ex)
        {
            return await FailLog(log, ex, ct);
        }
    }

    // ── Pull Documents ──────────────────────────────────────────────

    public async Task<SyncLog> PullDocumentsAsync(string initiatedBy, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PullDocuments, initiatedBy, ct);
        try
        {
            var E = (await client.GetOptionsAsync(ct)).Entities;

            // Preload Postgres lookups ONCE to avoid per-row N+1 queries.
            var custByName = new Dictionary<string, int>();
            foreach (var c in await Db.Customers
                         .Where(c => c.NameHe != null)
                         .Select(c => new { c.NameHe, c.Id })
                         .ToListAsync(ct))
                custByName[c.NameHe!] = c.Id;

            var recByMba = new Dictionary<string, CalibRecord>();
            foreach (var r in await Db.CalibRecords.ToListAsync(ct))
                if (r.MbaNum is not null)
                    recByMba.TryAdd(r.MbaNum, r);

            // Build Priority CUST → PostgreSQL customer id map (match on Hebrew name).
            var custMap = new Dictionary<int, int>();
            var custRows = await client.QueryAsync(
                E.Customers,
                filter: "ACTIVE eq 'Y'",
                select: "CUST,CUSTDES",
                ct: ct);
            foreach (var row in custRows)
            {
                var cust = IntOf(row, "CUST") ?? 0;
                var custdes = Str(row, "CUSTDES");
                if (custdes is null || cust == 0 || custMap.ContainsKey(cust)) continue;
                if (custByName.TryGetValue(custdes, out var pgId))
                    custMap[cust] = pgId;
            }

            var docRows = await client.QueryAsync(
                E.Documents,
                select: "MBANUM,LINE,DOC,SERNUM,SERNDES,MNFDES,CALIBDAYS,MODEL,CUST,MBA_LANGUAGE",
                orderby: "MBANUM,LINE",
                ct: ct);

            int count = 0;
            foreach (var row in LatestPerKey(docRows, "MBANUM"))
            {
                var mbaNum = Str(row, "MBANUM");
                if (mbaNum is null) continue;

                if (!recByMba.TryGetValue(mbaNum, out var record)) continue; // only update existing records

                bool changed = false;
                var serNum = Str(row, "SERNUM");
                if (serNum is not null && record.SerialNumber != serNum) { record.SerialNumber = serNum; changed = true; }

                var serndes = Str(row, "SERNDES");
                if (serndes is not null && record.ItemDescription != serndes) { record.ItemDescription = serndes; changed = true; }

                var mnfdes = Str(row, "MNFDES");
                if (mnfdes is not null && record.Manufacturer != mnfdes) { record.Manufacturer = mnfdes; changed = true; }

                var model = Str(row, "MODEL");
                if (model is not null && record.ItemModel != model) { record.ItemModel = model; changed = true; }

                var cust = IntOf(row, "CUST") ?? 0;
                if (cust > 0 && custMap.TryGetValue(cust, out var pgCustId) && record.CustomerId != pgCustId)
                {
                    record.CustomerId = pgCustId;
                    changed = true;
                }

                if (changed) count++;
            }

            await Db.SaveChangesAsync(ct);
            return await CompleteLog(log, count, ct);
        }
        catch (Exception ex)
        {
            return await FailLog(log, ex, ct);
        }
    }

    // ── Pull All ────────────────────────────────────────────────────

    public async Task<SyncLog> PullAllAsync(string initiatedBy, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PullAll, initiatedBy, ct);
        try
        {
            var usersLog = await PullUsersAsync(initiatedBy, ct);
            var customersLog = await PullCustomersAsync(initiatedBy, ct);
            var docsLog = await PullDocumentsAsync(initiatedBy, ct);

            int total = usersLog.ItemsSynced + customersLog.ItemsSynced + docsLog.ItemsSynced;

            if (usersLog.Status == SyncStatus.Failed ||
                customersLog.Status == SyncStatus.Failed ||
                docsLog.Status == SyncStatus.Failed)
            {
                var errors = new List<string>();
                if (usersLog.ErrorMessage is not null) errors.Add($"Users: {usersLog.ErrorMessage}");
                if (customersLog.ErrorMessage is not null) errors.Add($"Customers: {customersLog.ErrorMessage}");
                if (docsLog.ErrorMessage is not null) errors.Add($"Documents: {docsLog.ErrorMessage}");
                return await FailLog(log, string.Join("; ", errors), total, ct);
            }

            return await CompleteLog(log, total, ct);
        }
        catch (Exception ex)
        {
            return await FailLog(log, ex, ct);
        }
    }

    // ── Push CalibStatus ────────────────────────────────────────────

    public async Task<SyncLog> PushCalibStatusAsync(int recordId, CalibStatusEntry entry, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PushCalibStatus, "auto", ct);
        try
        {
            var record = await Db.CalibRecords.FindAsync([recordId], ct);
            if (record is null)
                return await FailLog(log, $"Record {recordId} not found", 0, ct);

            var E = (await client.GetOptionsAsync(ct)).Entities;
            var mbaFilter = $"MBANUM eq '{EscapeOData(record.MbaNum)}'";

            // Resolve DOC from the latest document line.
            int doc = 0;
            var docRows = await client.QueryAsync(
                E.Documents, filter: mbaFilter, select: "DOC,LINE", orderby: "LINE desc", top: 1, ct: ct);
            if (docRows.Count > 0)
                doc = IntOf(docRows[0], "DOC") ?? 0;

            // Next KLINE = max(KLINE) for this record + 1.
            int kline = 1;
            var klRows = await client.QueryAsync(
                E.CalibStatus,
                filter: $"{mbaFilter} and UPDATEMABANUM eq {record.UpdateNum}",
                select: "KLINE", orderby: "KLINE desc", top: 1, ct: ct);
            if (klRows.Count > 0)
                kline = (IntOf(klRows[0], "KLINE") ?? 0) + 1;

            // Build the row. Only include fields we set; omit nulls so Priority keeps defaults.
            // Dates are sent as ISO yyyy-MM-dd (OData date fields), not OLE-Automation doubles.
            var body = new Dictionary<string, object?>
            {
                ["MBANUM"] = record.MbaNum,
                ["UPDATEMABANUM"] = record.UpdateNum,
                ["DOC"] = doc,
                ["STATCODE"] = entry.StatCode.ToString(),
                ["KLINE"] = kline,
                ["MEMO"] = entry.Memo ?? "MB",
            };

            if (entry.StatusName is { Length: > 0 } sn)
                body["MBA_STATUSNAME"] = sn[..Math.Min(sn.Length, 16)];
            if (entry.UserLogin is { Length: > 0 } ul)
                body["USERLOGIN"] = ul[..Math.Min(ul.Length, 20)];
            if (entry.CDate is { } cd)
                body["CDATE"] = cd.ToString("yyyy-MM-dd");
            if (entry.NextCalibDate is { } ncd)
                body["NEXTCALIBDATE"] = ncd.ToString("yyyy-MM-dd");
            if (entry.AuthName is not null) body["AUTHNAME"] = entry.AuthName;
            if (entry.UnionReport is not null) body["UNIONREPORT"] = entry.UnionReport;
            if (entry.PartModel is not null) body["PARTMODEL"] = entry.PartModel;
            if (entry.ManufacturerName is not null) body["MNFCTRNAME"] = entry.ManufacturerName;
            if (entry.ManufacturerCode is not null) body["MNFCTRCODE"] = entry.ManufacturerCode;
            if (entry.StatCode is CalibStatus.GR or CalibStatus.UG)
                body["REJECTNOTES"] = record.Language == "EN" ? "EN" : "HE";

            await client.PostAsync(E.CalibStatus, body, ct);
            return await CompleteLog(log, 1, ct);
        }
        catch (Exception ex)
        {
            return await FailLog(log, ex, ct);
        }
    }

    // ── Test Connection ─────────────────────────────────────────────

    public async Task<bool> TestConnectionAsync(CancellationToken ct = default)
    {
        var opt = await client.GetOptionsAsync(ct);
        if (string.IsNullOrWhiteSpace(opt.BaseUrl))
        {
            logger.LogWarning("Priority OData not configured (ODataBaseUrl / PrioritySync:OData:BaseUrl is empty)");
            return false;
        }
        return await client.PingAsync(ct);
    }

    // ── Helpers ─────────────────────────────────────────────────────

    /// <summary>Group rows by an integer key column and keep the row with the highest LINE.</summary>
    private static IEnumerable<JsonElement> LatestPerKey(IEnumerable<JsonElement> rows, string keyField)
    {
        var best = new Dictionary<string, (int Line, JsonElement Row)>();
        foreach (var row in rows)
        {
            var key = Str(row, keyField);
            if (key is null) continue;
            int line = IntOf(row, "LINE") ?? 0;
            if (!best.TryGetValue(key, out var cur) || line >= cur.Line)
                best[key] = (line, row);
        }
        return best.Values.Select(v => v.Row);
    }

    private static string EscapeOData(string s) => s.Replace("'", "''");

    private static string? Str(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        var s = p.ValueKind == JsonValueKind.String ? p.GetString() : p.ToString();
        return string.IsNullOrWhiteSpace(s) ? null : s!.Trim();
    }

    private static int? IntOf(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        if (p.ValueKind == JsonValueKind.Number && p.TryGetInt32(out var i)) return i;
        if (p.ValueKind == JsonValueKind.String && int.TryParse(p.GetString(), out var j)) return j;
        return null;
    }
}
