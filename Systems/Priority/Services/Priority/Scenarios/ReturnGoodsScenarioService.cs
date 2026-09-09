using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Maba.Api.Services.Priority.Scenarios;

public interface IReturnGoodsScenarioService
{
    /// <summary>
    /// Run (or, in <paramref name="preview"/> mode, only plan) the scenario.
    /// Preview builds every OData call that WOULD be sent and returns them without
    /// touching the server.
    /// </summary>
    Task<ReturnGoodsResult> ExecuteAsync(ReturnGoodsRequest req, bool preview, bool verify = true, bool batch = false, CancellationToken ct = default);

    /// <summary>
    /// Process many documents via chunked $batch requests (≤16 docs/chunk to stay under the
    /// 100-op batch cap). Each chunk = 2 HTTP requests (Batch A create + Batch B call/cleanup).
    /// </summary>
    Task<ReturnGoodsManyResult> ExecuteManyAsync(IReadOnlyList<ReturnGoodsRequest> reqs, CancellationToken ct = default);
}

/// <summary>
/// Scenario 1 — "Return of Goods from Customer" intake for external calibration,
/// over Priority OData (replaces the manual thick-client flow in 1.docx).
///
/// The full sequence below is VERIFIED live against env s190225 (docs 2601014–2601018).
/// Entity/field names live in <see cref="ReturnGoodsScenarioOptions"/>.
/// See docs/scenarios/return-goods-external-calibration.md for the step map + findings.
///
/// Verified order of operations:
///   1. resolve customer (from the order) + its main contact
///   2. POST DOCUMENTS_N header (customer, contact, calib date, intake text, external-calib flag)
///   3. PATCH status → "טיוטא"
///   4. POST order link (MBA_DOCORD_SUBFORM)
///   5. mark matching order lines FLAG='Y' (MBA_DOCORDI) — this AUTO-CREATES the detail lines
///   6. resolve calibrator name → USERS.BUSERID and POST it to the calibrators sub-form
///   7. PATCH status → "בכיול חוץ"
///
/// NOT implemented here (thick-client-only workaround / domain-open): steps 13–18
/// (dummy SKU 999999-7 + serial *001 + MBA 999 → auto-create a linked service call).
/// That path depends on Priority's global serial-matching staging flow and needs a
/// domain decision; see the scenario doc.
/// </summary>
public class ReturnGoodsScenarioService(
    PriorityODataClient client,
    IOptions<ReturnGoodsScenarioOptions> options,
    PriorityScenarioCache cache,
    ILogger<ReturnGoodsScenarioService> logger) : IReturnGoodsScenarioService
{
    private readonly ReturnGoodsScenarioOptions _o = options.Value;

    public async Task<ReturnGoodsResult> ExecuteAsync(ReturnGoodsRequest req, bool preview, bool verify = true, bool batch = false, CancellationToken ct = default)
    {
        // Time the whole run and count every OData round-trip (reset here, read at the end,
        // stamped onto whatever result the runner returns — success or failure alike).
        var sw = System.Diagnostics.Stopwatch.StartNew();
        client.ResetCounters();
        var result = batch && !preview
            ? await RunBatchAsync(req, verify, ct)          // $batch fast path (2–3 HTTP)
            : await RunCoreAsync(req, preview, verify, ct);  // step-by-step (full read-back)
        return result with
        {
            DurationMs = sw.ElapsedMilliseconds,
            Writes = client.WriteCount,
            Reads = client.ReadCount,
            Transactions = client.TransactionCount,
        };
    }

    private const int BatchChunkDocs = 16;   // 6 ops/doc in Batch A × 16 = 96 ≤ 100-op cap

    public async Task<ReturnGoodsManyResult> ExecuteManyAsync(IReadOnlyList<ReturnGoodsRequest> reqs, CancellationToken ct = default)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        client.ResetCounters();
        var docs = new List<string>();
        var steps = new List<string>();
        int created = 0, failed = 0, chunks = 0;
        try
        {
            var opt = await client.GetOptionsAsync(ct);
            if (string.IsNullOrWhiteSpace(opt.BaseUrl))
                return new(false, reqs.Count, 0, reqs.Count, 0, docs, steps, "Priority OData not configured.");

            for (int off = 0; off < reqs.Count; off += BatchChunkDocs)
            {
                chunks++;
                var chunk = reqs.Skip(off).Take(BatchChunkDocs).ToList();

                // resolve each doc (cached)
                var res = new List<(string Cust, string? Contact, int CalibId, string Serial, int? DeviceId, ReturnGoodsRequest Req)>();
                foreach (var d in chunk)
                {
                    var r = await ResolveForBatchAsync(d, ct);
                    if (r is null) { failed++; steps.Add($"⚠️ כשל פתרון להזמנה {d.OrderNumber}"); continue; }
                    res.Add((r.Value.Cust, r.Value.Contact, r.Value.CalibId, r.Value.Serial, r.Value.DeviceId, d));
                }
                if (res.Count == 0) continue;

                // ── Batch A: all docs, each in its own atomicity group ──
                int idc = 0;
                var opsA = new List<BatchOp>();
                var headerIds = new List<string>();
                var dummyIds = new List<string>();
                for (int i = 0; i < res.Count; i++)
                {
                    var (cust, contact, calibId, _, deviceId, d) = res[i];
                    var g = $"a{i}";
                    var hid = (++idc).ToString(); headerIds.Add(hid);
                    opsA.Add(new(hid, "POST", _o.ReturnDocEntity, BuildHeader(d, cust, contact), g));
                    opsA.Add(new((++idc).ToString(), "PATCH", $"${hid}", new Dictionary<string, object?> { [_o.StatusField] = _o.StatusDraft }, g, [hid]));
                    opsA.Add(new((++idc).ToString(), "POST", $"${hid}/{_o.OrderLinkSubform}", new Dictionary<string, object?> { [_o.OrderNumField] = d.OrderNumber }, g, [hid]));
                    opsA.Add(new((++idc).ToString(), "POST", $"${hid}/{_o.CalibratorsSubform}", new Dictionary<string, object?> { [_o.CalibratorEmpIdField] = calibId }, g, [hid]));
                    var dlid = (++idc).ToString(); dummyIds.Add(dlid);
                    opsA.Add(new(dlid, "POST", $"${hid}/{_o.ReturnLinesSubform}", new Dictionary<string, object?> { [_o.LineSkuField] = _o.DummyLinePart }, g, [hid]));
                    opsA.Add(new((++idc).ToString(), "POST", $"${hid}/{_o.DeviceRegSubform}", new Dictionary<string, object?> { [_o.DeviceRegIdField] = deviceId, [_o.DeviceRegMbaField] = _o.DeviceRegMbaValue }, g, [hid]));
                }
                var respA = await client.BatchAsync(opsA, ct);
                steps.Add($"Chunk {chunks}: Batch A — {res.Count} מסמכים · {opsA.Count} פעולות · HTTP {(respA.TryGetValue(headerIds[0], out var fa) ? fa.Status : 0)}");

                var docKeys = res.Select((_, i) => TextFrom(respA, headerIds[i], _o.DocKeyField)).ToList();
                var dummyKlines = res.Select((_, i) => IntFrom(respA, dummyIds[i], _o.ReturnLineKeyField)).ToList();

                // ── Batch B: all docs' service call + cancel + cleanup + status ──
                idc = 0;
                var opsB = new List<BatchOp>();
                for (int i = 0; i < res.Count; i++)
                {
                    var docKey = docKeys[i];
                    if (docKey is null) { failed++; continue; }
                    var (cust, _, _, serial, deviceId, d) = res[i];
                    var docPath = $"{_o.ReturnDocEntity}({_o.DocKeyField}='{Esc(docKey)}',{_o.DocTypeField}='{_o.DocTypeValue}')";
                    var g = $"b{i}";
                    var callBody = new Dictionary<string, object?>
                    {
                        [_o.CallCustField] = cust, [_o.CallPartField] = _o.DummyPartName, [_o.CallSerialField] = serial,
                        [_o.CallReturnDocField] = docKey, [_o.CallMbaNumField] = $"{docKey}/{_o.CallMbaPrefix}", [_o.CallStatusField] = _o.CallStatusReceived,
                    };
                    if (d.ApprovedByCustomer) callBody[_o.CallExtCalibField] = _o.CallExtCalibValue;
                    var cid = (++idc).ToString();
                    opsB.Add(new(cid, "POST", _o.ServiceCallEntity, callBody, g));
                    opsB.Add(new((++idc).ToString(), "PATCH", $"${cid}", new Dictionary<string, object?> { [_o.CallStatusField] = _o.CallCancelStatus }, g, [cid]));
                    if (deviceId is not null)
                        opsB.Add(new((++idc).ToString(), "DELETE", $"{docPath}/{_o.DeviceRegSubform}({_o.DeviceRegIdField}={deviceId})"));
                    if (dummyKlines[i] is not null)
                        opsB.Add(new((++idc).ToString(), "DELETE", $"{docPath}/{_o.ReturnLinesSubform}({_o.ReturnLineKeyField}={dummyKlines[i]},{_o.DocTypeField}='{_o.DocTypeValue}')"));
                    opsB.Add(new((++idc).ToString(), "PATCH", docPath, new Dictionary<string, object?> { [_o.StatusField] = _o.StatusInExternalCalib }));
                    docs.Add(docKey); created++;
                }
                if (opsB.Count > 0)
                {
                    var respB = await client.BatchAsync(opsB, ct);
                    steps.Add($"Chunk {chunks}: Batch B — {opsB.Count} פעולות · HTTP {(respB.Count > 0 ? 200 : 0)}");
                }
            }

            sw.Stop();
            return new(failed == 0, reqs.Count, created, failed, chunks, docs, steps, null,
                sw.ElapsedMilliseconds, client.WriteCount, client.ReadCount, client.TransactionCount);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "ReturnGoods many-batch failed");
            return new(false, reqs.Count, created, reqs.Count - created, chunks, docs, steps, ex.Message,
                sw.ElapsedMilliseconds, client.WriteCount, client.ReadCount, client.TransactionCount);
        }
    }

    /// <summary>Resolve customer/contact/calibrator/device for one request (all cached). Null on failure.</summary>
    private async Task<(string Cust, string? Contact, int CalibId, string Serial, int? DeviceId)?> ResolveForBatchAsync(
        ReturnGoodsRequest req, CancellationToken ct)
    {
        string? cust = req.CustomerName;
        if (cust is null)
        {
            var orders = await client.QueryAsync(_o.OrdersEntity, filter: $"{_o.OrderNumField} eq '{Esc(req.OrderNumber)}'", top: 1, ct: ct);
            if (orders.Count == 0) return null;
            cust = Str(orders[0], _o.CustField);
        }
        if (cust is null) return null;

        string? contact = req.Contact;
        if (contact is null)
        {
            if (cache.TryGetContact(cust, out var cc)) contact = cc;
            else
            {
                var contacts = await client.QueryAsync(_o.ContactSourceEntity,
                    filter: $"{_o.ContactSourceCustField} eq '{Esc(cust)}' and {_o.ContactMainFlagField} eq '{_o.ContactMainFlagValue}'", top: 1, ct: ct);
                if (contacts.Count > 0) contact = Str(contacts[0], _o.ContactSourceNameField);
                if (contact is not null) cache.SetContact(cust, contact);
            }
        }

        int calibId;
        if (!cache.TryGetCalibrator(req.CalibratorName, out calibId))
        {
            var users = await client.QueryAsync(_o.CalibratorMasterEntity, filter: $"{_o.CalibratorGroupField} eq '{Esc(_o.CalibratorGroupName)}'", ct: ct);
            var match = users.FirstOrDefault(u => Str(u, _o.CalibratorMasterNameField) == req.CalibratorName);
            var bid = match.ValueKind == JsonValueKind.Undefined ? null : IntOf(match, _o.CalibratorMasterIdField);
            if (bid is null) return null;
            cache.SetCalibrator(req.CalibratorName, bid.Value); calibId = bid.Value;
        }

        var serial = $"{cust}-{_o.DummySerial}";
        var deviceId = await ResolveOrCreateDeviceIdAsync(serial, cust, ct);
        return (cust, contact, calibId, serial, deviceId);
    }

    /// <summary>Build the DOCUMENTS_N header body from a request (shared by batch paths).</summary>
    private Dictionary<string, object?> BuildHeader(ReturnGoodsRequest req, string cust, string? contact)
    {
        var header = new Dictionary<string, object?> { [_o.CustField] = cust };
        if (contact is not null && _o.ContactField.Length > 0) header[_o.ContactField] = contact;
        if (_o.DocumentDateField.Length > 0) header[_o.DocumentDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
        if (_o.IntakeTextField.Length > 0) header[_o.IntakeTextField] = req.IntakeText ?? $"כיול חוץ {req.CalibrationRange}";
        if (req.Site is not null && _o.SiteField.Length > 0) header[_o.SiteField] = req.Site;
        if (req.ApprovedByCustomer)
        {
            header[_o.ExternalCalibFlagField] = _o.ExternalCalibFlagValue;
            header[_o.CalibDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
        }
        return header;
    }

    private async Task<ReturnGoodsResult> RunCoreAsync(ReturnGoodsRequest req, bool preview, bool verify, CancellationToken ct = default)
    {
        var ops = new List<PlannedOp>();
        var checks = new List<StepCheck>();   // read-back verifications (one per written field)
        try
        {
            var opt = await client.GetOptionsAsync(ct);
            bool live = !preview && !string.IsNullOrWhiteSpace(opt.BaseUrl);
            if (!preview && !live)
                return Fail(ops, "Priority OData not configured (set PrioritySync:OData:BaseUrl + credentials).");

            // ── 1. Resolve customer (from the order) and its main contact ──
            string? cust = req.CustomerName;
            string? contact = req.Contact;
            if (live)
            {
                // Only hit ORDERS when we actually need to resolve the customer. When the
                // customer is supplied, skip it — step 4 (link order) surfaces a bad order anyway.
                if (cust is null)
                {
                    var orders = await client.QueryAsync(
                        _o.OrdersEntity, filter: $"{_o.OrderNumField} eq '{Esc(req.OrderNumber)}'", top: 1, ct: ct);
                    if (orders.Count == 0)
                        return Fail(ops, $"לא נמצאה הזמנה {req.OrderNumber} בישות {_o.OrdersEntity}.");
                    cust = Str(orders[0], _o.CustField);
                }

                if (contact is null && cust is not null)
                {
                    if (cache.TryGetContact(cust, out var cachedContact))
                        contact = cachedContact;   // cached — skip the PERSONNELLOAD read
                    else
                    {
                        var contacts = await client.QueryAsync(
                            _o.ContactSourceEntity,
                            filter: $"{_o.ContactSourceCustField} eq '{Esc(cust)}' and {_o.ContactMainFlagField} eq '{_o.ContactMainFlagValue}'",
                            top: 1, ct: ct);
                        if (contacts.Count > 0) contact = Str(contacts[0], _o.ContactSourceNameField);
                        if (contact is not null) cache.SetContact(cust, contact);
                    }
                }
            }
            cust ??= req.CustomerName ?? $"{{{{customer of {req.OrderNumber}}}}}";

            // ── 2. Create the document header ──
            var header = new Dictionary<string, object?> { [_o.CustField] = cust };
            if (contact is not null && _o.ContactField.Length > 0) header[_o.ContactField] = contact;
            // Document date "תאריך" (CURDATE) defaults to the creation date — override it to the requested date.
            if (_o.DocumentDateField.Length > 0) header[_o.DocumentDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
            if (_o.IntakeTextField.Length > 0) header[_o.IntakeTextField] = req.IntakeText ?? $"כיול חוץ {req.CalibrationRange}";
            if (req.Site is not null && _o.SiteField.Length > 0) header[_o.SiteField] = req.Site;
            if (req.ApprovedByCustomer)
            {
                header[_o.ExternalCalibFlagField] = _o.ExternalCalibFlagValue;               // "Y"
                header[_o.CalibDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
            }
            ops.Add(new("2 header", "POST", _o.ReturnDocEntity, header));

            string docKey = "{{docKey}}";
            if (live)
            {
                var created = await client.PostAsync(_o.ReturnDocEntity, header, ct);
                if (created is { } c && c.TryGetProperty(_o.DocKeyField, out var k)) docKey = k.ToString();
                else return Fail(ops, $"לא ניתן לקרוא את מפתח המסמך ({_o.DocKeyField}) מתשובת ה-POST.");
            }

            // Composite key: DOCUMENTS_N key = (DOCNO, TYPE='N')
            string DocPath() => $"{_o.ReturnDocEntity}({_o.DocKeyField}='{Esc(docKey)}',{_o.DocTypeField}='{_o.DocTypeValue}')";

            // Captured during steps 13–17 for the cleanup/cancel in steps 18–19.
            int? regDeviceId = null;         // MBA_SERN of the registered serial (step 18 delete)
            int? dummyLineKey = null;        // KLINE of the 999999-7 line (step 19 delete)
            string? serviceCallDocNo = null; // DOCNO of the created service call (step 18 cancel)

            // read-back: the header we just POSTed
            if (live && verify) await VerifyEntityAsync("2 header", DocPath(), header, checks, ct);

            // ── 3. Status → draft ──
            var draftBody = new Dictionary<string, object?> { [_o.StatusField] = _o.StatusDraft };
            ops.Add(new("3 status→draft", "PATCH", DocPath(), draftBody));
            if (live)
            {
                await client.PatchAsync(DocPath(), draftBody, ct);
                // verify NOW — step 7 overwrites this status later
                if (verify) await VerifyEntityAsync("3 status→draft", DocPath(), draftBody, checks, ct);
            }

            // ── 4. Link the order ──
            var linkBody = new Dictionary<string, object?> { [_o.OrderNumField] = req.OrderNumber };
            var linkPath = $"{DocPath()}/{_o.OrderLinkSubform}";
            ops.Add(new("4 link order", "POST", linkPath, linkBody));
            if (live)
            {
                await client.PostAsync(linkPath, linkBody, ct);
                if (verify) await VerifySubformContainsAsync("4 link order", linkPath, linkBody, checks, ct);
            }

            // ── 5. Mark matching order lines (FLAG='Y') → auto-creates the detail lines ──
            if (live)
            {
                var orderLines = await client.QueryAsync($"{DocPath()}/{_o.OrderLinesSelectSubform}", ct: ct);
                int marked = 0;
                foreach (var ln in orderLines)
                {
                    var sku = Str(ln, _o.OrderLineSkuField);
                    if (req.Skus is { Count: > 0 } && (sku is null || !req.Skus.Contains(sku))) continue; // only requested SKUs
                    var k1 = IntOf(ln, _o.OrderLineKey1);
                    var k2 = IntOf(ln, _o.OrderLineKey2);
                    if (k1 is null || k2 is null) continue;
                    var markPath = $"{DocPath()}/{_o.OrderLinesSelectSubform}({_o.OrderLineKey1}={k1},{_o.OrderLineKey2}={k2})";
                    var markBody = new Dictionary<string, object?> { [_o.OrderLineFlagField] = "Y" };
                    ops.Add(new("5 mark line", "PATCH", markPath, markBody));
                    await client.PatchAsync(markPath, markBody, ct);
                    // Read-back the OUTCOME, not the checkbox: marking FLAG='Y' makes Priority
                    // auto-create the detail line and RESET FLAG back to empty. So we verify the
                    // detail line for this SKU now exists in TRANSORDER_N_SUBFORM.
                    if (verify && sku is not null)
                        await VerifySubformContainsAsync($"5 detail line {sku}",
                            $"{DocPath()}/{_o.ReturnLinesSubform}",
                            new Dictionary<string, object?> { [_o.LineSkuField] = sku }, checks, ct);
                    marked++;
                }
                if (marked == 0)
                    ops.Add(new("5 mark line", "note", "(no matching order lines to mark)", null));
            }
            else
            {
                ops.Add(new("5 mark line", "PATCH",
                    $"{DocPath()}/{_o.OrderLinesSelectSubform}(ORD=..,KLINE=..)",
                    new Dictionary<string, object?> { [_o.OrderLineFlagField] = "Y", ["(for SKUs)"] = req.Skus }));
            }

            // ── 6. Calibrator: name → USERS.BUSERID → sub-form USERID ──
            if (req.CalibratorName is { Length: > 0 } && _o.CalibratorsSubform.Length > 0)
            {
                object? calibId = "<BUSERID>";
                if (live)
                {
                    if (cache.TryGetCalibrator(req.CalibratorName, out var cachedId))
                        calibId = cachedId;    // cached — skip the USERS read
                    else
                    {
                        var users = await client.QueryAsync(
                            _o.CalibratorMasterEntity,
                            filter: $"{_o.CalibratorGroupField} eq '{Esc(_o.CalibratorGroupName)}'", ct: ct);
                        var match = users.FirstOrDefault(u => Str(u, _o.CalibratorMasterNameField) == req.CalibratorName);
                        var bid = match.ValueKind == JsonValueKind.Undefined ? null : IntOf(match, _o.CalibratorMasterIdField);
                        if (bid is null)
                            return Fail(ops, $"כייל '{req.CalibratorName}' לא נמצא ב-{_o.CalibratorMasterEntity} (קבוצה {_o.CalibratorGroupName}).");
                        cache.SetCalibrator(req.CalibratorName, bid.Value);
                        calibId = bid;
                    }
                }
                var calibBody = new Dictionary<string, object?> { [_o.CalibratorEmpIdField] = calibId };
                var calibPath = $"{DocPath()}/{_o.CalibratorsSubform}";
                ops.Add(new("6 calibrator", "POST", calibPath, calibBody));
                if (live)
                {
                    await client.PostAsync(calibPath, calibBody, ct);
                    if (verify) await VerifySubformContainsAsync("6 calibrator", calibPath, calibBody, checks, ct);
                }
            }

            // ── 13–16. Literal device registration (exactly as the docx describes) ──
            //   13. dummy detail line "999999-7"
            //   14. tab "רישום מספרי מכשירים" (MBA_SCANSERN)
            //   15. serial 002 → SERNUM "<cust>-002"
            //   16. "מספר מבא" → 999 (NEWMBANUM)
            if (_o.LiteralDeviceRegistration)
            {
                var regSerial = $"{cust}-{_o.DummySerial}";   // e.g. 0100-002

                // 13. add the dummy "999999-7" detail line
                var dumLineBody = new Dictionary<string, object?> { [_o.LineSkuField] = _o.DummyLinePart };
                var dumLinePath = $"{DocPath()}/{_o.ReturnLinesSubform}";
                ops.Add(new("13 dummy-line", "POST", dumLinePath, dumLineBody));
                if (live)
                {
                    try
                    {
                        var dumCreated = await client.PostAsync(dumLinePath, dumLineBody, ct);
                        if (dumCreated is { } dc) dummyLineKey = IntOf(dc, _o.ReturnLineKeyField); // KLINE for step 19
                        if (verify)
                            await VerifySubformContainsAsync($"13 dummy-line {_o.DummyLinePart}",
                                dumLinePath, dumLineBody, checks, ct);
                    }
                    catch (Exception ex) { logger.LogWarning(ex, "Dummy detail line {P} failed", _o.DummyLinePart); }
                }

                // 14–16. register the device. MBA_SCANSERN requires the device internal id
                // (SERNUMBERS.SERN); SERNUM + NEWMBANUM are resolved/checked as the read-back.
                var regExpected = new Dictionary<string, object?>
                {
                    [_o.DeviceRegSerialField] = regSerial,          // 15 serial → 0100-002
                    [_o.DeviceRegMbaField]    = _o.DeviceRegMbaValue, // 16 מספר מבא → 999
                };
                var regPath = $"{DocPath()}/{_o.DeviceRegSubform}";
                ops.Add(new("14-16 device-reg", "POST", regPath, regExpected));
                if (live)
                {
                    // ensure the dummy instrument exists + resolve its internal SERN id (cached)
                    var deviceId = await ResolveOrCreateDeviceIdAsync(regSerial, cust, ct);
                    if (deviceId is null)
                        logger.LogWarning("Could not resolve device id for {S}; skipping registration", regSerial);
                    else
                    {
                        regDeviceId = deviceId; // for step 18 delete
                        var regBody = new Dictionary<string, object?>
                        {
                            [_o.DeviceRegIdField]  = deviceId,             // MBA_SERN (required)
                            [_o.DeviceRegMbaField] = _o.DeviceRegMbaValue, // NEWMBANUM = 999
                        };
                        try
                        {
                            await client.PostAsync(regPath, regBody, ct);
                            if (verify)
                                await VerifySubformContainsAsync("14-16 device-reg", regPath, regExpected, checks, ct);
                        }
                        catch (Exception ex) { logger.LogWarning(ex, "Device registration failed (non-fatal)"); }
                    }
                }
            }

            // ── 6b. Service call (step 17) — created DIRECTLY, no dummy-load dance ──
            // Upsert a per-customer dummy instrument ("<cust>-<serial>" on the dummy part),
            // then POST the service call linked to this return document.
            if (_o.CreateServiceCall)
            {
                var serial = $"{cust}-{_o.DummySerial}";
                var callBody = new Dictionary<string, object?>
                {
                    [_o.CallCustField] = cust,
                    [_o.CallPartField] = _o.DummyPartName,
                    [_o.CallSerialField] = serial,
                    [_o.CallReturnDocField] = docKey,
                    [_o.CallMbaNumField] = $"{docKey}/{_o.CallMbaPrefix}",
                    [_o.CallStatusField] = _o.CallStatusReceived,
                };
                if (req.ApprovedByCustomer) callBody[_o.CallExtCalibField] = _o.CallExtCalibValue;

                ops.Add(new("6b service-call", "POST", _o.ServiceCallEntity, callBody));
                if (live)
                {
                    // Ensure the dummy instrument exists — cached, so this is a no-op after
                    // step 14-16 already created it (removes the duplicate POST).
                    await ResolveOrCreateDeviceIdAsync(serial, cust, ct);

                    try
                    {
                        var call = await client.PostAsync(_o.ServiceCallEntity, callBody, ct);
                        // capture the DOCNO (for the step-18 cancel) and read it back by key (DOCNO, TYPE='Q')
                        if (call is { } cc && cc.TryGetProperty(_o.CallKeyField, out var cno))
                        {
                            serviceCallDocNo = cno.ToString();
                            if (verify)
                            {
                                var callPath = $"{_o.ServiceCallEntity}({_o.CallKeyField}='{Esc(serviceCallDocNo)}',{_o.CallTypeField}='{_o.CallTypeValue}')";
                                await VerifyEntityAsync("6b service-call", callPath, callBody, checks, ct);
                            }
                        }
                    }
                    catch (Exception ex) { logger.LogWarning(ex, "Service-call creation failed (non-fatal)"); }
                }
            }

            // ── 18–19. Cancel the service call + clean up the dummy (exactly as the docx) ──
            //   18. delete the serial registration → set the service call (17) status to "מבוטלת"
            //   19. delete the dummy "999999-7" detail line
            if (_o.CleanupDummy && live)
            {
                // 18a. delete the serial number (MBA_SCANSERN registration row)
                if (regDeviceId is not null)
                {
                    var scanKeyPath = $"{DocPath()}/{_o.DeviceRegSubform}({_o.DeviceRegIdField}={regDeviceId})";
                    ops.Add(new("18 delete-serial", "DELETE", scanKeyPath, null));
                    try
                    {
                        await client.DeleteAsync(scanKeyPath, ct);
                        if (verify)
                            await VerifyAbsentAsync("18 מחיקת מס' סידורי", _o.DeviceRegSerialField,
                                $"{cust}-{_o.DummySerial}", $"{DocPath()}/{_o.DeviceRegSubform}", checks, ct);
                    }
                    catch (Exception ex) { logger.LogWarning(ex, "Delete serial registration failed (non-fatal)"); }
                }

                // 18b. cancel the service call (CALLSTATUSCODE → "מבוטלת")
                if (serviceCallDocNo is not null)
                {
                    var callPath = $"{_o.ServiceCallEntity}({_o.CallKeyField}='{Esc(serviceCallDocNo)}',{_o.CallTypeField}='{_o.CallTypeValue}')";
                    var cancelBody = new Dictionary<string, object?> { [_o.CallStatusField] = _o.CallCancelStatus };
                    ops.Add(new("18 cancel-call", "PATCH", callPath, cancelBody));
                    try
                    {
                        await client.PatchAsync(callPath, cancelBody, ct);
                        if (verify) await VerifyEntityAsync("18 ביטול קריאה", callPath, cancelBody, checks, ct);
                    }
                    catch (Exception ex) { logger.LogWarning(ex, "Cancel service call failed (non-fatal)"); }
                }

                // 19. delete the dummy "999999-7" detail line
                if (dummyLineKey is not null)
                {
                    var linePath = $"{DocPath()}/{_o.ReturnLinesSubform}({_o.ReturnLineKeyField}={dummyLineKey},{_o.DocTypeField}='{_o.DocTypeValue}')";
                    ops.Add(new("19 delete-line", "DELETE", linePath, null));
                    try
                    {
                        await client.DeleteAsync(linePath, ct);
                        if (verify)
                            await VerifyAbsentAsync($"19 מחיקת שורה {_o.DummyLinePart}", _o.LineSkuField,
                                _o.DummyLinePart, $"{DocPath()}/{_o.ReturnLinesSubform}", checks, ct);
                    }
                    catch (Exception ex) { logger.LogWarning(ex, "Delete dummy line failed (non-fatal)"); }
                }
            }

            // ── 7. Status → external calibration ──
            var finalBody = new Dictionary<string, object?> { [_o.StatusField] = _o.StatusInExternalCalib };
            ops.Add(new("7 status→external", "PATCH", DocPath(), finalBody));
            if (live)
            {
                try
                {
                    await client.PatchAsync(DocPath(), finalBody, ct);
                    if (verify) await VerifyEntityAsync("7 status→external", DocPath(), finalBody, checks, ct);
                }
                catch (Exception ex) { logger.LogWarning(ex, "Status → {S} blocked by workflow (non-fatal)", _o.StatusInExternalCalib); }
            }

            var steps = ops.Select(o => o.Method == "note"
                ? $"[{o.Step}] {o.Path}"
                : $"[{o.Step}] {o.Method} {o.Path}  {JsonSerializer.Serialize(o.Body, JsonOpts)}").ToList();

            // Append the read-back trace so the text output shows exactly what matched.
            foreach (var c in checks)
                steps.Add($"    {(c.Ok ? "✓" : "✗")} אימות [{c.Step}] {c.Field}: ציפינו='{c.Expected}' התקבל='{c.Actual}'");

            bool? verified = checks.Count == 0 ? null : checks.All(c => c.Ok);
            var failed = checks.Where(c => !c.Ok).ToList();
            string? error = preview ? "PREVIEW — לא נשלחו קריאות לשרת"
                : failed.Count > 0 ? $"אימות read-back נכשל ב-{failed.Count} שדות: {string.Join(", ", failed.Select(f => $"{f.Step}/{f.Field}"))}"
                : null;

            return new ReturnGoodsResult(
                Success: true,
                DocumentNumber: live ? docKey : null,
                Steps: steps,
                Error: error,
                Checks: checks.Count == 0 ? null : checks,
                Verified: verified);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "ReturnGoods scenario failed");
            return Fail(ops, ex.Message);
        }
    }

    /// <summary>
    /// $batch fast path — the whole scenario in 2 write-batches (+1 read-batch when verifying).
    /// Same result as RunCoreAsync, a fraction of the HTTP round-trips. Resolution values
    /// (calibrator id, contact, device SERN) are cached, so a warm run is 2–3 transactions.
    /// </summary>
    private async Task<ReturnGoodsResult> RunBatchAsync(ReturnGoodsRequest req, bool verify, CancellationToken ct)
    {
        var checks = new List<StepCheck>();
        var trace = new List<string>();
        try
        {
            var opt = await client.GetOptionsAsync(ct);
            if (string.IsNullOrWhiteSpace(opt.BaseUrl))
                return new(false, null, trace, "Priority OData not configured.");

            // ── Resolve (cached) ──
            string? cust = req.CustomerName;
            if (cust is null)
            {
                var orders = await client.QueryAsync(_o.OrdersEntity,
                    filter: $"{_o.OrderNumField} eq '{Esc(req.OrderNumber)}'", top: 1, ct: ct);
                if (orders.Count == 0) return new(false, null, trace, $"לא נמצאה הזמנה {req.OrderNumber}.");
                cust = Str(orders[0], _o.CustField);
            }
            if (cust is null) return new(false, null, trace, "לא ניתן לפתור לקוח.");

            string? contact = req.Contact;
            if (contact is null)
            {
                if (cache.TryGetContact(cust, out var cc)) contact = cc;
                else
                {
                    var contacts = await client.QueryAsync(_o.ContactSourceEntity,
                        filter: $"{_o.ContactSourceCustField} eq '{Esc(cust)}' and {_o.ContactMainFlagField} eq '{_o.ContactMainFlagValue}'",
                        top: 1, ct: ct);
                    if (contacts.Count > 0) contact = Str(contacts[0], _o.ContactSourceNameField);
                    if (contact is not null) cache.SetContact(cust, contact);
                }
            }

            int calibId;
            if (cache.TryGetCalibrator(req.CalibratorName, out var cid)) calibId = cid;
            else
            {
                var users = await client.QueryAsync(_o.CalibratorMasterEntity,
                    filter: $"{_o.CalibratorGroupField} eq '{Esc(_o.CalibratorGroupName)}'", ct: ct);
                var match = users.FirstOrDefault(u => Str(u, _o.CalibratorMasterNameField) == req.CalibratorName);
                var bid = match.ValueKind == JsonValueKind.Undefined ? null : IntOf(match, _o.CalibratorMasterIdField);
                if (bid is null) return new(false, null, trace, $"כייל '{req.CalibratorName}' לא נמצא.");
                cache.SetCalibrator(req.CalibratorName, bid.Value); calibId = bid.Value;
            }

            var serial = $"{cust}-{_o.DummySerial}";
            var deviceId = await ResolveOrCreateDeviceIdAsync(serial, cust, ct);
            if (deviceId is null) return new(false, null, trace, $"לא ניתן לפתור device id ל-{serial}.");

            // ── BATCH A: header + status + link + calibrator + dummy-line + device-reg ──
            var header = new Dictionary<string, object?> { [_o.CustField] = cust };
            if (contact is not null && _o.ContactField.Length > 0) header[_o.ContactField] = contact;
            if (_o.DocumentDateField.Length > 0) header[_o.DocumentDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
            if (_o.IntakeTextField.Length > 0) header[_o.IntakeTextField] = req.IntakeText ?? $"כיול חוץ {req.CalibrationRange}";
            if (req.Site is not null && _o.SiteField.Length > 0) header[_o.SiteField] = req.Site;
            if (req.ApprovedByCustomer)
            {
                header[_o.ExternalCalibFlagField] = _o.ExternalCalibFlagValue;
                header[_o.CalibDateField] = req.CalibrationDate.ToString("yyyy-MM-dd");
            }
            var batchA = new List<BatchOp>
            {
                new("1", "POST", _o.ReturnDocEntity, header, "a"),
                new("2", "PATCH", "$1", new Dictionary<string, object?> { [_o.StatusField] = _o.StatusDraft }, "a", ["1"]),
                new("3", "POST", $"$1/{_o.OrderLinkSubform}", new Dictionary<string, object?> { [_o.OrderNumField] = req.OrderNumber }, "a", ["1"]),
                new("4", "POST", $"$1/{_o.CalibratorsSubform}", new Dictionary<string, object?> { [_o.CalibratorEmpIdField] = calibId }, "a", ["1"]),
                new("5", "POST", $"$1/{_o.ReturnLinesSubform}", new Dictionary<string, object?> { [_o.LineSkuField] = _o.DummyLinePart }, "a", ["1"]),
                new("6", "POST", $"$1/{_o.DeviceRegSubform}", new Dictionary<string, object?> { [_o.DeviceRegIdField] = deviceId, [_o.DeviceRegMbaField] = _o.DeviceRegMbaValue }, "a", ["1"]),
            };
            var respA = await client.BatchAsync(batchA, ct);
            AddBatchChecks(checks, respA, ("1", "A כותרת"), ("2", "A סטטוס טיוטא"), ("3", "A קישור הזמנה"),
                ("4", "A כייל"), ("5", "A שורת 999999-7"), ("6", "A רישום מכשיר"));

            var docKey = TextFrom(respA, "1", _o.DocKeyField);
            if (docKey is null) return new(false, null, trace, "לא ניתן לקרוא DOCNO מ-batch A.", checks, false);
            var dummyKline = IntFrom(respA, "5", _o.ReturnLineKeyField);
            string DocPath() => $"{_o.ReturnDocEntity}({_o.DocKeyField}='{Esc(docKey)}',{_o.DocTypeField}='{_o.DocTypeValue}')";

            // ── BATCH B: service call + cancel + delete-serial + delete-dummy + status ──
            var callBody = new Dictionary<string, object?>
            {
                [_o.CallCustField] = cust,
                [_o.CallPartField] = _o.DummyPartName,
                [_o.CallSerialField] = serial,
                [_o.CallReturnDocField] = docKey,
                [_o.CallMbaNumField] = $"{docKey}/{_o.CallMbaPrefix}",
                [_o.CallStatusField] = _o.CallStatusReceived,
            };
            if (req.ApprovedByCustomer) callBody[_o.CallExtCalibField] = _o.CallExtCalibValue;
            var batchB = new List<BatchOp>
            {
                new("1", "POST", _o.ServiceCallEntity, callBody, "b"),
                new("2", "PATCH", "$1", new Dictionary<string, object?> { [_o.CallStatusField] = _o.CallCancelStatus }, "b", ["1"]),
                new("3", "DELETE", $"{DocPath()}/{_o.DeviceRegSubform}({_o.DeviceRegIdField}={deviceId})"),
            };
            if (dummyKline is not null)
                batchB.Add(new("4", "DELETE", $"{DocPath()}/{_o.ReturnLinesSubform}({_o.ReturnLineKeyField}={dummyKline},{_o.DocTypeField}='{_o.DocTypeValue}')"));
            batchB.Add(new("5", "PATCH", DocPath(), new Dictionary<string, object?> { [_o.StatusField] = _o.StatusInExternalCalib }));

            var respB = await client.BatchAsync(batchB, ct);
            AddBatchChecks(checks, respB, ("1", "B קריאת שירות"), ("2", "B ביטול קריאה"),
                ("3", "B מחיקת מס' סידורי"), ("4", "B מחיקת 999999-7"), ("5", "B סטטוס בכיול חוץ"));
            var callDocNo = TextFrom(respB, "1", _o.CallKeyField);

            // ── VERIFY BATCH (optional): one read-batch → field-level read-back ──
            if (verify)
            {
                var vBatch = new List<BatchOp>
                {
                    new("h", "GET", $"{DocPath()}?$select={_o.CustField},{_o.ContactField},{_o.IntakeTextField},{_o.ExternalCalibFlagField},{_o.StatusField}"),
                    new("l", "GET", $"{DocPath()}/{_o.ReturnLinesSubform}?$select={_o.LineSkuField}"),
                    new("s", "GET", $"{DocPath()}/{_o.DeviceRegSubform}?$select={_o.DeviceRegSerialField}"),
                };
                if (callDocNo is not null)
                    vBatch.Add(new("c", "GET", $"{_o.ServiceCallEntity}({_o.CallKeyField}='{Esc(callDocNo)}',{_o.CallTypeField}='{_o.CallTypeValue}')?$select={_o.CallStatusField},{_o.CallMbaNumField},{_o.CallReturnDocField}"));
                var respV = await client.BatchAsync(vBatch, ct);

                if (respV.TryGetValue("h", out var h) && h.Body is { } hb)
                {
                    CheckField(checks, "אימות כותרת", _o.CustField, cust, hb);
                    if (contact is not null) CheckField(checks, "אימות כותרת", _o.ContactField, contact, hb);
                    CheckField(checks, "אימות כותרת", _o.IntakeTextField, req.IntakeText ?? $"כיול חוץ {req.CalibrationRange}", hb);
                    CheckField(checks, "אימות כותרת", _o.StatusField, _o.StatusInExternalCalib, hb);
                }
                var lineParts = ArrayValues(respV, "l", _o.LineSkuField);
                checks.Add(new("אימות שורות", _o.LineSkuField, $"כולל, בלי {_o.DummyLinePart}",
                    string.Join(",", lineParts), lineParts.Count > 0 && !lineParts.Contains(_o.DummyLinePart)));
                var serialRows = ArrayValues(respV, "s", _o.DeviceRegSerialField);
                checks.Add(new("אימות מחיקת סידורי", _o.DeviceRegSerialField, "(נמחק)",
                    serialRows.Count == 0 ? "(נמחק)" : "עדיין קיים", serialRows.Count == 0));
                if (respV.TryGetValue("c", out var c) && c.Body is { } cb)
                    CheckField(checks, "אימות ביטול קריאה", _o.CallStatusField, _o.CallCancelStatus, cb);
            }

            trace = BuildBatchTrace(batchA, respA, batchB, respB);
            bool allOk = checks.All(x => x.Ok);
            var failed = checks.Where(x => !x.Ok).ToList();
            return new(true, docKey, trace,
                failed.Count > 0 ? $"אימות נכשל ב-{failed.Count} בדיקות" : null,
                checks.Count == 0 ? null : checks, checks.Count == 0 ? null : allOk);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "ReturnGoods batch scenario failed");
            return new(false, null, trace, ex.Message, checks.Count == 0 ? null : checks, false);
        }
    }

    // ── Batch helpers ────────────────────────────────────────────────
    private static void AddBatchChecks(List<StepCheck> checks,
        IReadOnlyDictionary<string, (int Status, JsonElement? Body)> resp, params (string Id, string Label)[] ops)
    {
        foreach (var (id, label) in ops)
        {
            if (!resp.TryGetValue(id, out var r)) continue;
            bool ok = r.Status is >= 200 and < 300;
            checks.Add(new(label, "status", "2xx", r.Status.ToString(), ok));
        }
    }

    private static string? TextFrom(IReadOnlyDictionary<string, (int Status, JsonElement? Body)> resp, string id, string field)
        => resp.TryGetValue(id, out var r) && r.Body is { } b && b.TryGetProperty(field, out var p)
           && p.ValueKind is not JsonValueKind.Null and not JsonValueKind.Undefined
            ? (p.ValueKind == JsonValueKind.String ? p.GetString() : p.ToString()) : null;

    private static int? IntFrom(IReadOnlyDictionary<string, (int Status, JsonElement? Body)> resp, string id, string field)
        => resp.TryGetValue(id, out var r) && r.Body is { } b ? IntOf(b, field) : null;

    private static void CheckField(List<StepCheck> checks, string step, string field, string? expected, JsonElement actual)
    {
        if (actual.TryGetProperty(field, out var a))
            checks.Add(new(step, field, expected, ActualStr(a), ValMatch(expected, a)));
        else
            checks.Add(new(step, field, expected, "<חסר>", false));
    }

    private static List<string> ArrayValues(IReadOnlyDictionary<string, (int Status, JsonElement? Body)> resp, string id, string field)
    {
        var vals = new List<string>();
        if (resp.TryGetValue(id, out var r) && r.Body is { } b
            && b.TryGetProperty("value", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var el in arr.EnumerateArray())
                if (el.TryGetProperty(field, out var p)) vals.Add(ActualStr(p));
        return vals;
    }

    private static List<string> BuildBatchTrace(
        IReadOnlyList<BatchOp> a, IReadOnlyDictionary<string, (int Status, JsonElement? Body)> ra,
        IReadOnlyList<BatchOp> b, IReadOnlyDictionary<string, (int Status, JsonElement? Body)> rb)
    {
        var t = new List<string> { "── BATCH A (בקשת HTTP אחת) ──" };
        foreach (var op in a) t.Add($"  [{op.Id}] {op.Method} {op.Url} → {(ra.TryGetValue(op.Id, out var r) ? r.Status : 0)}");
        t.Add("── BATCH B (בקשת HTTP אחת) ──");
        foreach (var op in b) t.Add($"  [{op.Id}] {op.Method} {op.Url} → {(rb.TryGetValue(op.Id, out var r) ? r.Status : 0)}");
        return t;
    }

    private static readonly JsonSerializerOptions JsonOpts =
        new() { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    private static ReturnGoodsResult Fail(List<PlannedOp> ops, string error) =>
        new(false, null, ops.Select(o => $"[{o.Step}] {o.Method} {o.Path}").ToList(), error);

    private static string Esc(string s) => s.Replace("'", "''");

    private static string? Str(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        return p.ValueKind == JsonValueKind.String ? p.GetString() : p.ToString();
    }

    private static int? IntOf(JsonElement e, string name)
    {
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        if (p.ValueKind == JsonValueKind.Number && p.TryGetInt32(out var i)) return i;
        if (p.ValueKind == JsonValueKind.String && int.TryParse(p.GetString(), out var j)) return j;
        return null;
    }

    /// <summary>
    /// Resolve a device's internal id (SERNUMBERS.SERN) from its serial — required by
    /// MBA_SCANSERN registration, which rejects a bare serial string ("חסר מכשיר (ID)").
    /// </summary>
    private async Task<int?> ResolveDeviceIdAsync(string serial, CancellationToken ct)
    {
        var rows = await client.QueryAsync(
            _o.InstrumentEntity,
            filter: $"{_o.InstrumentSerialField} eq '{Esc(serial)}' and {_o.InstrumentPartField} eq '{Esc(_o.DummyPartName)}'",
            top: 1, ct: ct);
        return rows.Count > 0 ? IntOf(rows[0], _o.InstrumentIdField) : null;
    }

    /// <summary>
    /// Return the dummy device's internal id (SERNUMBERS.SERN), creating the instrument if
    /// needed. Cached per serial, so repeated runs skip BOTH the ensure-POST and the
    /// resolve-GET — and a single run never POSTs the instrument twice.
    /// </summary>
    private async Task<int?> ResolveOrCreateDeviceIdAsync(string serial, string cust, CancellationToken ct)
    {
        if (cache.TryGetDeviceId(serial, out var cached)) return cached;

        var instr = new Dictionary<string, object?>
        {
            [_o.InstrumentSerialField] = serial,
            [_o.InstrumentPartField]   = _o.DummyPartName,
            [_o.InstrumentCustField]   = cust,
        };
        try { await client.PostAsync(_o.InstrumentEntity, instr, ct); }
        catch (Exception ex) { logger.LogDebug(ex, "Instrument {S} exists (ok)", serial); }

        var id = await ResolveDeviceIdAsync(serial, ct);
        if (id is not null) cache.SetDeviceId(serial, id.Value);
        return id;
    }

    // ── Read-back verification helpers ───────────────────────────────

    /// <summary>Re-read a single entity by key and compare each written field to what came back.</summary>
    private async Task VerifyEntityAsync(
        string step, string readPath, Dictionary<string, object?> expected,
        List<StepCheck> checks, CancellationToken ct)
    {
        JsonElement? got = null;
        try { got = await client.GetOneAsync(readPath, select: string.Join(",", expected.Keys), ct: ct); }
        catch (Exception ex) { logger.LogWarning(ex, "read-back GET failed for {Step} ({Path})", step, readPath); }

        foreach (var (field, val) in expected)
        {
            var exp = Fmt(val);
            if (got is { } g && g.TryGetProperty(field, out var actual))
                checks.Add(new(step, field, exp, ActualStr(actual), ValMatch(exp, actual)));
            else
                checks.Add(new(step, field, exp, got is null ? "<לא נקרא>" : "<חסר בשרת>", false));
        }
    }

    /// <summary>Re-read a sub-form collection and confirm a row exists whose field matches what we wrote.</summary>
    private async Task VerifySubformContainsAsync(
        string step, string subformPath, Dictionary<string, object?> expected,
        List<StepCheck> checks, CancellationToken ct)
    {
        IReadOnlyList<JsonElement> rows = [];
        try { rows = await client.QueryAsync(subformPath, ct: ct); }
        catch (Exception ex) { logger.LogWarning(ex, "read-back query failed for {Step} ({Path})", step, subformPath); }

        foreach (var (field, val) in expected)
        {
            var exp = Fmt(val);
            string? seen = null;
            bool ok = false;
            foreach (var r in rows)
            {
                if (!r.TryGetProperty(field, out var a)) continue;
                seen ??= ActualStr(a);
                if (ValMatch(exp, a)) { ok = true; seen = ActualStr(a); break; }
            }
            checks.Add(new(step, field, exp, ok ? seen : (seen ?? "<לא נמצאה שורה>"), ok));
        }
    }

    /// <summary>Verify a sub-form NO LONGER contains a row matching the field/value (a delete took).</summary>
    private async Task VerifyAbsentAsync(
        string step, string field, string value, string subformPath,
        List<StepCheck> checks, CancellationToken ct)
    {
        IReadOnlyList<JsonElement> rows = [];
        try { rows = await client.QueryAsync(subformPath, ct: ct); }
        catch (Exception ex) { logger.LogWarning(ex, "verify-absent query failed for {Step} ({Path})", step, subformPath); }

        bool stillThere = rows.Any(r => r.TryGetProperty(field, out var a) && ValMatch(value, a));
        checks.Add(new(step, field, "(נמחק)", stillThere ? "עדיין קיים" : "(נמחק)", !stillThere));
    }

    private static string Fmt(object? v) => v switch
    {
        null => "",
        bool b => b ? "true" : "false",
        System.Collections.IEnumerable e and not string => string.Join(",", e.Cast<object?>().Select(x => x?.ToString())),
        _ => v.ToString() ?? ""
    };

    private static string ActualStr(JsonElement a) => a.ValueKind switch
    {
        JsonValueKind.String => a.GetString() ?? "",
        JsonValueKind.Null or JsonValueKind.Undefined => "",
        _ => a.ToString()
    };

    /// <summary>True if the value that came back equals what we sent, tolerating date/time and numeric formatting.</summary>
    private static bool ValMatch(string? expected, JsonElement actual)
    {
        if (string.IsNullOrEmpty(expected)) return true;   // nothing asserted
        var e = expected.Trim();
        var a = ActualStr(actual).Trim();
        if (a == e) return true;
        // date sent as "yyyy-MM-dd" vs returned "yyyy-MM-ddT00:00:00+03:00"
        if (e.Length == 10 && e[4] == '-' && e[7] == '-' && a.StartsWith(e)) return true;
        // numeric equality (e.g. 535 vs "535" / 535.0)
        if (decimal.TryParse(e, out var de) && decimal.TryParse(a, out var da) && de == da) return true;
        return false;
    }
}
