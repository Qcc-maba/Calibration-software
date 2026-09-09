using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

// ── Priority OData connection probe ──────────────────────────────────────────
// Standalone spike to verify connectivity + credentials AND that each Priority
// screen the MABA sync needs is exposed to the API with the expected fields.
// Run this before flipping PrioritySync:Mode to "OData".
//
// Usage (token auth — recommended):
//   dotnet run --project tools/PriorityODataProbe -- \
//       --url "https://server/odata/Priority/tabula.ini/maba" --token "<PAT>"
//
// Usage (on-prem user/password):
//   dotnet run --project tools/PriorityODataProbe -- \
//       --url "https://server/odata/Priority/tabula.ini/maba" --user APIUSER --pass secret
//
// By default it tests the four MABA screens. Override with:
//   --entities MBA_CUSTLOAD,MBA_DOCLOAD   (comma-separated, skips field checks)
//   --top N                               (sample row count, default 3)
//
// What it does:
//   1. GET service root      → lists the entity sets exposed to the API
//   2. GET $metadata         → confirms the model is reachable
//   3. For each screen       → samples rows, lists returned columns, and flags
//                              any expected field that is missing/not exposed
// ─────────────────────────────────────────────────────────────────────────────

// Expected fields per MABA screen (must match PriorityODataSyncService).
var MABA_SCREENS = new (string Entity, string[] Fields)[]
{
    ("MBA_USERSLOAD", new[] { "USERNAME", "EUSERNAME", "ACTIVE" }),
    ("MBA_CUSTLOAD",  new[] { "CUST", "LINE", "CUSTDES", "ECUSTDES", "ADDRESS", "EADDRESS", "ACTIVE" }),
    ("MBA_DOCLOAD",   new[] { "MBANUM", "LINE", "DOC", "SERNUM", "SERNDES", "MNFDES", "MODEL", "CUST", "MBA_LANGUAGE" }),
    ("MBA_CALIBLOAD", new[] { "MBANUM", "UPDATEMABANUM", "DOC", "STATCODE", "KLINE", "MEMO",
                              "MBA_STATUSNAME", "USERLOGIN", "CDATE", "NEXTCALIBDATE", "REJECTNOTES" }),
};

var opts = ParseArgs(args);
if (opts is null) return 1;
var (url, token, user, pass, entitiesArg, fieldsEntity, top) = opts.Value;

var baseUrl = url.TrimEnd('/');
using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

