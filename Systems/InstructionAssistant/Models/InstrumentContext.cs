namespace Maba.VCT.InstructionAssistant.Models;

/// <summary>
/// Identifies the instrument the calibrator is currently working on. Populated either
/// automatically from the active MABA/VCT calibration record, or from manual search
/// parameters. Any field may be empty when only partial information is known.
/// </summary>
public sealed class InstrumentContext
{
    /// <summary>Priority customer number / MABA customer id (preferred join key).</summary>
    public string? CustomerId { get; init; }

    /// <summary>Human-readable customer name (used for file-share folder matching and display).</summary>
    public string? CustomerName { get; init; }

    /// <summary>Instrument family / type (e.g. "Multimeter", "Torque wrench").</summary>
    public string? DeviceType { get; init; }

    /// <summary>Manufacturer + model, when known.</summary>
    public string? Manufacturer { get; init; }
    public string? Model { get; init; }

    /// <summary>The instrument serial number — the strongest per-instrument match key.</summary>
    public string? SerialNumber { get; init; }

    /// <summary>
    /// The customer's own asset/tag number (Priority MANUFC_SERIAL). Instruction files are often
    /// named after it rather than the manufacturer serial — e.g. "ECS - HIOKI DT4282 (97048883).docx".
    /// </summary>
    public string? CustomerAssetNumber { get; init; }

    /// <summary>MABA number (מספר מבא) of the calibration record this context was resolved from.</summary>
    public string? CalibRecordId { get; init; }

    public bool HasAnyKey =>
        !string.IsNullOrWhiteSpace(CustomerId) ||
        !string.IsNullOrWhiteSpace(CustomerName) ||
        !string.IsNullOrWhiteSpace(SerialNumber) ||
        !string.IsNullOrWhiteSpace(CustomerAssetNumber) ||
        !string.IsNullOrWhiteSpace(Model) ||          // central Excel matches on manufacturer+model
        !string.IsNullOrWhiteSpace(DeviceType);

    /// <summary>Overlay non-empty fields of <paramref name="explicit"/> on top of this context.</summary>
    public InstrumentContext MergeWith(InstrumentContext @explicit) => new()
    {
        CustomerId = Pick(@explicit.CustomerId, CustomerId),
        CustomerName = Pick(@explicit.CustomerName, CustomerName),
        DeviceType = Pick(@explicit.DeviceType, DeviceType),
        Manufacturer = Pick(@explicit.Manufacturer, Manufacturer),
        Model = Pick(@explicit.Model, Model),
        SerialNumber = Pick(@explicit.SerialNumber, SerialNumber),
        CustomerAssetNumber = Pick(@explicit.CustomerAssetNumber, CustomerAssetNumber),
        CalibRecordId = Pick(@explicit.CalibRecordId, CalibRecordId),
    };

    private static string? Pick(string? preferred, string? fallback) =>
        string.IsNullOrWhiteSpace(preferred) ? fallback : preferred;

    public override string ToString() =>
        $"customer={CustomerName ?? CustomerId ?? "?"} device={DeviceType ?? "?"} " +
        $"sn={SerialNumber ?? "?"} rec={CalibRecordId ?? "-"}";
}
