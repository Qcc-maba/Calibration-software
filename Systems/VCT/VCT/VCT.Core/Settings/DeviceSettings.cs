using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core
{
    public class VCTDeviceSettings
    {
        #region Properties

        public string SettingsName { get; set; }
        public TimeSpan SessionRequestTimeout_TimeSpan { get; set; }

        public TimeSpan KeepAlive_RXTimeout_TimeSpan { get; set; }

        public TimeSpan ClocksDeviation_TimeSpan { get; set; }
        public int ClocksDeviation_MaxAttempts { get; set; }

        #endregion

        #region Ctor

        public VCTDeviceSettings()
        {
            SessionRequestTimeout_TimeSpan = TimeSpan.FromMinutes(1);
            KeepAlive_RXTimeout_TimeSpan = TimeSpan.FromMinutes(2);

            ClocksDeviation_TimeSpan = TimeSpan.FromSeconds(5);
            ClocksDeviation_MaxAttempts = 10;
        }

        #endregion

        public VCTDeviceSettings Clone()
        {
            var cloned = new VCTDeviceSettings();
            var properties = this.GetType()
                .GetProperties(System.Reflection.BindingFlags.Public);

            foreach (var p in properties)
            {
                p.SetValue(cloned, p.GetValue(this));
            }

            return cloned;
        }
    }
}
