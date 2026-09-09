using System.Text;
using Maba.VCT.OrderAttachments.Msg;

namespace Maba.VCT.OrderAttachments.Tests;

/// <summary>
/// Guards the single condition that makes this service work at all on a Hebrew corpus.
///
/// Before <see cref="MsgEncoding.EnsureRegistered"/> was added, all ten files in the MBA-930 spike
/// failed with "No data is available for encoding 1255" and MsgReader.Rtf.Font type-initializer
/// errors. If this test ever fails, every .msg in the system stops opening.
/// </summary>
public class MsgEncodingTests
{
    [Fact]
    public void Windows_1255_is_available_after_registration()
    {
        MsgEncoding.EnsureRegistered();

        var hebrew = Encoding.GetEncoding(1255);

        Assert.NotNull(hebrew);
        Assert.Equal(1255, hebrew.CodePage);
    }

    [Fact]
    public void Windows_1255_round_trips_hebrew()
    {
        MsgEncoding.EnsureRegistered();
        var hebrew = Encoding.GetEncoding(1255);

        const string text = "כיול הצעת מחיר";
        Assert.Equal(text, hebrew.GetString(hebrew.GetBytes(text)));
    }

    [Fact]
    public void Registration_is_idempotent()
    {
        // Called from the extractor constructor and again per extract; it sits on a hot path.
        MsgEncoding.EnsureRegistered();
        MsgEncoding.EnsureRegistered();
        MsgEncoding.EnsureRegistered();

        Assert.Equal(1255, Encoding.GetEncoding(1255).CodePage);
    }

    [Fact]
    public void Latin1_is_available_too()
    {
        // HebrewTextRepair needs 1252 to undo the misreading.
        MsgEncoding.EnsureRegistered();
        Assert.Equal(1252, Encoding.GetEncoding(1252).CodePage);
    }
}
