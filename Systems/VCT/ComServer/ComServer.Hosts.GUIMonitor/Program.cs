using System;
using System.Windows.Forms;

namespace Maba.VCT.CommServer.Monitor
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new FormMain());
            }
            catch (Exception e)
            {
                Libs.Trace.Tracer.Info(e.Message);
            }
        }
    }
}
