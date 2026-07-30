using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Maba.Api.Services.Priority;

/// <summary>
/// Thin OData v4 client for Priority. Handles Basic-Auth (token or user/pass),
/// query-option building ($filter/$select/$orderby/$top), nextLink pagination,
/// and writes (POST). Options are resolved per call from
/// <see cref="IPriorityODataOptionsProvider"/> so Settings-page changes take
/// effect without a restart.
/// </summary>
public class PriorityODataClient(
    HttpClient http,
    IPriorityODataOptionsProvider optionsProvider,
    ILogger<PriorityODataClient> logger)
{
    public Task<PriorityODataOptions> GetOptionsAsync(CancellationToken ct = default) =>
        optionsProvider.GetAsync(ct);

    // ── Per-run transaction counters ─────────────────────────────────
    // Every HTTP round-trip to Priority is counted. A scenario resets these at the
    // start of a run and reads them at the end (the typed client is injected once
    // per request scope, so the counts are isolated to a single run).
    private int _reads, _writes;
    public int ReadCount => _reads;
    public int WriteCount => _writes;
    public int TransactionCount => _reads + _writes;
    public void ResetCounters() { _reads = 0; _writes = 0; }

    private static string BaseUrlOf(PriorityODataOptions opt) =>
        (opt.BaseUrl ?? throw new InvalidOperationException(
            "Priority OData BaseUrl not configured (PrioritySync:OData:BaseUrl or ODataBaseUrl)")).TrimEnd('/');

    private static void ApplyAuth(HttpRequestMessage req, PriorityODataOptions opt)
    {
        string user, pass;
        if (!string.IsNullOrWhiteSpace(opt.Token))
        {
            // Per the OData guide: username = token value, password = literal "PAT".
            user = opt.Token!;
            pass = "PAT";
        }
        else
        {
            user = opt.Username ?? "";
            pass = opt.Password ?? "";
        }
        var raw = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{user}:{pass}"));
        req.Headers.Authorization = new AuthenticationHeaderValue("Basic", raw);
    }

    /// <summary>
    /// GET an entity collection, following @odata.nextLink pagination, and return
    /// every row as a cloned <see cref="JsonElement"/> (safe to use after disposal).
    /// </summary>
    public async Task<IReadOnlyList<JsonElement>> QueryAsync(
        string entity,
        string? filter = null,
        string? select = null,
        string? orderby = null,
        int? top = null,
        string? expand = null,
        CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);

        // Priority truncates the JSON response when $select and $expand are combined — the
        // expand already returns all main fields, so drop $select whenever $expand is present.
        if (!string.IsNullOrWhiteSpace(expand)) select = null;

        var qs = new List<string>();
        if (!string.IsNullOrWhiteSpace(filter)) qs.Add("$filter=" + Uri.EscapeDataString(filter));
        if (!string.IsNullOrWhiteSpace(select)) qs.Add("$select=" + Uri.EscapeDataString(select));
        if (!string.IsNullOrWhiteSpace(expand)) qs.Add("$expand=" + Uri.EscapeDataString(expand));
        if (!string.IsNullOrWhiteSpace(orderby)) qs.Add("$orderby=" + Uri.EscapeDataString(orderby));
        if (top.HasValue) qs.Add("$top=" + top.Value);

        var url = $"{BaseUrlOf(opt)}/{entity}";
        if (qs.Count > 0) url += "?" + string.Join("&", qs);

        var results = new List<JsonElement>();
        string? next = url;
        while (next is not null)
        {
            _reads++;
            using var req = new HttpRequestMessage(HttpMethod.Get, next);
            req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            ApplyAuth(req, opt);

            using var resp = await http.SendAsync(req, ct);
            var body = await resp.Content.ReadAsStringAsync(ct);
            if (!resp.IsSuccessStatusCode)
                throw new HttpRequestException(
                    $"OData GET {entity} failed ({(int)resp.StatusCode}): {Truncate(body)}");

            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("value", out var val) && val.ValueKind == JsonValueKind.Array)
                foreach (var item in val.EnumerateArray())
                    results.Add(item.Clone());

            next = doc.RootElement.TryGetProperty("@odata.nextLink", out var nl)
                   && nl.ValueKind == JsonValueKind.String
                ? nl.GetString()
                : null;
        }
        return results;
    }

    /// <summary>
    /// POST a new row to an entity collection (requires the Priority transactions
    /// package). Returns the created entity as a cloned <see cref="JsonElement"/>
    /// (so callers can read the generated document key), or null if the body is empty.
    /// </summary>
    public async Task<JsonElement?> PostAsync(string entity, object body, CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);
        _writes++;
        var json = JsonSerializer.Serialize(body);
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrlOf(opt)}/{entity}")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        ApplyAuth(req, opt);

        using var resp = await http.SendAsync(req, ct);
        var respBody = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException(
                $"OData POST {entity} failed ({(int)resp.StatusCode}): {Truncate(respBody)}");

        if (string.IsNullOrWhiteSpace(respBody)) return null;
        try
        {
            using var doc = JsonDocument.Parse(respBody);
            return doc.RootElement.Clone();
        }
        catch { return null; }
    }

    /// <summary>
    /// GET a single entity by its key path (e.g. <c>DOCUMENTS_N(DOCNO='x',TYPE='N')</c>) and
    /// return it as a cloned <see cref="JsonElement"/>. Returns null on 404. Used by the
    /// scenario's read-back verification to confirm a write actually took.
    /// </summary>
    public async Task<JsonElement?> GetOneAsync(string entityPath, string? select = null, CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);
        var url = $"{BaseUrlOf(opt)}/{entityPath}";
        if (!string.IsNullOrWhiteSpace(select)) url += "?$select=" + Uri.EscapeDataString(select);

        _reads++;
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        ApplyAuth(req, opt);

        using var resp = await http.SendAsync(req, ct);
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (resp.StatusCode == System.Net.HttpStatusCode.NotFound) return null;
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException(
                $"OData GET {entityPath} failed ({(int)resp.StatusCode}): {Truncate(body)}");

        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.Clone();
    }

    /// <summary>PATCH an existing entity row (e.g. update a status field) at the given key path.</summary>
    public async Task PatchAsync(string entityPath, object body, CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);
        _writes++;
        var json = JsonSerializer.Serialize(body);
        using var req = new HttpRequestMessage(HttpMethod.Patch, $"{BaseUrlOf(opt)}/{entityPath}")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        ApplyAuth(req, opt);

        using var resp = await http.SendAsync(req, ct);
        var respBody = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException(
                $"OData PATCH {entityPath} failed ({(int)resp.StatusCode}): {Truncate(respBody)}");
    }

    /// <summary>
    /// DELETE an entity row at the given key path (e.g. a sub-form line). 200/204 = success;
    /// 404 is treated as already-gone (idempotent).
    /// </summary>
    public async Task DeleteAsync(string entityPath, CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);
        _writes++;
        using var req = new HttpRequestMessage(HttpMethod.Delete, $"{BaseUrlOf(opt)}/{entityPath}");
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        ApplyAuth(req, opt);

        using var resp = await http.SendAsync(req, ct);
        if (resp.StatusCode == System.Net.HttpStatusCode.NotFound) return;
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException(
                $"OData DELETE {entityPath} failed ({(int)resp.StatusCode}): {Truncate(body)}");
    }

    /// <summary>
    /// Execute an OData v4 JSON <c>$batch</c> — many operations in ONE HTTP round-trip.
    /// Supports content-id references (<c>$1</c>, <c>$1/SUBFORM</c>) and atomicity groups
    /// (change-sets). Counts as a single transaction. Returns each response keyed by op id.
    /// </summary>
    public async Task<IReadOnlyDictionary<string, (int Status, JsonElement? Body)>> BatchAsync(
        IReadOnlyList<BatchOp> ops, CancellationToken ct = default)
    {
        var opt = await optionsProvider.GetAsync(ct);
        // One HTTP round-trip. Count a read-only batch (verification) as a read, else a write.
        if (ops.All(o => string.Equals(o.Method, "GET", StringComparison.OrdinalIgnoreCase))) _reads++;
        else _writes++;

        var requests = new List<Dictionary<string, object?>>();
        foreach (var op in ops)
        {
            var r = new Dictionary<string, object?> { ["id"] = op.Id, ["method"] = op.Method, ["url"] = op.Url };
            if (op.AtomicityGroup is not null) r["atomicityGroup"] = op.AtomicityGroup;
            if (op.DependsOn is not null) r["dependsOn"] = op.DependsOn;
            if (op.Body is not null)
            {
                r["headers"] = new Dictionary<string, string> { ["Content-Type"] = "application/json" };
                r["body"] = op.Body;
            }
            requests.Add(r);
        }
        var payload = JsonSerializer.Serialize(new Dictionary<string, object?> { ["requests"] = requests });

        using var req = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrlOf(opt)}/$batch")
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        };
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        ApplyAuth(req, opt);

        using var resp = await http.SendAsync(req, ct);
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException($"OData $batch failed ({(int)resp.StatusCode}): {Truncate(body)}");

        var result = new Dictionary<string, (int, JsonElement?)>();
        using var doc = JsonDocument.Parse(body);
        if (doc.RootElement.TryGetProperty("responses", out var responses) && responses.ValueKind == JsonValueKind.Array)
            foreach (var r in responses.EnumerateArray())
            {
                var id = r.GetProperty("id").GetString() ?? "";
                var status = r.TryGetProperty("status", out var s) ? s.GetInt32() : 0;
                JsonElement? b = r.TryGetProperty("body", out var bb) && bb.ValueKind is not JsonValueKind.Null
                    ? bb.Clone() : null;
                result[id] = (status, b);
            }
        return result;
    }

    /// <summary>GET the service-root document to verify connectivity + credentials.</summary>
    public async Task<bool> PingAsync(CancellationToken ct = default)
    {
        try
        {
            var opt = await optionsProvider.GetAsync(ct);
            using var req = new HttpRequestMessage(HttpMethod.Get, BaseUrlOf(opt));
            req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            ApplyAuth(req, opt);
            using var resp = await http.SendAsync(req, ct);
            return resp.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Priority OData ping failed");
            return false;
        }
    }

    private static string Truncate(string s) => s.Length > 500 ? s[..500] : s;
}

/// <summary>One operation inside a <c>$batch</c> request. Url may be a content-id reference
/// like <c>$1</c> or <c>$1/SUBFORM</c>. Body null ⇒ no payload (e.g. DELETE).</summary>
public record BatchOp(
    string Id,
    string Method,
    string Url,
    object? Body = null,
    string? AtomicityGroup = null,
    string[]? DependsOn = null);
