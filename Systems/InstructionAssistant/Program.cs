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
builder.Services.AddSingleton<IDocumentTextExtractor, DocxTextExtractor>();
builder.Services.AddSingleton<CompositeTextExtractor>();

// Instruction sources
builder.Services.AddSingleton<IInstructionSourceProvider, ExcelInstructionProvider>();
builder.Services.AddSingleton<IInstructionSourceProvider, FileShareInstructionProvider>();
builder.Services.AddSingleton<IInstructionSourceProvider, PriorityInstructionSource>();

// Resolves a MABA number (מספר מבא) to the full instrument context.
builder.Services.AddSingleton<PriorityRecordResolver>();

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

// Auto (mabaNum) OR manual (customer/serial/deviceType) — "both" per the chosen design.
// mabaNum resolves the whole instrument from Priority; any explicit parameter overrides it.
app.MapGet("/api/instructions/summary", async (
    string? mabaNum, string? calibRecordId, string? customer, string? customerId,
    string? serial, string? deviceType, string? manufacturer, string? model,
    InstructionAssistantService svc, PriorityRecordResolver resolver, CancellationToken ct) =>
{
    var recordId = mabaNum ?? calibRecordId;   // calibRecordId kept as the older parameter name

    var explicitCtx = new InstrumentContext
    {
        CalibRecordId = recordId,
        CustomerName = customer,
        CustomerId = customerId,
        SerialNumber = serial,
        DeviceType = deviceType,
        Manufacturer = manufacturer,
        Model = model,
    };

    var ctx = explicitCtx;
    string? resolveNotice = null;

    if (!string.IsNullOrWhiteSpace(recordId))
    {
        var resolved = await resolver.ResolveAsync(recordId, ct);
        if (resolved is not null)
            ctx = resolved.MergeWith(explicitCtx);
        else
            resolveNotice = $"מספר מבא '{recordId}' לא נמצא ב-Priority — נעשה שימוש בפרמטרים שהועברו בלבד.";
    }

    var summary = await svc.GetSummaryAsync(ctx, ct);
    if (resolveNotice is not null) summary.Notices.Add(resolveNotice);
    return Results.Ok(summary);
});

// Manual fallback — find the MABA number by serial / model / manufacturer / customer.
app.MapGet("/api/instructions/search", async (
    string q, PriorityRecordResolver resolver, CancellationToken ct) =>
{
    var hits = await resolver.SearchAsync(q, 20, ct);
    return Results.Ok(new
    {
        query = q,
        results = hits.Select(h => new
        {
            mabaNum = h.CalibRecordId,
            customerId = h.CustomerId,
            customer = h.CustomerName,
            deviceType = h.DeviceType,
            manufacturer = h.Manufacturer,
            model = h.Model,
            serial = h.SerialNumber,
            customerAssetNumber = h.CustomerAssetNumber,
        }),
    });
});

app.Run();
