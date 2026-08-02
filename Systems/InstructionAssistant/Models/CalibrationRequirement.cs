namespace Maba.VCT.InstructionAssistant.Models;

/// <summary>
/// One row of the central calibration-requirements matrix (the "אקסל מרכז" workbook):
/// per (manufacturer, model, measurement parameter) — the test points, tolerance and notes.
/// A single instrument model spans several of these rows (one per measurement parameter).
/// </summary>
public sealed class CalibrationRequirement
{
    public string? EquipmentDescription { get; init; }
    public string? Manufacturer { get; init; }
    public string? Model { get; init; }
    public string? MeasurementParameter { get; init; }
    public string? TestPoints { get; init; }
    public string? CalibrationTolerance { get; init; }
    public string? Notes { get; init; }
}
