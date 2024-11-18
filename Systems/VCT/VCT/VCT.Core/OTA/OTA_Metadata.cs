using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.VCT.Core.Device.OTA
{
    public class OTA_Metadata
    {
        #region properties

        public string FileCode { get; set; }
        public ushort CRC16 { get; set; }
        public DateTime CreationDate { get; set; }
        public Version FileVersion { get; set; }
        public long FileSize { get; set; }

        #endregion

        #region Read / Write file

        public void Save(string path)
        {
            using (var sf = new FileStream(path, FileMode.Create))
            {
                var xr = new XmlSerializer(this.GetType());
                xr.Serialize(sf, this);
            }
        }

        public static OTA_Metadata Read(string path)
        {
            //if not exists
            if (!File.Exists(path))
                return null;

            using (var sf = new FileStream(path, FileMode.Open))
            {
                var xr = new XmlSerializer(typeof(OTA_Metadata));
                var y = xr.Deserialize(sf);
                var z = (OTA_Metadata)y;
                return z;
            }
        }

        #endregion
    }
}
