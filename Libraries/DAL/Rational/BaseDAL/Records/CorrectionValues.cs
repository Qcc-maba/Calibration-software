using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL.Records
{
    public class CorrectionValues
    {

        #region Members
        public double TemperatureValue { get; set; }
        public double Deviation { get; set; }
        public double HumidityValue { get; set; }
        #endregion

    }
}
