using System;
using System.Diagnostics.CodeAnalysis;
using System.ServiceProcess;

namespace Maba.VCT.CommServer.Hosts.ConsoleHost
{
    [ExcludeFromCodeCoverage]
    public class CalibrationService : ServiceBase
    {
        private CommServer.Core.MultiBLCommServer _comServer;

        public CalibrationService()
        {
            ServiceName = "MabaCalibrationServer";
            CanStop = true;
            CanPauseAndContinue = false;
            AutoLog = true;
        }

        protected override void OnStart(string[] args)
        {
            try
            {
                // Set working directory to exe location so relative paths work
                System.IO.Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);

                // Set up logging before anything else
                Program.SetupLogging();

                VCT.Libs.Trace.Tracer.Info("CalibrationService OnStart - running as Windows Service");
                VCT.Libs.Trace.Tracer.Info("Base directory: {0}", AppDomain.CurrentDomain.BaseDirectory);
                VCT.Libs.Trace.Tracer.Info("Working directory: {0}", System.IO.Directory.GetCurrentDirectory());

                var vctSettings = VCT.Core.Settings.VCTSettings.Read();
                if (vctSettings.Tunnels == null || vctSettings.Tunnels.Length == 0
                    || vctSettings.DeviceSettings == null || vctSettings.DeviceSettings.Length == 0)
                {
                    vctSettings = VCT.Core.Settings.VCTSettings.CreateDefaultSettings();
                    vctSettings.Save();
                }

                var settings = CommServer.Core.Settings.ComServerSettings.CreateDefaultSettings();
                if (settings.Modules == null || settings.Modules.Length == 0)
                {
                    settings.Modules = new Core.Module[]
                    {
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.Hydra2BLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.Hydra2BLCore).FullName
                        },
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.Datron9100BLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.Datron9100BLCore).FullName
                        }
                    };
                    settings.Save();
                }

                _comServer = new CommServer.Core.MultiBLCommServer();
                var hasTunnels = vctSettings.Tunnels != null && vctSettings.Tunnels.Length > 0;
                _comServer.Start(deferHardwareIdentificationUntilEnabled: hasTunnels);
                if (hasTunnels)
                {
                    VCT.Libs.Trace.Tracer.Info(
                        "[STARTUP] Identification paused until WebSocket CMD:\"Status\", Value:\"Start\" (same as console host).");
                }

                VCT.Libs.Trace.Tracer.Info("CalibrationService started successfully.");
            }
            catch (Exception e)
            {
                VCT.Libs.Trace.Tracer.Exception("CalibrationService OnStart FAILED", e);
                // Also write to Windows Event Log as fallback
                try
                {
                    System.Diagnostics.EventLog.WriteEntry("MabaCalibrationServer",
                        $"Service start FAILED: {e.GetType().Name}: {e.Message}\nStack: {e.StackTrace}",
                        System.Diagnostics.EventLogEntryType.Error);
                }
                catch (Exception logEx)
                {
                    System.Diagnostics.Debug.WriteLine("[CalibrationService] EventLog fallback failed: " + logEx.Message);
                }
                throw;
            }
        }

        protected override void OnStop()
        {
            VCT.Libs.Trace.Tracer.Info("CalibrationService stopping...");
            if (_comServer != null)
            {
                _comServer.Stop();
                _comServer = null;
            }
            VCT.Libs.Trace.Tracer.Info("CalibrationService stopped.");
        }
    }
}
