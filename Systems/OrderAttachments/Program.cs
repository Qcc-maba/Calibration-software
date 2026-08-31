using Maba.VCT.OrderAttachments.Convert;
using Maba.VCT.OrderAttachments.Data;
using Maba.VCT.OrderAttachments.Msg;

// MBA-930. Serves the documents Priority hangs off an order to the calibrator, converted to PDF.
//
// Registering the legacy code pages is the very first thing that happens. Priority's .msg files
// carry Windows-1255 and .NET ships only Unicode pages; without this every Hebrew mail fails.
MsgEncoding.EnsureRegistered();

var builder = WebApplication.CreateBuilder(args);

// Lets the same executable run as a console app in development and as a Windows Service on the
// server, the same way Maba.VCT.InstructionAssistant does.
builder.Host.UseWindowsService(o => o.ServiceName = "MabaOrderAttachments");

var connectionString =
    builder.Configuration.GetConnectionString("Calibrator")
    ?? throw new InvalidOperationException(
        "ConnectionStrings:Calibrator is not configured. In Production it comes from a " +
        "machine-scope environment variable, not from appsettings.json.");

var cacheDirectory = builder.Configuration["OrderAttachments:CacheDirectory"];
if (string.IsNullOrWhiteSpace(cacheDirectory))
    cacheDirectory = Path.Combine(AppContext.BaseDirectory, "pdf-cache");

var libreOffice = builder.Configuration["OrderAttachments:LibreOfficePath"]
                  ?? @"C:\Program Files\LibreOffice\program\soffice.exe";

builder.Services.AddSingleton(new AttachmentCatalog(connectionString));
builder.Services.AddSingleton<MsgExtractor>();
builder.Services.AddSingleton<ChromiumRenderer>();
builder.Services.AddSingleton(sp =>
    new ConversionCache(cacheDirectory, sp.GetRequiredService<ILogger<ConversionCache>>()));

// Order matters: the first converter that claims an extension wins, so the passthrough sits
// ahead of anything that would re-render a PDF that is already fine.
builder.Services.AddSingleton<IPdfConverter, PdfPassthroughConverter>();
builder.Services.AddSingleton<IPdfConverter>(sp =>
    new ImagePdfConverter(sp.GetRequiredService<ChromiumRenderer>()));
builder.Services.AddSingleton<IPdfConverter>(sp =>
    new TextPdfConverter(sp.GetRequiredService<ChromiumRenderer>()));
builder.Services.AddSingleton<IPdfConverter>(sp =>
    new OfficePdfConverter(libreOffice, sp.GetRequiredService<ILogger<OfficePdfConverter>>()));

builder.Services.AddSingleton<PdfConverterRegistry>();
builder.Services.AddSingleton<PdfCombiner>();
builder.Services.AddSingleton<AttachmentPdfService>();

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.SetIsOriginAllowed(_ => true).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();

// Reports what the service can actually reach, not merely that it started. Every field here is
// something that has silently broken a MABA service before: a LocalSystem account that cannot see
// a share, a browser installed under a developer's profile, a missing connection string.
app.MapGet("/health", async (AttachmentCatalog catalog, CancellationToken ct) =>
{
    string database;
    try
    {
        await catalog.GetCountsAsync([0], ct);
        database = "ok";
    }
    catch (Exception ex)
    {
        database = "FAILED: " + ex.Message;
    }

    var share = builder.Configuration["OrderAttachments:AttachmentShare"]
                ?? @"\\maba-priority\Priority\Attachments";

    // Playwright looks for browsers under PLAYWRIGHT_BROWSERS_PATH, defaulting to the CURRENT
    // USER's LocalAppData. A service running as LocalSystem therefore cannot see a browser you
    // installed for yourself - the install script sets a machine-wide path for exactly this.
    var browsersPath = Environment.GetEnvironmentVariable("PLAYWRIGHT_BROWSERS_PATH");
    var browsersDir = string.IsNullOrWhiteSpace(browsersPath)
        ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ms-playwright")
        : browsersPath;

    return Results.Ok(new
    {
        status = "ok",
        identity = Environment.UserName,
        database,
        attachmentShare = share,
        attachmentShareReachable = Directory.Exists(share),
        cacheDirectory,
        cacheWritable = CanWrite(cacheDirectory),
        browsersDirectory = browsersDir,
        chromiumInstalled = Directory.Exists(browsersDir) &&
                            Directory.EnumerateDirectories(browsersDir, "chromium*").Any(),
        libreOfficePath = libreOffice,
        libreOfficeInstalled = File.Exists(libreOffice),
    });
});

