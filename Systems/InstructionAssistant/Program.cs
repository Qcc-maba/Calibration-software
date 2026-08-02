using Maba.VCT.InstructionAssistant;
using Maba.VCT.InstructionAssistant.Extraction;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;
using Maba.VCT.InstructionAssistant.Sources;
using Maba.VCT.InstructionAssistant.Summarize;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<InstructionAssistantOptions>()
    .Bind(builder.Configuration.GetSection(InstructionAssistantOptions.SectionName));

// Text extraction
builder.Services.AddSingleton<IDocumentTextExtractor, PlainTextExtractor>();
builder.Services.AddSingleton<CompositeTextExtractor>();

// Instruction sources
builder.Services.AddSingleton<IInstructionSourceProvider, ExcelInstructionProvider>();
builder.Services.AddSingleton<IInstructionSourceProvider, FileShareInstructionProvider>();
builder.Services.AddSingleton<IInstructionSourceProvider, PriorityInstructionSource>();

// Summarizer — pick by config Mode (Claude cloud vs offline extractive)
var mode = builder.Configuration[$"{InstructionAssistantOptions.SectionName}:Summarizer:Mode"] ?? "Claude";
if (string.Equals(mode, "Extractive", StringComparison.OrdinalIgnoreCase))
    builder.Services.AddSingleton<IInstructionSummarizer, ExtractiveSummarizer>();
else
    builder.Services.AddHttpClient<IInstructionSummarizer, ClaudeSummarizer>(c =>
        c.Timeout = TimeSpan.FromSeconds(60));

builder.Services.AddSingleton<InstructionAssistantService>();
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.SetIsOriginAllowed(_ => true).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();

app.MapGet("/health", (IEnumerable<IInstructionSourceProvider> sources,
    Microsoft.Extensions.Options.IOptions<Maba.VCT.InstructionAssistant.Options.InstructionAssistantOptions> opt) => Results.Ok(new
{
    status = "ok",
    sources = sources.Select(s => s.Name),
    mode,
    centralExcelPath = opt.Value.CentralExcel.Path,
    centralExcelExists = !string.IsNullOrWhiteSpace(opt.Value.CentralExcel.Path) && File.Exists(opt.Value.CentralExcel.Path),
}));

// Auto (calibRecordId) OR manual (customer/serial/deviceType) — "both" per the chosen design.
app.MapGet("/api/instructions/summary", async (
    string? calibRecordId, string? customer, string? customerId,
    string? serial, string? deviceType, string? manufacturer, string? model,
    InstructionAssistantService svc, CancellationToken ct) =>
{
    var ctx = new InstrumentContext
    {
        CalibRecordId = calibRecordId,
        CustomerName = customer,
        CustomerId = customerId,
        SerialNumber = serial,
        DeviceType = deviceType,
        Manufacturer = manufacturer,
        Model = model,
    };

    var summary = await svc.GetSummaryAsync(ctx, ct);

    // Auto-resolution from a calibration record (looking up customer/serial by id) is pending
    // the MABA/VCT records integration — flag it so callers know why an id-only call is empty.
    if (!string.IsNullOrWhiteSpace(calibRecordId) && string.IsNullOrWhiteSpace(serial) && string.IsNullOrWhiteSpace(customer))
        summary.Notices.Add("זיהוי אוטומטי מרשומת הכיול עדיין לא מחובר — יש להעביר customer/serial עד להשלמת האינטגרציה.");

    return Results.Ok(summary);
});

// Manual search entry point — resolver pending the records integration.
app.MapGet("/api/instructions/search", (string q) => Results.Ok(new
{
    query = q,
    results = Array.Empty<object>(),
    note = "חיפוש ידני ימומש מול רשומות MABA/VCT או Priority לאחר חיבור מקור החיפוש.",
}));

app.Run();
