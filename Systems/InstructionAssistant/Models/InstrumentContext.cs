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

    /// <summary>MABA/VCT calibration record id, when the context came from an active record.</summary>
    public string? CalibRecordId { get; init; }

    public bool HasAnyKey =>
        !string.IsNullOrWhiteSpace(CustomerId) ||
        !string.IsNullOrWhiteSpace(CustomerName) ||
        !string.IsNullOrWhiteSpace(SerialNumber);

    public override string ToString() =>
        $"customer={CustomerName ?? CustomerId ?? "?"} device={DeviceType ?? "?"} " +
        $"sn={SerialNumber ?? "?"} rec={CalibRecordId ?? "-"}";
}
