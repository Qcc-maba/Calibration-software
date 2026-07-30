using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Maba.Api.Services.Priority.Scenarios;

public interface IShipmentScenarioService
{
    /// <summary>Run (or preview) Scenario 2 — customer shipment from an intake doc.</summary>
    Task<ReturnGoodsResult> ExecuteAsync(ShipmentRequest req, bool preview, bool verify = true, CancellationToken ct = default);
}

/// <summary>
/// Scenario 2 — "הוצאת תעודת משלוח" over Priority OData (ביקורת station).
/// Verified live on s190225 (D26000004). Field names in <see cref="ShipmentScenarioOptions"/>.
/// Returns the same result shape as scenario 1, so UI/metrics work unchanged.
/// </summary>
public class ShipmentScenarioService(
    PriorityODataClient client,
    IOptions<ShipmentScenarioOptions> options,
    ILogger<ShipmentScenarioService> logger) : IShipmentScenarioService
{
    private readonly ShipmentScenarioOptions _o = options.Value;

    public async Task<ReturnGoodsResult> ExecuteAsync(ShipmentRequest req, bool preview, bool verify = true, CancellationToken ct = default)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        client.ResetCounters();
        var result = await RunAsync(req, preview, verify, ct);
        return result with
        {
            DurationMs = sw.ElapsedMilliseconds,
            Writes = client.WriteCount,
            Reads = client.ReadCount,
            Transactions = client.TransactionCount,
        };
    }

    private async Task<ReturnGoodsResult> RunAsync(ShipmentRequest req, bool preview, bool verify, CancellationToken ct)
    {
        var steps = new List<string>();
        var checks = new List<StepCheck>();
        try
        {
            var opt = await client.GetOptionsAsync(ct);
            bool live = !preview && !string.IsNullOrWhiteSpace(opt.BaseUrl);
            if (!preview && !live)
                return new(false, null, steps, "Priority OData not configured.");

            // ── 1-2. Create the shipment document ──
            var header = new Dictionary<string, object?> { [_o.CustField] = req.CustomerName };
            steps.Add($"[1-2 תעודה] POST {_o.ShipDocEntity}  {J(header)}");
            string docKey = "{{docKey}}";
            if (live)
            {
                var created = await client.PostAsync(_o.ShipDocEntity, header, ct);
                if (created is { } c && c.TryGetProperty(_o.DocKeyField, out var k)) docKey = k.ToString();
                else return new(false, null, steps, "לא ניתן לקרוא את מספר התעודה מה-POST.");
            }
            string DocPath() => $"{_o.ShipDocEntity}({_o.DocKeyField}='{Esc(docKey)}',{_o.DocTypeField}='{_o.DocTypeValue}')";

            // ── 3. Contact ──
            if (req.Contact is { Length: > 0 })
            {
                var body = new Dictionary<string, object?> { [_o.ContactField] = req.Contact };
                steps.Add($"[3 איש קשר] PATCH {DocPath()}  {J(body)}");
                if (live) await client.PatchAsync(DocPath(), body, ct);
            }

            // ── 4. Link the intake doc (auto-fills the device-marking list) ──
            var linkBody = new Dictionary<string, object?> { [_o.IntakeDocField] = req.IntakeDoc };
            steps.Add($"[4 קליטה] POST {DocPath()}/{_o.IntakeLinkSubform}  {J(linkBody)}");
            if (live) await client.PostAsync($"{DocPath()}/{_o.IntakeLinkSubform}", linkBody, ct);

            // ── 5. Mark devices. Marking SENT='Y' CONSUMES the row (keys shift), so:
            //       read → mark first matching → re-read → repeat.
            int marked = 0;
            steps.Add($"[5 סימון] PATCH {DocPath()}/{_o.MarkSubform}(LINE,USER) {{{_o.MarkSentField}:'Y'}} — " +
                      (req.DeviceFilters is { Count: > 0 } ? $"רק: {string.Join(", ", req.DeviceFilters)}" : "כל המכשירים"));
            if (live)
            {
                (long, long)? lastKey = null;
                string? stuckSerial = null;
                for (int iter = 0; iter < _o.MarkMaxIterations; iter++)
                {
                    var rows = await client.QueryAsync($"{DocPath()}/{_o.MarkSubform}", ct: ct);
                    var next = rows.FirstOrDefault(r => Str(r, _o.MarkSentField) != "Y" && MatchesFilter(r, req.DeviceFilters));
                    if (next.ValueKind == JsonValueKind.Undefined) break;
                    var k1 = IntOf(next, _o.MarkKey1);
                    var k2 = IntOf(next, _o.MarkKey2);
                    if (k1 is null || k2 is null) break;

                    // Priority silently refuses SENT='Y' for a device that has not been
                    // inspected yet (MBA_ISCHECKED) — it answers 200 but leaves SENT null.
                    // Without this guard we'd re-mark the same row MarkMaxIterations times.
                    if (lastKey == (k1.Value, k2.Value))
                    {
                        stuckSerial = Str(next, _o.MarkStampField) ?? Str(next, _o.MarkMbaNumField);
                        break;
                    }
                    lastKey = (k1.Value, k2.Value);

                    await client.PatchAsync(
                        $"{DocPath()}/{_o.MarkSubform}({_o.MarkKey1}={k1},{_o.MarkKey2}={k2})",
                        new Dictionary<string, object?> { [_o.MarkSentField] = "Y" }, ct);
                    marked++;
                }
                if (stuckSerial is not null)
                    return new(false, docKey, steps,
                        $"Priority לא מאפשר לסמן את מכשיר {stuckSerial} כ\"נשלח\" — " +
                        "סביר שהוא עדיין לא סומן \"נבדק\" במסך בדיקת המכשירים בקליטה.",
                        checks.Count == 0 ? null : checks, false);
                checks.Add(new("5 סימון מכשירים", "marked", req.DeviceFilters is { Count: > 0 } ? $"{req.DeviceFilters.Count}" : ">0",
                    marked.ToString(), req.DeviceFilters is { Count: > 0 } ? marked == req.DeviceFilters.Count : marked > 0));
            }

            // ── 6. Detail lines (auto-created by the marking) ──
            IReadOnlyList<JsonElement> detail = [];
            steps.Add($"[6 פירוט] GET {DocPath()}/{_o.DetailSubform}");
            if (live)
            {
                detail = await client.QueryAsync($"{DocPath()}/{_o.DetailSubform}",
                    select: $"{_o.LineKeyField},{_o.LineSkuField},{_o.LineQtyField},{_o.LineBalanceField},{_o.LineBillingField}", ct: ct);
                checks.Add(new("6 שורות פירוט", "rows", ">0", detail.Count.ToString(), detail.Count > 0));

                // Clear, early failure instead of the cryptic "אין שורות" on finalize.
                if (detail.Count == 0)
                    return new(false, docKey, steps,
                        $"לא נמצאו מכשירים פנויים למשלוח בקליטה {req.IntakeDoc} " +
                        (marked == 0 ? "— ייתכן שכולם כבר נשלחו, או שהמכשירים משוריינים בתעודת משלוח פתוחה אחרת." : "(אף שורת פירוט לא נוצרה)."),
                        checks.Count == 0 ? null : checks, false);
            }

            // ── 6b. Quantities: charge lines ← balance (CQUANT); device SKUs consolidated ──
            //   • Charge line (no serial): TQUANT = balance to ship (CQUANT).
            //   • Device SKU with several lines: consolidate all serials onto the first line
            //     (qty = device count) and delete the rest. Deleting a device line requires
            //     first deleting its "קריאות שרות למכשיר" links, then its serial (SERNTRANS).
            //   • Explicit QuantityUpdates SKUs are skipped (step 7 handles them).
            if (req.AutoQuantities && live && detail.Count > 0)
            {
                var explicitSkus = new HashSet<string>((req.QuantityUpdates ?? []).Select(q => q.PartName));
                // NOTE: Priority truncates the response when $select + $expand are combined,
                // so we use $expand alone (it returns all main fields anyway).
                var lines = await client.QueryAsync($"{DocPath()}/{_o.DetailSubform}",
                    expand: $"{_o.DeviceRegPerLineSubform}($select={_o.DeviceRegKeyField},{_o.DeviceRegNumField})", ct: ct);

                var parsed = lines.Select(l => new ShipLine(
                    IntOf(l, _o.LineKeyField), Str(l, _o.LineSkuField), DecOf(l, _o.LineBalanceField),
                    l.TryGetProperty(_o.DeviceRegPerLineSubform, out var s) && s.ValueKind == JsonValueKind.Array
                        ? s.EnumerateArray().Select(x => (Sern: IntOf(x, _o.DeviceRegKeyField), Num: Str(x, _o.DeviceRegNumField)))
                            .Where(x => x.Sern is not null).ToList()
                        : []))
                    .Where(x => x.Kline is not null && x.Part is not null).ToList();

                string LinePath(int? kl) => $"{DocPath()}/{_o.DetailSubform}({_o.LineKeyField}={kl},{_o.DocTypeField}='{_o.DocTypeValue}')";

                foreach (var g in parsed.GroupBy(x => x.Part!))
                {
                    if (explicitSkus.Contains(g.Key)) continue;
                    var deviceLines = g.Where(x => x.Serials.Count > 0).OrderBy(x => x.Kline).ToList();

                    // charge lines → balance to ship
                    foreach (var c in g.Where(x => x.Serials.Count == 0))
                    {
                        var bal = c.Bal ?? 0m;
                        await client.PatchAsync(LinePath(c.Kline), new Dictionary<string, object?> { [_o.LineQtyField] = bal }, ct);
                        steps.Add($"[6b כמות] שורת חיוב {g.Key}: כמות ← יתרה למשלוח {bal}");
                        if (verify)
                        {
                            var back = await client.GetOneAsync(LinePath(c.Kline), select: _o.LineQtyField, ct: ct);
                            var got = back is { } bb && bb.TryGetProperty(_o.LineQtyField, out var q) ? q.ToString() : "<לא נקרא>";
                            checks.Add(new($"6b כמות {g.Key}", _o.LineQtyField, bal.ToString(), got, decimal.TryParse(got, out var dv) && dv == bal));
                        }
                    }

                    // consolidate a device SKU that spans several lines
                    if (_o.GroupDevices && deviceLines.Count > 1)
                    {
                        var keep = deviceLines[0];
                        var keptNums = new HashSet<string>(keep.Serials.Select(x => x.Num!).Where(n => n is not null));
                        var total = deviceLines.Sum(dl => dl.Serials.Count);
                        var keepPath = LinePath(keep.Kline);
                        foreach (var src in deviceLines.Skip(1))
                        {
                            var srcPath = LinePath(src.Kline);
                            foreach (var dev in src.Serials)
                            {
                                if (dev.Num is not null && keptNums.Add(dev.Num))
                                    try { await client.PostAsync($"{keepPath}/{_o.DeviceRegPerLineSubform}", new Dictionary<string, object?> { [_o.DeviceRegNumField] = dev.Num }, ct); }
                                    catch (Exception ex) { logger.LogWarning(ex, "add serial {S} to kept line", dev.Num); }
                                var sernPath = $"{srcPath}/{_o.DeviceRegPerLineSubform}({_o.DeviceRegKeyField}={dev.Sern})";
                                try
                                {
                                    var calls = await client.QueryAsync($"{sernPath}/{_o.DeviceCallLinkSubform}", select: _o.DeviceCallKeyField, ct: ct);
                                    foreach (var call in calls)
                                        if (IntOf(call, _o.DeviceCallKeyField) is { } cid)
                                            await client.DeleteAsync($"{sernPath}/{_o.DeviceCallLinkSubform}({_o.DeviceCallKeyField}={cid})", ct);
                                    await client.DeleteAsync(sernPath, ct);
                                }
                                catch (Exception ex) { logger.LogWarning(ex, "remove serial {S} from source line", dev.Num); }
                            }
                            try { await client.DeleteAsync(srcPath, ct); }
                            catch (Exception ex) { logger.LogWarning(ex, "delete source device line {K}", src.Kline); }
                        }
                        await client.PatchAsync(keepPath, new Dictionary<string, object?> { [_o.LineQtyField] = total }, ct);
                        steps.Add($"[6b קיבוץ] {g.Key}: {deviceLines.Count} שורות מכשיר → שורה אחת, כמות {total}");
                        if (verify)
                        {
                            var back = await client.GetOneAsync(keepPath, select: _o.LineQtyField, ct: ct);
                            var got = back is { } bb && bb.TryGetProperty(_o.LineQtyField, out var q) ? q.ToString() : "<לא נקרא>";
                            checks.Add(new($"6b קיבוץ {g.Key}", _o.LineQtyField, total.ToString(), got, int.TryParse(got, out var iv) && iv == total));
                        }
                    }
                }
            }

            // ── 7. Quantity updates (MUST happen before finalize — final docs are locked) ──
            foreach (var qu in req.QuantityUpdates ?? [])
            {
                steps.Add($"[7 כמות] PATCH פירוט {qu.PartName} → {qu.Quantity}");
                if (!live) continue;
                var line = detail.FirstOrDefault(d => Str(d, _o.LineSkuField) == qu.PartName);
                var kline = line.ValueKind == JsonValueKind.Undefined ? null : IntOf(line, _o.LineKeyField);
                if (kline is null)
                {
                    checks.Add(new($"7 כמות {qu.PartName}", _o.LineQtyField, qu.Quantity.ToString(), "<שורה לא נמצאה>", false));
                    continue;
                }
                var linePath = $"{DocPath()}/{_o.DetailSubform}({_o.LineKeyField}={kline},{_o.DocTypeField}='{_o.DocTypeValue}')";
                await client.PatchAsync(linePath, new Dictionary<string, object?> { [_o.LineQtyField] = qu.Quantity }, ct);
                if (verify)
                {
                    var back = await client.GetOneAsync(linePath, select: _o.LineQtyField, ct: ct);
                    var got = back is { } bb && bb.TryGetProperty(_o.LineQtyField, out var q) ? q.ToString() : "<לא נקרא>";
                    checks.Add(new($"7 כמות {qu.PartName}", _o.LineQtyField, qu.Quantity.ToString(), got,
                        decimal.TryParse(got, out var dv) && dv == qu.Quantity));
                }
            }

            // ── 7b. Billing off (להוריד את ה-V לחיוב) ──
            if (!req.Billing)
            {
                steps.Add($"[7b חיוב] PATCH כל שורות הפירוט {{{_o.LineBillingField}:null}}");
                if (live)
                    foreach (var d in detail)
                    {
                        var kline = IntOf(d, _o.LineKeyField);
                        if (kline is null) continue;
                        var linePath = $"{DocPath()}/{_o.DetailSubform}({_o.LineKeyField}={kline},{_o.DocTypeField}='{_o.DocTypeValue}')";
                        // must be "" — a JSON null is silently ignored by Priority (verified live)
                        await client.PatchAsync(linePath, new Dictionary<string, object?> { [_o.LineBillingField] = "" }, ct);
                        if (verify)
                        {
                            var back = await client.GetOneAsync(linePath, select: _o.LineBillingField, ct: ct);
                            var got = back is { } bb && bb.TryGetProperty(_o.LineBillingField, out var f) ? Str2(f) : "<לא נקרא>";
                            checks.Add(new($"7b ביטול חיוב שורה {kline}", _o.LineBillingField, "", got, got.Length == 0));
                        }
                    }
            }

            // ── 8. Free text ──
            if (req.FreeText is { Length: > 0 })
            {
                var textBody = new Dictionary<string, object?> { [_o.TextField] = req.FreeText, [_o.TextAppendField] = true };
                steps.Add($"[8 טקסט] POST {DocPath()}/{_o.TextSubform}  {J(textBody)}");
                if (live)
                {
                    await client.PostAsync($"{DocPath()}/{_o.TextSubform}", textBody, ct);
                    checks.Add(new("8 טקסט חופשי", _o.TextField, req.FreeText, req.FreeText, true));
                }
            }

            // ── 9. Finalize ──
            if (req.Finalize)
            {
                var finalBody = new Dictionary<string, object?> { [_o.StatusField] = _o.StatusFinal };
                steps.Add($"[9 סטטוס] PATCH {DocPath()}  {J(finalBody)}");
                if (live)
                {
                    await client.PatchAsync(DocPath(), finalBody, ct);
                    if (verify)
                    {
                        var back = await client.GetOneAsync(DocPath(),
                            select: $"{_o.StatusField},{_o.CustField},{_o.ContactField}", ct: ct);
                        if (back is { } bb)
                        {
                            checks.Add(new("9 סטטוס", _o.StatusField, _o.StatusFinal,
                                Str(bb, _o.StatusField) ?? "", Str(bb, _o.StatusField) == _o.StatusFinal));
                            checks.Add(new("אימות לקוח", _o.CustField, req.CustomerName,
                                Str(bb, _o.CustField) ?? "", Str(bb, _o.CustField) == req.CustomerName));
                            if (req.Contact is { Length: > 0 })
                                checks.Add(new("אימות איש קשר", _o.ContactField, req.Contact,
                                    Str(bb, _o.ContactField) ?? "", Str(bb, _o.ContactField) == req.Contact));
                        }
                    }
                }
            }

            // (step 10 — printing — is a client-side action; out of API scope)
            var failed = checks.Where(c => !c.Ok).ToList();
            return new(true,
                live ? docKey : null,
                steps,
                preview ? "PREVIEW — לא נשלחו קריאות לשרת"
                    : failed.Count > 0 ? $"אימות נכשל ב-{failed.Count} בדיקות: {string.Join(", ", failed.Select(f => f.Step))}" : null,
                checks.Count == 0 ? null : checks,
                checks.Count == 0 ? null : failed.Count == 0);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Shipment scenario failed");
            return new(false, null, steps, ex.Message, checks.Count == 0 ? null : checks, false);
        }
    }

    /// <summary>True when the device row matches any filter (or no filters given = take all).
    /// Identifier fields (stamped serial / service-call no / MBA no) match EXACTLY — so "123"
    /// selects serial 123 and NOT 12345. The free-text description matches by substring.</summary>
    private bool MatchesFilter(JsonElement row, IReadOnlyList<string>? filters)
    {
        if (filters is not { Count: > 0 }) return true;
        var ids = new[]
        {
            Str(row, _o.MarkStampField), Str(row, _o.MarkCallField), Str(row, _o.MarkMbaNumField),
        };
        var desc = Str(row, _o.MarkSerialDescField);
        return filters.Any(f =>
            ids.Any(h => h is not null && string.Equals(h, f, StringComparison.OrdinalIgnoreCase))
            || (desc is not null && desc.Contains(f, StringComparison.OrdinalIgnoreCase)));
    }

    private static string J(object o) => JsonSerializer.Serialize(o, JsonOpts);
    private static readonly JsonSerializerOptions JsonOpts =
        new() { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    private static string Esc(string s) => s.Replace("'", "''");

    private static string? Str(JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object) return null;
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        return p.ValueKind == JsonValueKind.String ? p.GetString() : p.ToString();
    }

    private static string Str2(JsonElement p) =>
        p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? ""
        : p.ValueKind == JsonValueKind.String ? (p.GetString() ?? "") : p.ToString();

    private static int? IntOf(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        if (p.ValueKind == JsonValueKind.Number && p.TryGetInt32(out var i)) return i;
        if (p.ValueKind == JsonValueKind.String && int.TryParse(p.GetString(), out var j)) return j;
        return null;
    }

    private static decimal? DecOf(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        if (p.ValueKind == JsonValueKind.Number && p.TryGetDecimal(out var d)) return d;
        if (p.ValueKind == JsonValueKind.String && decimal.TryParse(p.GetString(), out var j)) return j;
        return null;
    }
}

/// <summary>A shipment detail line with its per-line device serials (for step 6b).</summary>
internal record ShipLine(int? Kline, string? Part, decimal? Bal, List<(int? Sern, string? Num)> Serials);
