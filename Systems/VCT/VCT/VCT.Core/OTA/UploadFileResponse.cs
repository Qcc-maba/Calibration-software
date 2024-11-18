using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device.OTA
{
    public class UploadFileResponse :  Common.API.BaseResponse
    {
        #region Members

        public Version FileVersion { get; set; }

        public string FileCode { get; private set; }

        public ushort CRC16 { get; internal set; }

        public long FileSize { get; internal set; }

        public Errors? LastError { get; private set; }
        //public string LastError { get; private set; }

        #endregion

        #region Enum

        public enum Errors : byte
        {
            Already_Exists_Locally = 0x00,
            Bad_Request = 0x01
            //DEFAULT = 0xFF
        }

        #endregion

        #region Ctor

        public UploadFileResponse(OTA_Metadata originalMetadata, bool result, Errors? lastError = null)
        {
            this.FileVersion = originalMetadata.FileVersion;
            this.FileCode = originalMetadata.FileCode;
            this.FileSize = originalMetadata.FileSize;
            this.CRC16 = originalMetadata.CRC16;

            this.Result = result;

            LastError = lastError;
        }

        #endregion
    }
}