string authUser = !string.IsNullOrEmpty(token) ? token : user;
string authPass = !string.IsNullOrEmpty(token) ? "PAT" : pass;
var authHeader = new AuthenticationHeaderValue(
    "Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes($"{authUser}:{authPass}")));

async Task<(bool ok, int status, string body)> GetAsync(string u)
{
    using var req = new HttpRequestMessage(HttpMethod.Get, u);
    req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
    req.Headers.Authorization = authHeader;
    try
    {
        using var resp = await http.SendAsync(req);
        var body = await resp.Content.ReadAsStringAsync();
        return (resp.IsSuccessStatusCode, (int)resp.StatusCode, body);
    }
    catch (Exception ex)
    {
        return (false, 0, ex.Message);
    }
}

Console.WriteLine($"Probing {baseUrl}");
Console.WriteLine($"Auth: {(string.IsNullOrEmpty(token) ? $"user '{user}'" : "PAT token")}");
Console.WriteLine(new string('─', 64));

// 1) Service root
Console.WriteLine("\n[1] Service document (entity sets exposed to the API)");
var (ok1, st1, body1) = await GetAsync(baseUrl);
if (!ok1)
{
    Console.WriteLine($"  FAILED ({st1}): {Truncate(body1, 800)}");
    Console.WriteLine("\n  Check: URL, API license on the user, token value, network/cert.");
    return 2;
}
var exposed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
try
{
    using var doc = JsonDocument.Parse(body1);
    if (doc.RootElement.TryGetProperty("value", out var sets))
        foreach (var s in sets.EnumerateArray())
        {
            var n = s.GetProperty("name").GetString();
            if (n is not null) { exposed.Add(n); Console.WriteLine($"  • {n}"); }
        }
}
catch { Console.WriteLine($"  {Truncate(body1, 800)}"); }

// 2) Metadata
Console.WriteLine("\n[2] $metadata");
var (ok2, st2, body2) = await GetAsync($"{baseUrl}/$metadata");
Console.WriteLine(ok2 ? $"  OK ({body2.Length} chars)" : $"  FAILED ({st2}): {Truncate(body2, 400)}");

// 2b) Field discovery from $metadata for a specific entity (works even with 0 data rows)
if (ok2 && !string.IsNullOrEmpty(fieldsEntity))
{
    Console.WriteLine($"\n[2b] Fields of EntityType matching '{fieldsEntity}' (from $metadata)");
    var rx = new System.Text.RegularExpressions.Regex(
        $"<EntityType[^>]*Name=\"[^\"]*{System.Text.RegularExpressions.Regex.Escape(fieldsEntity)}[^\"]*\"[^>]*>(.*?)</EntityType>",
        System.Text.RegularExpressions.RegexOptions.Singleline | System.Text.RegularExpressions.RegexOptions.IgnoreCase);
    var m = rx.Match(body2);
    if (!m.Success)
        Console.WriteLine($"  (no EntityType name contains '{fieldsEntity}' — check the exact name in [1])");
    else
    {
        var props = System.Text.RegularExpressions.Regex.Matches(m.Groups[1].Value,
            "<(?:Property|NavigationProperty)[^>]*Name=\"([^\"]+)\"[^>]*?(?:Type=\"([^\"]+)\")?[^>]*/?>");
        foreach (System.Text.RegularExpressions.Match p in props)
            Console.WriteLine($"  • {p.Groups[1].Value}{(p.Groups[2].Success ? "  : " + p.Groups[2].Value : "")}");
    }
}

// 3) Per-screen checks
var screens = entitiesArg.Length > 0
    ? entitiesArg.Select(e => (Entity: e, Fields: Array.Empty<string>())).ToArray()
    : MABA_SCREENS;

Console.WriteLine($"\n[3] Screen checks ({screens.Length} screen(s), $top={top})");
int failures = 0;
foreach (var (entity, fields) in screens)
{
    Console.WriteLine($"\n  ── {entity} ──");
    if (exposed.Count > 0 && !exposed.Contains(entity))
        Console.WriteLine($"  ⚠ Not listed in the service document — screen may not be open to the API license.");

    var (ok, st, body) = await GetAsync($"{baseUrl}/{entity}?$top={top}");
    if (!ok)
    {
        failures++;
        Console.WriteLine($"  ✗ GET failed ({st}): {Truncate(body, 400)}");
        continue;
    }

    using var doc = JsonDocument.Parse(body);
    if (!doc.RootElement.TryGetProperty("value", out var rows) || rows.ValueKind != JsonValueKind.Array)
    {
        Console.WriteLine($"  ? Unexpected response: {Truncate(body, 300)}");
        continue;
    }

    var rowList = rows.EnumerateArray().ToList();
    Console.WriteLine($"  ✓ Reachable — {rowList.Count} sample row(s)");

    if (rowList.Count == 0)
    {
        Console.WriteLine("    (no rows — cannot verify fields; check ACTIVE filter / data)");
        continue;
    }

    var present = new HashSet<string>(
        rowList[0].EnumerateObject().Select(p => p.Name), StringComparer.OrdinalIgnoreCase);
    Console.WriteLine($"    columns: {string.Join(", ", present.OrderBy(x => x))}");

    if (fields.Length > 0)
    {
        var missing = fields.Where(f => !present.Contains(f)).ToArray();
        if (missing.Length == 0)
            Console.WriteLine($"    ✓ all {fields.Length} expected fields present");
        else
        {
            failures++;
            Console.WriteLine($"    ✗ MISSING expected fields: {string.Join(", ", missing)}");
        }
    }
}

Console.WriteLine("\n" + new string('─', 64));
Console.WriteLine(failures == 0
    ? "All checks passed — safe to configure OData in Settings and flip the mode."
    : $"{failures} issue(s) found — fix screen exposure / field names before going live.");
return failures == 0 ? 0 : 3;

static string Truncate(string s, int max) => s.Length > max ? s[..max] + "…" : s;

static (string url, string token, string user, string pass, string[] entities, string fields, int top)? ParseArgs(string[] args)
{
    string url = "", token = "", user = "", pass = "", fields = "";
    string[] entities = [];
    int top = 3;
    for (int i = 0; i < args.Length - 1; i++)
    {
        switch (args[i])
        {
            case "--url": url = args[++i]; break;
            case "--token": token = args[++i]; break;
            case "--user": user = args[++i]; break;
            case "--pass": pass = args[++i]; break;
            case "--entity": entities = [args[++i]]; break;
            case "--entities": entities = args[++i].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries); break;
            case "--fields": fields = args[++i]; break;
            case "--top": int.TryParse(args[++i], out top); break;
        }
    }
    if (string.IsNullOrEmpty(url) || (string.IsNullOrEmpty(token) && string.IsNullOrEmpty(user)))
    {
        Console.WriteLine("Usage: --url <serviceRoot> (--token <PAT> | --user <u> --pass <p>) [--entities a,b,c] [--fields <Entity>] [--top N]");
        return null;
    }
    return (url, token, user, pass, entities, fields, top);
}
