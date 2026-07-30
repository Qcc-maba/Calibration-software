namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>
/// Config for <see cref="ShipmentTriggerBackgroundService"/> — auto-fires a customer
/// shipment when devices are marked "נבדק" (MBA_ISCHECKED='Y') in the intake's device
/// inspection screen. Binds from "PriorityScenarios:ShipmentTrigger".
/// </summary>
public class ShipmentTriggerOptions
{
    public bool Enabled { get; set; }          = false;   // opt-in — off by default
    // Keep the load on Priority low: each cycle costs 1 + ScanRecentIntakes requests.
    // 5 intakes / 10s ≈ 0.6 req/s. Going much faster gets connections refused (10054/10060).
    public int PollSeconds { get; set; }       = 10;      // scan interval
    public int DebounceSeconds { get; set; }   = 5;       // wait after the LAST mark before firing
    public int ScanRecentIntakes { get; set; } = 5;       // how many recent finalized intakes to scan
    public int MaxBackoffSeconds { get; set; } = 120;     // cap when Priority is unreachable
    public string? CustomerFilter { get; set; }           // optional — only this customer's intakes
    public bool Billing { get; set; }          = true;    // shipment: charge?
    public bool Finalize { get; set; }         = true;    // shipment: status → סופית

    // ── Priority entity/field names ──────────────────────────────────
    public string IntakeEntity { get; set; }   = "DOCUMENTS_N";
    public string DocKeyField { get; set; }    = "DOCNO";
    public string DocTypeField { get; set; }   = "TYPE";
    public string DocTypeValue { get; set; }   = "N";
    public string CustField { get; set; }      = "CUSTNAME";
    public string StatusField { get; set; }    = "STATDES";
    public string StatusFinal { get; set; }    = "סופית";      // only finalized intakes are shippable
    public string CheckSubform { get; set; }   = "MBA_CHECKSERNS_SUBFORM";  // בדיקת מכשירים
    public string CheckedField { get; set; }   = "MBA_ISCHECKED";           // "נבדק?"
    public string CheckedValue { get; set; }   = "Y";
    public string CheckSerialField { get; set; } = "FREE1";                 // מספר סידורי (→ deviceFilters)
}
