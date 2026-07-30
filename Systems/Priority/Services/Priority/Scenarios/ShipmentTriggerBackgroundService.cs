using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>
/// Watches the intake device-inspection screen (MBA_CHECKSERNS.MBA_ISCHECKED) and auto-fires
/// a customer shipment once devices are marked "נבדק". Rules:
///   • all devices checked  → full shipment
///   • some devices checked → partial shipment (only the checked serials)
///   • fires DebounceSeconds after the LAST mark (so a burst of checks = one shipment)
/// Only recent finalized intakes are scanned (see <see cref="ShipmentTriggerOptions"/>).
/// </summary>
public class ShipmentTriggerBackgroundService(
    IServiceScopeFactory scopeFactory,
    IOptions<ShipmentTriggerOptions> options,
    ILogger<ShipmentTriggerBackgroundService> logger) : BackgroundService
{
    private readonly ShipmentTriggerOptions _o = options.Value;
    private readonly ConcurrentDictionary<string, WatchState> _state = new();

    private sealed class WatchState
    {
        public HashSet<string> Checked { get; set; } = new();
        public DateTime LastChangeUtc { get; set; }
        public bool Fired { get; set; }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_o.Enabled)
        {
            logger.LogInformation("ShipmentTrigger disabled (PriorityScenarios:ShipmentTrigger:Enabled=false).");
            return;
        }
        logger.LogInformation("ShipmentTrigger watching — poll {Poll}s, debounce {Deb}s, top {N} intakes.",
            _o.PollSeconds, _o.DebounceSeconds, _o.ScanRecentIntakes);

        int failures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            var delay = Math.Max(1, _o.PollSeconds);
            try
            {
                await ScanOnceAsync(stoppingToken);
                failures = 0;
            }
            catch (Exception ex)
            {
                failures++;
                // Back off when Priority refuses/times out, so we stop hammering it.
                delay = Math.Min(_o.MaxBackoffSeconds, delay * (int)Math.Pow(2, Math.Min(failures, 5)));
                if (failures == 1 || failures % 10 == 0)
                    logger.LogWarning("ShipmentTrigger scan failed ({N}) — backing off {D}s: {Msg}",
                        failures, delay, ex.GetBaseException().Message);
            }
            try { await Task.Delay(TimeSpan.FromSeconds(delay), stoppingToken); }
            catch (TaskCanceledException) { break; }
        }
    }

    private async Task ScanOnceAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var client = scope.ServiceProvider.GetRequiredService<PriorityODataClient>();
        var shipment = scope.ServiceProvider.GetRequiredService<IShipmentScenarioService>();

        var opt = await client.GetOptionsAsync(ct);
        if (string.IsNullOrWhiteSpace(opt.BaseUrl)) return;   // OData not configured

        // recent finalized intakes (optionally for one customer)
        var filter = $"{_o.StatusField} eq '{Esc(_o.StatusFinal)}'";
        if (!string.IsNullOrWhiteSpace(_o.CustomerFilter))
            filter += $" and {_o.CustField} eq '{Esc(_o.CustomerFilter)}'";
        var intakes = await client.QueryAsync(_o.IntakeEntity,
            filter: filter, select: $"{_o.DocKeyField},{_o.CustField}",
            orderby: $"{_o.DocKeyField} desc", top: _o.ScanRecentIntakes, ct: ct);

        foreach (var intake in intakes)
        {
            var doc = Str(intake, _o.DocKeyField);
            var cust = Str(intake, _o.CustField);
            if (doc is null || cust is null) continue;

            // read the device-inspection rows
            var docPath = $"{_o.IntakeEntity}({_o.DocKeyField}='{Esc(doc)}',{_o.DocTypeField}='{_o.DocTypeValue}')";
            IReadOnlyList<JsonElement> rows;
            try
            {
                rows = await client.QueryAsync($"{docPath}/{_o.CheckSubform}",
                    select: $"{_o.CheckSerialField},{_o.CheckedField}", ct: ct);
            }
            catch (Exception ex) { logger.LogDebug(ex, "inspection read failed for {Doc}", doc); continue; }

            var total = rows.Count;
            var checkedSerials = rows
                .Where(r => Str(r, _o.CheckedField) == _o.CheckedValue)
                .Select(r => Str(r, _o.CheckSerialField))
                .Where(s => s is not null).Select(s => s!)
                .ToHashSet();

            var st = _state.GetOrAdd(doc, _ => new WatchState());

            // reset the debounce timer whenever the checked set changes
            if (!checkedSerials.SetEquals(st.Checked))
            {
                st.Checked = checkedSerials;
                st.LastChangeUtc = DateTime.UtcNow;
                st.Fired = false;
                if (checkedSerials.Count > 0)
                    logger.LogInformation("Intake {Doc}: {N}/{T} devices marked — waiting {Deb}s…",
                        doc, checkedSerials.Count, total, _o.DebounceSeconds);
            }

            // fire once, DebounceSeconds after the last change
            if (checkedSerials.Count > 0 && !st.Fired
                && (DateTime.UtcNow - st.LastChangeUtc).TotalSeconds >= _o.DebounceSeconds)
            {
                st.Fired = true;   // set before awaiting to avoid a double-fire
                bool full = total > 0 && checkedSerials.Count >= total;
                var req = new ShipmentRequest(
                    CustomerName: cust,
                    IntakeDoc: doc,
                    Contact: null,
                    DeviceFilters: full ? null : checkedSerials.ToList(),
                    Billing: _o.Billing,
                    QuantityUpdates: null,
                    AutoQuantities: true,
                    FreeText: full ? null : "משלוח חלקי",
                    Finalize: _o.Finalize);

                logger.LogInformation("Intake {Doc}: firing {Kind} shipment ({N} devices)…",
                    doc, full ? "FULL" : "PARTIAL", checkedSerials.Count);
                try
                {
                    var result = await shipment.ExecuteAsync(req, preview: false, verify: true, ct);
                    if (result.Success)
                        logger.LogInformation("Intake {Doc}: shipment {Ship} created ({V}).",
                            doc, result.DocumentNumber, result.Verified == true ? "verified" : "check needed");
                    else
                        logger.LogWarning("Intake {Doc}: shipment failed — {Err}", doc, result.Error);
                }
                catch (Exception ex) { logger.LogWarning(ex, "Intake {Doc}: shipment trigger threw", doc); }
            }
        }
    }

    private static string Esc(string s) => s.Replace("'", "''");

    private static string? Str(JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object) return null;
        if (!e.TryGetProperty(name, out var p) || p.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return null;
        return p.ValueKind == JsonValueKind.String ? p.GetString() : p.ToString();
    }
}
