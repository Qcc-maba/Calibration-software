using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using Maba.VCT.InstructionAssistant.Models;
using Maba.VCT.InstructionAssistant.Options;

namespace Maba.VCT.InstructionAssistant.Summarize;

/// <summary>
/// Summarizes the instruction documents with the Anthropic Messages API. Asks the model to
/// return strict JSON (summary / key points / warnings) in Hebrew so the UI gets structure,
/// not just prose. The API key is read from the ANTHROPIC_API_KEY environment variable first,
/// then config. Combined source text is capped at <see cref="SummarizerOptions.MaxPromptChars"/>.
/// </summary>
public sealed class ClaudeSummarizer(
    HttpClient http,
    IOptions<InstructionAssistantOptions> options,
    ILogger<ClaudeSummarizer> logger) : IInstructionSummarizer
{
    private readonly InstructionAssistantOptions _opt = options.Value;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public async Task SummarizeAsync(
        InstrumentContext ctx, IReadOnlyList<InstructionDocument> docs, InstructionSummary result, CancellationToken ct = default)
    {
        var apiKey = Environment.GetEnvironmentVariable("ANTHROPIC_API_KEY") ?? _opt.Summarizer.ApiKey;
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            result.Notices.Add("מפתח Claude API לא הוגדר (ANTHROPIC_API_KEY) — לא בוצע סיכום ענן.");
            result.GeneratedBy = "none";
            return;
        }

        var (userText, redacted) = BuildSourceBlock(ctx, docs);
        if (redacted) result.Notices.Add("שמות לקוח הוסתרו לפני שליחה לענן.");

        var requestBody = new
        {
            model = _opt.Summarizer.Model,
            max_tokens = _opt.Summarizer.MaxTokens,
            system = SystemPrompt,
            messages = new[] { new { role = "user", content = userText } },
        };

        using var req = new HttpRequestMessage(HttpMethod.Post, _opt.Summarizer.BaseUrl)
        {
            Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json"),
        };
        req.Headers.Add("x-api-key", apiKey);
        req.Headers.Add("anthropic-version", _opt.Summarizer.AnthropicVersion);

        string body;
        try
        {
            using var resp = await http.SendAsync(req, ct);
            body = await resp.Content.ReadAsStringAsync(ct);
            if (!resp.IsSuccessStatusCode)
            {
                logger.LogWarning("Claude API failed ({Status}): {Body}", (int)resp.StatusCode, Truncate(body));
                result.Notices.Add($"קריאת Claude נכשלה ({(int)resp.StatusCode}).");
                result.GeneratedBy = "claude:error";
                return;
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Claude API call threw");
            result.Notices.Add("שגיאת רשת בקריאה ל-Claude.");
            result.GeneratedBy = "claude:error";
            return;
        }

        var (text, stopReason) = ExtractText(body);
        if (stopReason == "max_tokens")
            result.Notices.Add("הסיכום נקטע בגלל מגבלת אורך — ניתן להגדיל את Summarizer:MaxTokens.");

        ApplyModelJson(text, result);
        result.GeneratedBy = $"claude:{_opt.Summarizer.Model}";
    }

    private const string SystemPrompt =
        "אתה עוזר טכני למעבדת כיול. בהינתן הוראות לקוח ממקורות שונים עבור מכשיר מסוים, " +
        "הפק סיכום קצר, מדויק ומעשי בעברית עבור הכייל. אל תמציא מידע — הסתמך רק על הטקסט שסופק. " +
        "החזר אך ורק JSON תקין במבנה: " +
        "{\"summaryMarkdown\": string, \"keyPoints\": string[], \"warnings\": string[]}. " +
        "keyPoints = פעולות/דרישות מחייבות. warnings = אזהרות בטיחות או 'אין לבצע'. " +
        "אם אין הוראות רלוונטיות, החזר summaryMarkdown ריק ומערכים ריקים.";

    /// <summary>Builds the user message from the source docs; returns whether names were redacted.</summary>
    private (string text, bool redacted) BuildSourceBlock(InstrumentContext ctx, IReadOnlyList<InstructionDocument> docs)
    {
        var sb = new StringBuilder();
        sb.AppendLine("## המכשיר המכויל");
        sb.AppendLine($"- לקוח: {(_opt.RedactCustomerNames ? "[מוסתר]" : ctx.CustomerName ?? ctx.CustomerId ?? "לא ידוע")}");
        sb.AppendLine($"- סוג/דגם: {ctx.DeviceType} {ctx.Manufacturer} {ctx.Model}".TrimEnd());
        sb.AppendLine($"- מס' סידורי: {ctx.SerialNumber ?? "לא ידוע"}");
        sb.AppendLine();
        sb.AppendLine("## מקורות הוראות");

        int budget = _opt.Summarizer.MaxPromptChars;
        foreach (var d in docs)
        {
            if (budget <= 0) break;
            sb.AppendLine($"### {d.Title}  ({d.Source}, {d.MatchReason})");
            if (d.HasText)
            {
                var slice = d.Text.Length > budget ? d.Text[..budget] : d.Text;
                sb.AppendLine(slice);
                budget -= slice.Length;
            }
            else
            {
                sb.AppendLine($"[{d.ExtractionNote ?? "אין טקסט"}]");
            }
            sb.AppendLine();
        }

        var text = sb.ToString();
        if (_opt.RedactCustomerNames && !string.IsNullOrWhiteSpace(ctx.CustomerName))
            text = text.Replace(ctx.CustomerName, "[לקוח]", StringComparison.OrdinalIgnoreCase);

        return (text, _opt.RedactCustomerNames);
    }

    /// <summary>Returns the model's text plus its stop_reason (so truncation can be reported).</summary>
    private static (string Text, string? StopReason) ExtractText(string apiBody)
    {
        try
        {
            using var doc = JsonDocument.Parse(apiBody);
            var stop = doc.RootElement.TryGetProperty("stop_reason", out var sr) ? sr.GetString() : null;

            if (doc.RootElement.TryGetProperty("content", out var content) && content.ValueKind == JsonValueKind.Array)
            {
                var sb = new StringBuilder();
                foreach (var block in content.EnumerateArray())
                    if (block.TryGetProperty("type", out var t) && t.GetString() == "text"
                        && block.TryGetProperty("text", out var txt))
                        sb.Append(txt.GetString());
                return (sb.ToString(), stop);
            }
        }
        catch { /* fall through */ }
        return ("", null);
    }

    private void ApplyModelJson(string modelText, InstructionSummary result)
    {
        var json = UnwrapJson(modelText);
        if (json is null)
        {
            // The model returned prose instead of JSON — keep it as the summary body.
            result.SummaryMarkdown = modelText.Trim();
            return;
        }
        try
        {
            var parsed = JsonSerializer.Deserialize<ModelAnswer>(json, JsonOpts);
            if (parsed is not null)
            {
                result.SummaryMarkdown = parsed.SummaryMarkdown ?? "";
                result.KeyPoints = parsed.KeyPoints ?? [];
                result.Warnings = parsed.Warnings ?? [];
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not parse model JSON; salvaging the summary field");
            result.SummaryMarkdown = SalvageSummary(json) ?? modelText.Trim();
        }
    }

    /// <summary>Pull the first {...} block out of the model text (handles ```json fences).</summary>
    private static string? UnwrapJson(string text)
    {
        int start = text.IndexOf('{');
        int end = text.LastIndexOf('}');
        return (start >= 0 && end > start) ? text[start..(end + 1)] : null;
    }

    /// <summary>
    /// A response cut off by max_tokens leaves unparseable JSON. Rather than dumping the raw
    /// JSON into the UI, pull out whatever "summaryMarkdown" value was already written and
    /// un-escape it, so the calibrator still sees the (partial) Hebrew summary.
    /// </summary>
    private static string? SalvageSummary(string? partialJson)
    {
        if (string.IsNullOrEmpty(partialJson)) return null;

        const string key = "\"summaryMarkdown\"";
        int k = partialJson.IndexOf(key, StringComparison.Ordinal);
        if (k < 0) return null;

        int q = partialJson.IndexOf('"', k + key.Length + 1);   // opening quote of the value
        if (q < 0) return null;

        var sb = new StringBuilder();
        for (int i = q + 1; i < partialJson.Length; i++)
        {
            var c = partialJson[i];
            if (c == '\\' && i + 1 < partialJson.Length)
            {
                var next = partialJson[++i];
                sb.Append(next switch { 'n' => '\n', 't' => '\t', 'r' => '\r', _ => next });
                continue;
            }
            if (c == '"') break;   // end of the value
            sb.Append(c);
        }

        var text = sb.ToString().Trim();
        return text.Length > 0 ? text : null;
    }

    private static string Truncate(string s) => s.Length > 500 ? s[..500] : s;

    private sealed class ModelAnswer
    {
        public string? SummaryMarkdown { get; set; }
        public List<string>? KeyPoints { get; set; }
        public List<string>? Warnings { get; set; }
    }
}
