namespace Maba.VCT.InstructionAssistant.Options;

/// <summary>
/// Configuration bound from the "InstructionAssistant" section of appsettings /
/// environment. Secrets (the Anthropic key) come from the environment, never git.
/// </summary>
public sealed class InstructionAssistantOptions
{
    public const string SectionName = "InstructionAssistant";

    public FileShareOptions FileShare { get; set; } = new();
    public CentralExcelOptions CentralExcel { get; set; } = new();
    public SummarizerOptions Summarizer { get; set; } = new();
    public PriorityInstructionOptions Priority { get; set; } = new();

    /// <summary>Replace customer names with an opaque id before sending text to the cloud.</summary>
    public bool RedactCustomerNames { get; set; } = false;
}

public sealed class FileShareOptions
{
    /// <summary>Root folders (UNC or local) scanned for customer instruction files.</summary>
    public List<string> Roots { get; set; } = [];

    /// <summary>File extensions to consider (lowercase, with dot).</summary>
    public List<string> Extensions { get; set; } = [".txt", ".md", ".pdf", ".doc", ".docx"];

    /// <summary>Max files to return per lookup (keeps the summarizer prompt bounded).</summary>
    public int MaxFiles { get; set; } = 12;

    /// <summary>Max characters of extracted text kept per file.</summary>
    public int MaxCharsPerFile { get; set; } = 20_000;

    /// <summary>Recurse into sub-folders when scanning a root.</summary>
    public bool Recursive { get; set; } = true;
}

public sealed class CentralExcelOptions
{
    /// <summary>Path to the central calibration-requirements workbook ("אקסל מרכז").</summary>
    public string? Path { get; set; }

    /// <summary>Worksheet name to read (empty = first non-empty sheet).</summary>
    public string? SheetName { get; set; }

    /// <summary>Cache the parsed workbook this many seconds (0 = re-read every request).</summary>
    public int CacheSeconds { get; set; } = 300;
}

public sealed class SummarizerOptions
{
    /// <summary>"Claude" (cloud) or "Extractive" (offline, no AI).</summary>
    public string Mode { get; set; } = "Claude";

    /// <summary>Anthropic model id. Defaults to a capable, cost-effective model.</summary>
    public string Model { get; set; } = "claude-sonnet-5";

    /// <summary>Read from config OR the ANTHROPIC_API_KEY environment variable (env wins).</summary>
    public string? ApiKey { get; set; }

    public string BaseUrl { get; set; } = "https://api.anthropic.com/v1/messages";
    public string AnthropicVersion { get; set; } = "2023-06-01";
    public int MaxTokens { get; set; } = 1500;

    /// <summary>Total characters of combined source text sent to the model.</summary>
    public int MaxPromptChars { get; set; } = 60_000;
}

public sealed class PriorityInstructionOptions
{
    /// <summary>Enable reading order instruction text ("הנחיות לביצוע") from Priority.</summary>
    public bool Enabled { get; set; } = false;

    /// <summary>
    /// Read-only connection string to the Priority SQL Server company DB (amaba).
    /// Secret — supply via env (<c>InstructionAssistant__Priority__ConnectionString</c>) or the
    /// gitignored Development config, never in the committed appsettings.
    /// </summary>
    public string? ConnectionString { get; set; }

    /// <summary>How many of the customer's most recent orders to inspect for instruction text.</summary>
    public int MaxOrders { get; set; } = 8;

    /// <summary>Max instruction documents returned after collapsing duplicate order texts.</summary>
    public int MaxDocuments { get; set; } = 3;

    /// <summary>Ignore order texts shorter than this (empty/placeholder rows).</summary>
    public int MinTextChars { get; set; } = 200;

    /// <summary>Truncate each order's text at this length before it reaches the summarizer.</summary>
    public int MaxCharsPerOrder { get; set; } = 20_000;

    /// <summary>
    /// Columns held in legacy "visual Hebrew": Hebrew letters sit in normal logical order, but
    /// every Latin/digit token inside them is stored backwards, and a value with no Hebrew at all
    /// is stored fully reversed including word order. Un-scrambled on read by
    /// <c>PriorityRecordResolver.FixVisualHebrew</c>.
    ///
    /// Verified live by SQL (rendering-independent) 2026-08-04:
    /// MNFDES "IKOIH" 2,676 rows vs "HIOKI" 0 · SERNDES "%MMD%" 100,563 vs "%DMM%" 0, yet the
    /// Hebrew "מולטימטר" matches forward in 84,999 rows · digits likewise reversed
    /// ("מוט אורך מסטר 521" = a 125mm rod) · CUSTDES "%DTL%" 183 vs "%LTD%" 0, Lumenis stored
    /// "CSB DTL SINEMUL". MODEL / SERNUM / MANUFC_SERIAL are stored forward and are NOT listed.
    /// </summary>
    public List<string> VisualHebrewFields { get; set; } = ["MNFDES", "SERNDES", "CUSTDES"];
}
