using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.Hosts.ConsoleHost
{
    class Program
    {
        [MTAThread]
        static void Main(string[] args)
        {
            VCT.Libs.Trace.Tracer.Info("Maba CommServer Console-Host....");
            VCT.Libs.Trace.Tracer.Info("-".PadRight(40, '-'));

            try
            {
                #region DIGI server

                //var digiSettings = DIGI.APIProtocol.Settings.DigiSettings.Read();

                //if (digiSettings.Tunnels == null || digiSettings.Tunnels.Length == 0)

                //{
                //    digiSettings = DIGI.APIProtocol.Settings.DigiSettings.CreateDefaultSettings();
                //    digiSettings.Save();
                //}

                #endregion

                #region VCT settings

                var vctSettings = VCT.Core.Settings.VCTSettings.Read();

                if (vctSettings.Tunnels == null || vctSettings.Tunnels.Length == 0
                    || vctSettings.DeviceSettings == null || vctSettings.DeviceSettings.Length == 0)

                {
                    vctSettings = VCT.Core.Settings.VCTSettings.CreateDefaultSettings();
                    vctSettings.Save();
                }

                #endregion

                #region Com server settings

                var settings = CommServer.Core.Settings.ComServerSettings.CreateDefaultSettings();

                #region Modules

                if (settings.Modules == null || settings.Modules.Length == 0)
                {
                    settings.Modules = new Core.Module[]
                    {
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.Hydra2BLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.Hydra2BLCore).FullName
                        }
                    };

                    settings.Save();
                }

                #endregion

                #endregion

                var comServer = new Core.MultiBLCommServer();
                comServer.Start();

                VCT.Libs.Trace.Tracer.Info();
                VCT.Libs.Trace.Tracer.Info("Work forever...");

                while (true)
                {
                }
            }
            catch (Exception e)
            {
                VCT.Libs.Trace.Tracer.Exception("Failed to run CommsServer", e);

                Console.WriteLine("Press Any key to exit....");

                Console.ReadLine();
            }

        }
    }
}
