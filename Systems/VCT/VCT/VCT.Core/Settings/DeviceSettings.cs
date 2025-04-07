using Maba.VCT.Common;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core
{
    public class DeviceSettings
    {
        public enum IdentificationTypes : int
        {
            IDN = 0,
            TTI = 1,
            Modbus = 2
        }


        #region Properties
        public IdentificationTypes IdentificationType { get; set; }

        public string SettingsName { get; set; }
        public TimeSpan SessionRequestTimeout_TimeSpan { get; set; }

        public TimeSpan KeepAlive_RXTimeout_TimeSpan { get; set; }

        public TimeSpan ClocksDeviation_TimeSpan { get; set; }
        public int ClocksDeviation_MaxAttempts { get; set; }

        #endregion

        #region Members
        public IPacket IdentificationPacket { get; private set; }
        #endregion


        #region Ctor

        public DeviceSettings()
        {
            SessionRequestTimeout_TimeSpan = TimeSpan.FromMinutes(1);
            KeepAlive_RXTimeout_TimeSpan = TimeSpan.FromMinutes(2);

            ClocksDeviation_TimeSpan = TimeSpan.FromSeconds(5);
            ClocksDeviation_MaxAttempts = 10;

            IdentificationType = IdentificationTypes.IDN;


            switch (IdentificationType)
            {
                case DeviceSettings.IdentificationTypes.IDN:
                    IdentificationPacket = HydraProtocolHelper.Build_ID_Packet();
                    break;
                case DeviceSettings.IdentificationTypes.TTI:
                    IdentificationPacket = HydraProtocolHelper.Build_TTI_ID_Packet();
                    break;
                case DeviceSettings.IdentificationTypes.Modbus:
                    IdentificationPacket = HydraProtocolHelper.Build_OptidewGetDewpoint();
                    break;
                default:
                    break;

            }


        }

        #endregion

        public DeviceSettings Clone()
        {
            var cloned = new DeviceSettings();
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
