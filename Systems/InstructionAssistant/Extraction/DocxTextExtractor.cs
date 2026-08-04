using System.IO.Compression;
using System.Text;
using System.Xml;
using Maba.VCT.InstructionAssistant.Models;

namespace Maba.VCT.InstructionAssistant.Extraction;

/// <summary>
/// Reads text out of a .docx by unzipping word/document.xml and walking the WordprocessingML
/// runs. The ECS instruction files on the share are Word documents whose content lives in
/// paragraphs and tables, so table cells are emitted as tab-separated rows to keep test
/// points / tolerances readable for the summarizer.
///
/// Deliberately dependency-free (a .docx is an OPC zip) — no OpenXML SDK needed for read-only
/// text. Legacy binary .doc is NOT handled here; those files fall through to the "unsupported"
/// note in <see cref="CompositeTextExtractor"/>.
/// </summary>
public sealed class DocxTextExtractor : IDocumentTextExtractor
{
    private const string W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    public bool CanHandle(string extension) =>
        extension.Equals(".docx", StringComparison.OrdinalIgnoreCase);

    public Task ExtractAsync(string path, InstructionDocument doc, int maxChars, CancellationToken ct = default)
    {
        // Share the handle — these files sit on a drive where someone may have them open in Word.
        using var file = new FileStream(path, FileMode.Open, FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        using var zip = new ZipArchive(file, ZipArchiveMode.Read);
        var entry = zip.GetEntry("word/document.xml")
                    ?? throw new InvalidDataException("word/document.xml not found — not a Word document?");

        using var stream = entry.Open();
        var sb = new StringBuilder();
        var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, IgnoreComments = true };
        using var reader = XmlReader.Create(stream, settings);

        var inCell = false;
        while (reader.Read())
        {
            ct.ThrowIfCancellationRequested();
            if (sb.Length >= maxChars) break;

            if (reader.NodeType == XmlNodeType.Element && reader.NamespaceURI == W)
            {
                switch (reader.LocalName)
                {
                    case "t":
                        sb.Append(reader.ReadElementContentAsString());
                        break;
                    case "tab":
                        sb.Append('\t');
                        break;
                    case "br":
                    case "cr":
                        sb.Append('\n');
                        break;
                    case "tc":
                        inCell = true;
                        break;
                }
            }
            else if (reader.NodeType == XmlNodeType.EndElement && reader.NamespaceURI == W)
            {
                switch (reader.LocalName)
                {
                    case "p":
                        sb.Append(inCell ? '\t' : '\n');
                        break;
                    case "tc":
                        inCell = false;
                        break;
                    case "tr":
                        sb.Append('\n');
                        break;
                }
            }
        }

        doc.Text = Normalize(sb.ToString(), maxChars);
        return Task.CompletedTask;
    }

    /// <summary>Collapse the blank runs Word leaves behind, without losing row structure.</summary>
    private static string Normalize(string raw, int maxChars)
    {
        var lines = raw.Split('\n')
            .Select(l => l.Replace(' ', ' ').TrimEnd().Replace("\t\t", "\t").Trim('\t', ' '))
            .Where(l => l.Length > 0);

        var text = string.Join('\n', lines);
        return text.Length > maxChars ? text[..maxChars] : text;
    }
}
