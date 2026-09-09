using Maba.VCT.Libs.Trace;
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Maba.VCT.ComLayer
{
    /// <summary>
    /// VISA transport (visa32.dll), for instruments reached over USBTMC — the USB "device" port that
    /// modern bench instruments expose instead of GPIB or RS-232. Verified live 2026-09-01 against a
    /// Keysight EDU-X 1002A oscilloscope at <c>USB0::0x2A8D::0x178B::CN59280205::INSTR</c>
    /// (NI-VISA 26.5 with the USB Passport installed).
    /// <para>
    /// Like <see cref="GpibCom"/> and unlike the streaming transports, VISA is strictly
    /// request/response: a query is written and the reply must be read back explicitly. This layer
    /// therefore reads immediately after writing a <b>query</b> (a command whose text ends with '?')
    /// and raises <see cref="DataReceived"/> with the reply; non-query writes are fire-and-forget.
    /// Adjust <see cref="ReadAfterEveryWrite"/> if a device does not follow the '?'-query convention.
    /// </para>
    /// <para>
    /// Requires a VISA runtime (NI-VISA or the Keysight IO Libraries Suite); without one
    /// <c>visa32.dll</c> is absent and a <see cref="DllNotFoundException"/> is surfaced from
    /// <see cref="Open"/>. The host process runs 32-bit (see <see cref="GpibCom"/>), so the DLL that
    /// actually loads is the one in <c>SysWOW64</c>.
    /// </para>
    /// <para>
    /// The <see cref="IComLayer"/> contract is identical to <see cref="SerialCom"/>: open/close the
    /// link, send bytes, raise <see cref="DataReceived"/>. Protocol framing (packet cutting, SN
    /// identification) happens above, in the device host's parser — this layer is protocol-agnostic.
    /// </para>
    /// </summary>
    public class VisaCom : IComLayer
    {
        #region VISA interop (visa32.dll)

        // The VISA C API is __stdcall on Windows (unlike NI-488.2's gpib-32.dll, which is __cdecl).
        // Every call returns a ViStatus: 0 = success, > 0 = warning, < 0 = error.

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viOpenDefaultRM(out IntPtr sesn);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viFindRsrc(IntPtr sesn, string expr, out IntPtr findList, out int retCnt, StringBuilder desc);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viOpen(IntPtr sesn, string name, int mode, int timeout, out IntPtr vi);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viClose(IntPtr vi);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viClear(IntPtr vi);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viSetAttribute(IntPtr vi, int attrName, IntPtr attrValue);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viWrite(IntPtr vi, byte[] buf, int count, out int retCount);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viRead(IntPtr vi, byte[] buf, int count, out int retCount);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viStatusDesc(IntPtr vi, int status, StringBuilder desc);

        /// <summary>VI_ATTR_TMO_VALUE — I/O timeout in milliseconds (unlike GPIB's bucket codes).</summary>
        private const int VI_ATTR_TMO_VALUE = 0x3FFF001A;

        private const int VI_SUCCESS = 0;
        private const int VI_ERROR_RSRC_NFOUND = unchecked((int)0xBFFF0011);
        private const int VI_ERROR_TMO = unchecked((int)0xBFFF0015);

        /// <summary>Resource filter used when <see cref="ResourceName"/> is "AUTO".</summary>
        private const string UsbInstrumentFilter = "USB?*INSTR";

        #endregion

        #region properties

        public string Title { get; set; }
        public bool IsConnected { get { return _vi != IntPtr.Zero; } }
        public Tunnel ParentTunnel { get; private set; }
        public DateTime CreationTime { get; set; }
        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }

        /// <summary>
        /// The configured VISA resource string (e.g. "USB0::0x2A8D::0x178B::CN59280205::INSTR"), or
        /// "AUTO" to take the first USB instrument VISA can see.
        /// </summary>
        public string ResourceName { get; private set; }

        /// <summary>The resource actually opened — differs from <see cref="ResourceName"/> when it was "AUTO".</summary>
        public string ResolvedResourceName { get; private set; }

        /// <summary>I/O timeout in milliseconds. Long enough for a slow :AUToscale, short enough not to stall the tick.</summary>
        public int TimeoutMs { get; set; } = 5000;

        /// <summary>When true, read a reply after every write, not only after '?' queries.</summary>
        public bool ReadAfterEveryWrite { get; set; } = false;

        #endregion

        #region members

        private IntPtr _rm = IntPtr.Zero;      // resource-manager session
        private IntPtr _vi = IntPtr.Zero;      // instrument session (non-zero when open)
        private readonly object _sync = new object();
        private bool _disposed;
        private bool _layerClosedRaised;
        private const int ReadBufferSize = 8192;

        #endregion

        #region events

        public event DataReceivedDelegate DataReceived;
        public event LayerDestroyedDelegate LayerClosed;

        #endregion

        #region ctor

        /// <param name="resourceName">VISA resource string, or "AUTO" to pick the first USB instrument.</param>
        /// <param name="parentTunnel">Owning tunnel (carries the VISA config); may be null in tests.</param>
        public VisaCom(string resourceName, Tunnel parentTunnel = null)
        {
            ResourceName = resourceName;
            ParentTunnel = parentTunnel;
            CreationTime = DateTime.UtcNow;
            Title = "VISA " + resourceName;
        }

        #endregion

        #region IComLayer

        /// <summary>
        /// Opens the VISA resource manager and the instrument session, applies the I/O timeout and
        /// issues a device clear so the instrument starts from a known state. Throws with a decoded
        /// VISA status on failure; a missing VISA runtime surfaces as <see cref="DllNotFoundException"/>.
        /// </summary>
        public void Open()
        {
            lock (_sync)
            {
                if (_vi != IntPtr.Zero)
                    throw new InvalidOperationException("Already Open");

                int status;
                try
                {
                    status = viOpenDefaultRM(out _rm);
                }
                catch (DllNotFoundException ex)
                {
                    throw new DllNotFoundException(
                        "visa32.dll not found. No VISA runtime is installed. Install NI-VISA (with the USB " +
                        "Passport) or the Keysight IO Libraries Suite before using a VISA tunnel.", ex);
                }

                if (status < VI_SUCCESS)
                {
                    _rm = IntPtr.Zero;
                    throw new InvalidOperationException(
                        "VISA viOpenDefaultRM failed: " + DescribeStatus(IntPtr.Zero, status));
                }

                var resource = ResolveResource();

                IntPtr vi;
                status = viOpen(_rm, resource, 0, TimeoutMs, out vi);
                if (status < VI_SUCCESS)
                {
                    var detail = DescribeStatus(IntPtr.Zero, status);
                    CloseResourceManager();
                    throw new InvalidOperationException(string.Format(
                        "VISA open failed for '{0}': {1}. Is the instrument powered and connected, is its USB " +
                        "cable in the rear DEVICE port, and does the resource string match what VISA reports?",
                        resource, detail));
                }

                _vi = vi;
                ResolvedResourceName = resource;
                Title = "VISA " + resource;
                _layerClosedRaised = false;

                // Timeout is passed to viOpen for the open itself; set it as a session attribute too so
                // it governs every subsequent read/write.
                viSetAttribute(_vi, VI_ATTR_TMO_VALUE, new IntPtr(TimeoutMs));

                viClear(_vi); // device clear — put the instrument in a known state.
            }
        }

        /// <summary>
        /// Resolves <see cref="ResourceName"/> to a concrete VISA resource. Three forms are accepted:
        /// <list type="bullet">
        /// <item>a concrete resource string, used as-is;</item>
        /// <item><c>"AUTO"</c> - the first USB instrument VISA can see, mirroring the serial tunnel's
        /// "AUTO" port detection. Fine with one instrument on the bench, ambiguous with several;</item>
        /// <item>a VISA find expression (anything containing <c>?</c> or <c>*</c>), e.g.
        /// <c>USB?*::0xF4EC::?*INSTR</c> - the first match wins. This is how a tunnel pins one
        /// instrument by vendor/model without hard-coding a serial number, so swapping in another
        /// unit of the same model keeps working.</item>
        /// </list>
        /// </summary>
        private string ResolveResource()
        {
            var configured = (ResourceName ?? "").Trim();
            var isAuto = string.Equals(configured, "AUTO", StringComparison.OrdinalIgnoreCase);
            var isExpression = configured.IndexOf('?') >= 0 || configured.IndexOf('*') >= 0;

            if (!isAuto && !isExpression)
                return configured;

            var filter = isAuto ? UsbInstrumentFilter : configured;

            var desc = new StringBuilder(512);
            IntPtr findList;
            int count;
            var status = viFindRsrc(_rm, filter, out findList, out count, desc);

            if (status < VI_SUCCESS || count <= 0)
            {
                throw new InvalidOperationException(
                    "VISA tunnel '" + configured + "' matched no instrument (searched " + filter + "). " +
                    "Is the instrument powered and its USB device port connected?");
            }

            var found = desc.ToString();
            Tracer.Info("[VISA] '{0}' resolved to {1}{2}", configured, found,
                        count > 1 ? string.Format(" (first of {0} matches)", count) : "");
            return found;
        }

        public void SendString(string s)
        {
            if (s == null) return;

            // USBTMC frames each write as a message and sets the END bit, so a terminator is not
            // strictly required — but Keysight instruments expect the newline, so append one when the
            // caller did not. Verified against the EDU-X 1002A.
            var text = s.EndsWith("\n") ? s : s + "\n";
            SendBytes(Encoding.ASCII.GetBytes(text));

            if (ReadAfterEveryWrite || IsQuery(s))
                ReadReply();
        }

        /// <summary>
        /// True when a SCPI command expects a reply. The '?' marks the query, but it is NOT always the
        /// last character: a query that takes parameters puts them after it, as in
        /// ":MEASure:VPP? CHANnel1". Testing only the last character (as the GPIB layer does, which is
        /// safe for the parameterless queries the 9100 uses) left such a reply unread, the session
        /// waiting, and acquisition stalled after the very first measurement. In SCPI '?' appears only
        /// in queries, so looking anywhere in the command is the correct test.
        /// </summary>
        internal static bool IsQuery(string command)
        {
            return command != null && command.IndexOf('?') >= 0;
        }

        public void SendBytes(byte[] b)
        {
            if (b == null) return;
            SendBytes(b, 0, b.Length);
        }

        public void SendBytes(byte[] b, int offset, int count)
        {
            if (b == null) return;
            lock (_sync)
            {
                if (_vi == IntPtr.Zero) return;

                byte[] payload = b;
                if (offset != 0 || count != b.Length)
                {
                    payload = new byte[count];
                    Array.Copy(b, offset, payload, 0, count);
                }

                int written;
                var status = viWrite(_vi, payload, payload.Length, out written);
                LastTX_Time = DateTime.UtcNow;

                if (status < VI_SUCCESS)
                    Tracer.Info("[VISA] write error on {0}: {1}", ResolvedResourceName, DescribeStatus(_vi, status));
            }
        }

        /// <summary>
        /// Reads one reply and raises <see cref="DataReceived"/>. Handles replies longer than the read
        /// buffer by looping while the transfer keeps filling it. A timeout with no bytes is logged and
        /// swallowed (the BL treats a missing reply as a failed read and re-queues), matching the
        /// serial and GPIB transports.
        /// </summary>
        private void ReadReply()
        {
            var acc = new System.IO.MemoryStream();
            var buf = new byte[ReadBufferSize];

            lock (_sync)
            {
                if (_vi == IntPtr.Zero) return;

                // Bound the loop so a chatty/misbehaving device cannot spin forever.
                for (int guard = 0; guard < 64; guard++)
                {
                    int read;
                    var status = viRead(_vi, buf, buf.Length, out read);

                    if (read > 0)
                        acc.Write(buf, 0, read);

                    if (status < VI_SUCCESS)
                    {
                        // A bare timeout with no data is the common "device did not answer" case — log
                        // quietly. Anything else is a real transport fault worth flagging.
                        if (status == VI_ERROR_TMO && acc.Length == 0)
                            Tracer.Info("[VISA] read timeout on {0} (no reply)", ResolvedResourceName);
                        else
                            Tracer.Info("[VISA] read error on {0}: {1}", ResolvedResourceName, DescribeStatus(_vi, status));
                        break;
                    }

                    // VI_SUCCESS (not VI_SUCCESS_MAX_CNT) means the instrument finished the message.
                    // A short read also means there is nothing more to pull right now.
                    if (status == VI_SUCCESS || read < buf.Length)
                        break;
                }
            }

            if (acc.Length > 0)
            {
                LastRX_Time = DateTime.UtcNow;
                var data = acc.ToArray();

                // USBTMC messages are delimited by the transfer's END bit, not by CR/LF — one ReadReply
                // == one complete message, and a SCPI reply typically ends with a bare '\n'. The shared
                // Hydra parser only cuts a packet on "=>" or "\r\n", so without normalising here the
                // reply would never be framed and the device would stay pending forever. Same reason,
                // same fix as GpibCom.
                bool endsCrLf = data.Length >= 2 && data[data.Length - 2] == 0x0D && data[data.Length - 1] == 0x0A;
                if (!endsCrLf)
                {
                    int trim = data.Length;
                    while (trim > 0 && (data[trim - 1] == 0x0A || data[trim - 1] == 0x0D)) trim--; // drop a lone LF/CR
                    var framed = new byte[trim + 2];
                    Buffer.BlockCopy(data, 0, framed, 0, trim);
                    framed[trim] = 0x0D;
                    framed[trim + 1] = 0x0A;
                    data = framed;
                }

                var handler = DataReceived;
                if (handler != null)
                    handler(this, new DataReceivedEventArgs(data, 0, data.Length));
            }
        }

        /// <summary>Closes the instrument and resource-manager sessions and raises <see cref="LayerClosed"/> once.</summary>
        public void Close()
        {
            bool raise = false;

            lock (_sync)
            {
                if (_vi != IntPtr.Zero)
                {
                    try { viClose(_vi); }
                    catch (Exception ex) { Tracer.Info("[VISA] Close {0}: {1}", ResolvedResourceName, ex.Message); }
                    _vi = IntPtr.Zero;
                }

                CloseResourceManager();

                if (!_layerClosedRaised)
                {
                    _layerClosedRaised = true;
                    raise = true;
                }
            }

            if (raise)
            {
                var closed = LayerClosed;
                if (closed != null)
                    closed(this, new DestroyedEventArgs());
            }
        }

        private void CloseResourceManager()
        {
            if (_rm == IntPtr.Zero) return;
            try { viClose(_rm); }
            catch (Exception ex) { Tracer.Info("[VISA] Close RM: {0}", ex.Message); }
            _rm = IntPtr.Zero;
        }

        #endregion

        #region diagnostics

        /// <summary>
        /// Decodes a ViStatus into a readable one-line diagnostic, preferring the driver's own text
        /// (viStatusDesc) and falling back to the codes we name explicitly.
        /// </summary>
        private static string DescribeStatus(IntPtr vi, int status)
        {
            string text = null;
            try
            {
                var sb = new StringBuilder(512);
                if (viStatusDesc(vi, status, sb) == VI_SUCCESS && sb.Length > 0)
                    text = sb.ToString().Trim();
            }
            catch (Exception)
            {
                // A driver that cannot describe its own status must not mask the status itself.
            }

            if (string.IsNullOrEmpty(text))
                text = DecodeStatus(status);

            return string.Format("status=0x{0:X8} ({1})", status, text);
        }

        private static string DecodeStatus(int status)
        {
            switch (status)
            {
                case VI_SUCCESS: return "VI_SUCCESS";
                case VI_ERROR_RSRC_NFOUND:
                    return "VI_ERROR_RSRC_NFOUND: no such resource — check the resource string against what VISA reports";
                case VI_ERROR_TMO:
                    return "VI_ERROR_TMO: timeout — the instrument did not answer in time";
                default:
                    return status < VI_SUCCESS ? "VISA error" : "VISA warning";
            }
        }

        #endregion

        #region IDisposable

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            Close();
        }

        #endregion
    }
}
