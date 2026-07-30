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
    /// <para>Requires NI-488.2 to be installed; without it the adapter shows Device-Manager Code 28.</para>
    /// </summary>
    public class GpibCom : IComLayer
    {
        #region NI-488.2 interop (gpib-32.dll)

        // ibsta bits
        private const int ERR = 0x8000; // error
        private const int TIMO = 0x4000; // timeout

        // timeout codes (ibdev / ibtmo)
        private const int T10s = 13;

        [DllImport("gpib-32.dll", EntryPoint = "ibdev")]
        private static extern int ibdev(int boardIndex, int pad, int sad, int tmo, int eot, int eos);

        [DllImport("gpib-32.dll", EntryPoint = "ibonl")]
        private static extern int ibonl(int ud, int v);

        [DllImport("gpib-32.dll", EntryPoint = "ibclr")]
        private static extern int ibclr(int ud);

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

        /// <summary>When true, read a reply after every write, not only after '?' queries.</summary>
        public bool ReadAfterEveryWrite { get; set; } = false;

        #endregion

        #region members

        private int _ud = -1;                 // NI device unit descriptor (>=0 when open)
        private readonly object _sync = new object();
        private const int ReadBufferSize = 8192;

        #endregion

        #region events

        public event DataReceivedDelegate DataReceived;
        public event LayerDestroyedDelegate LayerClosed;

        #endregion

        #region ctor

        /// <param name="primaryAddress">GPIB primary address (PAD) the instrument is set to, 0-30.</param>
        /// <param name="boardIndex">NI GPIB board index (usually 0 for the first adapter).</param>
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

        public void Open()
        {
            lock (_sync)
            {
                if (_ud >= 0)
                    throw new Exception("Already Open");

                // eot=1 (assert EOI on last byte), eos=0 (no end-of-string char).
                var ud = ibdev(BoardIndex, PrimaryAddress, 0, T10s, 1, 0);
                if (ud < 0 || (ThreadIbsta() & ERR) != 0)
                    throw new Exception(string.Format(
                        "GPIB open failed (board {0}, addr {1}): iberr={2}. Is NI-488.2 installed and the adapter working?",
                        BoardIndex, PrimaryAddress, ThreadIberr()));

                _ud = ud;
                ibclr(_ud); // selected-device clear
            }
        }

        public void SendString(string s)
        {
            if (s == null) return;
            SendBytes(Encoding.ASCII.GetBytes(s));
            if (ReadAfterEveryWrite || s.TrimEnd().EndsWith("?"))
                ReadReply();
        }

        public void SendBytes(byte[] b)
        {
            SendBytes(b, 0, b.Length);
        }

        public void SendBytes(byte[] b, int offset, int count)
        {
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
                if ((ThreadIbsta() & ERR) != 0)
                    Tracer.Info("[GPIB] write error addr {0}: iberr={1}", PrimaryAddress, ThreadIberr());
            }
        }

        private void ReadReply()
        {
            byte[] buf = new byte[ReadBufferSize];
            int read;
            lock (_sync)
            {
                if (_ud < 0) return;
                ibrd(_ud, buf, buf.Length);
                if ((ThreadIbsta() & ERR) != 0)
                {
                    Tracer.Info("[GPIB] read error addr {0}: iberr={1}", PrimaryAddress, ThreadIberr());
                    return;
                }
                read = ThreadIbcnt(); // bytes actually read
            }
            if (read > 0)
            {
                LastRX_Time = DateTime.UtcNow;
                var handler = DataReceived;
                if (handler != null)
                    handler(this, new DataReceivedEventArgs(buf, 0, read));
            }
        }

        public void Close()
        {
            lock (_sync)
            {
                if (_ud >= 0)
                {
                    try { ibonl(_ud, 0); } // take the device offline
                    catch (Exception ex) { Tracer.Info("[GPIB] Close addr {0}: {1}", PrimaryAddress, ex.Message); }
                    _ud = -1;
                }
            }

            var closed = LayerClosed;
            if (closed != null)
                closed(this, new DestroyedEventArgs());
        }

        #endregion

        #region IDisposable

        public void Dispose()
        {
            Close();
            LayerClosed = null;
            DataReceived = null;
        }

        #endregion
    }
}
