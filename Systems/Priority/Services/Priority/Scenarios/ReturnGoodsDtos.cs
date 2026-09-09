namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>Inputs for the "Return of Goods from Customer / external calibration" scenario.</summary>
public record ReturnGoodsRequest(
    string OrderNumber,         // מספר הזמנה, e.g. "LA26102567"
    string? CustomerName,       // לשליפה אם צריך
    string? Site,               // אתר (e.g. "נאווה") — only when the customer has sites
    string? Contact,            // איש קשר תואם להזמנה
    string CalibratorName,      // שם כייל מהסידור עבודה, e.g. "ערן שבח"
    string CalibrationRange,    // תחום כיול מהאקסל, e.g. "טמפרטורה"
    DateOnly CalibrationDate,   // תאריך כיול מאושר
    bool ApprovedByCustomer,    // אושר ע"י לקוח
    // המק"טים לקליטה (שורות פירוט). מקור ההתאמה תחום↔מק"ט הוא קובץ אקסל חיצוני
    // שעדיין לא חובר — עד אז מועברים כקלט מפורש. ראו docs/scenarios.
    IReadOnlyList<string>? Skus = null,
    // טקסט לקליטה מפורש (אם ריק — נגזר כ"כיול חוץ <תחום>")
    string? IntakeText = null
);

/// <summary>One planned OData call (for preview / audit before sending).</summary>
public record PlannedOp(string Step, string Method, string Path, object? Body);

/// <summary>Result of processing many documents via chunked $batch requests.</summary>
public record ReturnGoodsManyResult(
    bool Success,
    int Total,               // documents requested
    int Created,             // documents created successfully
    int Failed,
    int Chunks,              // how many ≤16-doc chunks
    IReadOnlyList<string> DocumentNumbers,
    IReadOnlyList<string> Steps,
    string? Error,
    long DurationMs = 0,
    int Writes = 0,
    int Reads = 0,
    int Transactions = 0
);

/// <summary>
/// One read-back verification: after a write, we re-read the field and compare the
/// value that came back (<paramref name="Actual"/>) to what we sent (<paramref name="Expected"/>).
/// </summary>
public record StepCheck(string Step, string Field, string? Expected, string? Actual, bool Ok);

/// <summary>Result of running the scenario, including a per-step trace and read-back checks.</summary>
public record ReturnGoodsResult(
    bool Success,
    string? DocumentNumber,
    IReadOnlyList<string> Steps,
    string? Error,
    // Read-back verification of every written field (null in preview mode).
    IReadOnlyList<StepCheck>? Checks = null,
    // True only if every check matched; null when no checks ran (preview).
    bool? Verified = null,
    // Wall-clock time of the whole run, milliseconds.
    long DurationMs = 0,
    // OData transactions: writes (POST/PATCH) + reads (GET/query, incl. verification).
    int Writes = 0,
    int Reads = 0,
    int Transactions = 0
);