static bool CanWrite(string directory)
{
    try
    {
        Directory.CreateDirectory(directory);
        var probe = Path.Combine(directory, ".write-probe");
        File.WriteAllText(probe, "");
        File.Delete(probe);
        return true;
    }
    catch
    {
        return false;
    }
}

// The grid's red/grey file button. Batched on purpose: the work assignment screen renders a page
// of orders and must not issue one call per row. Orders with no files are simply absent, and the
// caller treats absent as zero.
app.MapGet("/api/orders/attachments/counts", async (
    string? ids, AttachmentCatalog catalog, CancellationToken ct) =>
{
    var parsed = ids?
        .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Select(s => int.TryParse(s, out var v) ? v : (int?)null)
        .Where(v => v.HasValue)
        .Select(v => v!.Value)
        .ToList();

    return Results.Ok(await catalog.GetCountsAsync(parsed, ct));
});

// The list behind the button: every file on the order, expanded into its openable parts. A .msg
// contributes its body plus each real attachment. Parts that cannot be produced are returned with
// an Error rather than omitted — a document the calibrator cannot open must still be visible, or
// they have no way to know it exists.
app.MapGet("/api/orders/{orderWorkPlanId:int}/attachments", async (
    int orderWorkPlanId,
    AttachmentCatalog catalog,
    AttachmentPdfService pdfs,
    CancellationToken ct) =>
{
    var rows = await catalog.GetForOrderAsync(orderWorkPlanId, ct);

    var result = rows.Select(row => new
    {
        row.FileNumber,
        row.FileName,
        row.Description,
        row.SourceKind,
        row.CanBeServed,
        row.IsPathTruncated,
        Parts = pdfs.Describe(row).Select(p => new
        {
            p.PartId,
            p.Name,
            p.Kind,
            p.Error,
            Url = p.Kind == "Error"
                ? null
                : $"/api/orders/{orderWorkPlanId}/attachments/{row.FileNumber}/{p.PartId}.pdf",
        }),
        // Both shapes are offered so the screen can choose without a rebuild: one PDF per part,
        // or the whole attachment combined. See PdfCombiner for why this is not decided here.
        MergedUrl = pdfs.Describe(row).Any(p => p.Kind != "Error")
            ? $"/api/orders/{orderWorkPlanId}/attachments/{row.FileNumber}/{AttachmentPdfService.MergedPartId}.pdf"
            : null,
    });

    return Results.Ok(result);
});

// One part, as PDF. Converted on first request and cached from then on.
app.MapGet("/api/orders/{orderWorkPlanId:int}/attachments/{fileNumber:int}/{partId}.pdf", async (
    int orderWorkPlanId,
    int fileNumber,
    string partId,
    AttachmentCatalog catalog,
    AttachmentPdfService pdfs,
    ILogger<Program> log,
    CancellationToken ct) =>
{
    var row = (await catalog.GetForOrderAsync(orderWorkPlanId, ct))
        .FirstOrDefault(r => r.FileNumber == fileNumber);

    if (row is null) return Results.NotFound();

    try
    {
        var pdf = partId == AttachmentPdfService.MergedPartId
            ? await pdfs.GetMergedPdfAsync(row, ct)
            : await pdfs.GetPdfAsync(row, partId, ct);

        return Results.File(pdf, "application/pdf", enableRangeProcessing: true);
    }
    catch (PdfConversionException ex)
    {
        // 422 rather than 500: the request was valid, this particular document just cannot be
        // turned into a PDF. The UI shows the reason instead of a generic failure.
        log.LogWarning(ex, "Conversion failed for order {Order} file {File} part {Part}",
            orderWorkPlanId, fileNumber, partId);
        return Results.Problem(ex.Message, statusCode: StatusCodes.Status422UnprocessableEntity);
    }
});

app.Run();
