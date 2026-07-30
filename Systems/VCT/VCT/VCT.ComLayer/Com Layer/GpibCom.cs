using Maba.VCT.Libs.Trace;
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Maba.VCT.ComLayer
{
    /// <summary>
    /// GPIB (IEEE-488) transport over the NI-488.2 driver (gpib-32.dll), for instruments connected
    /// through a National Instruments GPIB-USB adapter (e.g. GPIB-USB-HS+).
    /// <para>
    /// Unlike the streaming transports, GPIB is strictly request/response: a query is written and the
    /// reply must be read back explicitly. This layer therefore reads immediately after writing a
    /// <b>query</b> (a command whose text ends with '?') and raises <see cref="DataReceived"/> with the
    /// reply; non-query writes are fire-and-forget. Adjust <see cref="ReadAfterEveryWrite"/> if a device
    /// does not follow the '?'-query convention.
    /// </para>
    /// <para>
    /// Requires NI-488.2 to be installed; without it <c>gpib-32.dll</c> is absent (a
    /// <see cref="DllNotFoundException"/> is surfaced from <see cref="Open"/>) and the adapter shows
    /// Device-Manager Code 28.
    /// </para>
    /// <para>
    /// The <see cref="IComLayer"/> contract is identical to <see cref="SerialCom"/>: open/close the
    /// link, send bytes, raise <see cref="DataReceived"/>. Protocol framing (packet cutting, SN
    /// identification) happens above, in the device host's parser — this layer is protocol-agnostic.
    /// </para>
    /// </summary>
    public class GpibCom : IComLayer
    {
        #region NI-488.2 interop (gpib-32.dll)

        // gpib-32.dll exports are __stdcall; DllImport's default CallingConvention.Winapi resolves to
        // StdCall on Windows, which is correct. The classic ibsta/iberr/ibcnt globals are NOT thread-safe,
        // so we read status through the Thread* accessors immediately after each call, under _sync.

        // ibsta status bits (returned by every call and by ThreadIbsta()).
        private const int ERR  = 0x8000; // error — check iberr for the cause
        private const int TIMO = 0x4000; // timeout — the operation did not complete within ibtmo
        private const int END  = 0x2000; // END or EOS detected on a read
        private const int CMPL = 0x0100; // I/O completed

        // ibtmo / ibdev timeout codes. These select a driver timeout bucket, not raw milliseconds.
        private const int TNONE = 0;  // disabled (wait forever — avoid: a mute device would hang the tick)
        private const int T30us = 4;
        private const int T100us = 5;
        private const int T300us = 6;
        private const int T1ms = 7;
        private const int T3ms = 8;
        private const int T10ms = 9;
        private const int T30ms = 10;
        private const int T100ms = 11;
        private const int T300ms = 12;
        private const int T1s = 13;
        private const int T3s = 14;
        private const int T10s = 15;
        private const int T30s = 16;
        private const int T100s = 17;

        // ibdev EOS mode: no end-of-string terminator; reads end on EOI or a full buffer.
        private const int EosNone = 0;
        // ibdev EOT: assert EOI on the last byte of every write so the listener knows the message ended.
        private const int EotAssertEoi = 1;

        [DllImport("gpib-32.dll", EntryPoint = "ibdev")]
        private static extern int ibdev(int boardIndex, int pad, int sad, int tmo, int eot, int eos);

        [DllImport("gpib-32.dll", EntryPoint = "ibonl")]
        private static extern int ibonl(int ud, int v);

        [DllImport("gpib-32.dll", EntryPoint = "ibclr")]
        private static extern int ibclr(int ud);

        [DllImport("gpib-32.dll", EntryPoint = "ibtmo")]
        private static extern int ibtmo(int ud, int tmo);

        [DllImport("gpib-32.dll", EntryPoint = "ibwrt")]
        private static extern int ibwrt(int ud, byte[] buf, int cnt);

        [DllImport("gpib-32.dll", EntryPoint = "ibrd")]
        private static extern int ibrd(int ud, byte[] buf, int cnt);

        // Thread-safe status accessors (the classic ibsta/iberr/ibcnt globals are not thread-safe).
        [DllImport("gpib-32.dll", EntryPoint = "ThreadIbsta")]
        private static extern int ThreadIbsta();

        [DllImport("gpib-32.dll", EntryPoint = "ThreadIberr")]
        private static extern int ThreadIberr();

        [DllImport("gpib-32.dll", EntryPoint = "ThreadIbcnt")]
        private static extern int ThreadIbcnt();

        #endregion

        #region properties

        public string Title { get; set; }
        public bool IsConnected { get { return _ud >= 0; } }
        public Tunnel ParentTunnel { get; private set; }
        public DateTime CreationTime { get; set; }
        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }

        public int BoardIndex { get; private set; }
        public int PrimaryAddress { get; private set; }

        /// <summary>
        /// NI-488.2 timeout code applied per device via <c>ibtmo</c> (see the T* constants, 0-17).
        /// This is a driver bucket, not milliseconds. Set before <see cref="Open"/>; changing it after
        /// open re-applies it on the next call to <see cref="Open"/> only. Default = <c>T3s</c>.
        /// A short-but-not-tiny bucket keeps a mute device from stalling the polling tick while still
        /// tolerating a slow calibrator settle.
        /// </summary>
        public int TimeoutCode { get; set; } = T3s;

        /// <summary>When true, read a reply after every write, not only after '?' queries.</summary>
        public bool ReadAfterEveryWrite { get; set; } = false;

        #endregion

        #region members

        private int _ud = -1;                 // NI device unit descriptor (>=0 when open)
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

        /// <param name="primaryAddress">GPIB primary address (PAD) the instrument is set to, 0-30.</param>
        /// <param name="boardIndex">NI GPIB board index (usually 0 for the first adapter).</param>
        /// <param name="parentTunnel">Owning tunnel (carries the GPIB config); may be null in tests.</param>
        public GpibCom(int primaryAddress, int boardIndex = 0, Tunnel parentTunnel = null)
        {
            PrimaryAddress = primaryAddress;
            BoardIndex = boardIndex;
            ParentTunnel = parentTunnel;
            CreationTime = DateTime.UtcNow;
            Title = string.Format("GPIB board:{0} addr:{1}", boardIndex, primaryAddress);
        }

        #endregion

        #region IComLayer

        /// <summary>
        /// Opens a device-level handle (<c>ibdev</c>) on the configured board/address, applies the
        /// per-device timeout (<c>ibtmo</c>) and issues a Selected-Device Clear (<c>ibclr</c>).
        /// Throws with a decoded ibsta/iberr message on failure; a missing driver surfaces as
        /// <see cref="DllNotFoundException"/>.
        /// </summary>
        public void Open()
        {
            lock (_sync)
            {
                if (_ud >= 0)
                    throw new InvalidOperationException("Already Open");

                int ud;
                try
                {
                    ud = ibdev(BoardIndex, PrimaryAddress, 0, TimeoutCode, EotAssertEoi, EosNone);
                }
                catch (DllNotFoundException ex)
                {
                    throw new DllNotFoundException(
                        "gpib-32.dll not found. NI-488.2 is not installed (GPIB adapter shows Device-Manager Code 28). " +
                        "Install NI-488.2 before using the GPIB tunnel.", ex);
                }

                int sta = ThreadIbsta();
                if (ud < 0 || (sta & ERR) != 0)
                {
                    throw new InvalidOperationException(string.Format(
                        "GPIB open failed (board {0}, addr {1}): {2}. Is NI-488.2 installed, the adapter connected, " +
                        "and is the instrument powered and set to this GPIB address?",
                        BoardIndex, PrimaryAddress, DescribeStatus(sta, ThreadIberr())));
                }

                _ud = ud;
                _layerClosedRaised = false;

                // Apply the timeout explicitly as well as via ibdev, so a later TimeoutCode change
                // (before the next Open) is not silently lost, and to be explicit about the value.
                ibtmo(_ud, TimeoutCode);

                ibclr(_ud); // Selected-Device Clear — put the instrument in a known state.
            }
        }

        public void SendString(string s)
        {
            if (s == null) return;
            SendBytes(Encoding.ASCII.GetBytes(s));
            // GPIB queries are request/response: read the reply back immediately. EOI (asserted on the
            // instrument's last byte) terminates the read, so no line terminator is appended on write.
            if (ReadAfterEveryWrite || s.TrimEnd().EndsWith("?"))
                ReadReply();
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
                if (_ud < 0) return;

                byte[] payload = b;
                if (offset != 0 || count != b.Length)
                {
                    payload = new byte[count];
                    Array.Copy(b, offset, payload, 0, count);
                }

                ibwrt(_ud, payload, payload.Length);
                LastTX_Time = DateTime.UtcNow;

                int sta = ThreadIbsta();
                if ((sta & ERR) != 0)
                    Tracer.Info("[GPIB] write error addr {0}: {1}", PrimaryAddress, DescribeStatus(sta, ThreadIberr()));
            }
        }

        /// <summary>
        /// Reads one reply and raises <see cref="DataReceived"/>. Handles replies longer than the read
        /// buffer by looping until END (EOI/EOS) is seen, the transfer stops short, or an error/timeout
        /// occurs. A timeout with no bytes is logged and swallowed (the BL treats a missing reply as a
        /// failed read and re-queues), matching the serial-transport behaviour.
        /// </summary>
        private void ReadReply()
        {
            var acc = new System.IO.MemoryStream();
            var buf = new byte[ReadBufferSize];

            lock (_sync)
            {
                if (_ud < 0) return;

                // Bound the loop so a chatty/misbehaving device cannot spin forever.
                for (int guard = 0; guard < 64; guard++)
                {
                    ibrd(_ud, buf, buf.Length);
                    int sta = ThreadIbsta();
                    int read = ThreadIbcnt(); // bytes actually transferred by this ibrd

                    if (read > 0)
                        acc.Write(buf, 0, read);

                    if ((sta & ERR) != 0)
                    {
                        int err = ThreadIberr();
                        // A bare timeout with no data is the common "device did not answer" case — log
                        // quietly. Anything else is a real transport fault worth flagging.
                        if ((sta & TIMO) != 0 && acc.Length == 0)
                            Tracer.Info("[GPIB] read timeout addr {0} (no reply): {1}", PrimaryAddress, DescribeStatus(sta, err));
                        else
                            Tracer.Info("[GPIB] read error addr {0}: {1}", PrimaryAddress, DescribeStatus(sta, err));
                        break;
                    }

                    // END means the instrument finished the message. A short read (< buffer) with no END
                    // also means there is nothing more to pull right now.
                    if ((sta & END) != 0 || read < buf.Length)
                        break;
                }
            }

            if (acc.Length > 0)
            {
                LastRX_Time = DateTime.UtcNow;
                var data = acc.ToArray();
                var handler = DataReceived;
                if (handler != null)
                    handler(this, new DataReceivedEventArgs(data, 0, data.Length));
            }
        }

        /// <summary>Takes the device offline (<c>ibonl</c> v=0) and raises <see cref="LayerClosed"/> once.</summary>
        public void Close()
        {
            bool raise = false;

            lock (_sync)
            {
                if (_ud >= 0)
                {
                    try { ibonl(_ud, 0); } // take the device offline
                    catch (Exception ex) { Tracer.Info("[GPIB] Close addr {0}: {1}", PrimaryAddress, ex.Message); }
                    _ud = -1;
                }

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

        #endregion

        #region diagnostics

        /// <summary>Decodes an ibsta bitmask + iberr code into a readable one-line diagnostic.</summary>
        private static string DescribeStatus(int ibsta, int iberr)
        {
            return string.Format("ibsta=0x{0:X4} [{1}] iberr={2} ({3})",
                ibsta, DecodeIbsta(ibsta), iberr, DecodeIberr(iberr));
        }

        private static string DecodeIbsta(int ibsta)
        {
            var sb = new StringBuilder();
            if ((ibsta & ERR) != 0) sb.Append("ERR ");
            if ((ibsta & TIMO) != 0) sb.Append("TIMO ");
            if ((ibsta & END) != 0) sb.Append("END ");
            if ((ibsta & CMPL) != 0) sb.Append("CMPL ");
            if ((ibsta & 0x1000) != 0) sb.Append("SRQI ");
            if ((ibsta & 0x0040) != 0) sb.Append("REM ");
            if ((ibsta & 0x0020) != 0) sb.Append("CIC ");
            if ((ibsta & 0x0008) != 0) sb.Append("TACS ");
            if ((ibsta & 0x0004) != 0) sb.Append("LACS ");
            return sb.Length == 0 ? "-" : sb.ToString().TrimEnd();
        }

        /// <summary>Maps the NI-488.2 iberr error code to its mnemonic + meaning.</summary>
        private static string DecodeIberr(int iberr)
        {
            switch (iberr)
            {
                case 0:  return "EDVR: OS/driver error — is NI-488.2 installed and the adapter present?";
                case 1:  return "ECIC: board is not Controller-In-Charge";
                case 2:  return "ENOL: no listener — wrong GPIB address, or instrument off/disconnected";
                case 3:  return "EADR: board addressing error";
                case 4:  return "EARG: invalid argument to a call";
                case 5:  return "ESAC: board is not the System Controller";
                case 6:  return "EABO: I/O aborted (timeout or ibstop)";
                case 7:  return "ENEB: no such board — wrong GpibBoardIndex, or driver not loaded";
                case 8:  return "EDMA: DMA error";
                case 10: return "EOIP: async I/O already in progress";
                case 11: return "ECAP: capability missing for this operation";
                case 12: return "EFSO: file-system error";
                case 14: return "EBUS: GPIB bus error";
                case 15: return "ESTB: serial-poll status byte queue overflow";
                case 16: return "ESRQ: SRQ stuck in ON position";
                case 20: return "ETAB: table problem (device/board table)";
                default: return "unknown iberr";
            }
        }

        #endregion

        #region IDisposable

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            Close();
            LayerClosed = null;
            DataReceived = null;

            GC.SuppressFinalize(this);
        }

        #endregion
    }
}
