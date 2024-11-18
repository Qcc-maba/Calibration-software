using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL.UnitTest
{
    public class MyRecord
    {
        public long RecordID_64 { get; set; }
        public int RecordID_32 { get; set; }
        public DateTime CreationDate { get; set; }
        public bool IsEnabled { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public byte StationNumber { get; set; }
        public decimal Flow { get; set; }
        public byte[] Data { get; set; }
        public int? RecordID_Null { get; set; }
        public Int16 ProgramNumber { get; set; }


        public string LastName0 { get; set; }
        public bool IsEnabled0 { get; set; }
        public int RecordID_320 { get; set; }

        public override string ToString()
        {
            return String.Format("{0} :: {1}-{2}", this.RecordID_64, FirstName, LastName);
        }

        public override bool Equals(object obj)
        {
            var o2 = obj as MyRecord;
            if (o2 == null)
                return false;

            return o2.RecordID_64 == this.RecordID_64
                && o2.RecordID_32 == this.RecordID_32
                && this.CreationDate.ToString() == (o2.CreationDate).ToString()
                && o2.IsEnabled == this.IsEnabled
                && o2.FirstName == this.FirstName
                && o2.ProgramNumber == this.ProgramNumber
                && o2.RecordID_Null == this.RecordID_Null
                && o2.StationNumber == this.StationNumber
                && o2.Flow == this.Flow
                && Eqauls(o2.Data, this.Data);
        }

        private bool Eqauls(byte[] b1, byte[] b2)
        {
            if (b1 == null && b2 != null)
                return false;
            if (b1 != null && b2 == null)
                return false;
            if (b1.Length != b2.Length)
                return false;

            for (int i = 0; i < b1.Length; i++)
            {
                if (b1[i] != b2[i])
                    return false;
            }

            return true;
        }

        public override int GetHashCode()
        {
            return base.GetHashCode();
        }
    }
}
