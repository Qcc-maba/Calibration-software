using Maba.Core.Entities;
using Maba.Core.Enums;
using Maba.Core.Interfaces;
using Maba.Infrastructure.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Maba.Api.Services;

public class PrioritySyncService(
    MabaDbContext db,
    IConfiguration config,
    IAppConfigService appConfig,
    ILogger<PrioritySyncService> logger) : PrioritySyncBase(db, logger), IPrioritySyncService
{
    // Prefer the DB-configured connection string (Settings page); fall back to appsettings.
    private async Task<string> GetConnectionStringAsync(CancellationToken ct)
    {
        var dbValue = await appConfig.GetValueAsync("PrioritySync", "ConnectionString", ct);
        if (!string.IsNullOrWhiteSpace(dbValue)) return dbValue.Trim();
        return config.GetConnectionString("Priority")
            ?? throw new InvalidOperationException("Priority connection string not configured");
    }

    // ── Pull Users ──────────────────────────────────────────────────

    public async Task<SyncLog> PullUsersAsync(string initiatedBy, CancellationToken ct = default)
    {
        var log = await StartLog(SyncType.PullUsers, initiatedBy, ct);
        try
        {
            await using var sql = new SqlConnection(await GetConnectionStringAsync(ct));
            await sql.OpenAsync(ct);

            await using var cmd = sql.CreateCommand();
            cmd.CommandText = """
                SELECT DISTINCT USERNAME, EUSERNAME
                FROM MBA_USERSLOAD
                WHERE ACTIVE = 'Y' AND USERNAME IS NOT NULL AND LEN(LTRIM(USERNAME)) > 0
                """;
            cmd.CommandTimeout = 60;

            int count = 0;
            var seen = new HashSet<string>();   // DISTINCT USERNAME,EUSERNAME can repeat a USERNAME
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                var username = FieldStr(reader, "USERNAME");
                if (username is null) continue;
                if (!seen.Add(username)) continue;   // already handled this username in this batch
                var usernameEn = FieldStr(reader, "EUSERNAME");

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
            await using var sql = new SqlConnection(await GetConnectionStringAsync(ct));
            await sql.OpenAsync(ct);

            await using var cmd = sql.CreateCommand();
            cmd.CommandText = """
                SELECT CL.CUST, CL.CUSTDES, CL.ECUSTDES, CL.ADDRESS, CL.EADDRESS
                FROM MBA_CUSTLOAD CL
                INNER JOIN (
                    SELECT CUST, MAX(LINE) AS MaxLine
                    FROM MBA_CUSTLOAD
                    WHERE ACTIVE = 'Y' AND CUSTDES IS NOT NULL AND LEN(LTRIM(CUSTDES)) > 0
                    GROUP BY CUST
                ) ML ON CL.CUST = ML.CUST AND CL.LINE = ML.MaxLine
                ORDER BY CL.CUSTDES
                """;
            cmd.CommandTimeout = 60;

            int count = 0;
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                var nameHe = FieldStr(reader, "CUSTDES");
                if (nameHe is null) continue;
                var nameEn = FieldStr(reader, "ECUSTDES");
                var addrHe = FieldStr(reader, "ADDRESS");
                var addrEn = FieldStr(reader, "EADDRESS");

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
            await using var sql = new SqlConnection(await GetConnectionStringAsync(ct));
            await sql.OpenAsync(ct);

            // Preload Postgres lookups ONCE to avoid per-row N+1 queries (tens of
            // thousands of round-trips on real data volume otherwise).
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

            // Build customer CUST → PostgreSQL id map (in-memory lookup)
            var custMap = new Dictionary<int, int>();
            await using (var custCmd = sql.CreateCommand())
            {
                custCmd.CommandText = """
                    SELECT CUST, CUSTDES FROM MBA_CUSTLOAD
                    WHERE ACTIVE = 'Y' AND CUSTDES IS NOT NULL AND LEN(LTRIM(CUSTDES)) > 0
                    """;
                custCmd.CommandTimeout = 60;
                await using var custReader = await custCmd.ExecuteReaderAsync(ct);
                while (await custReader.ReadAsync(ct))
                {
                    var cust = Field<int?>(custReader, "CUST") ?? 0;
                    var custdes = FieldStr(custReader, "CUSTDES");
                    if (custdes is null || cust == 0 || custMap.ContainsKey(cust)) continue;
                    if (custByName.TryGetValue(custdes, out var pgId))
                        custMap[cust] = pgId;
                }
            }

            // Read documents
            await using var cmd = sql.CreateCommand();
            cmd.CommandText = """
                SELECT DM.MBANUM, DM.DOC, DM.SERNUM, DM.SERNDES, DM.MNFDES,
                       DM.CALIBDAYS, DM.MODEL, DM.CUST, DM.MBA_LANGUAGE
                FROM MBA_DOCLOAD DM
                INNER JOIN (
                    SELECT MBANUM, MAX(LINE) AS MaxLine
                    FROM MBA_DOCLOAD
                    GROUP BY MBANUM
                ) ML ON DM.MBANUM = ML.MBANUM AND DM.LINE = ML.MaxLine
                ORDER BY DM.MBANUM
                """;
            cmd.CommandTimeout = 120;

            int count = 0;
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                var mbaNum = FieldStr(reader, "MBANUM");
                if (mbaNum is null) continue;

                // Find existing record by mba_num (any update_num) via preloaded map
                if (!recByMba.TryGetValue(mbaNum, out var record)) continue; // only update existing records

                bool changed = false;
                var serNum = FieldStr(reader, "SERNUM");
                if (serNum is not null && record.SerialNumber != serNum) { record.SerialNumber = serNum; changed = true; }

                var serndes = FieldStr(reader, "SERNDES");
                if (serndes is not null && record.ItemDescription != serndes) { record.ItemDescription = serndes; changed = true; }

                var mnfdes = FieldStr(reader, "MNFDES");
                if (mnfdes is not null && record.Manufacturer != mnfdes) { record.Manufacturer = mnfdes; changed = true; }

                var model = FieldStr(reader, "MODEL");
                if (model is not null && record.ItemModel != model) { record.ItemModel = model; changed = true; }

                var cust = Field<int?>(reader, "CUST") ?? 0;
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

            // If any sub-sync failed, mark as failed
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

            await using var sql = new SqlConnection(await GetConnectionStringAsync(ct));
            await sql.OpenAsync(ct);

            // Get DOC from MBA_DOCLOAD
            int doc = 0;
            await using (var docCmd = sql.CreateCommand())
            {
                docCmd.CommandText = """
                    SELECT TOP 1 DOC FROM MBA_DOCLOAD DM
                    WHERE MBANUM = @mba
                    AND LINE = (SELECT MAX(LINE) FROM MBA_DOCLOAD DN WHERE DN.MBANUM = DM.MBANUM)
                    """;
                docCmd.Parameters.AddWithValue("@mba", record.MbaNum);
                var docResult = await docCmd.ExecuteScalarAsync(ct);
                if (docResult is not null and not DBNull)
                    doc = Convert.ToInt32(docResult);
            }

            // Get next KLINE from MBA_CALIBLOAD
            int kline = 1;
            await using (var klCmd = sql.CreateCommand())
            {
                klCmd.CommandText = """
                    SELECT MAX(KLINE) FROM MBA_CALIBLOAD
                    WHERE MBANUM = @mba AND UPDATEMABANUM = @upd
                    """;
                klCmd.Parameters.AddWithValue("@mba", record.MbaNum);
                klCmd.Parameters.AddWithValue("@upd", record.UpdateNum);
                var klResult = await klCmd.ExecuteScalarAsync(ct);
                if (klResult is not null and not DBNull)
                    kline = Convert.ToInt32(klResult) + 1;
            }

            // INSERT new status
            await using var insCmd = sql.CreateCommand();
            insCmd.CommandText = """
                INSERT INTO [dbo].[MBA_CALIBLOAD]
                    ([MBANUM], [UPDATEMABANUM], [DOC],
                     [MBA_STATUSNAME], [USERLOGIN], [STATCODE],
                     [CDATE], [UDATE], [FDATE],
                     [LSTATCODE], [KLINE], [MEMO],
                     [AUTHNAME], [REJECTNOTES], [UNIONREPORT],
                     [NEXTCALIBDATE], [PARTMODEL], [MNFCTRNAME], [MNFCTRCODE])
                VALUES
                    (@mba, @upd, @doc,
                     @statusName, @userLogin, @statCode,
                     @cdate, 0, 0,
                     '', @kline, @memo,
                     @authName, @rejectNotes, @unionReport,
                     @nextCalibDate, @partModel, @mnfctrName, @mnfctrCode)
                """;

            insCmd.Parameters.AddWithValue("@mba", record.MbaNum);
            insCmd.Parameters.AddWithValue("@upd", record.UpdateNum);
            insCmd.Parameters.AddWithValue("@doc", doc);
            insCmd.Parameters.AddWithValue("@statusName", (object?)entry.StatusName?.Substring(0, Math.Min(entry.StatusName.Length, 16)) ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@userLogin", (object?)entry.UserLogin?.Substring(0, Math.Min(entry.UserLogin.Length, 20)) ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@statCode", entry.StatCode.ToString());
            insCmd.Parameters.AddWithValue("@cdate", entry.CDate.HasValue
                ? entry.CDate.Value.ToDateTime(TimeOnly.MinValue).ToOADate()
                : 0);
            insCmd.Parameters.AddWithValue("@kline", kline);
            insCmd.Parameters.AddWithValue("@memo", (object?)entry.Memo ?? "MB");
            insCmd.Parameters.AddWithValue("@authName", (object?)entry.AuthName ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@rejectNotes",
                entry.StatCode is CalibStatus.GR or CalibStatus.UG
                    ? (record.Language == "EN" ? "EN" : "HE")
                    : (object)DBNull.Value);
            insCmd.Parameters.AddWithValue("@unionReport", (object?)entry.UnionReport ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@nextCalibDate", entry.NextCalibDate.HasValue
                ? entry.NextCalibDate.Value.ToDateTime(TimeOnly.MinValue).ToOADate()
                : 0);
            insCmd.Parameters.AddWithValue("@partModel", (object?)entry.PartModel ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@mnfctrName", (object?)entry.ManufacturerName ?? DBNull.Value);
            insCmd.Parameters.AddWithValue("@mnfctrCode", (object?)entry.ManufacturerCode ?? DBNull.Value);

            await insCmd.ExecuteNonQueryAsync(ct);
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
        try
        {
            await using var sql = new SqlConnection(await GetConnectionStringAsync(ct));
            await sql.OpenAsync(ct);
            await using var cmd = sql.CreateCommand();
            cmd.CommandText = "SELECT 1";
            await cmd.ExecuteScalarAsync(ct);
            return true;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Priority SQL Server connection test failed");
            return false;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────
    // (SyncLog lifecycle + GetRecentLogsAsync live in PrioritySyncBase)

    private static T? Field<T>(SqlDataReader r, string name)
    {
        try
        {
            int ord = r.GetOrdinal(name);
            if (r.IsDBNull(ord)) return default;
            object val = r.GetValue(ord);
            if (val is T t) return t;
            return (T)Convert.ChangeType(val, typeof(T));
        }
        catch { return default; }
    }

    private static string? FieldStr(SqlDataReader r, string name) =>
        Field<string>(r, name)?.Trim() is { Length: > 0 } s ? s : null;
}
