using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Management;
using System.Text.RegularExpressions;

namespace Maba.VCT.CommServer.Monitor
{
    /// <summary>
    /// A serial port plus its human-friendly device name (e.g. "COM3 — Prolific USB-to-Serial Comm Port"),
    /// so the user can tell a real USB adapter from a virtual Bluetooth COM port in the dropdown.
    /// </summary>
    public class SerialPortInfo
    {
        public string PortName { get; set; }
        public string Description { get; set; }

        public override string ToString()
        {
            return string.IsNullOrEmpty(Description) || Description == PortName
                ? PortName
                : PortName + " — " + Description;
        }

        /// <summary>Present COM ports, enriched with friendly names via WMI. Falls back to bare names.</summary>
        public static List<SerialPortInfo> List()
        {
            var ports = SerialPort.GetPortNames()
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(p => p, StringComparer.OrdinalIgnoreCase)
                .Select(p => new SerialPortInfo { PortName = p, Description = p })
                .ToList();

            try
            {
                var rx = new Regex(@"\((COM\d+)\)", RegexOptions.IgnoreCase);
                using (var searcher = new ManagementObjectSearcher(
                    "SELECT Name FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                using (var results = searcher.Get())
                {
                    foreach (ManagementObject mo in results)
                    {
                        var name = mo["Name"] as string;
                        if (string.IsNullOrEmpty(name)) continue;

                        var match = rx.Match(name);
                        if (!match.Success) continue;

                        var port = match.Groups[1].Value;
                        var info = ports.FirstOrDefault(
                            x => string.Equals(x.PortName, port, StringComparison.OrdinalIgnoreCase));
                        if (info != null)
                            info.Description = rx.Replace(name, "").Trim(); // strip the "(COMx)" suffix
                    }
                }
            }
            catch
            {
                // WMI unavailable / access denied — keep the bare port names already populated.
            }

            return ports;
        }
    }
}
