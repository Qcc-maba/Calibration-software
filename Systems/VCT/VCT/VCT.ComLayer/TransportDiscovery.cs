using Maba.VCT.Libs.Trace;
using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace Maba.VCT.ComLayer
{
    /// <summary>
    /// Finds the instruments that are actually attached, so the server does not have to be told about
    /// them one by one.
    /// <para>
    /// Static per-instrument tunnels are what made the configuration brittle: two instruments sharing
    /// a COM port collided, a tunnel for an instrument that had been unplugged wedged the whole device
    /// tick on its bus error, and every new instrument meant editing JSON. Discovery removes all
    /// three, because a link only exists if something answered on it.
    /// </para>
    /// <para>
    /// What it does NOT do is decide which instrument is which — that stays where it belongs, in the
    /// identification chain and the BL cores. Discovery only reports "there is something here, and it
    /// speaks at these settings".
    /// </para>
    /// </summary>
    public static class TransportDiscovery
    {
        #region VISA interop (enumeration only)

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viOpenDefaultRM(out IntPtr sesn);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viFindRsrc(IntPtr sesn, string expr, out IntPtr findList, out int retCnt, StringBuilder desc);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viFindNext(IntPtr findList, StringBuilder desc);

        [DllImport("visa32.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int viClose(IntPtr vi);

        private const int VI_SUCCESS = 0;

        #endregion

        /// <summary>Baud rates tried when probing an unknown serial instrument, most likely first.</summary>
        public static readonly int[] SerialBaudCandidates = { 9600, 115200, 19200, 38400, 57600, 4800, 2400, 1200 };

        /// <summary>
        /// The identification query used to decide whether something is listening. Every instrument on
        /// this bench answers it; one that does not simply is not discovered, and can still be given a
        /// static tunnel.
        /// </summary>
        private const string IdentificationQuery = "*IDN?";

        /// <summary>One discovered link, ready to be turned into a tunnel.</summary>
        public sealed class DiscoveredTransport
        {
            /// <summary>Human-readable name for the tunnel and the logs.</summary>
            public string Name { get; set; }

            /// <summary>The identification reply, when the probe read one.</summary>
            public string Identification { get; set; }

            public string VisaResource { get; set; }
            public int GpibPrimaryAddress { get; set; }
            public string SerialPortName { get; set; }
            public int SerialBaudRate { get; set; }

            public DiscoveredTransport()
            {
                GpibPrimaryAddress = -1;
            }
        }

        /// <summary>
        /// Enumerates every VISA resource matching a filter. Returns an empty list when no VISA runtime
        /// is installed - discovery is best-effort and must never stop the server from starting.
        /// </summary>
        public static List<string> FindVisaResources(string filter)
        {
            var found = new List<string>();
            var rm = IntPtr.Zero;

            try
            {
                if (viOpenDefaultRM(out rm) < VI_SUCCESS)
                    return found;

                var desc = new StringBuilder(512);
                IntPtr findList;
                int count;
                if (viFindRsrc(rm, filter, out findList, out count, desc) < VI_SUCCESS || count <= 0)
                    return found;

                found.Add(desc.ToString());
                for (int i = 1; i < count; i++)
                {
                    var next = new StringBuilder(512);
                    if (viFindNext(findList, next) >= VI_SUCCESS)
                        found.Add(next.ToString());
                }
            }
            catch (DllNotFoundException)
            {
                // No VISA runtime. USB and GPIB discovery are simply unavailable.
            }
            catch (Exception ex)
            {
                Tracer.Info("[Discovery] VISA enumeration failed for '{0}': {1}", filter, ex.Message);
            }
            finally
            {
                if (rm != IntPtr.Zero)
                {
                    try { viClose(rm); } catch (Exception) { }
                }
            }

            return found;
        }

        /// <summary>USB instruments (USBTMC), one transport per resource.</summary>
        public static List<DiscoveredTransport> DiscoverUsb()
        {
            var result = new List<DiscoveredTransport>();
            foreach (var resource in FindVisaResources("USB?*INSTR"))
            {
                result.Add(new DiscoveredTransport
                {
                    Name = "USB " + resource,
                    VisaResource = resource
                });
                Tracer.Info("[Discovery] USB instrument: {0}", resource);
            }
            return result;
        }

        /// <summary>
        /// Instruments answering on the GPIB bus, discovered rather than assumed.
        /// <para>
        /// This is what removes the wedge: the server previously opened a handle for every configured
        /// address whether or not anything was there, and a bus error on an empty address blocked the
        /// device tick for every other instrument. An address that nothing answers on is now simply
        /// never opened.
        /// </para>
        /// </summary>
        public static List<DiscoveredTransport> DiscoverGpib()
        {
            var result = new List<DiscoveredTransport>();
            foreach (var resource in FindVisaResources("GPIB?*INSTR"))
            {
                int address;
                if (!TryParseGpibAddress(resource, out address))
                {
                    Tracer.Info("[Discovery] GPIB resource '{0}' has no address this layer can use - skipped.", resource);
                    continue;
                }

                result.Add(new DiscoveredTransport
                {
                    Name = "GPIB " + address,
                    GpibPrimaryAddress = address
                });
                Tracer.Info("[Discovery] GPIB instrument at address {0} ({1})", address, resource);
            }
            return result;
        }

        /// <summary>
        /// Extracts the primary address from a VISA GPIB resource string ("GPIB0::7::INSTR").
        /// </summary>
        public static bool TryParseGpibAddress(string visaResource, out int address)
        {
            address = -1;
            if (string.IsNullOrEmpty(visaResource))
                return false;

            var parts = visaResource.Split(new[] { "::" }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2)
                return false;

            return int.TryParse(parts[1].Trim(), out address) && address >= 0 && address <= 30;
        }

        /// <summary>
        /// Serial instruments, including their baud rate.
        /// <para>
        /// Baud cannot be enumerated the way a USB or GPIB address can, so each candidate port is
        /// probed: open it, ask <c>*IDN?</c>, and keep the first speed that answers. That is the whole
        /// reason a serial instrument used to need hand-written configuration - the PRODIGIT wanted
        /// 115200 while the Fluke wanted 9600 on the same adapter.
        /// </para>
        /// </summary>
        /// <param name="excludePorts">Ports a static tunnel already claims; never probed.</param>
        /// <param name="candidatePorts">
        /// The ports worth probing. Supply this to keep discovery away from ports that are not
        /// instruments - a Bluetooth serial port in particular can block for many seconds on open,
        /// and probing the two on this bench stretched startup to 46 seconds. The caller knows which
        /// ports are what (it can ask the OS); this layer deliberately does not.
        /// When null, every port the OS reports is probed.
        /// </param>
        /// <param name="probeTimeoutMs">How long to wait for a reply at each speed.</param>
        public static List<DiscoveredTransport> DiscoverSerial(IEnumerable<string> excludePorts = null,
                                                              IEnumerable<string> candidatePorts = null,
                                                              int probeTimeoutMs = 300)
        {
            var result = new List<DiscoveredTransport>();

            var excluded = excludePorts != null
                ? new HashSet<string>(excludePorts.Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p.Trim()),
                                      StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            string[] ports;
            if (candidatePorts != null)
            {
                ports = candidatePorts.Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p.Trim()).ToArray();
            }
            else
            {
                try { ports = SerialPort.GetPortNames(); }
                catch (Exception ex)
                {
                    Tracer.Info("[Discovery] Could not list serial ports: {0}", ex.Message);
                    return result;
                }
            }

            foreach (var port in ports.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (excluded.Contains(port))
                {
                    Tracer.Info("[Discovery] {0}: claimed by a static tunnel - not probed.", port);
                    continue;
                }

                int baud;
                string identification;
                if (ProbeSerialPort(port, probeTimeoutMs, out baud, out identification))
                {
                    result.Add(new DiscoveredTransport
                    {
                        Name = "Serial " + port,
                        SerialPortName = port,
                        SerialBaudRate = baud,
                        Identification = identification
                    });
                    Tracer.Info("[Discovery] Serial instrument on {0} at {1} baud: {2}", port, baud, identification);
                }
            }

            return result;
        }

        /// <summary>
        /// Asks <c>*IDN?</c> on one port at each candidate speed and returns the first that answers.
        /// A port that cannot be opened, or that nothing answers on, is not an error - it is simply
        /// not an instrument.
        /// </summary>
        public static bool ProbeSerialPort(string portName, int timeoutMs, out int baud, out string identification)
        {
            baud = 0;
            identification = null;

            foreach (var candidate in SerialBaudCandidates)
            {
                SerialPort sp = null;
                try
                {
                    sp = new SerialPort(portName, candidate, Parity.None, 8, StopBits.One)
                    {
                        ReadTimeout = timeoutMs,
                        WriteTimeout = timeoutMs,
                        Handshake = Handshake.None,
                        DtrEnable = true,
                        RtsEnable = true
                    };
                    sp.Open();
                    sp.DiscardInBuffer();
                    sp.Write(IdentificationQuery + "\r\n");

                    System.Threading.Thread.Sleep(timeoutMs);

                    if (sp.BytesToRead <= 0)
                        continue;

                    var buffer = new byte[sp.BytesToRead];
                    sp.Read(buffer, 0, buffer.Length);
                    var text = Encoding.ASCII.GetString(buffer).Trim();

                    // A wrong speed produces bytes too, just meaningless ones. Require something that
                    // looks like an identification reply rather than any traffic at all.
                    if (LooksLikeIdentification(text))
                    {
                        baud = candidate;
                        identification = text;
                        return true;
                    }
                }
                catch (Exception)
                {
                    // Port busy, missing, or unreadable at this speed - try the next.
                }
                finally
                {
                    if (sp != null)
                    {
                        try { if (sp.IsOpen) sp.Close(); } catch (Exception) { }
                        sp.Dispose();
                    }
                }
            }

            return false;
        }

        /// <summary>
        /// True when a reply plausibly is an identification string rather than line noise from a
        /// mismatched baud rate. Framing errors produce high-bit bytes and control characters, so
        /// requiring mostly printable ASCII separates the two reliably.
        /// </summary>
        public static bool LooksLikeIdentification(string reply)
        {
            if (string.IsNullOrWhiteSpace(reply))
                return false;

            var trimmed = reply.Trim();
            if (trimmed.Length < 3)
                return false;

            var printable = trimmed.Count(c => c >= 0x20 && c <= 0x7E);
            if (printable < trimmed.Length * 0.9)
                return false;

            // Must carry at least one letter - a run of digits or punctuation is not an identity.
            return trimmed.Any(char.IsLetter);
        }
    }
}
