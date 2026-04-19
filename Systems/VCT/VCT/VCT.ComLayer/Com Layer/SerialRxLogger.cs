using System;
using System.IO;
using System.Text;

namespace Maba.VCT.ComLayer
{
    /// <summary>
    /// Appends raw bytes received from serial ports to ../logs/serial-rx.log (same layout as ConsoleHost install).
    /// Disable by setting environment variable CALIBRATION_LOG_SERIAL_RX=0
    /// </summary>
    internal static class SerialRxLogger
    {
        private static readonly object FileLock = new object();

        private static bool IsEnabled()
        {
            var v = Environment.GetEnvironmentVariable("CALIBRATION_LOG_SERIAL_RX");
            if (string.IsNullOrEmpty(v)) return true;
            return !v.Equals("0", StringComparison.OrdinalIgnoreCase) &&
                   !v.Equals("false", StringComparison.OrdinalIgnoreCase);
        }

        private static string GetLogsDirectory()
        {
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var logsDir = Path.Combine(baseDir, "..", "logs");
            try
            {
                Directory.CreateDirectory(logsDir);
                return Path.GetFullPath(logsDir);
            }
            catch
            {
                return baseDir;
            }
        }

        private static string FormatPayload(byte[] buffer, int offset, int count)
        {
            const int maxBytes = 768;
            var n = Math.Min(count, maxBytes);
            if (n <= 0) return string.Empty;

            var hex = new StringBuilder(n * 3);
            for (var i = 0; i < n; i++)
            {
                if (i > 0) hex.Append(' ');
                hex.Append(buffer[offset + i].ToString("X2"));
            }

            var printable = new StringBuilder(n);
            for (var i = 0; i < n; i++)
            {
                var b = buffer[offset + i];
                printable.Append(b >= 0x20 && b < 0x7F ? (char)b : '.');
            }

            var suffix = count > maxBytes ? $" ... (+{count - maxBytes} bytes)" : string.Empty;
            return hex + " | " + printable + suffix;
        }

        public static void Append(string portName, byte[] buffer, int offset, int count)
        {
            if (!IsEnabled() || count <= 0 || buffer == null) return;
            try
            {
                var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}\t{portName ?? "?"}\t{FormatPayload(buffer, offset, count)}";
                lock (FileLock)
                {
                    var path = Path.Combine(GetLogsDirectory(), "serial-rx.log");
                    File.AppendAllText(path, line + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch
            {
                // Never break serial path on log failure
            }
        }
    }
}
