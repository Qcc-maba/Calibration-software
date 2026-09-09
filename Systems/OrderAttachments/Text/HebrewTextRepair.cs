using System.Text;
using Maba.VCT.OrderAttachments.Msg;

namespace Maba.VCT.OrderAttachments.Text;

/// <summary>
/// Repairs Hebrew that was written as Windows-1255 and read back as Latin-1 somewhere before it
/// reached us. Inside a forwarded mail the quoted header block arrives looking like
/// <c>Subject: FW: ëéåì -äöòú îçéø A26010435</c>; the same bytes read as Windows-1255 say
/// <c>כיול - הצעת מחיר</c>.
///
/// This is NOT a rendering problem and cannot be fixed downstream. During the MBA-930 spike the
/// body was re-rendered with an explicit <c>&lt;meta charset="utf-8"&gt;</c> and the text stayed
/// broken, which is what proves the corruption is already in the bytes MsgReader returns. Most of
/// this corpus is forwarded chains, so without this repair the calibrator reads gibberish in the
/// majority of files.
///
/// The transform is a plain round-trip: encode the string back to the single-byte page it was
/// misread as, then decode those bytes as Hebrew.
/// </summary>
public static class HebrewTextRepair
{
    private const int Latin1CodePage = 1252;
    private const int HebrewCodePage = 1255;

    /// <summary>
    /// Repairs the mojibake runs in <paramref name="text"/> and leaves everything else alone.
    /// Safe to call on text that is already correct.
    /// </summary>
    public static string Repair(string? text)
    {
        if (string.IsNullOrEmpty(text)) return text ?? string.Empty;
        if (!LooksMojibake(text)) return text;

        MsgEncoding.EnsureRegistered();

        var latin1 = Encoding.GetEncoding(Latin1CodePage);
        var hebrew = Encoding.GetEncoding(HebrewCodePage);

        var result = new StringBuilder(text.Length);
        var run = new StringBuilder();

        foreach (var c in text)
        {
            if (IsSuspect(c))
            {
                run.Append(c);
                continue;
            }

            FlushRun(run, result, latin1, hebrew);
            result.Append(c);
        }

        FlushRun(run, result, latin1, hebrew);
        return result.ToString();
    }

    private static void FlushRun(StringBuilder run, StringBuilder result, Encoding latin1, Encoding hebrew)
    {
        if (run.Length == 0) return;

        var candidate = run.ToString();
        run.Clear();

        // A single stray accented character is far more likely to be a real accented letter in a
        // European name than a misread Hebrew word. Only convert runs long enough to be a word.
        if (candidate.Length < MinimumRunLength)
        {
            result.Append(candidate);
            return;
        }

        var bytes = latin1.GetBytes(candidate);
        var decoded = hebrew.GetString(bytes);

        // Only accept the repair if it actually produced Hebrew. If the round-trip lands on more
        // punctuation or another Latin-1 soup, the guess was wrong and the original stands.
        result.Append(ContainsHebrew(decoded) ? decoded : candidate);
    }

    private const int MinimumRunLength = 2;

    /// <summary>
    /// Characters that Windows-1255 Hebrew turns into when read as Latin-1: the 0xC0-0xFF band,
    /// which in real Latin-1 text is accented letters. Latin letters, digits, spaces and
    /// punctuation are never part of a misread run.
    /// </summary>
    private static bool IsSuspect(char c) => c >= 'À' && c <= 'ÿ';

    private static bool ContainsHebrew(string s)
    {
        foreach (var c in s)
            if (c >= '֐' && c <= '׿')
                return true;
        return false;
    }

    /// <summary>
    /// Cheap pre-check so correct text costs nothing. Requires a run of at least two suspect
    /// characters, which ordinary accented European text rarely produces.
    /// </summary>
    private static bool LooksMojibake(string text)
    {
        var run = 0;
        foreach (var c in text)
        {
            if (IsSuspect(c))
            {
                if (++run >= MinimumRunLength) return true;
            }
            else run = 0;
        }
        return false;
    }
}
