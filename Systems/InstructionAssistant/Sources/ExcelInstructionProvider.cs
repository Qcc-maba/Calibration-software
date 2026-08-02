using ClosedXML.Excel;
using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Sources;

/// <summary>
/// Reads the single central calibration-requirements workbook ("אקסל מרכז") and returns the
/// rows matching the instrument's manufacturer + model. The workbook is a matrix keyed by
/// (Equipment, Manufacturer, Model) with one row per measurement parameter; continuation rows
/// leave those first columns blank, so we forward-fill them. Parsed rows are cached in memory.
/// A model cell may list several variants comma/newline-separated — any variant may match.
/// </summary>
public sealed class ExcelInstructionProvider(
    IOptions<InstructionAssistantOptions> options,
    ILogger<ExcelInstructionProvider> logger) : IInstructionSourceProvider
{
    private readonly CentralExcelOptions _opt = options.Value.CentralExcel;
    private readonly object _lock = new();
    private List<CalibrationRequirement>? _cache;
    private DateTime _cachedAtUtc = DateTime.MinValue;

    public string Name => "central-excel";

    public Task<IReadOnlyList<InstructionDocument>> FindAsync(InstrumentContext ctx, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(_opt.Path))
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);

        if (string.IsNullOrWhiteSpace(ctx.Model) && string.IsNullOrWhiteSpace(ctx.DeviceType))
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);

        List<CalibrationRequirement> all;
        try { all = LoadRows(); }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to read central Excel {Path}", _opt.Path);
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);
        }

        var matched = all.Where(r => Matches(r, ctx)).ToList();
        if (matched.Count == 0)
            return Task.FromResult<IReadOnlyList<InstructionDocument>>([]);

        var doc = new InstructionDocument
        {
            Source = InstructionSourceType.FileShare,
            Title = $"אקסל מרכז — {ctx.Manufacturer} {ctx.Model}".Trim(),
            Reference = _opt.Path,
            MediaType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            MatchReason = "התאמה לפי יצרן+דגם בטבלת הכיול המרכזית",
            Requirements = matched,
            Text = RenderAsText(matched),
        };
        return Task.FromResult<IReadOnlyList<InstructionDocument>>([doc]);
    }

    private static bool Matches(CalibrationRequirement r, InstrumentContext ctx)
    {
        // Model is the strong key; manufacturer (if provided) must be consistent.
        if (!string.IsNullOrWhiteSpace(ctx.Model))
        {
            if (!ModelVariants(r.Model).Any(v => TokenEquals(v, ctx.Model!)))
                return false;
        }
        else
        {
            // No model → fall back to equipment/device-type match so we don't over-return.
            if (!Contains(r.EquipmentDescription, ctx.DeviceType))
                return false;
        }

        if (!string.IsNullOrWhiteSpace(ctx.Manufacturer) && !string.IsNullOrWhiteSpace(r.Manufacturer))
            if (!Contains(r.Manufacturer, ctx.Manufacturer) && !Contains(ctx.Manufacturer, r.Manufacturer))
                return false;

        return true;
    }

    private static IEnumerable<string> ModelVariants(string? modelCell) =>
        (modelCell ?? "")
            .Split([',', '\n', '\r', ';', '/'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static string Norm(string s) =>
        new string(s.Where(c => !char.IsWhiteSpace(c)).ToArray()).Trim().ToLowerInvariant();

    private static bool TokenEquals(string a, string b) => Norm(a) == Norm(b);

    private static bool Contains(string? hay, string? needle) =>
        !string.IsNullOrWhiteSpace(hay) && !string.IsNullOrWhiteSpace(needle) &&
        hay.Contains(needle, StringComparison.OrdinalIgnoreCase);

    private static string RenderAsText(List<CalibrationRequirement> rows)
    {
        var lines = new List<string> { "טבלת דרישות כיול (יצרן/דגם):" };
        foreach (var r in rows)
            lines.Add(
                $"- פרמטר: {r.MeasurementParameter} | נקודות בדיקה: {Flat(r.TestPoints)} | " +
                $"טולרנס: {Flat(r.CalibrationTolerance)} | הערות: {Flat(r.Notes)}");
        return string.Join("\n", lines);
    }

    private static string Flat(string? s) =>
        string.IsNullOrWhiteSpace(s) ? "-" : s.Replace("\r", " ").Replace("\n", " ").Trim();

    private List<CalibrationRequirement> LoadRows()
    {
        lock (_lock)
        {
            if (_cache is not null && (DateTime.UtcNow - _cachedAtUtc).TotalSeconds < _opt.CacheSeconds)
                return _cache;

            _cache = Parse(_opt.Path!, _opt.SheetName);
            _cachedAtUtc = DateTime.UtcNow;
            logger.LogInformation("Central Excel parsed: {Count} requirement rows", _cache.Count);
            return _cache;
        }
    }

    private static List<CalibrationRequirement> Parse(string path, string? sheetName)
    {
        using var wb = new XLWorkbook(path);
        var ws = !string.IsNullOrWhiteSpace(sheetName)
            ? wb.Worksheet(sheetName)
            : wb.Worksheets.FirstOrDefault(s => s.RowsUsed().Any()) ?? wb.Worksheet(1);

        var used = ws.RowsUsed().ToList();
        if (used.Count == 0) return [];

        // Map columns by header text (first used row).
        var header = used[0];
        int cEquip = 0, cMf = 0, cMd = 0, cParam = 0, cPts = 0, cTol = 0, cNotes = 0;
        foreach (var cell in header.CellsUsed())
        {
            var h = cell.GetString().Trim().ToLowerInvariant();
            int i = cell.Address.ColumnNumber;
            if (h.Contains("equipment")) cEquip = i;
            else if (h.Contains("manufacturer")) cMf = i;
            else if (h.Contains("model")) cMd = i;
            else if (h.Contains("parameter")) cParam = i;
            else if (h.Contains("test point")) cPts = i;
            else if (h.Contains("toleranc")) cTol = i;
            else if (h.Contains("note") || h.Contains("requirement")) cNotes = i;
        }
        // Fallback to positional layout if headers weren't found.
        if (cMf == 0 && cMd == 0) { cEquip = 1; cMf = 2; cMd = 3; cParam = 4; cPts = 5; cTol = 6; cNotes = 7; }

        string? fillEquip = null, fillMf = null, fillMd = null;
        var rows = new List<CalibrationRequirement>();
        foreach (var row in used.Skip(1))
        {
            string Get(int c) => c > 0 ? row.Cell(c).GetString().Trim() : "";
            var equip = Get(cEquip); var mf = Get(cMf); var md = Get(cMd);
            var param = Get(cParam); var pts = Get(cPts); var tol = Get(cTol); var notes = Get(cNotes);

            if (!string.IsNullOrWhiteSpace(equip)) fillEquip = equip;
            if (!string.IsNullOrWhiteSpace(mf)) fillMf = mf;
            if (!string.IsNullOrWhiteSpace(md)) fillMd = md;

            // Skip rows with no meaningful content.
            if (string.IsNullOrWhiteSpace(param) && string.IsNullOrWhiteSpace(pts) &&
                string.IsNullOrWhiteSpace(tol) && string.IsNullOrWhiteSpace(md) && string.IsNullOrWhiteSpace(mf))
                continue;

            rows.Add(new CalibrationRequirement
            {
                EquipmentDescription = fillEquip,
                Manufacturer = fillMf,
                Model = fillMd,
                MeasurementParameter = string.IsNullOrWhiteSpace(param) ? null : param,
                TestPoints = string.IsNullOrWhiteSpace(pts) ? null : pts,
                CalibrationTolerance = string.IsNullOrWhiteSpace(tol) ? null : tol,
                Notes = string.IsNullOrWhiteSpace(notes) ? null : notes,
            });
        }
        return rows;
    }
}
