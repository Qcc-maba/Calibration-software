using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace Maba.Calibration
{
    /// <summary>
    /// Desktop / Start-menu entry: restarts backend (service + WebSocket) and webapp via start-all.bat, no console window.
    /// </summary>
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            try
            {
                var exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                if (string.IsNullOrEmpty(exeDir))
                    return;

                var bat = Path.Combine(exeDir, "assets", "start-all.bat");
                if (!File.Exists(bat))
                    return;

                Process.Start(new ProcessStartInfo
                {
                    FileName = bat,
                    WorkingDirectory = Path.GetDirectoryName(bat) ?? exeDir,
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                });
            }
            catch
            {
                // Silent launcher — failures are logged by start-all.bat
            }
        }
    }
}
