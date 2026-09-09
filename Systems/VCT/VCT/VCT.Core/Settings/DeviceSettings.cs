using Maba.VCT.Common;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
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
        /// <summary>Built from <see cref="IdentificationType"/>; not stored in VCT.json (IPacket is not JSON-deserializable).</summary>
        [JsonIgnore]
        public IPacket IdentificationPacket { get; private set; }
        #endregion


        #region Ctor

        public DeviceSettings(IdentificationTypes identificationType = IdentificationTypes.IDN)
        {
            SessionRequestTimeout_TimeSpan = TimeSpan.FromMinutes(1);
            KeepAlive_RXTimeout_TimeSpan = TimeSpan.FromMinutes(2);

            ClocksDeviation_TimeSpan = TimeSpan.FromSeconds(5);
            ClocksDeviation_MaxAttempts = 10;

            IdentificationType = identificationType;
            ApplyIdentificationPacketForType();
        }

        /// <summary>After Newtonsoft deserializes <see cref="IdentificationType"/> and timeouts from disk, rebuild the packet (ignored on wire).</summary>
        [OnDeserialized]
        private void OnDeserialized(StreamingContext context)
        {
            ApplyIdentificationPacketForType();
        }

        private void ApplyIdentificationPacketForType()
        {
            switch (IdentificationType)
            {
                case IdentificationTypes.IDN:
                    IdentificationPacket = HydraProtocolHelper.Build_ID_Packet();
                    break;
                case IdentificationTypes.TTI:
                    IdentificationPacket = HydraProtocolHelper.Build_TTI_ID_Packet();
                    break;
                case IdentificationTypes.Modbus:
                    IdentificationPacket = HydraProtocolHelper.Build_OptidewGetDewpoint();
                    break;
                default:
                    IdentificationPacket = HydraProtocolHelper.Build_ID_Packet();
                    break;
            }
        }

        #endregion

        public DeviceSettings Clone()
        {
            var cloned = new DeviceSettings();
            var properties = this.GetType()
                .GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);

            foreach (var p in properties)
            {
                if (!p.CanRead || !p.CanWrite)
                    continue;
                p.SetValue(cloned, p.GetValue(this));
            }

            return cloned;
        }
    }
}
