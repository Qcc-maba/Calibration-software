using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.Core.Device.OTA;

namespace Hydra2.VCT.Core.Device.OTA
{
    public class OTAItem
    {
        #region properties

        public OTA_Metadata Metadata { get; internal set; }

        public byte[] Data { get; internal set; }

        public string LocalOTAData_FileName { get; internal set; }

        #endregion

        #region ctor

        public OTAItem()
        {

        }

        #endregion
    }
}
