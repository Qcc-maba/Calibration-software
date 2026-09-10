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

        /// <summary>Cap for the raw-traffic log. Smaller than server.log's because this records every
        /// byte that arrives, and the most recent couple of megabytes is what a diagnosis needs.</summary>
        internal const long MAX_SERIAL_RX_BYTES = 2L * 1024 * 1024;

        /// <summary>How often the size is actually checked. Calling FileInfo on every received packet
        /// would put a stat call in the serial path; once every few hundred writes bounds the file to
        /// the cap plus a little, which is all that matters.</summary>
        private const int SIZE_CHECK_EVERY = 200;

        /// <summary>Starts at the limit so the very first write checks: a station that comes up with an
        /// already-oversized file should not have to produce another 200 lines before it is trimmed.</summary>
        private static int _writesSinceSizeCheck = SIZE_CHECK_EVERY;

        /// <summary>
        /// Keeps the raw log bounded by moving a large one aside, exactly as the ConsoleHost does for
        /// server.log (see Program.RotateIfTooLarge - deliberately duplicated rather than shared,
        /// because these are different assemblies and this one must not gain a reference for it).
        /// <para>
        /// This file records every byte received on every serial port and is on by default; nothing
        /// has ever trimmed it, one reached 9.87 MB on a development machine, and publish-logs copies
        /// *.log to the share on every launch - so its size is somebody's network transfer too. The
        /// device tick now polls four times as often, which multiplies all of that.
        /// </para>
        /// </summary>
        private static void RotateIfTooLarge(string path)
        {
            if (++_writesSinceSizeCheck < SIZE_CHECK_EVERY) return;
            _writesSinceSizeCheck = 0;

            try
            {
                var current = new FileInfo(path);
                if (!current.Exists || current.Length <= MAX_SERIAL_RX_BYTES) return;

                var previous = Path.Combine(
                    Path.GetDirectoryName(path) ?? string.Empty,
                    Path.GetFileNameWithoutExtension(path) + ".prev" + Path.GetExtension(path));

                if (File.Exists(previous)) File.Delete(previous);
                File.Move(path, previous);
            }
            catch
            {
                // Same rule as the caller: never break the serial path over a log file.
            }
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
                    RotateIfTooLarge(path);
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
