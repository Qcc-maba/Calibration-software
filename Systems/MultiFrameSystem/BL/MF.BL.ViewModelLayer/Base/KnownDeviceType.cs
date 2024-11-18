using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Base
{
    public class KnownDeviceType
    {
        public string SN_Pattern { get; set; }

        public string[] SN_Examples { get; set; }

        public string DeviceTypeName { get; set; }

        public string Remote_API_URL { get; set; }

        public bool IsMatch(string SN)
        {
            return Regex.IsMatch(SN, this.SN_Pattern);
        }


        public string BuildURL_ActivateSN(string SN)
        {
            return $"{this.Remote_API_URL}/Inter/{SN}/Activate";
        }
        public string BuildURL_VerifySN(string SN)
        {
            return $"{this.Remote_API_URL}/Inter/{SN}/Verify";
        }

        public string BuildURL_UpdateDeviceLocation(string SN, string lat, string lon)
        {
            return $"{this.Remote_API_URL}/Inter/{SN}/Location?lat={lat}&lon={lon}";
        }
    }
}
