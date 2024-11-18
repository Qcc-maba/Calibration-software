using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Common.Models
{
    public class TempRecord
    {
        public const long DATETIME_UNIX_1970_1JAN = 621355968000000000;

        #region properties

        public string SN { get; set; }

        public Common.Models.DeviceRecordMetaData Metadata { get; set; }

        public DateTime RecordDate { get; set; }

        public long RecordDateT { get; set; }

        public string Data { get; set; }

        /*  public string ID
          {
              get
              {
                  return $"{this.SN}-{this.RecordDateT}";
              }
          }*/

        #endregion

        #region ctor(s)
        public TempRecord()
        {

        }

        public TempRecord(DateTime d)
        {
            this.RecordDate = d;
            this.RecordDateT = (d.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond;
        }

        #endregion

        #region public methods

        public byte[] GetData()
        {
            if (String.IsNullOrEmpty(this.Data) || this.Data.Length < 2)
                return new byte[0];

            var len = this.Data.Length;
            var b = new byte[len];
            int index = 0;

            while (index < len)
            {
                b[index] += (byte)(0x10 * parse(this.Data[index]));
                b[index] += parse(this.Data[index]);

                index += 2;
            }

            return b;
        }

        public void SetData(byte[] b)
        {
            var sr = new StringBuilder(b.Length * 2);
            for (int i = 0; i < b.Length; i++)
            {
                sr.Append(new char[] { Convert_High(b[i]), Convert_Low(b[i]) });
            }

            this.Data = sr.ToString();
        }

        #endregion

        #region private methods

        private char Convert_High(byte b)
        {
            var b_h = (byte)(b >> 4);
            if (0 <= b_h && b_h <= 9)
            {
                return (char)('0' + b_h);
            }
            else if (0x0A <= b_h && b_h <= 0x0F)
            {
                return (char)('A' + (b_h - 0x0A));
            }
            else
            {
                return '-';
            }
        }
        private char Convert_Low(byte b)
        {
            var b_h = (byte)(b & 0x0F);
            if (0 <= b_h && b_h <= 9)
            {
                return (char)('0' + b_h);
            }
            else if (0x0A <= b_h && b_h <= 0x0F)
            {
                return (char)('A' + (b_h - 0x0A));
            }
            else
            {
                return '-';
            }
        }
        private byte parse(char ch)
        {
            if ('0' <= ch && ch <= '9')
            {
                return (byte)(ch - '0');
            }
            else if ('A' <= ch && ch <= 'F')
            {
                return (byte)(ch - 'A' + 0x10);
            }
            else if ('a' <= ch && ch <= 'f')
            {
                return (byte)(ch - 'a' + 0x10);
            }
            else
            {
                return 0;
            }
        }

        #endregion
    }
}
